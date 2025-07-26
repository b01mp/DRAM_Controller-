package sdr_parameters ;
parameter tDLY = 2; // 2ns delay for simulation purpose


//---------------------------------------------------------------------
// SDRAM mode register definition
//

// Write Burst Mode
parameter Programmed_Length = 1'b0;
parameter Single_Access     = 1'b1;

// Operation Mode
parameter Standard          = 2'b00;

// CAS Latency
parameter Latency_2         = 3'b010;
parameter Latency_3         = 3'b011;

// Burst Type
parameter Sequential        = 1'b0;
parameter Interleaved       = 1'b1;

// Burst Length
parameter Length_1          = 3'b000;
parameter Length_2          = 3'b001;
parameter Length_4          = 3'b010;
parameter Length_8          = 3'b011;


/****************************
* Mode register setting
****************************/

parameter MR_Write_Burst_Mode = // Programmed_Length;
                                Single_Access;

parameter MR_Operation_Mode   =    Standard;

parameter MR_CAS_Latency      = Latency_2;
                                //    Latency_3;

parameter MR_Burst_Type       =    Sequential;
                                // Interleaved;

parameter MR_Burst_Length     =  Length_1;
                                // Length_2;
                                // Length_4;
                                // Length_8;

/****************************
* Bus width setting
****************************/

//
//           23 ......... 12     11 ....... 10      9 .........0
// sys_A  : MSB <-------------------------------------------> LSB
//
// Row    : RA_MSB <--> RA_LSB
// Bank   :                    BA_MSB <--> BA_LSB
// Column :                                       CA_MSB <--> CA_LSB
//
// MY DESIGN CONFIGS
parameter RA_MSB = 15;
parameter RA_LSB = 9 ;

parameter BA_MSB = 8;
parameter BA_LSB = 7;

parameter CA_MSB =  6;
parameter CA_LSB =  0;

parameter SDR_BA_WIDTH =  2; // BA0,BA1
parameter SDR_A_WIDTH  = 12; // A0-A11

/*
REFERENCE DESIGN CONFIG
parameter RA_MSB = 22;
parameter RA_LSB = 11;

parameter BA_MSB = 10;
parameter BA_LSB =  9;

parameter CA_MSB =  8;
parameter CA_LSB =  0;

parameter SDR_BA_WIDTH =  2; // BA0,BA1
parameter SDR_A_WIDTH  = 12; // A0-A11
*/



/****************************
* SDRAM AC timing spec
****************************/

// ----------------------------
// Timing Parameters
// ----------------------------
parameter tCK  = 20;
parameter tMRD = 2*tCK;
parameter tRP  = 15;
parameter tRFC = 66;
parameter tRCD = 15;
parameter tWR  = tCK + 7;
parameter tDAL = tWR + tRP;

//-------------------------------------------------------------
// Clock count definition for meeting SDRAM AC timing spec
// ------------------------------------------------------------



parameter NUM_CLK_tMRD = tMRD/tCK;
parameter NUM_CLK_tRP  =  tRP/tCK;
parameter NUM_CLK_tRFC = tRFC/tCK;
parameter NUM_CLK_tRCD = tRCD/tCK;
parameter NUM_CLK_tDAL = tDAL/tCK;

// tDAL needs to be satisfied before the next sdram ACTIVE command can
// be issued. State c_tDAL of CMD_FSM is created for this purpose.
// However, states c_idle, c_ACTIVE and c_tRCD need to be taken into
// account because ACTIVE command will not be issued until CMD_FSM
// switch from c_ACTIVE to c_tRCD. NUM_CLK_WAIT is the version after
// the adjustment.
//parameter NUM_CLK_WAIT = (NUM_CLK_tDAL < 3) ? 0 : NUM_CLK_tDAL - 3;
parameter NUM_CLK_WAIT = 0;// (NUM_CLK_tDAL < 3) ? 0 : NUM_CLK_tDAL - 3;

