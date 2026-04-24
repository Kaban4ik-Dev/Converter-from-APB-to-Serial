`include "constants.sv"

//====================================================
// Converter - Top Level Module
//====================================================
// This module connects:
// APB Driver (Internal) -> APB-to-RAM bridge -> RAM manager
// RAM manager -> RAM-to-Serial bridge -> Serial Driver (External)
//====================================================

module converter (
    //================================================
    // APB Slave Interface - Write (from APB master)
    //================================================
    input  logic        PCLK,           // APB clock (write clock domain)
    input  logic        PRESETn,        // APB reset
    input  logic [31:0] PADDR,          // APB address bus
    input  logic [2:0]  PPROT,          // Protection type
    input  logic        PSEL,           // APB select
    input  logic        PENABLE,        // APB enable
    input  logic        PWRITE,         // Write/read select
    input  logic [31:0] PWDATA,         // APB write data
    input  logic [3:0]  PSTRB,          // Write strobes
    output logic        PREADY,         // APB ready
    output logic [31:0] PRDATA,         // APB read data
    output logic        PSLVERR,        // APB slave error
    
    //================================================
    // Serial Master Interface - Read (to Serial slave)
    //================================================
    
    // Connector to RAM output, not a Serial
    input  logic        clk_rd,             // Read clock domain
    input  logic        rd_en,              // Read enable from serial
    output logic [DATA_WIDTH-1:0] rd_data,  // Read data to serial
    output logic        rd_empty            // Buffer empty flag

    // Serial
    //output logic        serial_clk,     // Serial bit clock (PCLK / 3)
    //output logic        serial_data,    // Serial data line (output from converter)
    //output logic        serial_ctrl,    // Control line: 0=command/address/data, 1=idle/response
    //input  logic        serial_ready,   // Serial slave ready to accept transaction
    //input  logic        serial_response // Serial slave response line (for read data)
);

    //================================================
    // Internal signals between modules
    //================================================
    // RAM Manager write interface
    logic                     wr_en;      // Write enable
    logic [DATA_WIDTH-1:0]    wr_data;    // Write data
    logic                     wr_full;    // Buffer full flag

    // RAM Manager read interface

    
    // Convert active-low APB reset to active-high for RAM manager
    logic rst_sync;
    assign rst_sync = !PRESETn;  // Convert to active-high
    
    //================================================
    // APB to RAM Bridge Instance
    //================================================
    apb_to_ram u_apb_to_ram (
        // APB Interface
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PADDR   (PADDR),
        .PPROT   (PPROT),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PREADY  (PREADY),
        .PRDATA  (PRDATA),
        .PSLVERR (PSLVERR),
        
        // RAM Manager Interface
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .wr_full (wr_full)
    );
    
    //================================================
    // RAM Manager Instance
    //================================================
    ram_manager u_ram_manager (
        // Clock domain A (write side - APB)
        .clk_wr  (PCLK),
        
        // Clock domain B (read side - Serial)
        .clk_rd  (clk_rd),
        
        // Reset
        .rst     (rst_sync),
        
        // Write interface (from APB)
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .wr_full (wr_full),
        
        // Read interface (to serial)
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .rd_empty(rd_empty)
    );

endmodule