`timescale 1ns/1ps
`include "../rtl/constants.sv"

//====================================================
// Testbench for Converter (Top Level)
//====================================================

module tb_converter ();

    //================================================
    // Testbench Signals
    //================================================
    logic        PCLK;           // APB clock (write clock)
    logic        clk_rd;         // Read clock (serial side)
    logic        rst;            // Active-high reset
    logic        PRESETn;        // Active-low APB reset
    
    // APB Signals
    logic [31:0] PADDR;
    logic [2:0]  PPROT;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;
    logic [3:0]  PSTRB;
    logic        PREADY;
    logic [31:0] PRDATA;
    logic        PSLVERR;
    
    // Read Interface (serial side)
    logic                     rd_en;
    logic [DATA_WIDTH-1:0]    rd_data;
    logic                     rd_empty;
    
    // Test Control
    logic [31:0] test_data [0:31];
    integer      i;
    integer      write_count;
    integer      read_count;
    integer      errors;
    
    //================================================
    // Clock Generation
    //================================================
    localparam CLK_PERIOD_WR = 20;  // 50 MHz
    localparam CLK_PERIOD_RD = 26;  // ~38.5 MHz
    
    // Write clock (APB clock)
    initial begin
        PCLK = 1'b0;
        forever #(CLK_PERIOD_WR/2) PCLK = ~PCLK;
    end
    
    // Read clock (serial side clock)
    initial begin
        clk_rd = 1'b0;
        forever #(CLK_PERIOD_RD/2) clk_rd = ~clk_rd;
    end
    
    //================================================
    // Reset Generation
    //================================================
    initial begin
        rst = 1'b1;
        PRESETn = 1'b0;
        #100;
        rst = 1'b0;
        PRESETn = 1'b1;
        #20;
    end
    
    //================================================
    // Converter Instance (DUT)
    //================================================
    converter dut (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PADDR   (PADDR),
        .PPROT   (PPROT),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PREADY  (PREADY),
        .PRDATA  (PRDATA),
        .PSLVERR (PSLVERR),
        
        .clk_rd  (clk_rd),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .rd_empty(rd_empty)
    );
    
    //================================================
    // APB Write Task
    //================================================
    task apb_write;
        input [31:0] address;
        input [31:0] data;
        begin
            @(posedge PCLK);
            // Setup phase
            PADDR   = address;
            PWDATA  = data;
            PWRITE  = 1'b1;
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            PSTRB   = 4'b1111;
            @(posedge PCLK);
            
            // Access phase
            PENABLE = 1'b1;
            @(posedge PCLK);
            
            // Wait for ready
            while (!PREADY) begin
                @(posedge PCLK);
            end
            
            // End transaction
            PSEL = 1'b0;
            PENABLE = 1'b0;
            @(posedge PCLK);
        end
    endtask
    
    //================================================
    // APB Read Task
    //================================================
    task apb_read;
        input [31:0] address;
        output [31:0] data;
        begin
            @(posedge PCLK);
            PADDR   = address;
            PWRITE  = 1'b0;
            PSEL    = 1'b1;
            PENABLE = 1'b0;
            @(posedge PCLK);
            
            PENABLE = 1'b1;
            @(posedge PCLK);
            
            while (!PREADY) begin
                @(posedge PCLK);
            end
            
            data = PRDATA;
            
            PSEL = 1'b0;
            PENABLE = 1'b0;
            @(posedge PCLK);
        end
    endtask
    
    //================================================
    // Read from RAM Task
    //================================================
    task ram_read;
        output [DATA_WIDTH-1:0] data;
        begin
            @(posedge clk_rd);
            rd_en = 1'b1;
            @(posedge clk_rd);
            data = rd_data;
            rd_en = 1'b0;
            @(posedge clk_rd);
        end
    endtask
    
    //================================================
    // Test Procedure
    //================================================
    initial begin
        logic [31:0] read_data_apb;
        logic [DATA_WIDTH-1:0] read_data_ram;
        
        // Initialize signals
        PADDR   = 32'b0;
        PPROT   = 3'b0;
        PSEL    = 1'b0;
        PENABLE = 1'b0;
        PWRITE  = 1'b0;
        PWDATA  = 32'b0;
        PSTRB   = 4'b0;
        rd_en   = 1'b0;
        
        // Initialize test data
        for (i = 0; i < 32; i++) begin
            test_data[i] = i * 32'h01010101;
        end
        
        errors = 0;
        write_count = 0;
        read_count = 0;
        
        #200;
        
        $display("========================================");
        $display("Converter (Top Level) Testbench Started");
        $display("========================================");
        $display("");
        
        //============================================
        // Test 1: Write 16 words to RAM
        //============================================
        $display("Test 1: Writing 16 words to RAM");
        $display("----------------------------------------");
        
        for (i = 0; i < 16; i++) begin
            apb_write(32'h0000_0000 + (i*4), test_data[i]);
            write_count++;
            $display("Write %0d: Data=0x%08X, PREADY=%b, wr_full=%b", 
                     write_count, test_data[i], PREADY, dut.u_ram_manager.wr_full);
            #20;
        end
        
        $display("");
        $display("Test 1 Complete: %0d writes", write_count);
        $display("");
        
        //============================================
        // Test 2: Try to write when RAM is full
        //============================================
        $display("Test 2: Writing additional words (RAM should be full)");
        $display("----------------------------------------");
        
        for (i = 16; i < 20; i++) begin
            apb_write(32'h0000_0000 + (i*4), test_data[i]);
            write_count++;
            $display("Write %0d: Data=0x%08X, PREADY=%b, wr_full=%b", 
                     write_count, test_data[i], PREADY, dut.u_ram_manager.wr_full);
            
            if (dut.u_ram_manager.wr_full && PREADY == 1'b0) begin
                $display("  -> Correct: PREADY=0 (stalled) when RAM full");
            end else if (dut.u_ram_manager.wr_full && PREADY == 1'b1) begin
                $display("  ERROR: PREADY should be 0 when RAM is full!");
                errors++;
            end
            #20;
        end
        
        $display("");
        
        //============================================
        // Test 3: Read back from RAM
        //============================================
        $display("Test 3: Reading data from RAM");
        $display("----------------------------------------");
        
        // Read first 8 words
        for (i = 0; i < 8; i++) begin
            ram_read(read_data_ram);
            read_count++;
            $display("Read %0d: Data=0x%08X (expected 0x%08X)", 
                     read_count, read_data_ram, test_data[i]);
            
            if (read_data_ram !== test_data[i][DATA_WIDTH-1:0]) begin
                $display("  ERROR: Read data mismatch!");
                errors++;
            end
            #(CLK_PERIOD_RD * 2);
        end
        
        $display("");
        $display("Test 3 Complete: %0d reads", read_count);
        $display("");
        
        //============================================
        // Test 4: Write again after reads (RAM not full)
        //============================================
        $display("Test 4: Writing after reads (RAM should have space)");
        $display("----------------------------------------");
        
        for (i = 16; i < 20; i++) begin
            apb_write(32'h0000_0000 + (i*4), test_data[i]);
            write_count++;
            $display("Write %0d: Data=0x%08X, PREADY=%b, wr_full=%b", 
                     write_count, test_data[i], PREADY, dut.u_ram_manager.wr_full);
            
            if (!dut.u_ram_manager.wr_full && PREADY == 1'b1) begin
                $display("  -> Correct: Write accepted");
            end
            #20;
        end
        
        $display("");
        
        //============================================
        // Test Summary
        //============================================
        $display("========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total writes: %0d", write_count);
        $display("Total reads: %0d", read_count);
        $display("Total errors: %0d", errors);
        $display("");
        
        if (errors == 0) begin
            $display("*** TEST PASSED ***");
        end else begin
            $display("*** TEST FAILED with %0d errors ***", errors);
        end
        
        $display("========================================");
        
        //#500;
        $finish;
    end
    
    //================================================
    // Monitor
    //================================================
    initial begin
        $monitor("Time=%0t | wr_full=%b rd_empty=%b PREADY=%b | writes=%0d reads=%0d",
                 $time, dut.u_ram_manager.wr_full, rd_empty, PREADY, write_count, read_count);
    end
    
    //================================================
    // Waveform Dump
    //================================================
    initial begin
        $dumpfile("tb_converter.vcd");
        $dumpvars(0, tb_converter);
    end
    
    initial begin
        #10000;
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule