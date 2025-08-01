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
                     $display("[%0t][SCOREBOARD] WRITE Addr=0x%0h Data=0x%0h",
                              $time,txn.paddr, txn.pwdata);
                end
            end else begin
                // read the transaction
                bit [15:0] expected;

                // default expected value if not written before
                expected = mem_model.exists(txn.paddr) ? mem_model[txn.paddr] : 0;

                if(verbose)begin
                    $display("[%0t][SCOREBOARD] READ Addr=0x%0h Expected=0x%0h Got=0x%0h",
                              $time,txn.paddr, expected, txn.prdata);
                end

                // if (txn.prdata !== expected) begin
                //     $error("[%0t][SCOREBOARD][FAIL] Addr=0x%0h Mismatch! Expected=0x%0h, Got=0x%0h",
                //            $time,txn.paddr, expected, txn.prdata);
                //     num_errors++;
                // end else begin
                //     if (verbose)
                //         $display("[%0t][SCOREBOARD][PASS] Addr=0x%0h Match OK",$time, txn.paddr);
                //     $stop;
                // end
                if(txn.prdata == expected) begin
                            if (verbose)
                            $display("[%0t][SCOREBOARD][PASS] Addr=0x%0h Match OK",$time, txn.paddr);
                                
                            $stop;
                end
                
            end
 
        end
    endtask

endclass
