typedef class apb_env;
typedef class apb_transaction;

class apb_test_rw_init;
	virtual apb_if vif;
	apb_env env; 
	apb_transaction txn;

	function new(virtual apb_if vif);
		this.vif = vif;
		env = new(vif); //initialized the nevironment here
	endfunction

	task run();
		env.run();
	endtask
endclass
