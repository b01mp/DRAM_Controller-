`timescale 1ns/100ps

import sdr_parameters::*;

module sdr_ctrl_main(
    input  logic        pclk,
    input  logic        preset,
    input  logic        pwrite,
    input  logic        penable,

    output logic [3:0] iState,
    output logic [3:0] cState,
    output logic [3:0] clkCNT,
    output logic       pready
);

// Parameters
//`include "sdr_parameters.sv"

// Delay State Definitions
`define endOf_tRP          (clkCNT == NUM_CLK_tRP) 
`define endOf_tRFC         (clkCNT == NUM_CLK_tRFC)
`define endOf_tMRD         (clkCNT == NUM_CLK_tMRD)
`define endOf_tRCD         (clkCNT == NUM_CLK_tRCD)
`define endOf_Cas_Latency  (clkCNT == NUM_CLK_CL)
`define endOf_Read_Burst   (clkCNT == (NUM_CLK_READ - 1))
`define endOf_Write_Burst  (clkCNT == NUM_CLK_WRITE)
`define endOf_tDAL         (clkCNT == NUM_CLK_WAIT)



// Internal Registers
logic        delay_100US;
logic [12:0] delay_100US_counter;



logic        sys_INIT_DONE; 
logic        sys_REF_REQ;
logic        sys_REF_ACK;
logic        sys_CYC_END;
logic        syncResetClkCNT;
logic 	     NOP_delay_counter;

// State Declaration
// init_state_t iState;
// cmd_state_t cState;


// INIT FSM //
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        iState <= #tDLY i_NOP;
	    //$display("[MAIN] Inside preset at time: %0t", $time);
        delay_100US = 0;
        delay_100US_counter = 0;
        pready = 0;
    end else begin
        case (iState)
            i_NOP:  begin
                        $display("[MAIN] Inside NOP State at time: %0t", $time);
                        if (!delay_100US) begin
                            if (delay_100US_counter < 10)begin
                                delay_100US_counter <= delay_100US_counter + 1;
                                //$display("[MAIN] delay counter value: %0d;  delay_100US = %0d ", delay_100US_counter, delay_100US);
                                
                            end else begin
                                delay_100US <= 1;  // 100us has passed
                                //$display("[MAIN] 100us delay SATISFIED! %0d cycles ; delay_100US = %0d ,moving on to next state ", delay_100US_counter, delay_100US);
                            end
                        end
                        else begin //if(delay_100US)begin                    // this signal is HIGH after 100us
                            //$display("[MAIN] Moving on to PRECHARGE STATE at %0t", $time);
                            iState <= #tDLY i_PRE;
                        end
                    end

            i_PRE:  begin
                        //$display("[MAIN] Inside PRECHARGE State at time: %0t", $time);
                        iState <= #tDLY (NUM_CLK_tRP == 0)? i_AR1 : i_tRP ;
                    end
            
            i_tRP:  begin
                        //$display("[MAIN] Inside tRP State at time: %0t", $time);
                        if (`endOf_tRP) iState <= #tDLY i_AR1;
                    end

            i_AR1:  begin
                        //$display("[MAIN] Inside AUTO REFRESH-1 State at time: %0t", $time);
                       iState <= #tDLY (NUM_CLK_tRFC == 0) ? i_AR2 : i_tRFC1;
                    end
            
            i_tRFC1:begin 
                        //$display("[MAIN] Inside tRFC1 State at time: %0t", $time);
                        if (`endOf_tRFC) iState <= #tDLY i_AR2;
                    end

            i_AR2:  begin
                        //$display("[MAIN] Inside AUTO REFRESH-2 State at time: %0t", $time);
                       iState <= #tDLY (NUM_CLK_tRFC == 0) ? i_MRS : i_tRFC2;
                    end

            i_tRFC2:begin
                        //$display("[MAIN] Inside tRFC2 State at time: %0t", $time);
                        if (`endOf_tRFC) iState <= #tDLY i_MRS;
                    end
            i_MRS:  begin
                        //$display("[MAIN] Inside MODE REGISTER State at time: %0t", $time);
                        iState <= #tDLY (NUM_CLK_tMRD == 0) ? i_ready : i_tMRD;
                    end
            i_tMRD: begin
                        //$display("[MAIN] Inside tMRD State at time: %0t", $time);
                        if (`endOf_tMRD) iState <= #tDLY i_ready;
                    end
            i_ready:begin
                        //$display("[MAIN] Inside READY State at time: %0t", $time);
                        iState <= #tDLY i_ready;
                        pready <= #tDLY 1;
                    end

            default:
                        iState <= #tDLY i_NOP;
        endcase
    end
end

