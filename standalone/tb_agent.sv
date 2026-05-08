//====================================================
// Testbench for Agent
//====================================================

`include "../rtl/constants.sv"
`include "../tb/agent.sv"

module tb_agent;
    // Parameters
    localparam TIMEOUT = 2000;
    localparam NUM_TRANSACTIONS = 20;
    
    // Mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) wr_mbox;
    mailbox #(bit [DATA_WIDTH-1:0]) rd_mbox;
    
    // Agent instance
    agent #(TIMEOUT) agnt;
    
    // Test variables
    int num_transactions = 0;
    int num_errors = 0;
    bit [31:0] expected_results [0:15];
    
    //================================================
    // Generate random transaction
    //================================================
    function bit [31:0] generate_transaction();
        bit [31:0] trans;
        bit op;
        bit [3:0] addr;
        bit [26:0] data;
        
        op = $random % 2;
        addr = $random % 16;
        data = $random;
        
        trans = {op, addr, data};
        return trans;
    endfunction
    
    //================================================
    // Calculate expected sin value for verification
    //================================================
    function real calculate_sin(bit [26:0] x);
        real rad;
        real result;
        rad = (real'(x) * 2 * 3.141592653589793 / 134217727.0);
        result = rad - (rad**3)/6.0 + (rad**5)/120.0 - (rad**7)/5040.0 + (rad**9)/362880.0;
        return result;
    endfunction
    
    //================================================
    // Master task (generates write commands)
    //================================================
    task master();
        bit [31:0] transaction;
        bit [26:0] write_data [0:15];
        static int write_count = 0;
        static int read_count = 0;
        
        $display("[%0t] Master started", $time);
        
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            transaction = generate_transaction();
            
            if (transaction[31] == 0) begin // Write operation
                $display("[%0t] Master sending WRITE: addr=0x%0h, data=0x%07h", 
                         $time, transaction[30:27], transaction[26:0]);
                
                // Store expected value for later verification
                write_data[transaction[30:27]] = transaction[26:0];
                write_count++;
                
                // Send to agent
                wr_mbox.put(transaction);
                
                // Wait a bit between transactions
                #(10 + $urandom_range(0, 20));
            end
        end
        
        // Wait for writes to complete
        #100;
        
        // Generate read transactions for all written addresses
        for (int addr = 0; addr < 16; addr++) begin
            if (write_data[addr] !== 0) begin
                transaction = {1'b1, addr[3:0], 27'b0};
                $display("[%0t] Master sending READ: addr=0x%0h", $time, addr);
                wr_mbox.put(transaction);
                read_count++;
                #(10 + $urandom_range(0, 10));
            end
        end
        
        $display("[%0t] Master completed: Writes=%0d, Reads=%0d", 
                 $time, write_count, read_count);
    endtask
    
    //================================================
    // Slave task (receives read results)
    //================================================
    task slave();
        bit [31:0] result;
        bit [31:0] expected;
        real expected_float;
        real result_float;
        
        $display("[%0t] Slave started", $time);
        
        while (num_transactions < NUM_TRANSACTIONS) begin
            if (rd_mbox.num() > 0) begin
                rd_mbox.get(result);
                num_transactions++;
                
                // Convert result back to float for comparison
                result_float = $bitstoshortreal(result);
                
                $display("[%0t] Slave received result[%0d]: 0x%08h (float=%0f)", 
                         $time, num_transactions, result, result_float);
                
                // Optional: Verify against expected value if you track it
                // expected_float = calculate_sin(written_data);
                // if (abs(result_float - expected_float) > 0.001) begin
                //     $display("ERROR: Mismatch! Expected=%0f, Got=%0f", 
                //              expected_float, result_float);
                //     num_errors++;
                // end
            end
            #5;
        end
        
        $display("[%0t] Slave completed. Total results: %0d", $time, num_transactions);
    endtask
    
    //================================================
    // Monitor task (observes agent behavior)
    //================================================
    task monitor();
        bit [31:0] cmd;
        
        $display("[%0t] Monitor started", $time);
        
        fork
            forever begin
                // Monitor write mailbox
                if (wr_mbox.num() > 0) begin
                    wr_mbox.peek(cmd);
                    if (cmd[31] == 0) begin
                        $display("[%0t] MONITOR: Write command detected - addr=%0d, data=0x%07h", 
                                 $time, cmd[30:27], cmd[26:0]);
                    end else begin
                        $display("[%0t] MONITOR: Read command detected - addr=%0d", 
                                 $time, cmd[30:27]);
                    end
                end
                
                // Monitor read mailbox
                if (rd_mbox.num() > 0) begin
                    rd_mbox.peek(cmd);
                    $display("[%0t] MONITOR: Read response ready - value=0x%08h", 
                             $time, cmd);
                end
                #5;
            end
        join_none
    endtask
    
    //================================================
    // Main test sequence
    //================================================
    initial begin
        // Create mailboxes
        wr_mbox = new();
        rd_mbox = new();
        
        // Create agent
        agnt = new("test_agent", rd_mbox, wr_mbox);
        
        $display("=========================================");
        $display("Starting Agent Testbench");
        $display("=========================================");
        
        // Start all tasks
        fork
            agnt.run();
            master();
            slave();
            monitor();
        join_none
        
        // Run for TIMEOUT
        #(TIMEOUT);
        
        $display("=========================================");
        $display("Testbench Completed");
        $display("Transactions processed: %0d", num_transactions);
        $display("Errors: %0d", num_errors);
        $display("=========================================");
        
        $finish;
    end
    
    //================================================
    // Dump waveforms (optional)
    //================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_agent);
    end
    
endmodule