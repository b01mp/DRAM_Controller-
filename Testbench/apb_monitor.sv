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
				$display("[MONITOR] Observed: WRITE Addr=0x%0h WDATA=0x%0h time: 0%t",
				            txn.paddr, txn.pwdata, $time);
			end else begin
				$display("[MONITOR] Observed READ Addr=0x%0h RDATA=0x%0h time: 0%t",
				            txn.paddr, txn.prdata, $time);
			end
                end

                mon2scb.put(txn);  //send the transaction to the scoreboard
            end
        end
    endtask
endclass
