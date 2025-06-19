`timescale 1ns / 1ps

module sdram_module (
    // SDRAM Interface
    inout  [15:0] dq,        // Bidirectional data bus
    input  [5:0]  addr,       // Multiplexed row/column address
    input  [1:0]  ba,         // Bank address
    input         clk,        // Clock
    input         cke,        // Clock enable
    input         cs_n,       // Chip select (active low)
    input         ras_n,      // Row address strobe (active low)
    input         cas_n,      // Column address strobe (active low)
    input         we_n,       // Write enable (active low)
    input         refresh,    // Refresh signal (from controller)
    input         precharge   // Precharge signal (from controller)
);

    // Memory Configuration
    parameter NUM_BANKS  = 4;
    parameter NUM_ROWS   = 64;
    parameter NUM_COLS   = 64;
    parameter DATA_WIDTH = 16;

    // Memory Array (4 banks × 64 rows × 64 columns)
    reg [DATA_WIDTH-1:0] memory [0:NUM_BANKS-1][0:NUM_ROWS-1][0:NUM_COLS-1];

    // Bank State Registers
    reg [5:0] active_row [0:NUM_BANKS-1];  // Track open row per bank
    reg [NUM_BANKS-1:0] bank_active;       // Bank activation status
    reg [DATA_WIDTH-1:0] data_out;         // Data output register
    reg data_out_en;                       // Output enable

    // Tri-State Data Bus
    assign dq = data_out_en ? data_out : {DATA_WIDTH{1'bz}};

    // Command Decoding
    wire cmd_activate  = ~cs_n & ~ras_n &  cas_n &  we_n;
    wire cmd_read      = ~cs_n &  ras_n & ~cas_n &  we_n;
    wire cmd_write     = ~cs_n &  ras_n & ~cas_n & ~we_n;
    wire cmd_precharge = ~cs_n & ~ras_n &  cas_n & ~we_n;
    wire cmd_refresh   = refresh;          // Directly use controller's refresh signal
    wire cmd_nop       =  cs_n | (ras_n & cas_n & we_n);

    // Internal Variables
    reg [5:0] col_addr_latched;
    reg [1:0] bank_latched;

    // Main Operation
    always @(posedge clk) begin
        if (cmd_nop) begin
            // No operation
            data_out_en <= 0;
        end
        else if (cmd_activate) begin
            // ACTIVE: Latch row and bank
            active_row[ba] <= addr;
            bank_active[ba] <= 1;
        end
        else if (cmd_read) begin
            // READ: Output data after CAS latency (simplified)
            data_out <= memory[ba][active_row[ba]][addr];
            data_out_en <= 1;
            col_addr_latched <= addr;
            bank_latched <= ba;
        end
        else if (cmd_write) begin
            // WRITE: Store data
            memory[ba][active_row[ba]][addr] <= dq;
        end
        else if (cmd_precharge || precharge) begin
            // PRECHARGE: Close all banks
            bank_active <= 0;
            data_out_en <= 0;
        end
        else if (cmd_refresh) begin
            // REFRESH: Simulate refresh cycle (no data change)
            data_out_en <= 0;
        end
    end

    // Initialize memory to zero
    integer b, r, c;
    initial begin
        for (b = 0; b < NUM_BANKS; b = b + 1) begin
            for (r = 0; r < NUM_ROWS; r = r + 1) begin
                for (c = 0; c < NUM_COLS; c = c + 1) begin
                    memory[b][r][c] = 0;
                end
            end
            bank_active[b] = 0;
        end
        data_out_en = 0;
    end

endmodule