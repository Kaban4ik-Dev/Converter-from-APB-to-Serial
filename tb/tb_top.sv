
//====================================================
// Main testbench
//====================================================

`include "../rtl/constants.sv"
`include "drv_int.sv"
`include "drv_ext.sv"
`include "agent.sv"
`include "tests.sv"
`include "scoreboard.sv"

parameter TIMEOUT = 30000;

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

    mailbox #(bit [DATA_WIDTH-1:0]) copy_mbox = new();   // Mailbox with copies of transactions for Scoreboard
    
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

    // Test class
    test_full test;

    // Scoreboard class
    scoreboard sc_board;
    
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
        
        // Create tests
        test = new("Full Test", apb_wr_mbox, copy_mbox, apb_op_mbox);

        // Create scoreboard
        sc_board = new("Scoreboard", copy_mbox, apb_rd_mbox);

        // Load read operations
        $display("\n=========================================");
        $display("           Setup test sequence           ");
        $display("=========================================\n");
        
        test.run();
        
        // Start main test sequence
        $display("\n=========================================");
        $display("           Driver operations             ");
        $display("=========================================\n");
        // Uncomment the desired debug output in file
        fork
            begin
                apb_drv_int.run();
            end
        join_none
        fork
            begin
                s_drv_ext.run();
            end
        join_none
        fork
            begin
                agent_ext.run();
            end
        join_none
        
        #TIMEOUT;
        $display("Timeout: simulation stopped after %0d ns", TIMEOUT);

        // Display results
        sc_board.run();

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