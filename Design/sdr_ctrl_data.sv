`timescale 1ns/100ps

module sdr_ctrl_data(
    input logic pclk,
    input logic preset,
    input logic [3:0] cState,
    input logic [3:0] clkCNT,

    input  logic [15:0] pwdata,
    output logic [15:0] prdata,
    
    inout  logic [15:0] sdr_DQ
);

`include "sdr_parameters.sv"

// State Declaration
init_state_t iState;
cmd_state_t cState;

// Using the MT48LC8M16A2 SDRAM Module

reg [15:0] regSdrDQ;
reg        enableSysD;

reg [15:0] regSysD;
reg        enableSdrDQ;

wire stateWRITEA;

// READ Cycle Data Path
assign #tDLY prdata = (enableSysD)? regSdrDQ : 16'hzzzz;

always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        regSdrDQ <= #tDLY 16'h0000;
    end else begin
        regSdrDQ <= #tDLY sdr_DQ;
    end
end

always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        enableSysD <= #tDLY 0;
    end else if ((cState == c_rdata) && (clkCNT == NUM_CLK_READ - 1)) begin
        enableSysD <= #tDLY 1;
    end else begin
        enableSysD <= #tDLY 0;
    end
end

// WRITE Cycle Data Path
assign #tDLY sdr_DQ = (enableSdrDQ)? regSysD : 4'bzzzz;

assign #tDLY stateWRITEA = (cState == c_WRITEA) ? 1'b1 : 1'b0;

always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        enableSdrDQ <= #tDLY 0;
    end else if(cState == c_WRITEA)begin
        enableSdrDQ <= #tDLY 1'b1;
    end else if ((cState == c_wdata) && (clkCNT == NUM_CLK_WRITE)) begin
        enableSdrDQ <= #tDLY 1'b0;
    end
end

always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        regSysD <= #tDLY 16'h0000;
    end else begin
        regSysD <= #tDLY pwdata;
    end
end

endmodule