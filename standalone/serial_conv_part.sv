//================================================
// Test module for Serial with one cycled RAM
//================================================

`include "../rtl/constants.sv"

module serial_conv_part (
    // Serial Master interface
    input  logic sclk,
    inout  wire  sdata,
    output logic sctrl,
    input  logic sready
);

    // RAM A
    logic                  ram_a_rd_en,
    logic [DATA_WIDTH-1:0] ram_a_rd_data,
    logic                  ram_a_rd_empty,
    
    // RAM B
    logic                  ram_b_wr_en,
    logic [DATA_WIDTH-1:0] ram_b_wr_data,
    logic                  ram_b_wr_full,

    
    //================================================
    // RAM instance - cycle: A to Read, B to Write
    //================================================
    ram ram_inst (
        .clk_wr    (sclk),
        .clk_rd    (sclk),
        .rst       (srst),
        .rd_en     (ram_a_rd_en),
        .rd_data   (ram_a_rd_data),
        .rd_empty  (ram_a_rd_empty),
        .wr_en     (ram_b_wr_en),
        .wr_data   (ram_b_wr_data),
        .wr_full   (ram_b_wr_full)
    );
    
    //================================================
    // Serial Bridge
    //================================================
    serial_bridge serial_bridge_inst (
        .scl      (sclk),
        .srst     (srst),
        .sdata    (sdata),
        .sready   (sready),
        .wr_en    (ram_a_wr_en),
        .wr_data  (ram_a_wr_data),
        .wr_full  (ram_a_wr_full),
        .rd_en    (ram_b_rd_en),
        .rd_data  (ram_b_rd_data),
        .rd_empty (ram_b_rd_empty)
    );

endmodule