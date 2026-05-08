//====================================================
// Soreboard fo results output
// and transaction monitoring
//====================================================

`include "../rtl/constants.sv"

class scoreboard;
    string name;     // Name
    int tr_cnt;      // Transaction count
    int result_cnt;  // Result count

    // Input mailboxes
    mailbox #(bit [DATA_WIDTH-1:0]) input_mbox = new();  // Mailbox A - input sin values (radians)
    mailbox #(bit [DATA_WIDTH-1:0]) result_mbox = new(); // Mailbox B - result sin values (IEEE 754)
    
    //================================================
    // Constructor
    //================================================
    function new(string name = "scoreboard",
				    mailbox #(bit [DATA_WIDTH-1:0]) input_mbox, 
                    mailbox #(bit [DATA_WIDTH-1:0]) result_mbox
	 );
        this.name = name;
        this.tr_cnt = 0;
        this.result_cnt = 0;
        this.input_mbox = input_mbox;
        this.result_mbox = result_mbox;
    endfunction
    
    //================================================
    // Main task
    //================================================
    task run();
        bit [DATA_WIDTH-1:0] input_data;  // Input data
        bit [DATA_WIDTH-1:0] result_data; // Sin calculation result

        real input_angle_arr[]; // Dynamic array for input data
        real output_sin_arr[];  // Dynamic array for sinus values
        int min_length;         // Minimum length for in/out arrays

        // Get number of transactions
        tr_cnt = input_mbox.num();
        // Get number of results
        result_cnt = result_mbox.num();

        input_angle_arr = {};
        output_sin_arr = {};
        
        // Get all input values
        while (input_mbox.num() > 0) begin
            // Get data
            input_mbox.get(input_data);
            // If it is a write operation
            if (input_data[31] == 1'b0) begin
                input_angle_arr = new[input_angle_arr.size() + 1] (input_angle_arr);
                // Convert to radians
                input_angle_arr[input_angle_arr.size() - 1] = input_data[26:0] * 2 * PI / 134217727;
            end
        end

        // Get all result values
        while (result_mbox.num() > 0) begin
            // Get data
            result_mbox.get(result_data);
            output_sin_arr = new[output_sin_arr.size() + 1] (output_sin_arr);
            // Convert from IEEE 754 to float
            output_sin_arr[output_sin_arr.size() - 1] = $bitstoshortreal(result_data);
        end

        $display("\n=========================================");
        $display("                 Results                 ");
        $display("=========================================\n");
        $display("Warning! Results and inputs are matching only if writes and reads occure sequentially on same address.");

        // Calculate min length for display
        min_length = (input_angle_arr.size() < output_sin_arr.size()) ? input_angle_arr.size() : output_sin_arr.size();
        for (int i = 0; i < min_length; i++) begin
            $display("[%0d] Input: %0f, Output: %0f", i, input_angle_arr[i], output_sin_arr[i]);
        end

        $display(" Serial-level transactions count: %0d", tr_cnt);
        $display(" Results count:  %0d", result_cnt);
        $display("========================================\n");
    endtask

endclass