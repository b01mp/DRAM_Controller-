    // Forward declarations for all classes
    typedef class apb_transaction;
    typedef class apb_generator;
    typedef class apb_driver;
    typedef class apb_monitor;
    typedef class apb_scoreboard;
    typedef class apb_env;
    typedef class apb_test_rw_init;

interface apb_if(
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
        input  prdata, pready, pslverr,
	clocking cb
    );

    modport monitor (
        //connects to the monitor
        //just observes everything

        input  pclk, preset,
        input  psel, penable, pwrite, paddr, pwdata,
        input  prdata, pready, pslverr,
	clocking cb
    );

    modport dut (
        // this is used for the DUT
        // input is to read to the dut and output is to write to the dut


        input  pclk, preset, psel, penable, pwrite, paddr, pwdata,
        output prdata, pready, pslverr,
	clocking cb
    );
endinterface






    // Transaction class
    class apb_transaction;
        
        // Transaction fields
        rand bit        pwrite;   // 1 = write, 0 = read
        rand bit [15:0] paddr;    // Address
        rand bit [15:0] pwdata;   // Write data
            bit [15:0] prdata;   // Read data (captured during monitor/driver)
            bit        pslverr;  // Optional error flag

        // Constructor
        function new();
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


    // GENERATOR CLASS
    class apb_generator;

        mailbox gen2drv;
        int unsigned num_transactions = 10;
        bit verbose = 1;
    
        function new(mailbox gen2drv);
            this.gen2drv = gen2drv;
        endfunction
    
        task write(input [15:0] addr, input [15:0] data);
            apb_transaction txn = new();
            txn.paddr = addr;
            txn.pwdata = data;
            txn.pwrite = 1;
            if (verbose)
                $display("[GENERATOR] WRITE  Addr=0x%0h Data=0x%0h", addr, data);
            gen2drv.put(txn);
        endtask
    
        task read(input [15:0] addr);
            apb_transaction txn = new();
            txn.paddr = addr;
            txn.pwrite = 0;
            if (verbose)
                $display("[GENERATOR] READ   Addr=0x%0h", addr);
            gen2drv.put(txn);
        endtask
    
        task run();
            // example use-case
            write(16'h0000, 16'h1234);
            read(16'h0000);
    
            write(16'h0200, 16'h5678);
            read(16'h0200);
    
            write(16'h0400, 16'h9ABC);
            read(16'h0400);
    
            write(16'h0600, 16'hDEF0);
            read(16'h0600);
        endtask
    
    endclass




    // Driver class
    class apb_driver;
    //  virtual apb_if.master vif;
        virtual apb_if.master vif;
        mailbox gen2drv;
        bit verbose = 1;
        apb_transaction txn;
        function new(virtual apb_if vif, mailbox gen2drv);
            this.vif = vif;
            this.gen2drv = gen2drv;
            txn= new(); 
        endfunction


        // blocking run task
        task run();
            if(verbose)begin
                    $display("[DRIVER] Driving." );
            end

            forever begin
                gen2drv.get(txn);

                if(verbose)begin
                    //$display("[DRIVER] Driving. Addr=0x%0h", txn.pwrite ? "WRITE" : "READ", txn.paddr);
            $display("[DRIVER] Driving. Addr=0x%0h at time=%0t", txn.paddr, $time);
                end

                drive(txn);
            end
        endtask

        // actual APB Driving Logic
        task drive(apb_transaction txn);
            @(posedge vif.pclk);

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
                $display("[DRIVER] Done: Addr=0x%0h %s %s=0x0%h time=%0t",
                            txn.paddr,
                            (txn.pwrite?"WRITE":"READ"),
                            (txn.pwrite?"WDATA":"RDATA"),
                            (txn.pwrite? txn.pwdata:txn.prdata),
                $time);
            end

            // Reset bus signals
            vif.cb.psel    <= 0;
            vif.cb.penable <= 0;
            vif.cb.paddr   <= 0;
            vif.cb.pwrite  <= 0;
            vif.cb.pwdata  <= 0;
        endtask
    endclass


    // Monitor class
    class apb_monitor;
    //  virtual apb_if.monitor vif;
        virtual apb_if.monitor vif; // inerface monitor modport

        mailbox mon2scb;

        bit verbose = 1;

        //constructor
        function new(virtual apb_if vif,
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
                if(txn.pwrite)begin
                    $display("[MONITOR] Observed: WRITE Addr=0x%0h WDATA=0x%0h",
                                txn.paddr, txn.pwdata);
                end else begin
                    $display("[MONITOR] Observed READ Addr=0x%0h RDATA=0x%0h",
                                txn.paddr, txn.prdata);
                end
                    end

                    mon2scb.put(txn);  //send the transaction to the scoreboard
                end
            end
        endtask
    endclass


    // Scoreboard class
    class apb_scoreboard;

        mailbox mon2scb;    // mailbox to receive observed transactions from monitor

        bit[15:0] mem_model[*]; // 16-bit data

        int num_errors = 0;     //error counter

        bit verbose = 1;

        // Constructor
        function new(mailbox mon2scb);
            this.mon2scb = mon2scb;
        endfunction
        
        // main task
        task run();
            apb_transaction txn = new();

            forever begin
                //wait for a transaction from the monitor
                mon2scb.get(txn);

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
                    expected = mem_model.exists(txn.paddr) ? mem_model[txn.paddr] : 0;

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


    // Environment class
    class apb_env;
	
        virtual apb_if vif;
        
        mailbox gen2drv = new(1);
        mailbox mon2scb = new(1);

        apb_generator gen;
        apb_driver drv;
        apb_monitor mon;
        apb_scoreboard scb;

        function new(virtual apb_if vif);
            // gen2drv = new();
            // mon2scb = new();
            gen = new(gen2drv);
            drv = new(vif.master, gen2drv);
            mon = new(vif.monitor, mon2scb);
            scb = new(mon2scb);

            this.vif = vif;
        endfunction

        task run();
            fork
                gen.run();
                drv.run();
                mon.run();
                scb.run();	
            join_none
        endtask
    endclass

    // Test class
    class apb_test_rw_init;
        virtual apb_if vif;
        apb_env env;
        
        function new(virtual apb_if vif);
            this.vif = vif;
            env = new(vif);
        endfunction
        
        task run();
            $display("Starting APB Read-Write Test...");
            env.run();
            $display("APB Read-Write Test Completed");
        endtask
    endclass


module testbench;
	logic pclk;
	logic preset;

	// APB Signals
 	apb_if.dut apb_if_inst(pclk, preset);

	// SDRAM signals
	logic [3:0]  sdr_DQ;   // sdr data
	logic [11:0] sdr_A;    // sdr address
	logic [1:0]  sdr_BA;   // sdr bank address
	logic        sdr_CSn;  // sdr chip select
	logic        sdr_RASn; // sdr row address
	logic        sdr_CASn; // sdr column select
	logic        sdr_WEn;  // sdr write enable
	logic        sdr_DQM;  // sdr write data mask
	logic 		 sdr_REF;  // sdr refresh 
	logic 		 sdr_PRE;

	logic        sdr_CKE;  // sdr clock enable

	// SDRAM Controller Top Module Instantiation
	sdram_controller DUT(
		// APB INTERFACE
		.PCLK(apb_if_inst.pclk),
		.PRESETn(apb_if_inst.preset),
		.PSEL(apb_if_inst.psel),
		.PENABLE(apb_if_inst.penable),
		.PWRITE(apb_if_inst.pwrite),
		.PADDR(apb_if_inst.paddr),
		.PWDATA(apb_if_inst.pwdata),
		.PRDATA(apb_if_inst.prdata),
		.PREADY(apb_if_inst.pready),
		.PSLVERR(apb_if_inst.pslverr),

		// SDRAM MODEL
		.sdram_dq(sdr_DQ),
		.sdram_cs_n(sdr_CSn),
		.sdram_write_en(sdr_WEn),
		.sdram_cas_n(sdr_CASn),
		.sdram_ras_n(sdr_RASn),
		.refresh(sdr_REF),
		.precharge(sdr_PRE),
		.bank_sel_in(sdr_BA),
		.sdram_addr(sdr_A),
		.sdram_clk(apb_if_inst.pclk),
		.sdram_clk_en(sdr_CKE)
	);

	// SDRAM Module Instantiation
	sdram_module SDRAM(
		.dq(sdr_DQ),
		.addr(sdr_A),
		.ba(sdr_BA),
		.clk(apb_if_inst.pclk),
		.cke(sdr_CKE),
		.cs_n(sdr_CSn),
		.ras_n(sdr_RASn),
		.cas_n(sdr_CASn),
		.we_n(sdr_WEn),
		.refresh(sdr_REF),
		.precharge(sdr_PRE)
	);

	// generate clock
	// initial pclk= 0;
	always #10 pclk = ~pclk;

	initial begin
		apb_if_inst.pwrite <= 0;
		apb_if_inst.enable <= 1;
		apb_if_inst.preset <= 1;
		apb_if_inst.paddr <= 16'hFFFF;
		apb_if_inst.pwdata <= 16'hzzzz;
		apb_if_inst.prdata <= 16'hzzzz;
		apb_if_inst.pready <= 1;

		#10;
		@(posedge pclk);
		$display("coming out of reset at %0t", $time);
		apb_if_inst.preset <= 0; 
		#100000;
		@(posedge dut.init_done);   // change it's name depending on the design
		#500;
		@(negedge pclk);

		// Run Test //
		apb_test_rw_init test1 = new(apb_if_inst);
		test1 = new(apb_if_inst);
		test1.run();

		#1000;
		$finish;
		$display("Simulation complete at time %0t", $time);

	end

endmodule