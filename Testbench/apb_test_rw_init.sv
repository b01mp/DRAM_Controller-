typedef class apb_env;
typedef class apb_transaction;

class apb_test_rw_init;

	virtual apb_if vif;
	apb_env env; 
	apb_transaction txn;

	function new(virtual apb_if vif);
		this.vif = vif;
		env = new(vif); //initialized the environment here
	endfunction

	task run();
		$display("[TEST]***************Starting Test! TIME: %0t****************", $time);
		env.run();
		#1000;
	endtask
endclass
