
//====================================================
// Tests data circle:
// APB Write -> RAM (Write as A) -> RAM (Read as B) -> APB Read
//====================================================

`include "../rtl/constants.sv"
`include "../tb/drv_int.sv"

module tb_apb;
    
    // Clock
    logic PCLK;
    
    // Mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) apb_wr_mbox = new(); // Mailbox A - data to write
    mailbox #(bit [DATA_WIDTH-1:0]) apb_rd_mbox = new(); // Mailbox B - place to put read data
    mailbox #(bit) apb_op_mbox = new();                  // Mailbox C - operations (1 - read, 0 - write)
    
    // APB interface
    apb_if vif();
    
    // Converter (DUT) instance - Slave
    apb_conv_part dut (
        .PCLK        (vif.PCLK),
        .PRESETn     (vif.PRESETn),
        .PADDR       (vif.PADDR),
        .PPROT       (vif.PPROT),
        .PSEL        (vif.PSEL),
        .PENABLE     (vif.PENABLE),
        .PWRITE      (vif.PWRITE),
        .PWDATA      (vif.PWDATA),
        .PSTRB       (vif.PSTRB),
        .PREADY      (vif.PREADY),
        .PRDATA      (vif.PRDATA),
        .PSLVERR     (vif.PSLVERR)
    );
    
    // Driver instance - Master
    drv_int #(2000) driver;
    
    //================================================
    // Clock generation
    //================================================
    initial begin
        PCLK = 0;
        forever #10 PCLK = ~PCLK;
    end

    assign vif.PCLK = PCLK;

    //================================================
    // Simulation timeout
    //================================================
    initial begin
        #2000;
        $display("Timeout: simulation stopped after %0d ns", 2000);
        $finish;
    end
    
    //================================================
    // Main test sequence
    //================================================
    initial begin
        reg [31:0] expected_data [0:4];
        reg [31:0] actual_data;
        integer i;
        static bit test_passed = 1'b1;
        
        // Initialize expected data
        expected_data[0] = 32'hAABBCCDD;
        expected_data[1] = 32'h11223344;
        expected_data[2] = 32'h55667788;
        expected_data[3] = 32'h99AABBCC;
        expected_data[4] = 32'hDDEEFF00;
        
        // Create driver
		driver = new("APB_DRIVER", vif.master, apb_wr_mbox, apb_rd_mbox, apb_op_mbox);
        
        // Load write mailbox
        $display("\n=========================================");
        $display("              Write 5 words              ");
        $display("=========================================\n");
        for (i = 0; i < 5; i++) begin
            apb_wr_mbox.put(expected_data[i]);
            apb_op_mbox.put(0);
            $display("[%0t] Word put in mailbox A[%0d]: 0x%08h, op: %0d", $time, i, expected_data[i], 0);
        end

        // Load read operations
        $display("\n=========================================");
        $display("              Read 5 words                ");
        $display("=========================================\n");
        for (i = 0; i < 5; i++) begin
            apb_op_mbox.put(1);
            $display("[%0t] Read operation queued[%0d]", $time, i);
        end
        
        // Start driver
        $display("\n=========================================");
        $display("           Driver operations             ");
        $display("=========================================\n");
        // Uncomment the desired debug output in the drv_int.sv driver file
        driver.run();

        // Check results
        $display("\n========================================");
        $display("          CHECKING RESULTS              ");
        $display("========================================\n");
        for (i = 0; i < 5; i++) begin
            apb_rd_mbox.get(actual_data);
            if (actual_data !== expected_data[i]) begin
                $display("ERROR: Data mismatch at index %0d", i);
                $display("  Expected: 0x%08h", expected_data[i]);
                $display("  Got:      0x%08h", actual_data[i]);
                test_passed = 1'b0;
            end else begin
                $display("PASS: Data[%0d] is 0x%08h matches: 0x%08h", i, actual_data, expected_data[i]);
            end
        end
        
        $display("\n========================================");
        if (test_passed) begin
            $display("TEST PASSED: All 5 transactions completed successfully!");
        end else begin
            $display("TEST FAILED: Data mismatch detected!");
        end
        $display("========================================\n");
        
        #100;
        $finish;
    end
    
    //================================================
    // Waveform dumping
    //================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_apb);
    end

endmodule