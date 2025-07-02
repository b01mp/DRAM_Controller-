`timescale 1ns/100ps

module sdr_ctrl_main(
    input  logic        pclk,
    input  logic        preset,
    input  logic        pwrite,
    input  logic        penable,

    output logic [3:0] iState,
    output logic [3:0] cState,
    output logic [3:0] clkCNT
);

// Parameters
`include "sdr_parameters.sv"

// Delay State Definitions
wire endOf_tRP          = (clkCNT == NUM_CLK_tRP);
wire endOf_tRFC         = (clkCNT == NUM_CLK_tRFC);
wire endOf_tMRD         = (clkCNT == NUM_CLK_tMRD);
wire endOf_tRCD         = (clkCNT == NUM_CLK_tRCD);
wire endOf_Cas_Latency  = (clkCNT == NUM_CLK_CL);
wire endOf_Read_Burst   = (clkCNT == (NUM_CLK_READ - 1));
wire endOf_Write_Burst  = (clkCNT == NUM_CLK_WRITE);
wire endOf_tDAL         = (clkCNT == NUM_CLK_WAIT);

// istate enum
typedef enum logic [3:0] {
    i_NOP    = 4'd0,
    i_PRE    = 4'd1,
    i_tRP    = 4'd2,
    i_AR1    = 4'd3,
    i_tRFC1  = 4'd4,
    i_AR2    = 4'd5,
    i_tRFC2  = 4'd6,
    i_MRS    = 4'd7,
    i_tMRD   = 4'd8,
    i_ready  = 4'd9
} init_state_t;

// cstate enum
typedef enum logic [3:0] {
    c_idle    = 4'd0,
    c_ACTIVE  = 4'd1,
    c_tRCD    = 4'd2,
    c_READA   = 4'd3,
    c_cl      = 4'd4,
    c_rdata   = 4'd5,
    c_WRITEA  = 4'd6,
    c_wdata   = 4'd7,
    c_tDAL    = 4'd8,
    c_AR      = 4'd9,
    c_tRFC    = 4'd10
} cmd_state_t;


// Internal Registers
reg        delay_100US;
reg [12:0] delay_100US_counter;

reg        sys_INIT_DONE; 
reg        sys_REF_REQ;
reg        sys_REF_ACK;
reg        sys_CYC_END;
reg        syncResetClkCNT;

// State Declaration
init_state_t iState;
cmd_state_t cState;


// INIT FSM //
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        iState <= #tDLY i_NOP;
    end else begin
        case (iState)
            i_NOP:  begin
                       if(delay_100US)                    // this signal is HIGH after 100us
                             iState <= #tDLY i_PRE;
                    end
            
            i_PRE:  begin
                       iState <= #tDLY (NUM_CLK_tRP == 0)? i_AR1 : i_tRP 
                    end
            
            i_tRP:  begin
                       if (endOf_tRP) iState <= #tDLY i_AR1;
                    end

            i_AR1:  begin
                       iState <= #tDLY (NUM_CLK_tRFC == 0) ? i_AR2 : i_tRFC1;
                    end
            
            i_tRFC1:begin 
                        if (endOf_tRFC) iState <= #tDLY i_AR2;
                    end

            i_AR2:  begin
                       iState <= #tDLY (NUM_CLK_tRFC == 0) ? i_MRS : i_tRFC2;
                    end

            i_tRFC2:begin
                        if (endOf_tRFC) iState <= #tDLY i_MRS;
                    end
            i_MRS:  begin
                        iState <= #tDLY (NUM_CLK_tMRD == 0) ? i_ready : i_tMRD;
                    end
            i_tMRD: begin
                        if (endOf_tMRD) iState <= #tDLY i_ready;
                    end
            i_ready:begin
                        iState <= #tDLY i_ready;
                    end

            default:
                        iState <= #tDLY i_NOP;
        endcase
    end
end

// Logic for 100US Delay
always_ff @(posedge pclk or posedge preset) begin 
    if (preset) begin
        delay_100US_counter <= 0;
        delay_100US <= 0;
    end else if (!delay_100US) begin
        if (delay_100US_counter < d100US - 1)
            delay_100US_counter <= NOP_delay_counter + 1;
        else
            delay_100US <= 1;  // 100us has passed
    end
end
endmodule

