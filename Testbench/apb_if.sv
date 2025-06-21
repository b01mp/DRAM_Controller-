// INTERFACE //
interface apb_if (
    input logic pclk,
    input logic preset
);
    // Signals
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [15:0] paddr;
    logic [15:0] pwdata;
    logic [15:0] prdata;
    logic        pready;
    logic        pslverr;

    // Declare the clocking block (used manually in testbench)
    clocking cb @(posedge pclk);
        default input #1ns output #1ns;
        input  prdata, pready, pslverr;
        output psel, penable, pwrite, paddr, pwdata;
    endclocking

    modport master (
        //the master will be used by the driver. 
        // driver "writes" to the output variables that is the psel, penable, pwrite, paddr, pwdata,
        // driver "reads" from the input variable that is the prdata, pready, pslverr

        input  pclk, preset,
        output psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr
    );

    modport monitor (
        //connects to the monitor
        //just observes everything

        input  pclk, preset,
        input  psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr
    );

    modport dut (
        // this is used for the DUT
        // input is to read to the dut and output is to write to the dut


        input  pclk, preset, psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr
    );
endinterface