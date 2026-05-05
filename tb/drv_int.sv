//====================================================
// APB Master Internal Driver
//====================================================

`include "../rtl/constants.sv"

class drv_int #(int TIMEOUT = 2000);
    string name; // Name
    int tr_cnt;  // Transaction count
    int wr_cnt;  // Write operations count
    int rd_cnt;  // Read transactions count

    virtual interface apb_if.master vif;         // Interface for APB signals
    mailbox #(bit [DATA_WIDTH-1:0]) apb_wr_mbox; // Mailbox A - data to write
    mailbox #(bit [DATA_WIDTH-1:0]) apb_rd_mbox; // Mailbox B - place to put read data
    mailbox #(bit) apb_op_mbox;                  // Mailbox C - operations (1 - read, 0 - write)
    
    //================================================
    // Constructor
    //================================================
    function new(string name = "drv_int", virtual interface apb_if.master vif,
				    mailbox #(bit [DATA_WIDTH-1:0]) apb_wr_mbox, 
                    mailbox #(bit [DATA_WIDTH-1:0]) apb_rd_mbox,
                    mailbox #(bit) apb_op_mbox
	 );
        this.name = name;
        this.tr_cnt = 0;
        this.wr_cnt = 0;
        this.rd_cnt = 0;
        this.vif = vif;
		this.set_mailboxes(apb_wr_mbox, apb_rd_mbox, apb_op_mbox);
    endfunction
    
    //================================================
    // Set mailboxes
    //================================================
    function void set_mailboxes(mailbox #(bit [DATA_WIDTH-1:0]) apb_wr_mbox, 
                                mailbox #(bit [DATA_WIDTH-1:0]) apb_rd_mbox,
                                mailbox #(bit) apb_op_mbox);
        this.apb_wr_mbox = apb_wr_mbox;
        this.apb_rd_mbox = apb_rd_mbox;
        this.apb_op_mbox = apb_op_mbox;
    endfunction
    
    //================================================
    // Main task
    //================================================
    task run();
        bit [DATA_WIDTH-1:0] wr_data; // Data to write
        bit [DATA_WIDTH-1:0] rd_data; // Read data
        bit cmd;                      // Command
        
        time curr_time = $time;

        // Reset
        perform_reset();
        
        // Work cycle
        while (curr_time < TIMEOUT * 0.98) begin
            // While there is a pending operation
            while (apb_op_mbox.num() > 0) begin
                apb_op_mbox.get(cmd);
                if (cmd == 1) begin
                    perform_read();
                end else if (apb_wr_mbox.num() > 0) begin
                    perform_write();
                end
            end
            // Skip time if there is no tasks
            if (apb_op_mbox.num() <= 0) begin
                wait_clocks(1);
            end
            curr_time = $time;
        end

        // Finish work
        //print_stats();
    endtask

    //================================================
    // Perform reset operation
    //================================================
    task perform_reset();
        vif.PRESETn = 1'b1;
        @(posedge vif.PCLK);
        vif.PRESETn = 1'b0;
        @(posedge vif.PCLK);
        vif.PRESETn = 1'b1;

        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        vif.PWRITE  <= 1'b0;
        vif.PADDR   <= 32'h0000_0000;
        vif.PPROT   <= 3'b000;
        vif.PWDATA  <= 32'h0000_0000;
        vif.PSTRB   <= 4'b0000;
    endtask

    //================================================
    // Perform write operation
    //================================================
    task perform_write();
        bit [DATA_WIDTH-1:0] write_data;
        apb_wr_mbox.get(write_data);

        // Start write transaction
        // T1 - SETUP
        @(posedge vif.PCLK);
        vif.PSEL    <= 1'b1;
        vif.PWRITE  <= 1'b1;
        vif.PADDR   <= 32'h0000_0000;
        vif.PPROT   <= 3'b000;
        vif.PWDATA  <= write_data;
        vif.PSTRB   <= 4'b1111;
        // T2 - WAIT
        @(posedge vif.PCLK);
        vif.PENABLE <= 1'b1;
        // T3 - T_n - until data was written
        while (!vif.PREADY) begin
            @(posedge vif.PCLK);
        end
        // T_n+1 - ACCESS
        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        
        // Display result
        //$display("[%0t] 0x%08h: WRITE successful", $time, write_data);
        tr_cnt++;
        wr_cnt++;
        wait_clocks(1);
    endtask
    
    //================================================
    // Perform read operation
    //================================================
    task perform_read();
        bit [DATA_WIDTH-1:0] read_data;

        // Start read transaction
        // T1 - SETUP
        @(posedge vif.PCLK);
        vif.PSEL    <= 1'b1;
        vif.PWRITE  <= 1'b0;
        vif.PADDR   <= 32'h0000_0000;
        vif.PPROT   <= 3'b000;
        vif.PSTRB   <= 4'b0000;
        // T2 - WAIT
        @(posedge vif.PCLK);
        vif.PENABLE <= 1'b1;
        // T3 - T_n - until data was read
        while (!vif.PREADY) begin
            @(posedge vif.PCLK);
        end
        // T_n+1 - ACCESS
        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
        read_data = vif.PRDATA;

        // Display result
        apb_rd_mbox.put(read_data);
        //$display("[%0t] 0x%08h: READ successful", $time, read_data);
        tr_cnt++;
        rd_cnt++;
        wait_clocks(1);
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
        $display("  WR mailbox remaining:    %0d", apb_wr_mbox.num());
        $display("  RD mailbox size:         %0d", apb_rd_mbox.num());
        $display("========================================\n");
    endfunction
    
    //================================================
    // Wait for clocks
    //================================================
    task wait_clocks(int clocks);
        repeat(clocks) @(posedge vif.PCLK);
    endtask

endclass