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