//parameter NUM_CLK_CL    = (MR_CAS_Latency == Latency_2) ? 2 :
  //                        (MR_CAS_Latency == Latency_3) ? 3 :
    //
      //                    2;  // default
parameter NUM_CLK_CL    = 2;
//
//parameter NUM_CLK_READ  = (MR_Burst_Length == Length_1) ? 1 :
//                          (MR_Burst_Length == Length_2) ? 2 :
//                          (MR_Burst_Length == Length_4) ? 4 :
//                          (MR_Burst_Length == Length_8) ? 8 :
//                          4; // default
parameter NUM_CLK_READ  = 1;

//parameter NUM_CLK_WRITE = (MR_Burst_Length == Length_1) ? 1 :
//                          (MR_Burst_Length == Length_2) ? 2 :
//                          (MR_Burst_Length == Length_4) ? 4 :
//                          (MR_Burst_Length == Length_8) ? 8 :
//                          4; // default

parameter NUM_CLK_WRITE = 1;

// -----------------------------------------------------------
// Delays
// -----------------------------------------------------------
parameter d100US = 5000;

//---------------------------------------------------------------------
// SDRAM commands (sdr_CSn, sdr_RASn, sdr_CASn, sdr_WEn)
//

parameter INHIBIT            = 4'b1111;
parameter NOP                = 4'b0111;
parameter ACTIVE             = 4'b0011;
parameter READ               = 4'b0101;
parameter WRITE              = 4'b0100;
parameter BURST_TERMINATE    = 4'b0110;
parameter PRECHARGE          = 4'b0010;
parameter AUTO_REFRESH       = 4'b0001;
parameter LOAD_MODE_REGISTER = 4'b0000;


//--------------------------------------------------------
// STATE DEFINITIONS
//--------------------------------------------------------
// istate
parameter i_NOP    = 4'd0;
parameter i_PRE    = 4'd1;
parameter i_tRP    = 4'd2;
parameter i_AR1    = 4'd3;
parameter i_tRFC1  = 4'd4;
parameter i_AR2    = 4'd5;
parameter i_tRFC2  = 4'd6;
parameter i_MRS    = 4'd7;
parameter i_tMRD   = 4'd8;
parameter i_ready  = 4'd9;


// cstate 
parameter c_idle    = 4'd0;
parameter c_ACTIVE  = 4'd1;
parameter c_tRCD    = 4'd2;
parameter c_READA   = 4'd3;
parameter c_cl      = 4'd4;
parameter c_rdata   = 4'd5;
parameter c_WRITEA  = 4'd6;
parameter c_wdata   = 4'd7;
parameter c_tDAL    = 4'd8;
parameter c_AR      = 4'd9;
parameter c_tRFC    = 4'd10;
parameter c_latch   = 4'd11;

function string getIStateName(input logic [3:0] state);
    case (state)
        4'd0:  return "i_NOP";
        4'd1:  return "i_PRE";
        4'd2:  return "i_tRP";
        4'd3:  return "i_AR1";
        4'd4:  return "i_tRFC1";
        4'd5:  return "i_AR2";
        4'd6:  return "i_tRFC2";
        4'd7:  return "i_MRS";
        4'd8:  return "i_tMRD";
        4'd9:  return "i_ready";
        default: return "UNKNOWN";
    endcase
endfunction

function string getCStateName(input logic [3:0] state);
    case (state)
        4'd0:  return "c_idle";
        4'd1:  return "c_ACTIVE";
        4'd2:  return "c_tRCD";
        4'd3:  return "c_READA";
        4'd4:  return "c_cl";
        4'd5:  return "c_rdata";
        4'd6:  return "c_WRITEA";
        4'd7:  return "c_wdata";
        4'd8:  return "c_tDAL";
        4'd9:  return "c_AR";
        4'd10: return "c_tRFC";
        default: return "UNKNOWN";
    endcase
endfunction


endpackage