// sys_INIT_DONE Generation
always_ff @(posedge pclk or posedge preset) begin
    if(preset)begin
        sys_INIT_DONE <= #tDLY 0;
    end else begin
        case (iState)
            i_ready: sys_INIT_DONE <= #tDLY 1;
            default: sys_INIT_DONE <= #tDLY 0;
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
                        if(sys_REF_REQ && sys_INIT_DONE) cState <= #tDLY c_AR;
                        else if (!penable && sys_INIT_DONE) cState <= #tDLY c_ACTIVE;
                    end

            c_ACTIVE:begin
                        if(NUM_CLK_tRCD == 0)
                            cState <= #tDLY (pwrite)? c_WRITEA : c_READA;
                        else
                            cState <= #tDLY c_tRCD; 
                     end
            
            c_tRCD: begin
                        if(endOf_tRCD)
                            cState <= #tDLY (pwrite) ? c_READA : c_WRITEA;
                    end

            c_READA:begin
                        cState <= #tDLY c_cl;
                    end

            c_cl:   begin
                        if(endOf_Cas_Latency) cState <= #tDLY c_rdata;
                    end

            c_rdata:begin
                        if(endOf_Read_Burst) cState <= #tDLY c_idle;
                    end

            c_WRITEA:begin
                        cState <= #tDLY c_wdata;
                    end

            c_wdata:begin
                        if (endOf_Write_Burst) cState <= #tDLY c_tDAL;
                    end

            c_tDAL: begin
                        if (endOf_tDAL) cState <= #tDLY c_idle;
                    end

            c_AR:   begin
                        cState <= #tDLY (NUM_CLK_tRFC == 0) ? c_idle : c_tRFC;
                    end

            c_tRFC: begin
                        if (endOf_tRFC) cState <= #tDLY c_idle;
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
        sys_REF_ACK <= #tDLY 0;
    end else begin
        case(cState)
            c_idle:
                if (sys_REF_REQ && sys_INIT_DONE) sys_CYC_END <= #tDLY 1;
                else if (!sys_ADSn && sys_INIT_DONE) sys_CYC_END <= #tDLY 0;
                else sys_CYC_END <= #tDLY 1;

            c_ACTIVE,
            c_tRCD,
            c_READA,
            c_cl,
            c_WRITEA,
            c_wdata:
                sys_CYC_END <= #tDLY 0;
            c_rdata:
                sys_CYC_END <= #tDLY (endOf_Read_Burst) ? 1 : 0;
            c_tDAL:
                sys_CYC_END <= #tDLY (endOf_tDAL) ? 1 : 0;
            default:
                sys_CYC_END <= #tDLY 1;
        endcase 
    end
end

// Clock Counter
always_ff @(posedge pclk) begin
    if(syncResetClkCNT)clkCNT <= #tDLY 0;
    else clkCNT <= #tDLY clkCNT + 1;
end

// syncResetClkCNT generation
always_ff @(iState or cState or clkCNT) begin
    case(iState)
        i_PRE: 
            syncResetClkCNT <= #tDLY (NUM_CLK_tRP == 0) ? 1 : 0;
        i_AR1,
        i_AR2:
            syncResetClkCNT <= #tDLY (NUM_CLK_tRFC == 0) ? 1 : 0;
        i_NOP:
            syncResetClkCNT <= #tDLY 1;
        i_tRP:
            syncResetClkCNT <= #tDLY (endOf_tRP) ? 1 : 0;
        i_tMRD:
            syncResetClkCNT <= #tDLY (endOf_tMRD) ? 1 : 0;
        i_tRFC1,
        i_tRFC2:
            syncResetClkCNT <= #tDLY (endOf_tRFC) ? 1 : 0;
        i_ready:
            case (cState)
                c_ACTIVE:
                    syncResetClkCNT <= #tDLY (NUM_CLK_tRCD == 0) ? 1 : 0;
                c_idle:
                    syncResetClkCNT <= #tDLY 1;
                c_tRCD:
                    syncResetClkCNT <= #tDLY (endOf_tRCD) ? 1 : 0;
                c_tRFC:
                    syncResetClkCNT <= #tDLY (endOf_tRFC) ? 1 : 0;
                c_cl:
                syncResetClkCNT <= #tDLY (endOf_Cas_Latency) ? 1 : 0;
                c_rdata:
                        syncResetClkCNT <= #tDLY (clkCNT == NUM_CLK_READ) ? 1 : 0;
                c_wdata:
                        syncResetClkCNT <= #tDLY (endOf_Write_Burst) ? 1 : 0;
                default:
                        syncResetClkCNT <= #tDLY 0;
            endcase
    endcase
end