`timescale 1ns/ 100ps

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

    output logic [15:0] sdr_D,
    output logic [15:0] sdr_A,
    output logic [1:0]  sdr_BA,
    output logic sdr_CKE,
    output logic sdr_CSn,
    output logic sdr_RASn,
    output logic sdr_CASn,
    output logic sdr_WEn,
    output logic sdr_DQM
);

`include "sdr_parameters.sv"

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
    .clkCNT(clkCNT)
);

sdr_ctrl_sig d2(
    .pclk(pclk),
    .preset(preset),
    .paddr(paddr),

    .iState(iState),
    .cState(cState),
    .clkCNT(clkCNT),

    .sdr_CKE(sdr_CKE),
    .sdr_CSn(sdr_CSn),
    .sdr_RASn(sdr_RASn),
    .sdr_CASn(sdr_CASn),
    .sdr_WEn(sdr_WEn),
    .sdr_BA(sdr_BA),
    .sdr_A(sdr_A)
);

sdr_ctrl_top d3(
    .pclk(pclk),
    .preset(preset),
    .cState(cState),
    .clkCNT(clkCNT),

    .pwdata(pwdata),
    .prdata(prdata),
    .sdr_DQ(sdr_DQ)
);

endmodule