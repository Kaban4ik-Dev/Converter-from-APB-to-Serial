`include "constants.sv"

module apb_bridge (
    // APB Slave Interface
    input  logic        PCLK,       // System clock
    input  logic        PRESETn,    // System reset
    input  logic [31:0] PADDR,      // Address in converter where to write 
    input  logic [1:0]  PPROT,      // Protection type
    input  logic        PSEL,       // Select current slave
    input  logic        PENABLE,    // Enable current slave
    input  logic        PWRITE,     // Write = 1, read = 0
    input  logic [31:0] PWDATA,     // Data to write
    input  logic [3:0]  PSTRB,      // Bytes to override
    output logic        PREADY,     // Slave ready
    output logic [31:0] PRDATA,     // Data to read
    output logic        PSLVERR,    // Slave error
    
    // Write RAM Interface (RAM A - for writing)
    output logic                  wr_en,
    output logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  wr_full,
    
    // Read RAM Interface (RAM B - for reading)
    output logic                  rd_en,
    input  logic                  rd_valid,
    input  logic [DATA_WIDTH-1:0] rd_data,
    input  logic                  rd_empty
);

    //================================================
    // State encoding
    //================================================
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        WAIT   = 2'b10,
        ACCESS = 2'b11
    } state_t;
    
    state_t apb_state = IDLE;
    state_t apb_next_state = IDLE;
    
    //================================================
    // State continuous assignment and reset
    //================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            apb_state <= IDLE;
        else
            apb_state <= apb_next_state;
    end

    //================================================
    // Apb bridge logic
    //================================================
    always_comb begin
        PREADY = 1'b0;
        wr_en = 1'b0;
        wr_data = '0;
        rd_en = 1'b0;
        PRDATA = '0;
        PSLVERR = 1'b0;
        apb_next_state = apb_state;
        
        case (apb_state)
            IDLE: begin
                if (PSEL && !PENABLE) begin
                    PREADY = 1'b0;
                    apb_next_state = SETUP;
                end
            end
            
            SETUP: begin
                if (PSEL && PENABLE) begin
                    apb_next_state = WAIT;
                end else begin
                    apb_next_state = IDLE;
                end
            end

            WAIT: begin
                // Write operation
                if (PWRITE) begin
                    // Write data if there is enough space
                    if (!wr_full) begin
                        wr_en = 1'b1;
                        wr_data = PWDATA;
                        apb_next_state = ACCESS;
                        PREADY = 1'b1;
                    end else begin // Wait until there is enough space
                        apb_next_state = WAIT;
                    end
                end else begin // Read operation
                    // Start reading operation if data exists
                    if (!rd_empty) begin
                        rd_en = 1'b1;
                        apb_next_state = ACCESS;
                        PREADY = 1'b0;
                    end else begin // Wait until there is data to read
                        apb_next_state = WAIT;
                    end
                end
                
            end
            
            ACCESS: begin
                // Write operation finish
                if (PWRITE) begin
                    PREADY = 1'b0;
                    apb_next_state = IDLE;
                end else if (rd_valid) begin // Read operation finish
                    PREADY = 1'b1;
                    PRDATA = rd_data;
                    apb_next_state = IDLE;
                end else begin
                    PREADY = 1'b0;
                    apb_next_state = IDLE;
                end
            end
        endcase
    end
endmodule