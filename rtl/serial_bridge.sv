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
            bit_cnt <= 5'b00000;
        end else begin
            state <= next_state;
            // Increment counter only when data is being transmitted
            bit_cnt <= (state == IDLE || state == WR_END || state == WAIT) ? 5'b00000 : bit_cnt + 1;
        end
    end

    //================================================
    // Serial bridge logic
    //================================================
    always_comb begin
        // Default values
        sctrl = 1'b0;
        next_state = state;

        case (state)
            IDLE: begin
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
                // Get data from RAM A at the start
                if (!bit_cnt) begin
                    wr_buf = rd_data;
                    rd_en = 1'b0;
                end
                // When each 8th bit reached - set pause by WR_END state
                sdata = wr_buf[bit_cnt]; // LSB send
                next_state = (bit_cnt[2:0] == 3'b111) ? WR_END : WRITE;
            end

            WR_END: begin
                // If bit counter is full - write has ended
                if (bit_cnt == 5'b11111) begin
                    // End if it is a write transaction
                    if (sready) begin
                        sctrl = 0;
                        next_state = IDLE;
                    end else // Continue if it is a read transaction
                        next_state = WAIT;

                end else // Else - batch has ended
                    next_state = WRITE;
            end

            WAIT: begin
                // Waiting until sready
                // Recieving read data by MSB
                rd_buf = {rd_buf[30:0], sdata};
                if (sready) begin
                    // Read has finished
                    sctrl = 0;
                    next_state = RD_END;
                    // Send data to RAM B
                    wr_en = 1'b1;
                    wr_data = rd_buf;
                end
            end

            RD_END: begin
                // Finish read operation
                wr_en = 1'b0;
                next_state = IDLE;
            end

        endcase
    end
    
endmodule