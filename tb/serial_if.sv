//====================================================
// Serial Interface
//====================================================

`include "../rtl/constants.sv"

interface serial_if ();
    // Serial Interface
    logic sclk;
    logic srst;
    wire  sdata;
    logic sctrl;
    logic sready;

    // Separate ports for sdata for Testbench
    bit sdata_out_en;      // 1 - TB writes, 0 - TB reads
    bit sdata_out_value;   // Data from TB
    
    // Tri-stable driver
    assign sdata = sdata_out_en ? sdata_out_value : 1'bz;
    
    // Output signal for TB
    wire sdata_in_value = sdata;

    // Modport for Master signals
    modport master(
        // Master inout
        inout sdata,
        // Master output
        output sctrl,
        // Master input
        input  sclk, srst, sready
    );

    // Modport for Slave signals
    modport slave(
        // Slave inout
        inout sdata,
        // Slave input
        input  sctrl, sdata_in_value,
        // Slave output
        output sclk, srst, sready, sdata_out_en, sdata_out_value
    );
    
    // Modport for Monitor signals
    modport monitor(
        // Monitor input
        input sclk, srst, sctrl, sdata, sready
    );
endinterface