class apb_driver;
//  virtual apb_if.master vif;
    virtual apb_if.master vif;
    mailbox gen2drv;
    bit verbose = 1;
    apb_transaction txn;
    event drv_done;
    
    function new(virtual apb_if vif, mailbox gen2drv, event drv_done);
        this.vif = vif;
        this.gen2drv = gen2drv;
        txn = new(); 
        this.drv_done = drv_done;
    endfunction


    // blocking run task
    task run();
	//$display("[DRIVER] event object id: %0p", drv_done);
        // if(verbose)begin
        //         $display("[DRIVER] Driving." );
        // end

        forever begin
            gen2drv.get(txn);

            if(verbose)begin
                $display("[%0t][DRIVER] Driving. Addr=0x%0h, %s %s=0x0%h",$time, txn.paddr, (txn.pwrite?"WRITE":"READ"),(txn.pwrite?"WDATA":"RDATA"),(txn.pwrite? txn.pwdata:txn.prdata));
		        // $display("[%0t][DRIVER] Driving. Addr=0x%0h",$time, txn.paddr);
            end

            drive(txn);
            -> drv_done;
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
            $display("[%0t][DRIVER] Done: Addr=0x%0h %s %s=0x0%h",
                        $time,
                        txn.paddr,
                        (txn.pwrite?"WRITE":"READ"),
                        (txn.pwrite?"WDATA":"RDATA"),
                        (txn.pwrite? txn.pwdata:txn.prdata)
                    );
        end

        // $display("[DRIVER] about to trigger drv_done at time 0x%0t", $time);
        // #5 -> drv_done;
        // $display("[%0t][DRIVER] triggered drv_done at time", $time);

        repeat(4)@(posedge vif.pclk);
        // Reset bus signals
        $display("[%0t] Reset Signals ", $time);
        vif.cb.psel    <= 0;
        vif.cb.penable <= 0;
        vif.cb.paddr   <= 0;
        vif.cb.pwrite  <= 0;
        vif.cb.pwdata  <= 0;
    endtask
endclass
