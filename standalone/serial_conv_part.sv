//================================================
// Test module for Serial with one cycled RAM
//================================================

`include "../rtl/constants.sv"

module serial_conv_part (
    // Serial Master interface
    input  logic sclk,
    input  logic srst,
    inout  wire  sdata,
    output logic sctrl,
    input  logic sready,

    // RAM A - from Testbench to Serial
    input  logic                  ram_a_wr_en,
    input  logic [DATA_WIDTH-1:0] ram_a_wr_data,
    output logic                  ram_a_wr_full,
    
    // RAM B - from Serial to Testbench
    input  logic                  ram_b_rd_en,
    output logic                  ram_b_rd_valid,
    output logic [DATA_WIDTH-1:0] ram_b_rd_data,
    output logic                  ram_b_rd_empty
);
    // RAM A - from RAM to Mailbox
    logic                  ram_a_rd_en;
    logic                  ram_a_rd_valid;
    logic [DATA_WIDTH-1:0] ram_a_rd_data;
    logic                  ram_a_rd_empty;

    // RAM B - from Mailbox to RAM
    logic                  ram_b_wr_en;
    logic [DATA_WIDTH-1:0] ram_b_wr_data;
    logic                  ram_b_wr_full;

    //================================================
    // RAM A Instance - to read from
    //================================================
    ram ram_a_inst (
        .clk_wr    (sclk),
        .clk_rd    (sclk),
        .rst       (srst),
        .rd_en     (ram_a_rd_en),
        .rd_valid  (ram_a_rd_valid),
        .rd_data   (ram_a_rd_data),
        .rd_empty  (ram_a_rd_empty),
        .wr_en     (ram_a_wr_en),
        .wr_data   (ram_a_wr_data),
        .wr_full   (ram_a_wr_full)
    );

    //================================================
    // RAM B Instance - to write to
    //================================================
    ram ram_b_inst (
        .clk_wr    (sclk),
        .clk_rd    (sclk),
        .rst       (srst),
        .rd_en     (ram_b_rd_en),
        .rd_valid  (ram_b_rd_valid),
        .rd_data   (ram_b_rd_data),
        .rd_empty  (ram_b_rd_empty),
        .wr_en     (ram_b_wr_en),
        .wr_data   (ram_b_wr_data),
        .wr_full   (ram_b_wr_full)
    );
    
    //================================================
    // Serial Bridge
    //================================================
    serial_bridge serial_bridge_inst (
        .sclk     (sclk),
        .srst     (srst),
        .sctrl    (sctrl),
        .sdata    (sdata),
        .sready   (sready),
        .rd_en    (ram_a_rd_en),
        .rd_valid (ram_a_rd_valid),
        .rd_data  (ram_a_rd_data),
        .rd_empty (ram_a_rd_empty),
        .wr_en    (ram_b_wr_en),
        .wr_data  (ram_b_wr_data),
        .wr_full  (ram_b_wr_full)
    );

endmodule