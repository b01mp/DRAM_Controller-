`timescale 1ns/100ps

`include "sdr_paramenters.sv"

module sdr_ctrl_sig(
    input logic                 pclk,
    input logic                 preset,
    input logic [RA_MSB:CA_LSB] paddr,
    input logic [3:0]           iState,
    input logic [3:0]           cState,

    output logic                    sdr_CKE,
    output logic                    sdr_CSn,
    output logic                    sdr_RASn,
    output logic                    sdr_CASn,
    output logic                    sdr_WEn,
    output logic [SDR_BA_WIDTH-1:0] sdr_BA,
    output logic [SDR_A_WIDTH-1:0]  sdr_A
);

init_state_t iState;
cmd_state_t cState;

logic [3:0] sdr_COMMAND;
assign {sdr_CSn, sdr_RASn, sdr_CASn, sdr_WEn} = sdr_cmd;


always_ff@(posedge pclk or posedge preset)begin
    if(preset)begin
        sdr_COMMAND <= #tDLY INHIBIT;
        sdr_CKE <= #tDLY;
        sdr_BA <= #tDLY {SDR_BA_WIDTH{1'b1}};
        sdr_A <= #tDLY {SDR_A_WIDTH{1'b1}};
    end else begin
        case (iState)
            i_tRP,
            i_tRFC1,
            i_tRFC2,
            i_tMRD,
            i_NOP:  begin
                        sdr_COMMAND <= #tDLY NOP;
                        sdr_CKE <= #tDLY 1'b1;
                        sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b1}};
                        sdr_A   <= #tDLY {SDR_A_WIDTH{1'b1}};
                    end

            i_PRE:  begin
                        sdr_COMMAND <= #tDLY PRECHARGE;
                        sdr_CKE <= #tDLY 1'b1;
                        sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b1}};
                        sdr_A   <= #tDLY {SDR_A_WIDTH{1'b1}};
                    end

            i_AR1,
            i_AR2:  begin
                        sdr_COMMAND <= #tDLY AUTO_REFRESH;
                        sdr_CKE <= #tDLY 1'b1;
                        sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b1}};
                        sdr_A   <= #tDLY {SDR_A_WIDTH{1'b1}};
                    end

            i_MRS:  begin
                        sdr_COMMAND <= #tDLY LOAD_MODE_REGISTER;
                        sdr_CKE <= #tDLY 1'b1;
                        sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b0}};
                        sdr_A   <= #tDLY {
                                        2'b00,
                                        MR_Write_Burst_Mode,
                                        MR_Operation_Mode,
                                        MR_CAS_Latency,
                                        MR_Burst_Type,
                                        MR_Burst_Length
                                    };
                    end
            i_ready:begin
                        case (cState)
                            c_idle,
                            c_tRCD,
                            c_tRFC,
                            c_cl,
                            c_rdata,
                            c_wdata:    begin
                                            sdr_COMMAND <= #tDLY NOP;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b1}};
                                            sdr_A   <= #tDLY {SDR_A_WIDTH{1'b1}};                              
                                        end
                            c_ACTIVE:   begin
                                            sdr_COMMAND <= #tDLY ACTIVE;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA  <= #tDLY paddr[BA_MSB:BA_LSB];//bank
                                            sdr_A   <= #tDLY paddr[RA_MSB:RA_LSB];//row
                                        end
                            c_READA:    begin
                                            sdr_COMMAND <= #tDLY READ;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA <= #tDLY paddr[BA_MSB:BA_LSB];//bank
                                            sdr_A <= #tDLY {
                                                                1'b1,                    // A10 = 1 (auto-precharge enable)
                                                                1'b0,                    // A9 = 0 (don't care)
                                                                2'b00,                   // A8,A7 = 00 (don't care)
                                                                paddr[CA_MSB:CA_LSB]     // 7 bit column address
                                                            };
                                        end

                            c_WRITEA:   begin
                                            sdr_COMMAND <= #tDLY WRITE;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA  <= #tDLY sys_A[BA_MSB:BA_LSB];
                                            sdr_A <= #tDLY {
                                                                1'b1,                    // A10 = 1 (auto-precharge enable)
                                                                1'b0,                    // A9 = 0 (don't care)
                                                                2'b00,                   // A8,A7 = 00 (don't care)
                                                                paddr[CA_MSB:CA_LSB]     // 7 bit column address
                                                            };
                                        end
                            c_AR:       begin
                                            sdr_COMMAND <= #tDLY AUTO_REFRESH;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA <= #tDLY {SDR_BA_WIDTH{1'b1}};
                                            sdr_A <= #tDLY {SDR_A_WIDTH{1'b1}};
                                        end
                            default:    begin
                                            sdr_COMMAND <= #tDLY NOP;
                                            sdr_CKE <= #tDLY 1'b1;
                                            sdr_BA <= #tDLY {SDR_BA_WIDTH{1'b1}};
                                            sdr_A <= #tDLY {SDR_A_WIDTH{1'b1}};
                                        end
                        endcase
                    end
            default:begin
                        sdr_COMMAND <= #tDLY NOP;
                        sdr_CKE <= #tDLY 1'b1;
                        sdr_BA  <= #tDLY {SDR_BA_WIDTH{1'b1}};
                        sdr_A   <= #tDLY {SDR_A_WIDTH{1'b1}};
                    end
        endcase
    end
end
    
endmodule