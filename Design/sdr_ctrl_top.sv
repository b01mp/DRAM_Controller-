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
    output logic pready,

    inout logic [15:0] sdr_D,
    output logic [11:0] sdr_A,
    output logic [1:0]  sdr_BA,
    output logic sdr_CKE,
    output logic sdr_CSn,
    output logic sdr_RASn,
    output logic sdr_CASn,
    output logic sdr_WEn,
    output logic sdr_DQM
);

//`include "sdr_parameters.sv"

parameter depth = 8;
parameter FIFO_DEPTH = depth;
reg [32:0] fifo [depth-1:0];
reg [2:0] wr_ptr = 0,rd_ptr = 0;
reg fifo_full = 0,fifo_empty = 0;
logic pready_reg = 0;
assign pready = pready_reg;
logic apb_req_pending = 0;

reg        cmd_in_progress = 0;
reg [32:0] current_cmd = 0;
logic [15:0] prdata_reg = 0;
assign prdata = prdata_reg;
logic [15:0] prdata_wire;
wire cmd_done;

wire is_write = current_cmd[32];
wire [15:0] cmd_addr = current_cmd[31:16];
wire [15:0] cmd_data = current_cmd[15:0];

always_ff @(posedge pclk or posedge preset) begin
    if (preset) begin
        wr_ptr      <= 0;
        rd_ptr      <= 0;
        fifo_full   <= 0;
        fifo_empty  <= 1;
        cmd_in_progress <= 0;
        current_cmd <= 0;
        prdata_reg <= 0;
    end else begin
        fifo_empty <= (wr_ptr == rd_ptr) && !fifo_full;
        fifo_full  <= ((wr_ptr + 1) % FIFO_DEPTH) == rd_ptr;

        // Push command into FIFO on APB access
        if (pselect && penable && !fifo_full) begin
            fifo[wr_ptr] <= {pwrite, paddr, pwdata};
            wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
            pready_reg <= 1;
            apb_req_pending <= 1;
        end
        if (!penable && apb_req_pending) begin
            pready_reg <= 0;
        end
        if (!cmd_in_progress && fifo_empty) begin
            pready_reg <= 1;
            apb_req_pending <= 0;
        end

        // When controller signals done, clear in-progress and handle read data
        if (cmd_in_progress && cmd_done) begin
            cmd_in_progress <= 0;
            if(!current_cmd[32])begin
                prdata_reg <= prdata_wire;
            end            
        end
        // If not processing a command and FIFO not empty, pop and issue
        // Only process commands when SDRAM is initialized (sys_INIT_DONE)
        if (!cmd_in_progress && !fifo_empty && d1.sys_INIT_DONE) begin
            current_cmd <= fifo[rd_ptr];
            $display("[POP] is_write=%b, cmd_addr=0x%h, cmd_data=0x%h, raw=0x%h", fifo[rd_ptr][32], fifo[rd_ptr][31:16], fifo[rd_ptr][15:0], fifo[rd_ptr]);
            cmd_in_progress <= 1;
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;            
        end
    end
end

// Pass to controller only when cmd_in_progress is set
wire ctrl_pwrite = cmd_in_progress ? is_write : 1'b0;
wire [15:0] ctrl_paddr = cmd_in_progress ? cmd_addr : 16'b0;
wire [15:0] ctrl_pwdata = cmd_in_progress ? cmd_data : 16'b0;
wire ctrl_penable = cmd_in_progress;


wire [3:0] iState;
wire [3:0] cState;
wire [3:0] clkCNT;

assign #tDLY sdr_DQM = 0;

sdr_ctrl_main d1(
    .pclk(pclk),
    .preset(preset),
    .pwrite(ctrl_pwrite),
    .penable(ctrl_penable),
    .iState(iState),
    .cState(cState),
    .clkCNT(clkCNT),
    .cmd_done(cmd_done)
);

sdr_ctrl_sig d2(
    .pclk(pclk),
    .preset(preset),
    .paddr(ctrl_paddr),
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
    .pwdata(ctrl_pwdata),
    .prdata(prdata_wire),
    .sdr_DQ(sdr_D)
);

always_ff@(posedge pclk) begin
    if (!preset) begin
        $display("[%0t][APB] iState=%s, cState=%s, clkCNT=%0d, pready=%0d, penable=%0d, pwrite=%0d, paddr=0x%0h, pwdata=0x%0h, prdata=0x%0h",
         $time, getIStateName(iState), getCStateName(cState), clkCNT,
         pready, penable, pwrite, paddr, pwdata, prdata);

        $display("[%0t][SDR] sdr_WEn=%0d,sdr_A=0x%0h, sdr_D  = 0x%0h",
                    $time,sdr_WEn,sdr_A,sdr_D);
        
        // Debug FIFO processing
        if (cmd_in_progress) begin
            $display("[%0t][FIFO] Processing cmd: %s addr=0x%04h data=0x%04h, sys_INIT_DONE=%b",
                     $time, current_cmd[32] ? "WRITE" : "READ", current_cmd[31:16], current_cmd[15:0], d1.sys_INIT_DONE);
        end
    end
end

endmodule
