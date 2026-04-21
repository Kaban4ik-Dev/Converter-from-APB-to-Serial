
//====================================================
// All global constants for both rtl and tb
//====================================================

`ifndef CONSTANTS_SV
`define CONSTANTS_SV

parameter ADDR_WIDTH = 2;
parameter DATA_WIDTH = 32;
parameter RAM_CELLS_COUNT = 1 << ADDR_WIDTH;
parameter CLK_PERIOD = 10;

`endif