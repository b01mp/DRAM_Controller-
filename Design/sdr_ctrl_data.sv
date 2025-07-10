`timescale 1ns/100ps

import sdr_parameters::*;

module sdr_ctrl_data(
    input logic pclk,
    input logic preset,
    input logic [3:0] cState,
    input logic [3:0] clkCNT,

    // APB SIDE
    input  logic [15:0] pwdata,
    output logic [15:0] prdata,
    
    // SDRAM SIDE
    inout  logic [15:0] sdr_DQ
);

//`include "sdr_parameters.sv"

// State Declaration
//init_state_t iState;
//cmd_state_t cState;

// Using the MT48LC8M16A2 SDRAM Module

logic [15:0] regSdrDQ;
logic        enableSysD;

logic [15:0] regSysD;
logic        enableSdrDQ;

logic stateWRITEA;

// READ Cycle Data Path
assign #tDLY prdata = (enableSysD)? regSdrDQ : 16'hzzzz;

// always_ff@(posedge pclk or posedge preset)begin
//     if(preset)begin
//         regSdrDQ <= #tDLY 16'h0000;
//     end else begin
//         regSdrDQ <= #tDLY sdr_DQ;
//     end
// end

// always_ff@(posedge pclk or posedge preset)begin
//     if(preset)begin
//         enableSysD <= #tDLY 0;
//     end else if ((cState == c_rdata) && (clkCNT == NUM_CLK_READ - 1)) begin
//         enableSysD <= #tDLY 1;
//     end else begin
//         enableSysD <= #tDLY 0;
//     end
// end

always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        regSdrDQ <= #tDLY 16'h0000;
        enableSysD <= #tDLY 0;
    end else if (cState == c_READA) begin
        regSdrDQ <= #tDLY sdr_DQ;
        enableSysD <= #tDLY 1;
    end else if ((cState == c_rdata)&&(clkCNT != 1)) begin
        regSdrDQ <= #tDLY sdr_DQ;
    end else if ((cState == c_rdata)&&(clkCNT == 1)) begin
        enableSysD <= #tDLY 0;
    end
end


// // WRITE Cycle Data Path
assign #tDLY sdr_DQ = (enableSdrDQ)? regSysD : 16'bzzzz;

assign #tDLY stateWRITEA = (cState == c_WRITEA) ? 1'b1 : 1'b0;

// write data from bus into buffer register regSysD
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        regSysD <= #tDLY 16'h0000;
        enableSdrDQ <= 0;
    end else if (cState == c_WRITEA) begin
        regSysD <= #tDLY pwdata;
        enableSdrDQ <= 1;
    end else if((cState == c_wdata) && (clkCNT != 1)) begin
        regSysD <= #tDLY pwdata;
    end else if ((cState == c_wdata) && (clkCNT == 1)) begin
        enableSdrDQ <= 0;
    end
end

// always_ff@(posedge pclk or posedge preset)begin
//     if(preset)begin
//         regSysD <= #tDLY 16'h0000;
//     end else begin
//         regSysD <= #tDLY pwdata;
//     end
// end

// Additional debug information - WRITE
// always_ff@(posedge pclk) begin
//     if (!preset) begin
//         $display("[%0t][DATA] State=%0d, clkCNT=%0d, enableSdrDQ=%0b, regSysD=0x%0h, sdr_DQ=0x%0h pwdata = 0x%0h", 
//                  $time, cState, clkCNT, enableSdrDQ, regSysD, sdr_DQ, pwdata);
//     end
// end

// // Additional debug information - READ
// always_ff@(posedge pclk) begin
//     if (!preset) begin
//         $display("[%0t][DATA] State=%0d, clkCNT=%0d, enableSysD=%0b, regSdrDQ=0x%0h, sdr_DQ=0x%0h prdata = 0x%0h", 
//                  $time, cState, clkCNT, enableSysD, regSdrDQ, sdr_DQ, prdata);
//     end
// end

endmodule


/*
else if ((cState == c_wdata) && (clkCNT == NUM_CLK_WRITE - 1)) begin
        $display("sdr_DQ = %0d", sdr_DQ);
        enableSdrDQ <= #tDLY 1'b0;
    end
*/


