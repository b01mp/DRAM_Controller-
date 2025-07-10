class apb_generator;

    mailbox gen2drv;
    int unsigned num_transactions = 10;
    bit verbose = 1;
    apb_transaction txn;
    event drv_done;
    mailbox drv2gen;  // Acknowledgment mailbox

    function new(mailbox gen2drv, event drv_done);
        this.gen2drv = gen2drv;
        this.drv_done = drv_done;
    endfunction

    // task write;
    //     input [15:0] addr;
    //     input [15:0] data;

	//     txn = new();
    //     begin
    //         txn.paddr = addr;
    //         txn.pwdata = data;
    //         txn.pwrite = 1;

    //         $display("[%0t][GENERATOR] WRITE Addr = 0x%0h Data = 0x%0h",$time, addr, data);
            
    //         gen2drv.put(txn);
    //         $display("[%0t][GENERATOR]about to wait for drv_done", $time);
    //         #100;
    //     end
    // endtask

    // task read;
    //     input [15:0] addr;
        
	//     txn = new();
    //     begin
    //         // #5 @(drv_done);
    //         // $display("[%0t][GENERATOR] drv_done received", $time);

    //         txn.paddr = addr;
    //         txn.pwrite = 0;

    //         $display("[%0t][GENERATOR] READ Addr = 0x%0h",$time, addr);
            
    //         gen2drv.put(txn);

    //         #120;
    //     end
    // endtask


    task write(input [15:0] addr, input [15:0] data);
        txn = new();
        txn.paddr = addr;
        txn.pwdata = data;
        txn.pwrite = 1;
        
        if(verbose) begin
            $display("[%0t][GENERATOR] Sending WRITE: Addr=0x%0h Data=0x%0h", $time, addr, data);
        end
        
        gen2drv.put(txn);
        
        // Wait for driver to complete the transaction
        @(drv_done);
        
        if(verbose) begin
            $display("[%0t][GENERATOR] WRITE completed: Addr=0x%0h Data=0x%0h", $time, addr, data);
        end
    endtask
    
    task read(input [15:0] addr, output [15:0] data);
        txn = new();
        txn.paddr = addr;
        txn.pwrite = 0;
        
        if(verbose) begin
            $display("[%0t][GENERATOR] Sending READ: Addr=0x%0h", $time, addr);
        end
        
        gen2drv.put(txn);
        
        // Wait for driver to complete the transaction
        @(drv_done);
        
        // Get the read data
        data = txn.prdata;
        
        if(verbose) begin
            $display("[%0t][GENERATOR] READ completed: Addr=0x%0h Data=0x%0h", $time, addr, data);
        end
    endtask
    
    task run();
        logic [15:0] read_data;
        
        // Test sequence with proper synchronization
        write(16'h0010, 16'h1234);
        read(16'h0010, read_data);
        
        write(16'h0200, 16'h5678);
        read (16'h0200, read_data);
        
        // write(16'h0400, 16'h9ABC);
        // read(16'h0400, read_data);
        
        // write(16'h0600, 16'hDEF0);
        // read(16'h0600, read_data);
        
        $display("[%0t][GENERATOR] All transactions completed", $time);
    endtask
endclass