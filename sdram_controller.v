`timescale 1ns / 1ps
module sdram_controller (
    // APB Interface
    input         pclk,
    input         presetn,
    input         psel,
    input         penable,
    input         pwrite,
    input  [15:0] paddr,
    input  [15:0] pwdata,
    output reg [15:0] prdata,
    output reg        pready,

    // SDRAM Interface
    inout  [15:0] sdram_dq,
    output reg  [5:0] sdram_addr,
    output reg  [1:0] sdram_ba,
    output reg        sdram_clk,
    output reg        sdram_cke,
    output reg        sdram_cs_n,
    output reg        sdram_ras_n,
    output reg        sdram_cas_n,
    output reg        sdram_we_n,
    output reg        sdram_refresh,
    output reg        sdram_precharge
);

    // Timing Parameters
    parameter tRC  = 6;
    parameter tRP  = 2;
    parameter tRCD = 2;
    parameter CL   = 2;
    parameter REFRESH_INTERVAL = 512;

    // State Encoding (Verilog style)
    parameter [3:0] 
        INIT_NOP       = 4'b0000,
        INIT_PRECHARGE = 4'b0001,
        INIT_REFRESH1  = 4'b0010,
        INIT_REFRESH2  = 4'b0011,
        INIT_READY     = 4'b0100,
        CMD_IDLE       = 4'b0101,
        CMD_ACTIVATE   = 4'b0110,
        CMD_ROW_DELAY  = 4'b0111,
        CMD_READ       = 4'b1000,
        CMD_WRITE      = 4'b1001,
        CMD_DATA       = 4'b1010,
        CMD_PRECHARGE  = 4'b1011,
        CMD_REFRESH    = 4'b1100;

    reg [3:0] current_state, next_state;
    reg [15:0] refresh_counter;
    reg [3:0] timer;
    reg [15:0] data_out;
    reg data_out_en;
    reg [1:0] bank;
    reg [5:0] row_addr, col_addr;

    // Tri-state buffer for data bus
    assign sdram_dq = data_out_en ? data_out : 16'hzzzz;

    // State Transition Logic
    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            current_state <= INIT_NOP;
            refresh_counter <= 0;
            sdram_cke <= 0;
            {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b1111;
            sdram_refresh <= 0;
            sdram_precharge <= 0;
            sdram_clk <= 0;
        end else begin
            current_state <= next_state;
            refresh_counter <= refresh_counter + 1;
            if (timer > 0) timer <= timer - 1;
            sdram_clk <= ~sdram_clk; // Generate SDRAM clock
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            INIT_NOP:       if (timer == 0) next_state = INIT_PRECHARGE;
            INIT_PRECHARGE: if (timer == 0) next_state = INIT_REFRESH1;
            INIT_REFRESH1:  if (timer == 0) next_state = INIT_REFRESH2;
            INIT_REFRESH2:  if (timer == 0) next_state = INIT_READY;
            INIT_READY:     if (psel) next_state = CMD_IDLE;
            CMD_IDLE:       if (penable) next_state = CMD_ACTIVATE;
                            else if (refresh_counter >= REFRESH_INTERVAL) 
                                next_state = CMD_REFRESH;
            CMD_ACTIVATE:   if (timer == 0) next_state = CMD_ROW_DELAY;
            CMD_ROW_DELAY:  if (timer == 0) next_state = pwrite ? CMD_WRITE : CMD_READ;
            CMD_READ:       if (timer == 0) next_state = CMD_DATA;
            CMD_WRITE:      if (timer == 0) next_state = CMD_DATA;
            CMD_DATA:       if (timer == 0) next_state = CMD_PRECHARGE;
            CMD_PRECHARGE:  if (timer == 0) next_state = INIT_READY;
            CMD_REFRESH:    if (timer == 0) next_state = INIT_READY;
            default:        next_state = INIT_NOP;
        endcase
    end

    // Output Logic
    always @(posedge pclk) begin
        // Default outputs
        {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b1111; // NOP
        sdram_addr <= 0;
        sdram_ba <= 0;
        data_out_en <= 0;
        timer <= 0;
        sdram_refresh <= 0;
        sdram_precharge <= 0;
        pready <= 0;

        case (current_state)
            INIT_NOP: begin
                sdram_cke <= 1;
                timer <= 10;
            end
            
            INIT_PRECHARGE: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0010;
                 // Precharge all banks
                sdram_precharge <= 1'b1;
                timer <= tRP;
            end
            
            INIT_REFRESH1, INIT_REFRESH2: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0001;
                sdram_refresh <= 1'b1;
                timer <= tRC;
            end
            
            INIT_READY: begin
                pready <= 1;
            end
            
            CMD_IDLE: begin
                pready <= 1;
                sdram_ba <= bank;
            end
            
            CMD_ACTIVATE: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0011;
                sdram_addr <= row_addr;
                sdram_ba <= bank;
                timer <= tRCD;
            end
            
            CMD_READ: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0101;
                sdram_addr <= col_addr;
                sdram_ba <= bank;
                timer <= CL;
            end
            
            CMD_WRITE: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0100;
                sdram_addr <= col_addr;
                sdram_ba <= bank;
                data_out <= pwdata;
                data_out_en <= 1;
            end
            
            CMD_DATA: begin
                if (!pwrite) prdata <= sdram_dq;
                timer <= tRP;
            end
            
            CMD_PRECHARGE: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0010;
                sdram_precharge <= 1'b1;
            end
            
            CMD_REFRESH: begin
                {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n} <= 4'b0001;
                sdram_refresh <= 1'b1;
                refresh_counter <= 0;
                timer <= tRC;
            end
        endcase
    end

    // Address Translation
    always @(*) begin
        bank = paddr[15:14];
        row_addr = paddr[13:8];
        col_addr = paddr[7:2];
    end

endmodule