// Logic for 100US Delay
// always_ff @(posedge pclk or posedge preset) begin 
//     if (preset) begin
//         delay_100US_counter <= 0;
//         delay_100US <= 0;
//     end else begin
//         case (iState)
//             i_NOP:  begin
//                         if (!delay_100US) begin
//                             if (delay_100US_counter < d100US - 1)begin
//                                 delay_100US_counter <= NOP_delay_counter + 1;
//                                 $display("[MAIN] delay counter value: %0d;  delay_100US = %0d ", delay_100US_counter, delay_100US);
//                             end else begin
//                                 delay_100US <= 1;  // 100us has passed
//                                 $display("[MAIN] 100us delay SATISFIED! %0d cycles ; delay_100US = %0d ,moving on to next state.", delay_100US_counter, delay_100US);
//                             end
//                         end
//                     end
//         endcase
//     end
// end

// sys_INIT_DONE Generation
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        sys_INIT_DONE <= #tDLY 0;
    end else begin
        case (iState)
            i_ready:begin
                     sys_INIT_DONE <= #tDLY 1;
                    end
            default: begin
                        sys_INIT_DONE <= #tDLY 0;
            end
        endcase
    end
end

// CMD FSM //
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        cState <= #tDLY c_idle;
    end else begin
        case (cState)
            c_idle: begin
                        // $display("[CMD] Inside IDLE State at time: %0t", $time);
                        // $display("[CMD][IDLE] PENABLE = %0d; sys_INIT_DONE = %0d; time = %0t",penable, sys_INIT_DONE, $time);
                        if(sys_REF_REQ && sys_INIT_DONE) cState <= #tDLY c_AR;
                        else if (penable && sys_INIT_DONE) cState <= #tDLY c_ACTIVE;
                    end

            c_ACTIVE:begin
                        // $display("[CMD] Inside ACTIVE State at time: %0t", $time);
                        if(NUM_CLK_tRCD == 0)begin
                            // $display("PWRITE: %0d", pwrite);
                            cState <= #tDLY (pwrite)? c_WRITEA : c_READA;
                        end else
                            cState <= #tDLY c_tRCD; 
                     end
            
            c_tRCD: begin
                        // $display("[CMD] Inside tRCD State at time: %0t", $time);
                        if(`endOf_tRCD)
                            cState <= #tDLY (pwrite) ? c_WRITEA : c_READA;
                    end

            c_READA:begin
                        // $display("[CMD] Inside READA State at time: %0t", $time);
                        cState <= #tDLY c_cl;
                    end

            c_cl:   begin
                        // $display("[CMD] Inside c_cl State at time: %0t", $time);
                        if(`endOf_Cas_Latency) cState <= #tDLY c_rdata;
                    end

            c_rdata:begin
                        // $display("[CMD] Inside RDATA State at time: %0t", $time);
                        if(`endOf_Read_Burst) cState <= #tDLY c_idle;
                    end

            c_WRITEA:begin
                        // $display("[CMD] Inside WRITEA State at time: %0t", $time);
                        
                        cState <= #tDLY c_wdata;
                    end

            c_wdata:begin
                        // $display("[CMD] Inside WDATA State at time: %0t", $time);
                        
                        if (`endOf_Write_Burst) cState <= #tDLY c_tDAL;
                    end

            c_tDAL: begin
                        // $display("[CMD] Inside tDAL State at time: %0t", $time);
                        if (`endOf_tDAL) cState <= #tDLY c_idle;
                    end

            c_AR:   begin
                        // $display("[CMD] Inside AUTO REFRESH State at time: %0t", $time);
                        cState <= #tDLY (NUM_CLK_tRFC == 0) ? c_idle : c_tRFC;
                    end

            c_tRFC: begin
                        // $display("[CMD] Inside tRFC State at time: %0t", $time);
                        if (`endOf_tRFC) cState <= #tDLY c_idle;
                    end

            default:
                    cState <= #tDLY c_idle;
        endcase
    end
end

// sys_REF_ACK generation
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        sys_REF_ACK <= #tDLY 0;
    end else begin
        case (cState)
            c_idle:
                if (sys_REF_REQ && sys_INIT_DONE) sys_REF_ACK <= #tDLY 1;
                else sys_REF_ACK <= #tDLY 0;
            c_AR:
                if (NUM_CLK_tRFC == 0) sys_REF_ACK <= #tDLY 0;
                else sys_REF_ACK <= #tDLY 1;
            default:
                sys_REF_ACK <= #tDLY 0;
        endcase
    end
end

// sys_CYC_END generation
always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        sys_CYC_END <= #tDLY 0;
    end else begin
        case(cState)
            c_idle:
                if (sys_REF_REQ && sys_INIT_DONE) sys_CYC_END <= #tDLY 1;
                else if (!penable && sys_INIT_DONE) sys_CYC_END <= #tDLY 0;
                else sys_CYC_END <= #tDLY 1;

            c_ACTIVE,
            c_tRCD,
            c_READA,
            c_cl,
            c_WRITEA,
            c_wdata:
                sys_CYC_END <= #tDLY 0;
            c_rdata:
                sys_CYC_END <= #tDLY (`endOf_Read_Burst) ? 1 : 0;
            c_tDAL:
                sys_CYC_END <= #tDLY (`endOf_tDAL) ? 1 : 0;
            default:
                sys_CYC_END <= #tDLY 1;
        endcase 
    end
