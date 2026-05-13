//====================================================
// Testbench for Agent
//====================================================

`include "../rtl/constants.sv"
`include "../tb/tb_constants.sv"
`include "../tb/agent.sv"

module tb_agent;
    // Parameters
    localparam TIMEOUT = 2000;
    localparam NUM_TRANSACTIONS = 16;
    
    // Mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) wr_mbox;
    mailbox #(bit [DATA_WIDTH-1:0]) rd_mbox;
    
    // Agent instance
    agent #(TIMEOUT) agnt;
    
    // Test variables
    bit [31:0] expected_input [0:NUM_TRANSACTIONS-1];
    
    //================================================
    // Generate random transaction
    //================================================
    function bit [31:0] generate_transaction(bit op, bit [3:0] addr);
        bit [31:0] signal;
        bit [26:0] data;

        // Set random input value
        data = $random();
        // Form transaction
        signal = {op, addr, data};
        $display("[%0t] Transaction created: %0d-%0d-%0d", $time, signal[31], signal[30:27], signal[26:0]);
        return signal;
    endfunction
    
    //================================================
    // Generate write and read commands
    //================================================
    task generate_commands();
        bit [31:0] transaction;
        
        // Create write transactions
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            // Create transaction
            transaction = generate_transaction(1'b0, i);
            // Save input value
            expected_input[i] = transaction[26:0];
            // Send to agent
            wr_mbox.put(transaction);
        end
        
        // Wait for writes to complete
        #100;
        
        // Generate read transactions for all written addresses
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            // Create transaction
            transaction = generate_transaction(1'b1, i);
            // Send to agent
            wr_mbox.put(transaction);
        end

        // Wait for reads to complete
        #100;
    endtask
    
    //================================================
    // Display results
    //================================================
    task display_results();
        bit [31:0] result;
        bit [31:0] expected;
        real input_float;
        real result_float;
        integer file;

        file = $fopen("results.txt", "w");
        if (file == 0) begin
            $display("Error opening file");
            $finish;
        end
        
        $display("\n=========================================");
        $display("                 Results                 ");
        $display("=========================================\n");
        
        for (int i = 0; i < NUM_TRANSACTIONS; i++) begin
            // Get result if it is in rd_mbox
            if (rd_mbox.num() > 0) begin
                rd_mbox.get(result);
            end
            // Convert result back to float for comparison
            result_float = $bitstoshortreal(result);
            // Get input angle in radians
            input_float = real'(expected_input[i]) * 2 * PI / 134217727.0;
            $display("[%0d] Input: %0f, Output: %0f", i, input_float, result_float);
            // Print to file
            $fdisplay(file, "%0f : %0f", input_float, result_float);
        end
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
        
        $display("\n=========================================");
        $display("             Testing sequence            ");
        $display("=========================================\n");
        
        generate_commands();
        
        agnt.run();
        
        display_results();
        
        // Run for TIMEOUT
        #(TIMEOUT);
        
        $finish;
    end
    
    //================================================
    // Dump waveforms
    //================================================
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_agent);
    end
    
endmodule