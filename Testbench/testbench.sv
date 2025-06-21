`timescale 1ns/1ps

// TESTBENCH //
module testbench
    
    logic pclk;
    logic preset;

    apb_if apb_if_inst(pclk, preset);

    dram_controller dut (
        .pclk     (apb_if_inst.pclk),
        .preset   (apb_if_inst.preset),
        .psel     (apb_if_inst.psel),
        .penable  (apb_if_inst.penable),
        .pwrite   (apb_if_inst.pwrite),
        .paddr    (apb_if_inst.paddr),
        .pwdata   (apb_if_inst.pwdata),
        .prdata   (apb_if_inst.prdata),
        .pready   (apb_if_inst.pready),
        .pslverr  (apb_if_inst.pslverr)
        // Connect SDRAM pins separately if needed
    );

    apb_test test;

    //generate clock
    initial pclk = 0;
    always #10 pclk = ~pclk;

    //reset task
    task reset_dut();
        preset = 1;
        #50;
        preset = 0;
        #50;
        preset = 1;
        $display("[TB] Reset Complete");
    endtask

    initial begin
        // Reset
        reset_dut();

        // Create test and run
        test = new(apb_if_inst);
        test.num_transactions = 20;  // You can change this
        test.run();

        // Simulation end
        #100;
        $display("[TB] Simulation complete.");
        $finish;
    end
    
endmodule