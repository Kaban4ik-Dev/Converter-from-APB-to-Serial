`include "constants.sv"

//====================================================
// APB to RAM Bridge
//====================================================
// This module acts as an APB slave that writes incoming APB write transactions to a RAM manager module
// 
// Key features:
// - Implements AMBA APB slave protocol
// - Stalls master using PREADY when RAM is full (do not accept writes)
//====================================================

module apb_to_ram (
    //================================================
    // APB Slave Interface Inputs
    //================================================
    input  logic        PCLK,           // APB clock
    input  logic        PRESETn,        // APB reset (active LOW)
    input  logic [31:0] PADDR,          // APB address bus (not used)
    input  logic [2:0]  PPROT,          // Protection type (not used)
    input  logic        PSEL,           // Slave select (active HIGH)
    input  logic        PENABLE,        // Enable signal (second phase of transfer)
    input  logic        PWRITE,         // Transfer direction: 1=write, 0=read
    input  logic [31:0] PWDATA,         // Write data from master
    input  logic [3:0]  PSTRB,          // Write strobes (byte enables, not used)
    
    //================================================
    // APB Slave Interface Outputs
    //================================================
    output logic        PREADY,         // Ready signal: 1=slave ready, 0=slave busy/wait
    output logic [31:0] PRDATA,         // Read data to master (always 0 in write-only bridge)
    output logic        PSLVERR,        // Slave error response (not used, always 0)
    
    //================================================
    // RAM Manager Interface (connect to ram_manager)
    //================================================
    output logic                     wr_en,      // Write enable pulse to RAM
    output logic [DATA_WIDTH-1:0]    wr_data,    // Data to write to RAM
    input  logic                     wr_full     // RAM full flag from RAM manager
);    
    //================================================
    // APB State Machine Definition
    //================================================
    // APB3 protocol has two main states:
    // - IDLE:   No transaction in progress
    // - SETUP:  Setup phase (PSEL=1, PENABLE=0) - address phase
    // - ACCESS: Access phase (PSEL=1, PENABLE=1) - data phase
    apb_state_t current_state;
    apb_state_t next_state;
    
    //================================================
    // Internal Signals
    //================================================
    logic write_transaction;      // Current transaction is a write
    logic write_accepted;         // Write has been accepted this cycle
    //logic stall_due_to_full;      // Stall master because RAM is full
    
    //================================================
    // State Machine - Sequential Logic
    //================================================
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    //================================================
    // State Machine - Combinational Next State Logic
    //================================================
    always_comb begin
        next_state = current_state;
        
        case (current_state)
            //------------------------------------------------
            // IDLE state: No active transaction
            //------------------------------------------------
            IDLE: begin
                // Transaction starts when PSEL asserted and PENABLE is 0
                if (PSEL && !PENABLE) begin
                    next_state = SETUP;
                end
            end
            
            //------------------------------------------------
            // SETUP state: Address phase (PSEL=1, PENABLE=0)
            //------------------------------------------------
            SETUP: begin
                // Move to ACCESS phase when PENABLE is asserted
                if (PSEL && PENABLE) begin
                    next_state = ACCESS;
                end
                // Abort if PSEL deasserted
                else if (!PSEL) begin
                    next_state = IDLE;
                end
            end
            
            //------------------------------------------------
            // ACCESS state: Data phase (PSEL=1, PENABLE=1)
            //------------------------------------------------
            ACCESS: begin
                // Transaction completes when PREADY is 1
                // Return to IDLE for next transaction
                if (PREADY) begin
                    next_state = IDLE;
                end
                // Stay in ACCESS if PREADY is 0 (master is waiting)
                else begin
                    next_state = ACCESS;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    //================================================
    // Transaction Type Detection
    //================================================
    // Capture PWRITE during SETUP phase (valid address phase)
    // PWRITE is stable throughout the transaction
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            write_transaction <= 1'b0;
        end else if (current_state == SETUP) begin
            // Sample write/read direction during address phase
            write_transaction <= PWRITE;
        end
    end
    
    //================================================
    // PREADY Generation - Flow Control
    //================================================
    // PREADY signals slave readiness:
    // - Always 1 during SETUP phase (address always accepted)
    // - During ACCESS phase: 
    //   1 for reads (return 0)
    //   0 for writes when RAM is full (stall master)
    //   1 for writes when RAM has space
    always_comb begin
        case (current_state)
            SETUP: begin
                // Address phase: always ready
                PREADY = 1'b1;
            end
            
            ACCESS: begin
                if (!write_transaction) begin
                    // Read transactions: always ready (return 0)
                    PREADY = 1'b1;
                end else begin
                    // Write transactions: stall if RAM is full
                    PREADY = !wr_full;
                end
            end
            
            default: begin
                PREADY = 1'b1;
            end
        endcase
    end
    
    //================================================
    // Write Enable Generation
    //================================================
    // Write is accepted when:
    // 1. Brige is in ACCESS phase (data phase)
    // 2. Transaction is a write
    // 3. RAM is not full
    // 4. Transaction completes (PREADY=1)
    assign write_accepted = (current_state == ACCESS) && 
                            write_transaction && 
                            !wr_full && 
                            PREADY;
    
    // Generate single-cycle write enable pulse to RAM manager
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            wr_en <= 1'b0;
        end else begin
            wr_en <= write_accepted;
        end
    end
    
    //================================================
    // Write Data Registration
    //================================================
    // Write data during ACCESS phase when write is accepted
    // PWDATA is valid throughout ACCESS phase
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            wr_data <= '0;
        end else if (write_accepted) begin
            // Truncate or extend to match RAM data width
            if (DATA_WIDTH <= APB_DATA_WIDTH) begin
                wr_data <= PWDATA[DATA_WIDTH-1:0];
            end else begin
                // If RAM wider than APB, zero-extend
                wr_data <= {{(DATA_WIDTH-APB_DATA_WIDTH){1'b0}}, PWDATA};
            end
        end
    end
    
    //================================================
    // Read Data Generation
    //================================================
    // Read operations via APB return zero.
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PRDATA <= '0;
        end else if ((current_state == ACCESS) && !write_transaction && PREADY) begin
            PRDATA <= '0;
        end
    end
    
    //================================================
    // Slave Error Response
    //================================================
    // No error conditions in this implementation
    // PSLVERR is always 0 (no error)
    assign PSLVERR = 1'b0;

endmodule