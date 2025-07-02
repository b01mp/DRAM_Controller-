`timescale 1ns/1ps 

module testbench;
	logic pclk;
	logic preset;

	// APB Signals
 	apb_if.dut apb_if_inst(pclk, preset);

	// SDRAM signals
	logic [3:0]  sdr_DQ;   // sdr data
	logic [11:0] sdr_A;    // sdr address
	logic [1:0]  sdr_BA;   // sdr bank address
	logic        sdr_CSn;  // sdr chip select
	logic        sdr_RASn; // sdr row address
	logic        sdr_CASn; // sdr column select
	logic        sdr_WEn;  // sdr write enable
	logic        sdr_DQM;  // sdr write data mask
	logic 		 sdr_REF;  // sdr refresh 
	logic 		 sdr_PRE;

	logic        sdr_CKE;  // sdr clock enable

	// SDRAM Controller Top Module Instantiation
	sdram_controller DUT(
		// APB INTERFACE
		.PCLK(apb_if_inst.pclk),
		.PRESETn(apb_if_inst.preset),
		.PSEL(apb_if_inst.psel),
		.PENABLE(apb_if_inst.penable),
		.PWRITE(apb_if_inst.pwrite),
		.PADDR(apb_if_inst.paddr),
		.PWDATA(apb_if_inst.pwdata),
		.PRDATA(apb_if_inst.prdata),
		.PREADY(apb_if_inst.pready),
		.PSLVERR(apb_if_inst.pslverr),

		// SDRAM MODEL
		.sdram_dq(sdr_DQ),
		.sdram_cs_n(sdr_CSn),
		.sdram_write_en(sdr_WEn),
		.sdram_cas_n(sdr_CASn),
		.sdram_ras_n(sdr_RASn),
		.refresh(sdr_REF),
		.precharge(sdr_PRE),
		.bank_sel_in(sdr_BA),
		.sdram_addr(sdr_A),
		.sdram_clk(apb_if_inst.pclk),
		.sdram_clk_en(sdr_CKE)
	);

	// SDRAM Module Instantiation
	sdram_module SDRAM(
		.dq(sdr_DQ),
		.addr(sdr_A),
		.ba(sdr_BA),
		.clk(apb_if_inst.pclk),
		.cke(sdr_CKE),
		.cs_n(sdr_CSn),
		.ras_n(sdr_RASn),
		.cas_n(sdr_CASn),
		.we_n(sdr_WEn),
		.refresh(sdr_REF),
		.precharge(sdr_PRE)
	);

	
	
	// generate clock
	// initial pclk= 0;
	always #10 pclk = ~pclk;

	initial begin
		apb_if_inst.pwrite <= 0;
		apb_if_inst.enable <= 1;
		apb_if_inst.preset <= 1;
		apb_if_inst.paddr <= 16'hFFFF;
		apb_if_inst.pwdata <= 16'hzzzz;
		apb_if_inst.prdata <= 16'hzzzz;
		apb_if_inst.pready <= 1;

		#10;
		@(posedge pclk);
		$display("coming out of reset at %0t", $time);
		apb_if_inst.preset <= 0; 
		#100000;
		@(posedge dut.init_done);   // change it's name depending on the design
		#500;
		@(negedge pclk);

		// Run Test //
		apb_test_rw_init test1 = new(apb_if_inst);
		test1 = new(apb_if_inst);
		test1.run();

		#1000;
		$finish;
		$display("Simulation complete at time %0t", $time);

	end
	
endmodule