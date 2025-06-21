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
    task drive(apb_transaction txn);
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
