// Environment //
class apb_env;
    
    //virtual interface handle 
    virtual apb_if vif;

    //mailboxes
    mailbox gen2drv;
    mailbox mon2scb;

    //component handles
    apb_generator  gen;
    apb_driver     drv;
    apb_monitor    mon;
    apb_scoreboard scb;

    //verbosity settings 
    bit verbose_gen = 1;
    bit verbose_drv = 1;
    bit verbose_mon = 1; 
    bit verbose_scb = 1;

    //Constructor
    function new(virtual apb_if vif);
        this.vif = vif;

        //initialize mailboxes
        gen2drv = new();
        mon2scb = new();

        //instantiate components
        gen = new(gen2drv);
        drv = new(vif.master, gen2drv);
        mon = new(vif.monitor, mon2scb);
        scb = new(mon2scb);

        //set verbosity
        gen.verbose = verbose_gen;
        drv.verbose = verbose_drv;
        mon.verbose = verbose_mon;
        scb.verbose = verbose_scb;

    endfunction

    //run all components
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask

endclass
