// TRANSACTION OBJECT //
class apb_transaction;

    // Transaction fields
    rand bit        pwrite;   // 1 = write, 0 = read
    rand bit [15:0] paddr;    // Address
    rand bit [15:0] pwdata;   // Write data
         bit [15:0] prdata;   // Read data (captured during monitor/driver)
         bit        pslverr;  // Optional error flag

    // Constructor
    function new(string name = "apb_transaction");
    endfunction

    // Print method for debug
    function void display();
        $display("[APB TRANS] %s Addr=0x%0h %s Data=0x%0h",
                 (pwrite ? "WRITE" : "READ"),
                 paddr,
                 (pwrite ? "WDATA" : "->RDATA"),
                 (pwrite ? pwdata : prdata));
    endfunction

endclass



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


// GENERATOR //
class apb_generator;
    
    mailbox gen2drv;
    int unsigned num_transactions = 10;
    bit verbose = 1;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        apb_transaction txn;

        for (int i=0; i<num_transactions; i++) begin
            txn = new();

            // randomize transaction
            assert(txn.randomize() with{
                paddr inside {[16'h0000 : 16'h00FF]};
                pwrite dist {1 := 50, 0 := 50};
                pwdata inside {[16'h0000 : 16'hFFFF]};
            }) else $fatal("[GENERATOR] Randomization failed");

            if(verbose)begin
                $display("[GENERATOR] -> TXN[%0d]: %s Addr=0x%0h", i, txn.pwrite ? "WRITE" : "READ", txn.paddr);
            end

            gen2drv.put(txn); 
        end
    endtask
endclass


// DRIVER //
class apb_driver;
    virtual apb_if.master vif;
    mailbox gen2drv;
    bit verbose = 1;

    function new(virtual apb_if.master vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction


    // blocking run task
    task run();
        apb_transaction txn;

        forever begin
            gen2drv.get(txn);

            if(verbose)begin
                $display("[DRIVER] Driving: %s Addr=0x%0h", txn.pwrite ? "WRITE" : "READ", txn.paddr);
            end

            drive(txn)
        end
    endtask

    // actual APB Driving Logic
    task drive(port_list);
        @(posedfe vif.pclk);

        // Setup Phase
        vif.cb.paddr <= txn.paddr;
        vif.cb.pwrite <= txn.pwrite;
        vif.cb.pwdata <= txn.pwdata;
        vif.cb.psel <= 1;
        vif.cb.penable <= 0;

        @(posedge vif.pclk);

        // Enable Phase
        vif.cb.penable <= 1;

        do @(posedge vif.pclk); while (!vif.cb.pready); // wait for pready

        // Complete
        if(!txn.pwrite)begin
            txn.prdata = vif.cb.prdata;
        end

        txn.pslverr = vif.cb.pslverr;

        if(verbose)begin
            $display("[DRIVER] Done: Addr=0x%0h %s %s=0x0%h",
                        txn.paddr,
                        (txn.pwrite?"WRITE":"READ"),
                        (txn.pwrite?"WDATA":"RDATA"),
                        (txn.pwrite? txn.pwdata:txn.prdata));
        end

        // Reset bus signals
        vif.cb.psel    <= 0;
        vif.cb.penable <= 0;
        vif.cb.paddr   <= 0;
        vif.cb.pwrite  <= 0;
        vif.cb.pwdata  <= 0;
    endtask
endclass