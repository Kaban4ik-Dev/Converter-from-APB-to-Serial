`include "constants.sv"

module ram_manager (
    input  logic clk,
    input  logic rst,       // Reset all to null
    
    input  logic op,        // Operation 0 - read, 1 - write
    input  logic rst_c,     // Reset (free) cell
    input  logic [ADDR_WIDTH-1:0] addr,  // Address to read/write
    input  logic [DATA_WIDTH-1:0] wdata, // Write data
    output logic [DATA_WIDTH-1:0] rdata, // Read data
    
    output logic isfree,                 // Is there any free cell
    output logic [ADDR_WIDTH-1:0] faddr  // Address of free cell
);
    // ======= RAM =======
    logic [DATA_WIDTH-1:0] memory [0:RAM_CELLS_COUNT-1];
    
    // ======= Empty cells =======
    logic free [0:RAM_CELLS_COUNT-1];  // 1 - free, 0 - in use
    
    // Combinatorial search for the first free address
    always_comb begin
        faddr = 0;
        isfree = 1'b0;
        for (int i = 0; i < RAM_CELLS_COUNT; i++) begin
            if (free[i]) begin
                faddr = i;
                isfree = 1'b1;
                break;
            end
        end
    end
    
    // Reading data
    always_comb begin
        if (op == 1'b0) begin
            rdata = memory[addr];
        end else begin
            rdata = '0;
        end
    end
    
    // Writing data
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < RAM_CELLS_COUNT; i++) begin
                memory[i] <= '0;
                free[i] <= 1'b1; // Setting all cells to "free" state
            end
        end else begin
            // Resetting a specific cell
            if (rst_c) begin
                free[addr] <= 1'b1;
                // memory[addr] <= '0;  // Optional
            end
            
            // Writing operation
            if (op == 1'b1) begin
                memory[addr] <= wdata;
                free[addr] <= 1'b0;  // Setting cell to "occupied" state
            end
        end
    end

endmodule