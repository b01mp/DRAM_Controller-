class apb_driver;
//  virtual apb_if.master vif;
    virtual apb_if.master vif;
    mailbox gen2drv;
    bit verbose = 1;
    apb_transaction txn;
    event drv_done;

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

        -> drv_done;
    endtask
endclass
