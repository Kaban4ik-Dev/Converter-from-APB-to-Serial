
//====================================================
// All global constants for both rtl and tb
//====================================================

`ifndef CONSTANTS_SV
`define CONSTANTS_SV

// ==== For RAM rtl module ====
parameter ADDR_WIDTH = 5;
parameter DATA_WIDTH = 32;
parameter RAM_CELLS_COUNT = 1 << ADDR_WIDTH;

// ==== For RAM testbench ====
parameter PTR_WIDTH = ADDR_WIDTH + 1; // Gray code needs 1 more bit to detect overflow
parameter CLK_PERIOD_A = 10; // CLK for APB in RAM testbench
parameter CLK_PERIOD_B = 13; // CLK for Serial in RAM testbench

// ==== For APB standart ====
parameter APB_DATA_WIDTH = 32; // Maximum allowed data width
typedef enum logic [1:0] {
    IDLE   = 2'b00,   // No active transaction
    SETUP  = 2'b01,   // Setup phase (address phase)
    ACCESS = 2'b10    // Access phase (data phase)
} apb_state_t;

// ==== For APB to RAM testbench ====


// ==== For RAM to Serial testbench ====


// ==== For Converter testbench ====


// ==== For Internal Driver testbench ====


// ==== For External Driver testbench ====


// ==== For Agent testbench ====


// ==== For Test (main testbench) ====

`endif