end

// // Clock Counter
// always_ff @(posedge pclk) begin
//     if(syncResetClkCNT)clkCNT <= #tDLY 0;
//     else clkCNT <= #tDLY clkCNT + 1;

//     $display("clkCNT = %0d; syncResetClkCNT = %0d; at time: %0t", clkCNT, syncResetClkCNT, $time);
// end

// // syncResetClkCNT generation
// always_ff@(posedge pclk or posedge preset) begin
//     if(preset)begin
//         syncResetClkCNT <= 0;
//     end else begin
//         case(iState)
//             i_PRE: 
//                 syncResetClkCNT <= #tDLY (NUM_CLK_tRP == 0) ? 1 : 0;
//             i_AR1,
//             i_AR2:
//                 syncResetClkCNT <= #tDLY (NUM_CLK_tRFC == 0) ? 1 : 0;
//             i_NOP:
//                 syncResetClkCNT <= #tDLY 1;
//             i_tRP:
//                 syncResetClkCNT <= #tDLY (endOf_tRP) ? 1 : 0;
//             i_tMRD:
//                 syncResetClkCNT <= #tDLY (endOf_tMRD) ? 1 : 0;
//             i_tRFC1,
//             i_tRFC2:
//                 syncResetClkCNT <= #tDLY (endOf_tRFC) ? 1 : 0;
//             i_ready:
//                 case (cState)
//                     c_ACTIVE:
//                         syncResetClkCNT <= #tDLY (NUM_CLK_tRCD == 0) ? 1 : 0;
//                     c_idle:
//                         syncResetClkCNT <= #tDLY 1;
//                     c_tRCD:
//                         syncResetClkCNT <= #tDLY (endOf_tRCD) ? 1 : 0;
//                     c_tRFC:
//                         syncResetClkCNT <= #tDLY (endOf_tRFC) ? 1 : 0;
//                     c_cl:
//                         syncResetClkCNT <= #tDLY (endOf_Cas_Latency) ? 1 : 0;
//                     c_rdata:
//                         syncResetClkCNT <= #tDLY (clkCNT == NUM_CLK_READ) ? 1 : 0;
//                     c_wdata:
//                         syncResetClkCNT <= #tDLY (endOf_Write_Burst) ? 1 : 0;
//                     default:
//                         syncResetClkCNT <= #tDLY 0;
//                 endcase
//         endcase
//     end
// end


// Clock Counter - Keep this sequential (clocked)
// always_ff @(posedge pclk or posedge preset) begin
//     if(preset) begin
//         clkCNT <= #tDLY 0;
//     end else if(syncResetClkCNT) begin
//         clkCNT <= #tDLY 0;
//     end else begin
//         clkCNT <= #tDLY clkCNT + 1;
//     end
//     //$display("clkCNT = %0d; syncResetClkCNT = %0d; at time: %0t", clkCNT, syncResetClkCNT, $time);
// end

always_ff @(posedge pclk or posedge preset) begin
    if(syncResetClkCNT) begin
        clkCNT <= #tDLY 0;
    end else begin
        clkCNT <= #tDLY clkCNT + 1;
    end
    //$display("clkCNT = %0d; syncResetClkCNT = %0d; at time: %0t", clkCNT, syncResetClkCNT, $time);
end

always@(iState or cState or clkCNT) begin
    if(preset) begin
        syncResetClkCNT = 0;
    end else begin
        case(iState)
            i_PRE:
                syncResetClkCNT = (NUM_CLK_tRP == 0) ? 1 : 0;
            i_AR1,
            i_AR2:
                syncResetClkCNT = (NUM_CLK_tRFC == 0) ? 1 : 0;
            i_NOP:
                syncResetClkCNT = 1;
            i_tRP:
                syncResetClkCNT = (`endOf_tRP) ? 1 : 0;
            i_tMRD:
                syncResetClkCNT = (`endOf_tMRD) ? 1 : 0;
            i_tRFC1,
            i_tRFC2:
                syncResetClkCNT = (`endOf_tRFC) ? 1 : 0;
            i_ready:
                case (cState)
                    c_ACTIVE:
                        syncResetClkCNT = (NUM_CLK_tRCD == 0) ? 1 : 0;
                    c_idle:
                        syncResetClkCNT = 1;
                    c_tRCD:
                        syncResetClkCNT = (`endOf_tRCD) ? 1 : 0;
                    c_tRFC:
                        syncResetClkCNT = (`endOf_tRFC) ? 1 : 0;
                    c_cl:
                        syncResetClkCNT = (`endOf_Cas_Latency) ? 1 : 0;
                    c_rdata:
                        syncResetClkCNT = (clkCNT == NUM_CLK_READ) ? 1 : 0;
                    c_wdata:
                        syncResetClkCNT = (`endOf_Write_Burst) ? 1 : 0;
                    default:
                        syncResetClkCNT = 0;
                endcase
            default:
                syncResetClkCNT = 0;
        endcase
    end
end

endmodule