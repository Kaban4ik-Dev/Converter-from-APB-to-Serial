//====================================================
// External Agent for sin calculation
//====================================================

`include "../rtl/constants.sv"

class agent #(int TIMEOUT = 2000);
    string name;           // Name
    bit [31:0] mem [0:31]; // Memory: 16 cells to write, 16 cells to read

    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox; // Mailbox A - from Master to Slave (write)
    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox; // Mailbox B - from Slave to Master (read)
    
    //================================================
    // Constructor
    //================================================
    function new(string name = "agent",
				    mailbox #(bit [DATA_WIDTH-1:0]) s_rd_mbox, 
                    mailbox #(bit [DATA_WIDTH-1:0]) s_wr_mbox
	 );
        this.name = name;
        for(int i = 0; i < 32; i++) begin
            mem[i] = '0;
        end
        this.s_rd_mbox = s_rd_mbox;
        this.s_wr_mbox = s_wr_mbox;
    endfunction
    
    //================================================
    // Main task
    //================================================
    task run();
        bit [DATA_WIDTH-1:0] wr_data; // Data to write to Master
        bit [DATA_WIDTH-1:0] rd_data; // Read data from Master

        time curr_time = $time;

        // Main working cycle
        $display("[%0t] Agent started", $time);
        while (curr_time < TIMEOUT * 0.95) begin
            // If there are any commands
            if (s_wr_mbox.num() > 0) begin
                // Get command
                s_wr_mbox.get(rd_data);

                // Check address range (not bigger than 16 cells)
                // Not really usefull in current situation because it is impossible to fit numbers bigger than 15 in 4 bits
                if (rd_data[30:27] <= 4'b1111) begin
                    
                    // Get operation (1 - read, 0 - write)
                    if (rd_data[31] == 1'b0) begin
                        // Store data
                        mem[rd_data[30:27]] = rd_data[26:0];
                        // Calculate sin and store result
                        //$display("[%0t] Word written in Agent: 0x%08h", $time, rd_data);
                        //$display("[%0t] Input in sin: 0x%0d", $time, mem[rd_data[30:27]]);
                        sin(mem[rd_data[30:27]], mem[rd_data[30:27] + 16]);
                        //$display("[%0t] Output from sin: 0x%0d", $time, mem[rd_data[30:27] + 16]);
                    end else begin
                        wr_data = mem[rd_data[30:27] + 16];
                        //$display("[%0t] Word read from Agent: 0x%08h", $time, wr_data);
                        // Write result to the mailbox
                        s_rd_mbox.put(wr_data);
                    end
                
                // If address if out of range
                end else begin
                    //$display("[%0t] Error: address out of range in Agent: 0x%08h", $time, rd_data);
                    // If it is a read operation
                    if (rd_data[31] == 1'b1) begin
                        wr_data = 32'h00000000;
                        // Write result to the mailbox
                        s_rd_mbox.put(wr_data);
                    end
                end
            end

            #10;
            // Get current time
            curr_time = $time;
        end
        $display("[%0t] Agent stopped", $time);
    endtask

    
    //================================================
    // Sin calculating task
    // Using Taylor series
    //================================================
    task sin(
        input  bit [26:0] x, // Input in radians 0 - 2pi to 0 - 134 217 727
        output bit [31:0] y  // Output in number (IEEE 754)
    );
        real rad;
        real result;

        // Convert input x into angle in radians
        rad = (real'(x) * 2 * PI / 134217727.0);
        //$display("[%0t] Radians: %0g", $time, rad);
        // Calculate Teylor series
        result = rad - (rad**3)/6.0 + (rad**5)/120.0 - (rad**7)/5040.0 + (rad**9)/362880.0;
        //$display("[%0t] Sin value: %0g", $time, result);
        
        // Convert from float to IEEE 754
        y = $shortrealtobits(result);
    endtask

endclass