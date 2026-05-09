`include "constants.sv"

module serial_bridge (
    // Serial Master interface
    input  logic sclk,
    input  logic srst,
    inout  wire  sdata,
    output logic sctrl,
    input  logic sready,
    
    // Read RAM Interface (RAM A - for reading)
    output logic                  rd_en,
    input  logic                  rd_valid,
    input  logic [DATA_WIDTH-1:0] rd_data,
    input  logic                  rd_empty,
    
    // Write RAM Interface (RAM B - for writing)
    output logic                  wr_en,
    output logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  wr_full
);
    
    //================================================
    // State encoding
    //================================================
    typedef enum logic [2:0] {
        IDLE,
        SETUP,
        WRITE,
        WR_END,
        WAIT,
        RD_END
    } state_t;

    state_t state = IDLE;
    state_t next_state = IDLE;

    //================================================
    // Inner counters and buffers
    //================================================
    logic [4:0] bit_cnt;    // Bit counter (0..31) for 32-bit word
    logic [31:0] wr_buf;    // Write buffer
    logic [31:0] rd_buf;    // Read buffer

    //================================================
    // State continuous assignment and reset
    //================================================
    always_ff @(posedge sclk or negedge srst) begin
        if (!srst) begin
            state <= IDLE;
            bit_cnt <= 5'b0;
            rd_buf <= 32'b0;
            wr_buf <= 32'b0;
        end else begin
            state <= next_state;
            // Increment counter only when data is being transmitted
            if (state == IDLE || state == WAIT)
                bit_cnt <= 5'b00000;
            else if (state == WRITE)
                bit_cnt <= bit_cnt + 1;
            
            // Read word during WAIT phase
            if ((state == WAIT || state == RD_END) && sdata !== 1'bz)
                rd_buf <= {rd_buf[30:0], sdata};

            // Get data from RAM A at the start
            if (state == WRITE && bit_cnt == 5'b0)
                wr_buf <= rd_data;
        end
    end

    //================================================
    // Serial bridge logic
    //================================================
    // Send data via serial in write phase
    assign sdata = (state == WRITE) ? wr_buf[bit_cnt] : 1'bz; // LSB send

    always_comb begin
        // Default values
        next_state = state;
        rd_en = 1'b0;
        wr_en = 1'b0;
        wr_data = 32'b0;

        case (state)
            IDLE: begin
                sctrl = 1'b0;
                // Start transaction if there is pending data
                if (!rd_empty) begin
                    sctrl = 1'b1;
                    next_state = WRITE;
                    // Start reading data from RAM A
                    rd_en = 1'b1;
                end
            end

            WRITE: begin
                // Start write transaction
                sctrl = 1'b1;
                // When each 8th bit reached - set pause by WR_END state
                next_state = (bit_cnt[2:0] == 3'b111) ? WR_END : WRITE;
            end

            WR_END: begin
                sctrl = 1'b1;
                // If bit counter has cycled - write has ended
                if (bit_cnt == 5'b00000) begin
                    // End if it is a write transaction
                    if (wr_buf[31] == 1'b0) begin
                        sctrl = 1'b0;
                        next_state = IDLE;
                    end else begin // Continue if it is a read transaction
                        next_state = WAIT;
                    end
                end else begin // Else - batch has ended
                    next_state = WRITE;
                end
            end

            WAIT: begin
                sctrl = 1'b1;
                // Waiting until sready
                if (sready) begin
                    // Read has finished
                    next_state = RD_END;
                end
            end

            RD_END: begin
                // Send data to RAM B
                wr_en = 1'b1;
                wr_data = rd_buf;
                // Finish read operation
                sctrl = 1'b0;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end
    
endmodule