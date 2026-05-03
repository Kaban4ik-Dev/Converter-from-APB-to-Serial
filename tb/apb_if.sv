//====================================================
// APB Interface
//====================================================

`include "../rtl/constants.sv"

interface apb_if ();
    // APB Interface
    logic                  PCLK;       // System clock
    logic                  PRESETn;    // System reset
    logic [APB_ADDR_W-1:0] PADDR;      // Address in converter where to write 
    logic [1:0]            PPROT;      // Protection type
    logic                  PSEL;       // Select current slave
    logic                  PENABLE;    // Enable current slave
    logic                  PWRITE;     // Write = 1, read = 0
    logic [APB_DATA_W-1:0] PWDATA;     // Data to write
    logic [3:0]            PSTRB;      // Bytes to override
    logic                  PREADY;     // Slave ready
    logic [APB_DATA_W-1:0] PRDATA;     // Data to read
    logic                  PSLVERR;    // Slave error

    // Modport for Master signals
    modport master(
        // Master output
        output PRESETn, PADDR, PPROT, PSEL, PENABLE, PWRITE, PWDATA, PSTRB,
        // Master input
        input  PCLK, PREADY, PRDATA, PSLVERR
    );

    // Modport for Slave signals
    modport slave(
        // Slave input
        input  PCLK, PRESETn, PADDR, PPROT, PSEL, PENABLE, PWRITE, PWDATA, PSTRB,
        // Slave output
        output PREADY, PRDATA, PSLVERR
    );
    
    // Modport for Monitor signals
    modport monitor(
        // Monitor input
        input PRESETn, PADDR, PPROT, PSEL, PENABLE, PWRITE, PWDATA, PSTRB,
        input PCLK, PREADY, PRDATA, PSLVERR
    );
endinterface