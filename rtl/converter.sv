`include "constants.sv"

//====================================================
// Converter - APB Slave to Serial Master Bridge
//====================================================
module converter (
    // APB Slave Interface
    input  logic        PCLK,
    input  logic        PRESETn,
    input  logic [31:0] PADDR,
    input  logic [1:0]  PPROT,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,
    input  logic [3:0]  PSTRB,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    output logic        PSLVERR,
    
    // Serial Interface (master)
    input  logic        sclk,
    input  logic        srst,
    inout  wire         sdata,
    output logic        sctrl,
    input  logic        sready
);

    //================================================
    // Internal RAM connections
    //================================================
    
    // RAM A
    // APB writes to RAM A -> Serial reads from RAM A
    logic                     ram_a_wr_en;
    logic [DATA_WIDTH-1:0]    ram_a_wr_data;
    logic                     ram_a_wr_full;
    logic                     ram_a_rd_en;
    logic                     ram_a_rd_valid;
    logic [DATA_WIDTH-1:0]    ram_a_rd_data;
    logic                     ram_a_rd_empty;
    
    // RAM B
    // Serial writes to RAM B -> APB reads from RAM B
    logic                     ram_b_wr_en;
    logic [DATA_WIDTH-1:0]    ram_b_wr_data;
    logic                     ram_b_wr_full;
    logic                     ram_b_rd_en;
    logic                     ram_b_rd_valid;
    logic [DATA_WIDTH-1:0]    ram_b_rd_data;
    logic                     ram_b_rd_empty;
    
    //================================================
    // RAM Manager instances
    //================================================
    
    // RAM A: Write from APB (clk_wr = PCLK), Read from Serial (clk_rd = sclk)
    ram ram_a (
        .clk_wr    (PCLK),
        .clk_rd    (sclk),
        .rst       (PRESETn),
        .wr_en     (ram_a_wr_en),
        .wr_data   (ram_a_wr_data),
        .wr_full   (ram_a_wr_full),
        .rd_en     (ram_a_rd_en),
        .rd_valid  (ram_a_rd_valid),
        .rd_data   (ram_a_rd_data),
        .rd_empty  (ram_a_rd_empty)
    );
    
    // RAM B: Write from Serial (clk_wr = sclk), Read from APB (clk_rd = PCLK)
    ram ram_b (
        .clk_wr    (sclk),
        .clk_rd    (PCLK),
        .rst       (PRESETn),
        .wr_en     (ram_b_wr_en),
        .wr_data   (ram_b_wr_data),
        .wr_full   (ram_b_wr_full),
        .rd_en     (ram_b_rd_en),
        .rd_valid  (ram_b_rd_valid),
        .rd_data   (ram_b_rd_data),
        .rd_empty  (ram_b_rd_empty)
    );
    
    //================================================
    // APB Bridge instance
    //================================================
    // APB master writes to RAM A, reads from RAM B
    apb_bridge apb_bridge_inst (
        // APB Slave Interface
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
        // RAM A interface (write-only)
        .wr_en     (ram_a_wr_en),
        .wr_data   (ram_a_wr_data),
        .wr_full   (ram_a_wr_full),
        // RAM B interface (read-only)
        .rd_en     (ram_b_rd_en),
        .rd_valid  (ram_b_rd_valid),
        .rd_data   (ram_b_rd_data),
        .rd_empty  (ram_b_rd_empty)
    );
    
    //================================================
    // Serial Bridge instance
    //================================================
    // Serial master reads from RAM A, writes to RAM B
    serial_bridge serial_bridge_inst (
        // Serial Master Interface
        .sclk     (sclk),
        .srst     (srst),
        .sctrl    (sctrl),
        .sdata    (sdata),
        .sready   (sready),
        // RAM A interface (read-only)
        .rd_en    (ram_a_rd_en),
        .rd_valid (ram_a_rd_valid),
        .rd_data  (ram_a_rd_data),
        .rd_empty (ram_a_rd_empty),
        // RAM B interface (write-only)
        .wr_en    (ram_b_wr_en),
        .wr_data  (ram_b_wr_data),
        .wr_full  (ram_b_wr_full)
    );

endmodule