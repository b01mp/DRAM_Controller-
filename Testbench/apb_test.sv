class apb_test;
    
    //environment handle
    apb_env env;

    //virtual interface handle
    virtual apb_if vif;

    //number of transactions to be generated
    int num_transactions = 20;

    //constructor
    function new(virtual apb_if vif);
        this.vif = vif;

        //create and cofigure environment
        env = new(vif);

        //set verbosity 
        env.verbose_gen = 1;
        env.verbose_drv = 1;
        env.verbose_mon = 1;
        env.verbose_scb = 1;
    endfunction

    //run the test
    task run();
        $display("[TEST] Starting DRAM Controller Test with %0d transactions...", num_transactions);

        //set the number of transactions in generator
        env.gen.num_transactions = num_transactions;

        //start environment
        env.run();

        //wait for generator to finish
        wait(env.gen.done);

        $display("[TEST] all transactions done");

        #10; //wait for transactions to process

        // final result
        if (env.scb.num_errors == 0) begin
            $display("[TEST] PASS: No mismatches found.");
        end else begin
            $error("[TEST] FAIL: %0d mismatches found.", env.scb.num_errors);
        end
    endtask
endclass