`timescale 1ns/1ps

module tb_ram_manager;
    `include "../rtl/constants.sv"
    
    logic clk_wr, clk_rd, rst;
    logic wr_en;
    logic [DATA_WIDTH-1:0] wr_data;
    logic wr_full;
    logic rd_en;
    logic [DATA_WIDTH-1:0] rd_data;
    logic rd_empty;
    
    ram_manager uut (
        .clk_wr(clk_wr), .clk_rd(clk_rd), .rst(rst),
        .wr_en(wr_en), .wr_data(wr_data), .wr_full(wr_full),
        .rd_en(rd_en), .rd_data(rd_data), .rd_empty(rd_empty)
    );
    
    always #(CLK_PERIOD_A/2) clk_wr = ~clk_wr;
    always #(CLK_PERIOD_B/2) clk_rd = ~clk_rd;
    
    initial begin
        // Initialize
        clk_wr = 0; clk_rd = 0; rst = 1;
        wr_en = 0; rd_en = 0; wr_data = 0;
        
        // Reset
        repeat(5) @(posedge clk_wr);
        repeat(5) @(posedge clk_rd);
        rst = 0;
        repeat(2) @(posedge clk_wr);
        
        $display("\n=== FIFO Test: Write 5 values, then read 5 values ===\n");
        
        // Write 5 values
        $display("WRITING:");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk_wr);
            wr_en = 1;
            wr_data = i * 16'h1000;
            @(posedge clk_wr);
            wr_en = 0;
            $display("  [%0t] Wrote 0x%0h", $time, i * 16'h1000);
        end
        
        // Wait for CDC synchronization
        repeat(10) @(posedge clk_rd);
        
        // Read 5 values
        $display("\nREADING:");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk_rd);
            rd_en = 1;
            @(posedge clk_rd);
            $display("  [%0t] Read 0x%0h", $time, rd_data);
            rd_en = 0;
            
            // Verify
            if (rd_data == i * 16'h1000)
                $display("PASS: Expected 0x%0h", i * 16'h1000);
            else
                $display("FAIL: Expected 0x%0h, got 0x%0h", i * 16'h1000, rd_data);
        end
        
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
        $dumpfile("tb_ram_manager.vcd");
        $dumpvars(0, tb_ram_manager);
    end
endmodule