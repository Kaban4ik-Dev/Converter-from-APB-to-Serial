`timescale 1ns/1ns

module tb_ram;
    `include "../rtl/constants.sv"
    
    logic clk_wr, clk_rd, rst;
    logic wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic wr_full;
    logic rd_en;
    logic rd_valid;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_empty;
    
    ram ram_dut (
        .clk_wr(clk_wr), .clk_rd(clk_rd), .rst(rst),
        .wr_en(wr_en), .wr_data(wr_data), .wr_full(wr_full),
        .rd_en(rd_en), .rd_valid(rd_valid), .rd_data(rd_data), .rd_empty(rd_empty)
    );
    
    always #(CLK_A) clk_wr = ~clk_wr;
    always #(CLK_B) clk_rd = ~clk_rd;
    
    initial begin
        // Initialize
        clk_wr = 0; clk_rd = 0; rst = 0;
        wr_en = 0; rd_en = 0; wr_data = 'x;
        
        // Reset
        repeat(2) @(posedge clk_wr);
        rst = 1;
        
        $display("\n=== FIFO Test: Write 32 values (to full), then read 32 values (to empty) ===\n");
        
        // Write 33 values (one last value must be lost)
        $display("WRITING:");
        for (int i = 0; i < 33; i++) begin
            @(posedge clk_wr);
            wr_en = 1;
            wr_data = i * 16'h1000;
            @(posedge clk_wr);
            wr_en = 0;
            wr_data = 'x;
            $display("  [%0t] Write attempt 0x%0h", $time, i * 16'h1000);
        end
        
        // Read 32 values
        $display("\nREADING:");
        for (int i = 0; i < 32; i++) begin
            @(posedge clk_rd); // First step for address
            rd_en = 1;
            @(posedge clk_rd); // Second step for data
            rd_en = 0;
            if (rd_data == i * 16'h1000)
                $display("PASS: Expected 0x%0h, got 0x%0h", i * 16'h1000, rd_data);
            else
                $display("FAIL: Expected 0x%0h, got 0x%0h", i * 16'h1000, rd_data);
        end

        repeat(2) @(posedge clk_rd);
        
        // Final check
        @(posedge clk_rd);
        if (rd_empty)
            $display("\nBuffer is empty as expected");
        else
            $display("\nBuffer should be empty but rd_empty = 0");
        
        $display("\n=== Test Complete ===");
        $finish;
    end
    
    initial begin
        $dumpfile("tb_ram.vcd");
        $dumpvars(0, tb_ram);
    end
endmodule