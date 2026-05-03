//================================================
// Test module for APB with one cycled RAM
//================================================

`include "../rtl/constants.sv"

module apb_conv_part (
    // APB Slave Interface
    input  logic                  PCLK,
    input  logic                  PRESETn,
    input  logic [APB_ADDR_W-1:0] PADDR,
    input  logic [1:0]            PPROT,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [APB_DATA_W-1:0] PWDATA,
    input  logic [3:0]            PSTRB,
    output logic                  PREADY,
    output logic [APB_DATA_W-1:0] PRDATA,
    output logic                  PSLVERR
);

    // RAM A
    logic                  ram_a_wr_en;
    logic [DATA_WIDTH-1:0] ram_a_wr_data;
    logic                  ram_a_wr_full;
    
    // RAM B
    logic                  ram_b_rd_en;
    logic                  ram_b_rd_valid;
    logic [DATA_WIDTH-1:0] ram_b_rd_data;
    logic                  ram_b_rd_empty;

    
    //================================================
    // RAM instance - cycle: A to Write, B to Read
    //================================================
    ram ram_inst (
        .clk_wr    (PCLK),
        .clk_rd    (PCLK),
        .rst       (PRESETn),
        .wr_en     (ram_a_wr_en),
        .wr_data   (ram_a_wr_data),
        .wr_full   (ram_a_wr_full),
        .rd_en     (ram_b_rd_en),
        .rd_valid  (ram_b_rd_valid),
        .rd_data   (ram_b_rd_data),
        .rd_empty  (ram_b_rd_empty)
    );
    
    //================================================
    // APB Bridge
    //================================================
    apb_bridge apb_bridge_inst (
        .PCLK      (PCLK),
        .PRESETn   (PRESETn),
        .PADDR     (PADDR),
        .PPROT     (PPROT),
        .PSEL      (PSEL),
        .PENABLE   (PENABLE),
        .PWRITE    (PWRITE),
        .PWDATA    (PWDATA),
        .PSTRB     (PSTRB),
        .PREADY    (PREADY),
        .PRDATA    (PRDATA),
        .PSLVERR   (PSLVERR),
        .wr_en     (ram_a_wr_en),
        .wr_data   (ram_a_wr_data),
        .wr_full   (ram_a_wr_full),
        .rd_en     (ram_b_rd_en),
        .rd_valid  (ram_b_rd_valid),
        .rd_data   (ram_b_rd_data),
        .rd_empty  (ram_b_rd_empty)
    );

endmodule