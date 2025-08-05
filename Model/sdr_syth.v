`timescale 1ns/100ps

module sdr_synth(
  sdr_DQ,        // sdr data
  sdr_A,         // sdr address
  sdr_BA,        // sdr bank address
  sdr_CK,        // sdr clock
  sdr_CKE,       // sdr clock enable
  sdr_CSn,       // sdr chip select
  sdr_RASn,      // sdr row address
  sdr_CASn,      // sdr column select
  sdr_WEn,       // sdr write enable
  sdr_DQM        // sdr write data mask
);

parameter Data_Width = 16;        // 16 bits
parameter SDR_A_WIDTH = 12;       // 12 bits (but you'll use 7 for row/column)
parameter SDR_BA_WIDTH = 2;       // 2 bits (4 banks)
parameter ROW_WIDTH = 7;          // 7 bits for row (as per your mapping)
parameter COL_WIDTH = 7;          // 7 bits for column (as per your mapping)
parameter NUM_BANKS = 4;          // 4 banks
parameter MEM_DEPTH = 2**(ROW_WIDTH + COL_WIDTH); // Memory depth per bank

input [SDR_A_WIDTH-1:0]  sdr_A;
input [SDR_BA_WIDTH-1:0] sdr_BA;
input                    sdr_CK;
input                    sdr_CKE;
input                    sdr_CSn;
input                    sdr_RASn;
input                    sdr_CASn;
input                    sdr_WEn;
input                    sdr_DQM;
inout [Data_Width-1:0]   sdr_DQ;


// Memory Array - Using Block RAM for synthesis
reg [Data_Width-1:0] memory_bank0 [0:MEM_DEPTH-1];
reg [Data_Width-1:0] memory_bank1 [0:MEM_DEPTH-1];
reg [Data_Width-1:0] memory_bank2 [0:MEM_DEPTH-1];
reg [Data_Width-1:0] memory_bank3 [0:MEM_DEPTH-1];

// Internal Registers
reg [2:0] cas_latency;
reg [2:0] burst_length;
reg [3:0] burst_type;
reg [1:0] write_burst_mode;

reg [SDR_BA_WIDTH-1:0] active_bank;
reg [ROW_WIDTH-1:0]    active_row;
reg [COL_WIDTH-1:0]    active_column;

reg [3:0] latency_counter;
reg [3:0] burst_counter;

reg [Data_Width-1:0] data_out_reg;
reg data_out_enable;

// State machine for read operations
reg read_active;
reg read_latency_phase;

// State machine for write operations  
reg write_active;

// Mode register
reg [SDR_A_WIDTH-1:0] mode_register;

// Initialize memory (for simulation purposes)
integer i;



initial begin
    // Initialize mode register with your specifications
    // CAS latency = 2, burst length = 1, sequential burst, single write burst
    cas_latency = 3'b010;       // Latency_2
    burst_length = 3'b000;      // Length_1
    burst_type = 1'b0;          // Sequential
    write_burst_mode = 1'b1;    // Single access
    
    // Initialize control signals
    active_bank = 2'd0;
    active_row = 7'd0;
    active_column = 7'd0;
    latency_counter = 4'd0;
    burst_counter = 4'd0;
    data_out_reg = 16'd0;
    data_out_enable = 1'b0;
    read_active = 1'b0;
    read_latency_phase = 1'b0;
    write_active = 1'b0;
    mode_register = 12'd0;
    
    // Initialize memory arrays (optional - for clean simulation)
    for (i = 0; i < MEM_DEPTH; i = i + 1) begin
        memory_bank0[i] = 16'd0;
        memory_bank1[i] = 16'd0;
        memory_bank2[i] = 16'd0;
        memory_bank3[i] = 16'd0;
    end
end

// Tri-State Data Bus Control
assign sdr_DQ = (data_out_enable && !sdr_CSn) ? data_out_reg : {Data_Width{1'bz}};

// Main SDRAM Command Processing
always @(posedge sdr_CKE) begin
    case ({sdr_CSn, sdr_RASn, sdr_CASn, sdr_WEn})
        4'b0000: begin
                mode_register <= sdr_A;
                cas_latency <= sdr_A[6:4];
                burst_length <= (sdr_A[2:0] == 3'b000) ? 3'd1 :
                               (sdr_A[2:0] == 3'b001) ? 3'd2 :
                               (sdr_A[2:0] == 3'b010) ? 3'd4 :
                               (sdr_A[2:0] == 3'b011) ? 3'd8 : 3'd1;
                write_burst_mode <= sdr_A[9] ? 2'd1 : 2'd0; // Single access or burst
                burst_type <= sdr_A[3] ? 4'd1 : 4'd0; // Interleaved or sequential
        end

        // Auto Refresh (REF) - 0001
        4'b0001: begin
                // Auto refresh command - no action needed for basic model
                read_active <= 1'b0;
                write_active <= 1'b0;
                data_out_enable <= 1'b0;
        end

        // Precharge (PRE) - 0010
        4'b0010: begin
                // Precharge command - close active rows
                read_active <= 1'b0;
                write_active <= 1'b0;
                data_out_enable <= 1'b0;
        end

        // Activate 
        4'b0011: begin
                active_bank <= sdr_BA;
                active_row <= sdr_A; //[ROW_WIDTH-1:0]; // Use only 7 bits for row
                read_active <= 1'b0;
                write_active <= 1'b0;
                data_out_enable <= 1'b0;
        end

        // Write 
        4'b0100: begin
                active_column <= sdr_A; //[COL_WIDTH-1:0]; // Use only 7 bits for column
                write_active <= 1'b1;
                burst_counter <= burst_length;
                
                // Write data immediately (no latency for write)
                if (!sdr_DQM) begin
                    case (sdr_BA)
                        2'b00: memory_bank0[{active_row, sdr_A[COL_WIDTH-1:0]}] <= sdr_DQ;
                        2'b01: memory_bank1[{active_row, sdr_A[COL_WIDTH-1:0]}] <= sdr_DQ;
                        2'b10: memory_bank2[{active_row, sdr_A[COL_WIDTH-1:0]}] <= sdr_DQ;
                        2'b11: memory_bank3[{active_row, sdr_A[COL_WIDTH-1:0]}] <= sdr_DQ;
                    endcase
                end
        end

        // Read
        4'b0101: begin
                active_column <= sdr_A; //[COL_WIDTH-1:0]; // Use only 7 bits for column
                read_latency_phase <= 1'b1;
                latency_counter <= cas_latency - 1; // Start latency countdown
                burst_counter <= burst_length;
            end

        // Burst Terminate
        4'b0110: begin
                read_active <= 1'b0;
                write_active <= 1'b0;
                data_out_enable <= 1'b0;
                burst_counter <= 4'd0;
            end

        // NOP or Continuing operations
        4'b0111: begin
                // Handle ongoing read latency
                if (read_latency_phase) begin
                    if (latency_counter == 4'd0) begin
                        read_latency_phase <= 1'b0;
                        read_active <= 1'b1;
                        data_out_enable <= 1'b1;
                        
                        // Output first data
                        case (active_bank)
                            2'b00: data_out_reg <= memory_bank0[{active_row, active_column}];
                            2'b01: data_out_reg <= memory_bank1[{active_row, active_column}];
                            2'b10: data_out_reg <= memory_bank2[{active_row, active_column}];
                            2'b11: data_out_reg <= memory_bank3[{active_row, active_column}];
                        endcase
                    end else begin
                        latency_counter <= latency_counter - 1;
                    end
                end
                
                // Handle ongoing read burst
                else if (read_active) begin
                    if (burst_counter > 4'd1) begin
                        burst_counter <= burst_counter - 1;
                        active_column <= active_column + 1;
                        
                        // Output next data
                        case (active_bank)
                            2'b00: data_out_reg <= memory_bank0[{active_row, active_column + 1}];
                            2'b01: data_out_reg <= memory_bank1[{active_row, active_column + 1}];
                            2'b10: data_out_reg <= memory_bank2[{active_row, active_column + 1}];
                            2'b11: data_out_reg <= memory_bank3[{active_row, active_column + 1}];
                        endcase
                    end else begin
                        read_active <= 1'b0;
                        data_out_enable <= 1'b0;
                    end
                end
                
                // Handle ongoing write burst  
                else if (write_active) begin
                    if (burst_counter > 4'd1) begin
                        burst_counter <= burst_counter - 1;
                        active_column <= active_column + 1;
                        
                        // Write next data
                        if (!sdr_DQM) begin
                            case (active_bank)
                                2'b00: memory_bank0[{active_row, active_column + 1}] <= sdr_DQ;
                                2'b01: memory_bank1[{active_row, active_column + 1}] <= sdr_DQ;
                                2'b10: memory_bank2[{active_row, active_column + 1}] <= sdr_DQ;
                                2'b11: memory_bank3[{active_row, active_column + 1}] <= sdr_DQ;
                            endcase
                        end
                    end else begin
                        write_active <= 1'b0;
                    end
                end
            end

            default: begin
                // Do nothing or handle invalid commands
            end
    endcase
end

endmodule