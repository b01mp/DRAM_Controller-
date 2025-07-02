// class apb_generator;

//     mailbox gen2drv;
//     int unsigned num_transactions = 10;
//     bit verbose = 1;

//     function new(mailbox gen2drv);
//         this.gen2drv = gen2drv;
//     endfunction

//     task run();
//         apb_transaction txn;

//         for (int i=0; i<num_transactions; i++) begin
//             txn = new();

//             // randomize transaction
//             assert(txn.randomize() with{
//                 paddr inside {[16'h0000 : 16'h00FF]};
//                 pwrite dist {1 := 50, 0 := 50};
//                 pwdata inside {[16'h0000 : 16'hFFFF]};
//             }) else $fatal("[GENERATOR] Randomization failed");

//             if(verbose)begin
//                 $display("[GENERATOR] -> TXN[%0d]: %s Addr=0x%0h", i, txn.pwrite ? "WRITE" : "READ", txn.paddr);
//             end

//             gen2drv.put(txn); 
//         end
//     endtask

// endclass



class apb_generator;

    mailbox gen2drv;
    int unsigned num_transactions = 10;
    bit verbose = 1;
    apb_transaction txn;
    event drv_done;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task write;
        txn = new();

        input [15:0] addr;
        input [15:0] data;
        begin
            txn.paddr = addr;
            txn.pwdata = data;
            txn.pwrite = 1;
        end
    endtask

    task read;
        @(drv_done);
        txn = new();
        input [15:0] addr;
        
        begin
            txn.paddr = addr;
            txn.pwrite = 0;
        end
    endtask
    
    write(16'h000000, 16'h1234);
    read(16'h000000);

    write(16'h000200, 16'h5678);
    read(16'h000200);

    write(16'h000400, 16'h9ABC);
    read(16'h000400);

    write(16'h000600, 16'hDEF0);
    read(16'h000600);
endclass

