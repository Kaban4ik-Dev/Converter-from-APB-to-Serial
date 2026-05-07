
//====================================================
// Main testbench
//====================================================

`include "../rtl/constants.sv"
`include "drv_int.sv"
`include "drv_ext.sv"
`include "agent.sv"
`include "tests.sv"

parameter TIMEOUT = 10000;

module tb_top;
    
    // Clock
    logic PCLK;
    logic sclk;

    // Variables
    bit [DATA_WIDTH-1:0] result_word;
    
    // Mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) apb_wr_mbox = new(); // Mailbox APB A - data to write
    mailbox #(bit [DATA_WIDTH-1:0]) apb_rd_mbox = new(); // Mailbox APB B - place to put read data
    mailbox #(bit)                  apb_op_mbox = new(); // Mailbox APB C - operations (1 - read, 0 - write)
    
    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox = new();   // Mailbox Serial A - from Master to Slave (write)
    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox = new();   // Mailbox Serial B - from Slave to Master (read)
    
    // APB interface
    apb_if apb_vif();

    // Serial interface
    serial_if s_vif();
    
    // Converter (DUT) instance - APB Slave, Serial Master
    converter dut (
        // APB Bridge ports
        .PCLK    (apb_vif.PCLK),
        .PRESETn (apb_vif.PRESETn),
        .PADDR   (apb_vif.PADDR),
        .PPROT   (apb_vif.PPROT),
        .PSEL    (apb_vif.PSEL),
        .PENABLE (apb_vif.PENABLE),
        .PWRITE  (apb_vif.PWRITE),
        .PWDATA  (apb_vif.PWDATA),
        .PSTRB   (apb_vif.PSTRB),
        .PREADY  (apb_vif.PREADY),
        .PRDATA  (apb_vif.PRDATA),
        .PSLVERR (apb_vif.PSLVERR),
        // Serial Bridge ports
        .sclk    (s_vif.sclk),
        .srst    (s_vif.srst),
        .sctrl   (s_vif.sctrl),
        .sdata   (s_vif.sdata),
        .sready  (s_vif.sready)
    );
    
    // Internal Driver instance - Master
    drv_int #(TIMEOUT) apb_drv_int;

    // External Driver instance - Slave
    drv_ext #(TIMEOUT) s_drv_ext;

    // External Agent - calculates sin
    agent #(TIMEOUT) agent_ext;


    //================================================
    // Test classes
    //================================================

    TestWriteRead test;
    
    //================================================
    // Clock generation
    //================================================
    initial begin
        PCLK = 0;
        forever #30 PCLK = ~PCLK;
    end

    initial begin
        sclk = 0;
        forever #10 sclk = ~sclk;
    end

    assign apb_vif.PCLK = PCLK;
    assign s_vif.sclk = sclk;

    //================================================
    // Simulation timeout
    //================================================
    //initial begin
    //    #TIMEOUT;
    //    $display("Timeout: simulation stopped after %0d ns", TIMEOUT);
    //    $finish;
    //end
    
    //================================================
    // Main test sequence
    //================================================
    initial begin
        // Create drivers
		apb_drv_int = new("APB_DRIVER", apb_vif.master, apb_wr_mbox, apb_rd_mbox, apb_op_mbox);
        s_drv_ext = new("SERIAL_DRIVER", s_vif.slave, s_rd_mbox, s_wr_mbox);

        // Reset serial driver
        s_vif.srst = 1'b1;
        @(posedge s_vif.sclk);
        s_vif.srst = 1'b0;
        @(posedge s_vif.sclk);
        s_vif.srst = 1'b1;

        // Create agent
        agent_ext = new("AGENT_EXT", s_rd_mbox, s_wr_mbox);
        
        // Create test classes
        test = new("Test 1", apb_wr_mbox, apb_op_mbox);

        // Load read operations
        $display("\n=========================================");
        $display("           Setup test sequence           ");
        $display("=========================================\n");
        
        test.run();
        
        // Start main test sequence
        $display("\n=========================================");
        $display("           Driver operations             ");
        $display("=========================================\n");
        // Uncomment the desired debug output in the driver files
        fork
            begin
                //$display("[%0t] Internal driver started", $time);
                apb_drv_int.run();
                //$display("[%0t] Internal driver stopped", $time);
            end
        join_none
        fork
            begin
                //$display("[%0t] External driver started", $time);
                s_drv_ext.run();
                //$display("[%0t] External driver stopped", $time);
            end
        join_none
        fork
            begin
                //$display("[%0t] Agent started", $time);
                agent_ext.run();
                //$display("[%0t] Agent stopped", $time);
            end
        join_none
        
        #TIMEOUT;
        $display("Timeout: simulation stopped after %0d ns", TIMEOUT);

        $display("\n=========================================");
        $display("                 Results                 ");
        $display("=========================================\n");
        while (apb_rd_mbox.num() > 0) begin
            apb_rd_mbox.get(result_word);
            $display("Read data: 0x%0h", result_word);
        end
        $display("\n");

        $finish;
    end
    
    //================================================
    // Waveform dumping
    //================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_top);
    end

endmodule