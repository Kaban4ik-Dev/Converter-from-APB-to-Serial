
//====================================================
// Tests two data circles:
// Write -> RAM A -> Serial Write
// Serial Read -> RAM B ->  Read
//====================================================

`include "../rtl/constants.sv"
`include "../tb/drv_ext.sv"

module tb_serial;
    
    // Clock
    logic sclk;

    // RAM A - to write to
    logic ram_a_wr_en;
    logic [DATA_WIDTH-1:0] ram_a_wr_data;
    logic ram_a_wr_full;

    // RAM B - to read from
    logic ram_b_rd_en;
    logic ram_b_rd_valid;
    logic [DATA_WIDTH-1:0] ram_b_rd_data;
    logic ram_b_rd_empty;
    
    // Mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox = new(); // Mailbox A - from Master to Slave (write)
    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox = new(); // Mailbox B - from Slave to Master (read)
    
    // Serial interface
    serial_if vif();
    
    // Converter (DUT) instance - Master
    serial_conv_part dut (
        .sclk           (vif.sclk),
        .srst           (vif.srst),
        .sdata          (vif.sdata),
        .sctrl          (vif.sctrl),
        .sready         (vif.sready),
        .ram_a_wr_en    (ram_a_wr_en), 
        .ram_a_wr_data  (ram_a_wr_data), 
        .ram_a_wr_full  (ram_a_wr_full),
        .ram_b_rd_en    (ram_b_rd_en), 
        .ram_b_rd_valid (ram_b_rd_valid), 
        .ram_b_rd_data  (ram_b_rd_data), 
        .ram_b_rd_empty (ram_b_rd_empty)
    );
    
    // Driver instance - Slave
    drv_ext #(10000) driver;
    
    //================================================
    // Clock generation
    //================================================
    initial begin
        sclk = 0;
        forever #10 sclk = ~sclk;
    end

    assign vif.sclk = sclk;

    //================================================
    // Simulation timeout
    //================================================
    initial begin
        #10000;
        $display("Timeout: simulation stopped after %0d ns", 10000);
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
		driver = new("SERIAL_DRIVER", vif.slave, s_rd_mbox, s_wr_mbox);
        
        // Reset driver
        vif.srst = 1'b1;
        @(posedge vif.sclk);
        vif.srst = 1'b0;
        @(posedge vif.sclk);
        vif.srst = 1'b1;
        
        // Start driver in background
        $display("\n=========================================");
        $display("              Driver started             ");
        $display("=========================================\n");
        // Uncomment the desired debug output in the drv_ext.sv driver file
        fork
            driver.run();
        join_none
        @(posedge sclk);
        
        // Load write data
        $display("\n=========================================");
        $display("              Write 5 words              ");
        $display("=========================================\n");
        // To the read buffer
        for (i = 0; i < 5; i++) begin
            s_rd_mbox.put((1 << 31) | ((i + 1) * 16'h1000));
        end

        // To the RAM A (write)
        for (i = 0; i < 5; i++) begin
            @(posedge sclk);
            ram_a_wr_en = 1;
            ram_a_wr_data = (1 << 31) | ((i + 1) * 16'h1000);
            @(posedge sclk);
            ram_a_wr_en = 0;
            ram_a_wr_data = 'x;
            $display("[%0t] Word written in RAM A[%0d]: 0x%08h, op: %0d", $time, i, (1 << 31) | ((i + 1) * 16'h1000), 1);
        end

        // Wait for driver to receive all 5 words and respond
        while (s_wr_mbox.num() < 5)
            @(posedge sclk);
        // Give time for bridge to write responses to RAM B
        repeat(100) @(posedge sclk);

        // Load read operations
        $display("\n=========================================");
        $display("              Read 5 words                ");
        $display("=========================================\n");
        fork 
            begin
                // From the write buffer
                int j = 0;
                while (s_wr_mbox.num() > 0) begin
                    s_wr_mbox.get(actual_data);
                    $display("[%0t] Word passed to Agent[%0d]: 0x%08h", $time, j, actual_data);
                    i++;
                end
            end
            begin
                // From RAM B
                int k = 0;
                while(!ram_b_rd_empty) begin
                    @(posedge sclk); // First step for address
                    ram_b_rd_en = 1;
                    @(posedge sclk); // Second step for data
                    ram_b_rd_en = 0;
                    $display("[%0t] Word read from RAM B[%0d]: 0x%08h", $time, k, ram_b_rd_data);
                    k++;
                    @(posedge sclk); // Wait until ram_b_rd_empty is granted
                end
            end
        join
        
        #100;
        $finish;
    end
    
    //================================================
    // Waveform dumping
    //================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_serial);
    end

endmodule