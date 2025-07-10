`timescale 1ns/100ps
`include "apb_transaction.sv"
`include "apb_driver.sv"
`include "apb_monitor.sv"
`include "apb_scoreboard.sv"
`include "apb_generator.sv"
`include "apb_env.sv"
`include "apb_test_rw_init.sv"

module testbench;
    logic pclk;
    logic preset;
    
    // APB Signals
    apb_if apb_if_inst(pclk, preset);
    
    // SDRAM SIGNALS
    wire [15:0] sdr_D;
    wire [15:0] sdr_A;
    wire [1:0] sdr_BA;
    wire sdr_CKE;
    wire sdr_CSn;
    wire sdr_RASn;
    wire sdr_CASn;
    wire sdr_WEn;
    wire sdr_DQM;
    
    sdr_ctrl_top DUT(
        .pclk(pclk),
        .preset(preset),
        .pselect(apb_if_inst.psel),
        .penable(apb_if_inst.penable),
        .pwrite(apb_if_inst.pwrite),
        .paddr(apb_if_inst.paddr),
        .pwdata(apb_if_inst.pwdata),
        .prdata(apb_if_inst.prdata),
        .pready(apb_if_inst.pready),
        .sdr_D(sdr_D),
        .sdr_A(sdr_A),
        .sdr_BA(sdr_BA),
        .sdr_CKE(sdr_CKE),
        .sdr_CSn(sdr_CSn),
        .sdr_RASn(sdr_RASn),
        .sdr_CASn(sdr_CASn),
        .sdr_WEn(sdr_WEn),
        .sdr_DQM(sdr_DQM)
    );
    
    sdr MUT(
        .sdr_DQ(sdr_D),
        .sdr_A(sdr_A),
        .sdr_BA(sdr_BA),
        .sdr_CK(pclk),
        .sdr_CKE(sdr_CKE),
        .sdr_CSn(sdr_CSn),
        .sdr_RASn(sdr_RASn),
        .sdr_CASn(sdr_CASn),
        .sdr_WEn(sdr_WEn),
        .sdr_DQM(sdr_DQM)
    );
    
    // Clock generation
    initial pclk = 0;
    always #10 pclk = ~pclk;  // 50MHz clock (20ns period)
    
    apb_test_rw_init test1;
    
    initial begin
        // Initialize all signals during reset
        initialize_signals();
        
        // Apply reset
        apply_reset();
        
        // Wait for initialization to complete
        wait_for_init_done();
        
        // Run the test
        run_test();
        
        // End simulation
        end_simulation();
    end
    
    // Task to initialize all signals
    task initialize_signals();
        $display("[TESTBENCH] Initializing signals at time %0t", $time);
        
        // Initialize APB signals to idle state
        apb_if_inst.psel    = 1'b0;
        apb_if_inst.penable = 1'b0;
        apb_if_inst.pwrite  = 1'b0;
        apb_if_inst.paddr   = 32'h0;
        apb_if_inst.pwdata  = 32'h0;
        
        // Apply reset
        preset = 1'b1;
        
        $display("[TESTBENCH] Signals initialized");
    endtask
    
    // Task to apply reset properly
    task apply_reset();
        $display("[TESTBENCH] Applying reset at time %0t", $time);
        
        // Hold reset for multiple clock cycles
        repeat(3) @(posedge pclk);
        
        // Release reset on negative edge to avoid race conditions
        @(negedge pclk);
        preset = 1'b0;
        
        $display("[TESTBENCH] Reset released at time %0t", $time);
    endtask
    
    // Task to wait for initialization
    task wait_for_init_done();
        $display("[TESTBENCH] Waiting for SDRAM initialization to complete...");
        
        // Wait for the initialization done signal
        @(posedge DUT.d1.sys_INIT_DONE);
        
        // Add a few more clock cycles for stability
        repeat(2) @(posedge pclk);
        
        $display("[TESTBENCH] SDRAM initialization complete at time %0t", $time);
    endtask
    
    // Task to run the test
    task run_test();
        $display("[TESTBENCH] **************** Starting Test! ****************");
        
        // Ensure we start on a clean clock edge
        @(negedge pclk);
        
        // Create and run the test
        test1 = new(apb_if_inst);
        test1.run();
        
        // Wait for test completion
        repeat(30) @(posedge pclk);
        
        $display("[TESTBENCH] Test completed at time %0t", $time);
    endtask
    
    // Task to end simulation
    task end_simulation();
        // Allow some time for final transactions
        #1000;
        
        $display("[TESTBENCH] Simulation complete at time %0t", $time);
        $finish;
    endtask
    
    // Monitor for debugging
    // initial begin
    //     $monitor("Time: %0t | preset: %b | pclk: %b | sys_INIT_DONE: %b | psel: %b | penable: %b", 
    //              $time, preset, pclk, DUT.d1.sys_INIT_DONE, apb_if_inst.psel, apb_if_inst.penable);
    // end
    
    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("[TESTBENCH] ERROR: Simulation timeout!");
        $finish;
    end
    
endmodule