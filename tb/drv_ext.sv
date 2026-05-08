//====================================================
// Serial Slave External Driver
//====================================================

`include "../rtl/constants.sv"

class drv_ext #(int TIMEOUT = 2000);
    string name; // Name
    int tr_cnt;  // Transaction count
    int wr_cnt;  // Write operations count
    int rd_cnt;  // Read operations count

    virtual interface serial_if.slave vif;     // Interface for Serial signals
    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox; // Mailbox A - from Master to Slave (write)
    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox; // Mailbox B - from Slave to Master (read)
    
    //================================================
    // Constructor
    //================================================
    function new(string name = "drv_ext", virtual interface serial_if.slave vif,
				    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox, 
                    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox
	 );
        this.name = name;
        this.tr_cnt = 0;
        this.wr_cnt = 0;
        this.rd_cnt = 0;
        this.vif = vif;
        this.s_rd_mbox = s_rd_mbox;
        this.s_wr_mbox = s_wr_mbox;
    endfunction
    
    //================================================
    // Main task
    //================================================
    task run();
        bit [DATA_WIDTH-1:0] wr_data; // Data to write to Master
        bit [DATA_WIDTH-1:0] rd_data; // Read data from Master

        int wr_bit_cnt; // Bit counter for 32 bit word read
        int rd_bit_cnt; // Bit counter for 32 bit word write

        time curr_time = $time;
        vif.sready = 1'b0;
        
        // Work cycle
        $display("[%0t] External driver started", $time);
        while (curr_time < TIMEOUT * 0.95) begin
        //forever begin

            // While there is a running operation
            while (vif.sctrl == 1'b1) begin

                // Write data to Slave
                for (wr_bit_cnt = 0; wr_bit_cnt < 32; wr_bit_cnt++) begin
                    // Wait untill data transmission start
					while (vif.sdata_in_value === 1'bz)
						@(posedge vif.sclk);
                    // Read data bit from Serial
                    wr_data[wr_bit_cnt] = vif.sdata_in_value;
                    // Go to another bit
                    @(posedge vif.sclk);
                end
                //$display("[%0t] 0x%08h: Write successful", $time, wr_data);

                // Process of recieving data has finished
                // Give data to Agent
                s_wr_mbox.put(wr_data);

                // If it is a read operation
                if (wr_data[DATA_WIDTH-1] == 1'b1) begin
                    // Wait until read data is ready
                    while (s_rd_mbox.num() <= 0)
                        @(posedge vif.sclk);
                    s_rd_mbox.get(rd_data);

                    // Read data from Slave (MSB first)
                    for (rd_bit_cnt = 0; rd_bit_cnt < 32; rd_bit_cnt++) begin
                        // Write data bit to Serial
                        vif.sdata_out_en = 1'b1;
                        vif.sdata_out_value = rd_data[31 - rd_bit_cnt];
                        // If 8-bit batch has finished
                        if (rd_bit_cnt[2:0] == 3'b111) begin
                            // If it is the last bit transaction
                            if(rd_bit_cnt == 31)
                                vif.sready = 1'b1;
                            // Skip pause and finish data transmission
                            @(posedge vif.sclk);
                            vif.sready = 1'b0;
                            vif.sdata_out_en = 1'b0;
                        end
                        // Go to another bit
                        @(posedge vif.sclk);
                    end
                end
                //$display("[%0t] 0x%08h: Read successful", $time, rd_data);
            end

            // Wait for next transaction
            if (vif.sctrl !== 1'b1)
                @(posedge vif.sclk);

            // Get current time
            curr_time = $time;
        end

        // Finish work
        //print_stats();
        $display("[%0t] External driver stopped", $time);
    endtask

    //================================================
    // Perform reset operation
    //================================================
    task perform_reset();
        vif.srst = 1'b1;
        @(posedge vif.sclk);
        vif.srst = 1'b0;
        @(posedge vif.sclk);
        vif.srst = 1'b1;
    endtask
    
    //================================================
    // Print statistics
    //================================================
    function void print_stats();
        $display("\n========================================");
        $display("Statistics for %s:", name);
        $display("========================================");
        $display("  Successful transactions: %0d", tr_cnt);
        $display("    - Writes:  %0d", wr_cnt);
        $display("    - Reads:   %0d", rd_cnt);
        $display("========================================\n");
    endfunction
    
    //================================================
    // Wait for clocks
    //================================================
    task wait_clocks(int clocks);
        repeat(clocks) @(posedge vif.sclk);
    endtask

endclass