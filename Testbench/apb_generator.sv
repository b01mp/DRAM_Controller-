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