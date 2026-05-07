//====================================================
// Different tests classes
//====================================================

`include "../rtl/constants.sv"

// Abstract base class for tests
virtual class ABCTest;
    protected mailbox #(bit [DATA_WIDTH-1:0]) data_mbox;
    protected mailbox #(bit) cmd_mbox;
    protected string name;
    
    // Constructor
    function new(string name = "ABCTest", mailbox #( bit [DATA_WIDTH-1:0]) data_mbox, mailbox #(bit) cmd_mbox);
        this.name = name;
        this.data_mbox = data_mbox;
        this.cmd_mbox = cmd_mbox;
    endfunction
    
    // Pure virtula method - ABC cannot have test sequence
    pure virtual task run();
    
    // Send test transaction into mailboxes
    protected task perform_transaction(bit apb_op, bit ag_op, bit [3:0] addr, bit [26:0] data);
        bit [DATA_WIDTH-1:0] signal;
        // Form signal
        signal[31] = ag_op;
        signal[30:27] = addr;
        signal[26:0] = data;

        // Put to mailboxes
        data_mbox.put(signal);
        cmd_mbox.put(apb_op);
        $display("[%0t] Transaction created: 0x%0h", $time, signal);
    endtask

endclass

// Test 1: Write and read
class TestWriteRead extends ABCTest;
    
    function new(string name = "Test 1", mailbox #(bit [DATA_WIDTH-1:0]) data_mbox, mailbox #(bit) cmd_mbox);
        super.new(name, data_mbox, cmd_mbox);
    endfunction
    
    virtual task run();
        
        // Write data
        perform_transaction(1'b0, 1'b0, 4'h5, 27'hABCDE);
        // Read data
        perform_transaction(1'b0, 1'b1, 4'h5, 27'h0); // Send read operation
        perform_transaction(1'b1, 1'b1, 4'h5, 27'h0); // Read data from converter
        perform_transaction(1'b1, 1'b1, 4'h5, 27'h0); // Read data from converter
        
        //perform_transaction(1'b0, 1'b0, 4'hA, 27'h12345);
        //perform_transaction(1'b0, 1'b1, 4'h5, 27'h0);
        //perform_transaction(1'b1, 1'b1, 4'hA, 27'h0);
        
    endtask
endclass