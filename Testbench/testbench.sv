`timescale 1ns/1ps

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



// MONITOR //
class apb_monitor;
    
    virtual apb_if.monitor vif; // inerface monitor modport

    mailbox mon2scb;

    bit verbose = 1;

    //constructor
    function new(virtual apb_if.monitor vif,
                mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    // main run task
    task run();
        apb_transaction txn;

        forever begin
            //wait for valid transfer throught the apb
            @(posedge vif.pclk);
            if (vif.cb.psel && vif.cb.penable && vif.cb.pready) begin
                txn = new();

                // sample the values at the correct phase
                txn.paddr  = vif.cb.paddr;
                txn.pwrite = vif.cb.pwrite;
                txn.pwdata = vif.cb.pwdata;
                txn.prdata = vif.cb.prdata;

                if(verbose) begin
                    $display("[MONITOR] Observed %s Addr=0x%0h %s=0x%0h".
                            txn.pwrite ? "WRITE" : "READ",
                            txn.paddr,
                            txn.pwrite ? "WDATA" : "RDATA",
                            txn.pwrite  txn.pwdata : txn.prdata);
                end

                mon2scb.put(txn);  //send the transaction to the scoreboard
            end
        end
    endtask
endclass



// Scoreboard //
class apb_scoreboard;
    
    
    mailbox mon2scb;    // mailbox to receive observed transactions from monitor

    bit[15:0] mem_model[*]; // 16-bit data

    int num_errors = 0;     //error counter

    bit verbose = 1;

    // Constructor
    function new(mailbox mon2scb);
        this.mon2scb = mon2scb
    endfunction
    
    // main task
    task run
        apb_transaction txn;

        forever begin
            //wait for a transaction from the monitor
            mon2scb.get txn;

            if (txn.pwrite) begin
                //write transaction
                mem_model[txn.paddr] = txn.pwdata;

                if(verbose)begin
                     $display("[SCOREBOARD] WRITE Addr=0x%0h Data=0x%0h",
                              txn.paddr, txn.pwdata);
                end
            end else begin
                // read the transaction
                bit [15:0] expected;

                // default expected value if not written before
                expected = mem_model.exists(txn.paddr) ? mem_model[txn.paddr] : '0;

                if(verbose)begin
                    $display("[SCOREBOARD] READ Addr=0x%0h Expected=0x%0h Got=0x%0h",
                              txn.paddr, expected, txn.prdata);
                end

                if (txn.prdata !== expected) begin
                    $error("[SCOREBOARD][FAIL] Addr=0x%0h Mismatch! Expected=0x%0h, Got=0x%0h",
                           txn.paddr, expected, txn.prdata);
                    num_errors++;
                end else begin
                    if (verbose)
                        $display("[SCOREBOARD][PASS] Addr=0x%0h Match OK", txn.paddr);
                end
            end
        end
    endtask

endclass

// Environment //
class apb_env;
    
    //virtual interface handle 
    virtual apb_if vif;

    //mailboxes
    mailbox gen2drv;
    mailbox mon2scb;

    //component handles
    apb_generator  gen;
    apb_driver     drv;
    apb_monitor    mon;
    apb_scoreboard scb;

    //verbosity settings 
    bit verbose_gen = 1;
    bit verbose_drv = 1;
    bit verbose_mon = 1; 
    bit verbose_scb = 1;

    //Constructor
    function new(virtual apb_if vif);
        this.vif = vif;

        //initialize mailboxes
        gen2drv = new();
        mon2scb = new();

        //instantiate components
        gen = new(gen2drv);
        drv = new(vif.master, gen2drv);
        mon = new(vif.monitor, mon2scb);
        scb = new(mon2scb);

        //set verbosity
        gen.verbose = verbose_gen;
        drv.verbose = verbose_drv;
        mon.verbose = verbose_mon;
        scb.verbose = verbose_scb;

    endfunction

    //run all components
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask

endclass


class apb_test;
    
    //environment handle
    apb_env env;

    //virtual interface handle
    virtual apb_if vif;

    //number of transactions to be generated
    int num_transactions = 20;

    //constructor
    function new(virtual apb_if vif);
        this.vif = vif;

        //create and cofigure environment
        env = new(vif);

        //set verbosity 
        env.verbose_gen = 1;
        env.verbose_drv = 1;
        env.verbose_mon = 1;
        env.verbose_scb = 1;
    endfunction

    //run the test
    task run();
        $display("[TEST] Starting DRAM Controller Test with %0d transactions...", num_transactions);

        //set the number of transactions in generator
        env.gen.num_transactions = num_transactions;

        //start environment
        env.run();

        //wait for generator to finish
        wait(env.gen.done);

        $display("[TEST] all transactions done");

        #10; //wait for transactions to process

        // final result
        if (env.scb.num_errors == 0) begin
            $display("[TEST] PASS: No mismatches found.");
        end else begin
            $error("[TEST] FAIL: %0d mismatches found.", env.scb.num_errors);
        end
    endtask
endclass


// TESTBENCH //
module testbench
    
    logic pclk;
    logic preset;

    apb_if apb_if_inst(pclk, preset);

    dram_controller dut (
        .pclk     (apb_if_inst.pclk),
        .preset   (apb_if_inst.preset),
        .psel     (apb_if_inst.psel),
        .penable  (apb_if_inst.penable),
        .pwrite   (apb_if_inst.pwrite),
        .paddr    (apb_if_inst.paddr),
        .pwdata   (apb_if_inst.pwdata),
        .prdata   (apb_if_inst.prdata),
        .pready   (apb_if_inst.pready),
        .pslverr  (apb_if_inst.pslverr)
        // Connect SDRAM pins separately if needed
    );

    apb_test test;

    //generate clock
    initial pclk = 0;
    always #10 pclk = ~pclk;

    //reset task
    task reset_dut();
        preset = 1;
        #50;
        preset = 0;
        #50;
        preset = 1;
        $display("[TB] Reset Complete");
    endtask

    initial begin
        // Reset
        reset_dut();

        // Create test and run
        test = new(apb_if_inst);
        test.num_transactions = 20;  // You can change this
        test.run();

        // Simulation end
        #100;
        $display("[TB] Simulation complete.");
        $finish;
    end
    
endmodule