//====================================================
// Serial Interface
//====================================================

`include "../rtl/constants.sv"

interface serial_if ();
    // Serial Interface
    logic sclk,
    wire  sdata,
    logic sctrl,
    logic sready

    // Modport for Master signals
    modport master(
        // Master inout
        inout sdata,
        // Master output
        output sctrl,
        // Master input
        input  sclk, sready
    );

    // Modport for Slave signals
    modport slave(
        // Slave inout
        inout sdata,
        // Slave input
        input  sctrl,
        // Slave output
        output sclk, sready
    );
    
    // Modport for Monitor signals
    modport monitor(
        // Monitor input
        input sclk, sctrl, sdata, sready
    );
endinterface