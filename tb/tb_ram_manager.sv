`include "../rtl/constants.sv"

module tb_ram_manager();
    // Signals
    logic clk;
    logic rst;
    logic op;
    logic rst_c;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] rdata;
    logic isfree;
    logic [ADDR_WIDTH-1:0] faddr;
    
    // DUT (ram) Instance
    ram_manager dut_ram (
        .clk(clk),
        .rst(rst),
        .op(op),
        .rst_c(rst_c),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .isfree(isfree),
        .faddr(faddr)
    );
    
    // CLK generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialization
        rst = 1;
        op = 0;
        rst_c = 0;
        addr = 0;
        wdata = 0;
        
        // Reset
        repeat(2) @(posedge clk);
        rst = 0;
        @(posedge clk);
        
        $display("=== Starting test: Fill all RAM cells ===");
        $display("Time\tAddr\tWdata\tIsFree\tFAddr");
        
        // Filling RAM
        for (int i = 0; i < RAM_CELLS_COUNT; i++) begin
            addr = i;             // Next address
            wdata = i * 4 + 100;  // Test data
            op = 1;               // Write operation
            @(posedge clk);
            
            $display("%0t\t%0d\t%0d\t%0d\t%0d", $time, addr, wdata, isfree, faddr);
            
            // Checking that the first available address is incremented
            if (i < RAM_CELLS_COUNT - 1) begin
                @(posedge clk);  // An additional clock cycle for updating the faddr
                $display("    Next cycle: faddr=%0d", faddr);
                assert (faddr == i + 1) 
                    else $error("After writing addr %0d, expected free addr %0d, got %0d", i, i+1, faddr);
            end
        end
        
        // Checking that after filling all the cells, isfree = 0
        @(posedge clk);
        assert (isfree == 0) 
            else $error("isfree should be 0 when RAM is full");
        
        $display("\n=== RAM is full. IsFree = %0d ===", isfree);
        $display("=== Now emptying all cells ===");
        
        // Emptying RAM
        for (int i = 0; i < RAM_CELLS_COUNT; i++) begin
            addr = i;
            rst_c = 1;  // Reset (free) cell
            op = 0;     // Read operation
            @(posedge clk);
            
            $display("%0t\t%0d\t-\t%0d\t%0d", $time, addr, isfree, faddr);

            // Turning rst_c off
            rst_c = 0;
            @(posedge clk);
            
            // After each reset, the first free address should be 0
            assert (faddr == 0) 
                else $error("After freeing addr %0d, faddr should be 0, got %0d", i, faddr);
        end
        
        // Checking that isfree = 1 after emptying
        assert (isfree == 1) 
            else $error("isfree should be 1 after emptying all cells");
        assert (faddr == 0) 
            else $error("faddr should be 0 after emptying, got %0d", faddr);
        
        $display("\n=== Test completed successfully ===");
        $display("Final state: isfree=%0d, faddr=%0d", isfree, faddr);
        
        $finish;
    end
    
    // Signal monitoring
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_ram_manager);
    end
    
endmodule