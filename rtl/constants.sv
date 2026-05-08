
//====================================================
// All global constants for both rtl and tb
//====================================================

`ifndef CONSTANTS_SV
`define CONSTANTS_SV

// ==== For RAM rtl module ====
parameter ADDR_WIDTH = 5;                    // RAM address bus width
parameter DATA_WIDTH = 32;                   // RAM data bus width
parameter RAM_CELLS_COUNT = 1 << ADDR_WIDTH; // RAM cells count, depending on maximum allowed by address length
parameter PTR_WIDTH = ADDR_WIDTH + 1;        // Width for painter on an empty cell: Gray code needs 1 more bit to detect overflow

// ==== For RAM standalone testbench ====
parameter CLK_A = 5; // CLK for APB in RAM testbench
parameter CLK_B = 15; // CLK for Serial in RAM testbench

// ==== For APB standart ====
parameter APB_ADDR_W = 32;
parameter APB_DATA_W = 32;

// ==== For Agent sinus calculation ====
real PI = 3.14159265358979322846264338327950288419716939937510; // PI constant

`endif