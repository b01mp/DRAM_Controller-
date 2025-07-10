`timescale 1ns/ 100ps

import sdr_parameters::*;

module sdr_ctrl_top(
    input logic pclk,
    input logic preset,
    input logic pselect,   
    input logic penable,
    input logic pwrite,
    input logic [15:0] paddr,
    input logic [15:0] pwdata,
    output logic [15:0] prdata,
    output logic [15:0] pready,

    inout logic [15:0] sdr_D,
    output logic [15:0] sdr_A,
    output logic [1:0]  sdr_BA,
    output logic sdr_CKE,
    output logic sdr_CSn,
    output logic sdr_RASn,
    output logic sdr_CASn,
    output logic sdr_WEn,
    output logic sdr_DQM
);

//`include "sdr_parameters.sv"

wire [3:0] iState;
wire [3:0] cState;
wire [3:0] clkCNT;

assign #tDLY sdr_DQM = 0;

sdr_ctrl_main d1(
    .pclk(pclk),
    .preset(preset),
    .pwrite(pwrite),
    .penable(penable),

    .iState(iState),
    .cState(cState),
    .clkCNT(clkCNT),
    .pready(pready)
);

sdr_ctrl_sig d2(
    .pclk(pclk),
    .preset(preset),
    .paddr(paddr),

    .iState(iState),
    .cState(cState),

    .sdr_CKE(sdr_CKE),
    .sdr_CSn(sdr_CSn),
    .sdr_RASn(sdr_RASn),
    .sdr_CASn(sdr_CASn),
    .sdr_WEn(sdr_WEn),
    .sdr_BA(sdr_BA),
    .sdr_A(sdr_A)
);

sdr_ctrl_data d3(
    .pclk(pclk),
    .preset(preset),
    .cState(cState),
    .clkCNT(clkCNT),

    .pwdata(pwdata),
    .prdata(prdata),
    .sdr_DQ(sdr_D)
);

always_ff@(posedge pclk) begin
    if (!preset) begin
        $display("[%0t][APB] iState=%s, cState=%s, clkCNT=%0d, pready=%0d, penable=%0d, pwrite=%0d, paddr=0x%0h, pwdata=0x%0h, prdata=0x%0h",
         $time, getIStateName(iState), getCStateName(cState), clkCNT,
         pready, penable, pwrite, paddr, pwdata, prdata);

        $display("[%0t][SDR] sdr_WEn=%0d,sdr_A=0x%0h, sdr_D  = 0x%0h",
                    $time,sdr_WEn,sdr_A,sdr_D);
    end
end

endmodule
