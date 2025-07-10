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
            if (vif.psel && /*vif.penable && */vif.pready) begin
                txn = new();

                // sample the values at the correct phase
                txn.paddr  = vif.paddr;
                txn.pwrite = vif.pwrite;
                txn.pwdata = vif.pwdata;
                txn.prdata = vif.prdata;

                if(verbose) begin
                    if(txn.pwrite)begin
                        // $display("[%0t][MONITOR] Observed: WRITE Addr=0x%0h WDATA=0x%0h",
                        //             $time,txn.paddr, txn.pwdata);
                    end else begin
                        // $display("[%0t][MONITOR] Observed READ Addr=0x%0h RDATA=0x%0h",
                        //             $time,txn.paddr, txn.prdata);
                    end
                end

                mon2scb.put(txn);  //send the transaction to the scoreboard
            end
        end
    endtask
endclass
