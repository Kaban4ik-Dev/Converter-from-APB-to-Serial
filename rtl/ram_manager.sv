`include "constants.sv"

//====================================================
// RAM Manager - Circular Buffer with Dual-Port RAM
// Async clock domains with Gray-code CDC
//====================================================
module ram_manager (
    // Clock domain A (write side - APB)
    input  logic    clk_wr,
    // Clock domain B (read side - Serial)
    input  logic    clk_rd,
    // Reset signal
    input  logic    rst,
    
    // Write interface (clk_wr domain)
    input  logic                     wr_en,
    input  logic [DATA_WIDTH-1:0]    wr_data,
    output logic                     wr_full,
    
    // Read interface (clk_rd domain)
    input  logic                     rd_en,
    output logic [DATA_WIDTH-1:0]    rd_data,
    output logic                     rd_empty
);

    // ============================================
    // 1. Dual-Port RAM
    // ============================================
    logic [DATA_WIDTH-1:0] ram [0:RAM_CELLS_COUNT-1]; // RAM memory
    
    logic [ADDR_WIDTH-1:0] ram_wr_addr;  // Address for writing to dual-port RAM (selects which word to write)
    logic                  ram_wr_en;    // Write enable for RAM port A (active high)
    logic [ADDR_WIDTH-1:0] ram_rd_addr;  // Address for reading from dual-port RAM (selects which word to read)
    logic [DATA_WIDTH-1:0] ram_rd_data;  // Data output from RAM port B (valid one cycle after ram_rd_addr changes)
    
    // Port A - Write (clk_wr)
    always_ff @(posedge clk_wr) begin
        if (ram_wr_en)
            ram[ram_wr_addr] <= wr_data;
    end
    
    // Port B - Read (clk_rd)
    always_ff @(posedge clk_rd) begin
        ram_rd_data <= ram[ram_rd_addr];
    end
    
    assign rd_data = ram_rd_data;
    
    
    // ============================================
    // 2. Pointers to read and write cells
    // ============================================
    logic [PTR_WIDTH-1:0] wr_ptr_bin;      // Write pointer (binary)
    logic [PTR_WIDTH-1:0] rd_ptr_bin;      // Read pointer (binary)
    
    logic [PTR_WIDTH-1:0] wr_ptr_gray;     // Write pointer (Gray)
    logic [PTR_WIDTH-1:0] rd_ptr_gray;     // Read pointer (Gray)
    
    
    // ============================================
    // 3. Write pointer update (clk_wr domain)
    // ============================================

    // Increment control for write pointer: only advance when write is requested AND buffer is not full
    logic wr_ptr_inc;
    assign wr_ptr_inc = wr_en && !wr_full;

    // Binary write pointer update on write clock
    // Reset to zero, then increment by 1 on each valid write operation
    always_ff @(posedge clk_wr or posedge rst) begin
        if (rst)
            wr_ptr_bin <= '0;                 // Reset pointer to start of circular buffer
        else if (wr_ptr_inc)
            wr_ptr_bin <= wr_ptr_bin + 1'b1;  // Advance to next word position (increment by 1)
    end
    
    // Binary to Gray conversion
    assign wr_ptr_gray = (wr_ptr_bin >> 1) ^ wr_ptr_bin;
    
    
    // ============================================
    // 4. Read pointer update (clk_rd domain)
    // ============================================

    // Increment control for read pointer: only advance when read is requested AND buffer is not empty
    logic rd_ptr_inc;
    assign rd_ptr_inc = rd_en && !rd_empty;

    // Binary read pointer update on read clock
    // Reset to zero, then increment by 1 on each valid read operation
    // Tracks how many words have been read from the circular buffer
    always_ff @(posedge clk_rd or posedge rst) begin
        if (rst)
            rd_ptr_bin <= '0;                 // Reset pointer to start of circular buffer
        else if (rd_ptr_inc)
            rd_ptr_bin <= rd_ptr_bin + 1'b1;  // Advance to next word position after reading
    end

    // Binary to Gray code conversion for read pointer
    // Gray code ensures only 1 bit changes between consecutive values
    // Critical for safe CDC (Clock Domain Crossing) without metastability
    // Formula: gray = (binary >> 1) XOR binary
    assign rd_ptr_gray = (rd_ptr_bin >> 1) ^ rd_ptr_bin;
    
    
    // ============================================
    // 5. Gray-code synchronizers (2-stage flip-flops)
    // ============================================

    // Synchronized Gray-coded pointers after crossing clock domains
    // These values are stable and metastability-free in their respective destination domains
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync;
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync;

    // ============================================
    // Synchronize read pointer (clk_rd -> clk_wr)
    // ============================================
    // First stage flip-flop: samples asynchronous Gray-coded read pointer
    // May be metastable, but Gray code minimizes transition bits
    logic [PTR_WIDTH-1:0] rd_ptr_gray_sync_meta;
    always_ff @(posedge clk_wr or posedge rst) begin
        if (rst) begin
            rd_ptr_gray_sync_meta <= '0;  // Reset metastability stage
            rd_ptr_gray_sync <= '0;       // Reset synchronized pointer
        end else begin
            rd_ptr_gray_sync_meta <= rd_ptr_gray;      // First stage: (may be metastable)
            rd_ptr_gray_sync <= rd_ptr_gray_sync_meta; // Second stage: removes metastability
        end
    end

    // ============================================
    // Synchronize write pointer (clk_wr -> clk_rd)
    // ============================================
    // First stage flip-flop: samples asynchronous Gray-coded write pointer
    // Two-flop synchronizer ensures safe crossing into read clock domain
    logic [PTR_WIDTH-1:0] wr_ptr_gray_sync_meta;
    always_ff @(posedge clk_rd or posedge rst) begin
        if (rst) begin
            wr_ptr_gray_sync_meta <= '0;  // Reset metastability stage
            wr_ptr_gray_sync <= '0;       // Reset synchronized pointer
        end else begin
            wr_ptr_gray_sync_meta <= wr_ptr_gray;      // First stage: (may be metastable)
            wr_ptr_gray_sync <= wr_ptr_gray_sync_meta; // Second stage: removes metastability
        end
    end
    
    
    // ============================================
    // 6. Gray to Binary conversion (combinatorial)
    // ============================================

    // Algorithm: MSB stays same, each subsequent bit = XOR of previous bin bit and current gray bit
    // Critical for comparing pointers after CDC (can't compare Gray values directly)
    function automatic logic [PTR_WIDTH-1:0] gray_to_bin;
        input logic [PTR_WIDTH-1:0] gray;  // Gray-coded input value (from synchronized pointer)
        logic [PTR_WIDTH-1:0] bin;         // Binary output to be computed
        integer i;                         // Loop index for bit-by-bit conversion
        begin
            bin[PTR_WIDTH-1] = gray[PTR_WIDTH-1];  // Most significant bits are identical
            for (i = PTR_WIDTH-2; i >= 0; i--)     // Iterate from MSB-1 down to LSB
                bin[i] = bin[i+1] ^ gray[i];       // XOR previous binary bit with current Gray bit
            gray_to_bin = bin;                     // Return converted binary value
        end
    endfunction

    // Synchronized binary pointers (after Gray-to-Binary conversion)
    // These values are now in binary format and safe to use for comparison in destination clock domain
    logic [PTR_WIDTH-1:0] rd_ptr_bin_sync;
    logic [PTR_WIDTH-1:0] wr_ptr_bin_sync;

    // Convert synchronized Gray-coded read pointer to binary for full/empty comparison
    // Executes combinatorially - no clock involved
    assign rd_ptr_bin_sync = gray_to_bin(rd_ptr_gray_sync);

    // Convert synchronized Gray-coded write pointer to binary for full/empty comparison
    // Write pointer from clk_wr domain now usable in clk_rd domain for empty detection
    assign wr_ptr_bin_sync = gray_to_bin(wr_ptr_gray_sync);
    
    
    // ============================================
    // 7. Full/Empty detection
    // ============================================

    // Buffer is FULL when write pointer catches up to read pointer from behind
    // With PTR_WIDTH = ADDR_WIDTH+1, the MSB indicates wrap-around count
    // Full condition: MSBs differ (different wrap count) AND lower bits match (same position in buffer)

    // Next write pointer value (if increment happens in current cycle)
    // Used for full detection before actually updating the pointer
    logic [PTR_WIDTH-1:0] wr_ptr_next;
    assign wr_ptr_next = wr_ptr_bin + wr_ptr_inc;  // Pre-computed next position

    // Full assertion: write pointer's next value has completed one full circle relative to read pointer
    // Condition 1: MSBs are different (write has wrapped, read hasn't, or vice versa)
    // Condition 2: All lower ADDR_WIDTH bits are equal (pointing to same RAM address)
    assign wr_full = (wr_ptr_next[PTR_WIDTH-1] != rd_ptr_bin_sync[PTR_WIDTH-1]) &&  // Different wrap count
                    (wr_ptr_next[PTR_WIDTH-2:0] == rd_ptr_bin_sync[PTR_WIDTH-2:0]); // Same position within buffer

    // Buffer is EMPTY when read pointer has caught up to write pointer
    // Simple equality comparison because both pointers have same wrap count when empty
    // No MSB check needed - when equal, buffer contains zero words
    assign rd_empty = (rd_ptr_bin == wr_ptr_bin_sync);  // Read position equals write position
        
    
    // ============================================
    // 8. RAM address generation
    // ============================================
    assign ram_wr_en = wr_en && !wr_full;
    assign ram_wr_addr = wr_ptr_bin[ADDR_WIDTH-1:0];
    assign ram_rd_addr = rd_ptr_bin[ADDR_WIDTH-1:0];

endmodule