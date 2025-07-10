typedef class apb_generator;
typedef class apb_driver;
typedef class apb_monitor;
typedef class apb_scoreboard;

class apb_env;
	
	virtual apb_if vif;
	
	mailbox gen2drv = new(1);
	mailbox mon2scb = new(1);
	event drv_done;

	apb_generator gen;
	apb_driver drv;
	apb_monitor mon;
	apb_scoreboard scb;

	function new(virtual apb_if vif);
		// gen2drv = new();
		// mon2scb = new();
		gen = new(gen2drv, drv_done);
		drv = new(vif.master, gen2drv, drv_done);
		mon = new(vif.monitor, mon2scb);
		scb = new(mon2scb);

		this.vif = vif;
	endfunction

	task run();
		fork
			$display("[ENV]***************Starting Environment! TIME: %0t****************", $time);
			gen.run();
			drv.run();
			mon.run();
			scb.run();	
		join
	endtask
endclass
