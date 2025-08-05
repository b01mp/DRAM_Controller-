module top_test (
    input clk,                    // 100MHz clock
    input [15:0] sw,             // 16 switches
    input btnC, btnU, btnD, btnL, btnR,  // 5 buttons
    output [15:0] led,           // 16 LEDs
    output [6:0] seg,            // 7-segment display
    output [7:0] an,             // 7-segment anodes
    
    // SDRAM interface ports
    inout [15:0] sdr_D,          // SDRAM data bus
    output [15:0] sdr_A,         // SDRAM address bus
    output [1:0] sdr_BA,         // SDRAM bank address
    output sdr_CKE,              // SDRAM clock enable
    output sdr_CSn,              // SDRAM chip select (active low)
    output sdr_RASn,             // SDRAM row address strobe (active low)
    output sdr_CASn,             // SDRAM column address strobe (active low)
    output sdr_WEn,              // SDRAM write enable (active low)
    output sdr_DQM               // SDRAM data mask
);

//---------------------------------------------------------------------
// Clock and Reset
//---------------------------------------------------------------------
wire clk_slow;
reg [25:0] clk_divider = 0;
reg reset_n = 1'b0;
reg [7:0] reset_counter = 8'h00;

// Create slower clock for manual testing
always @(posedge clk) begin
    clk_divider <= clk_divider + 1;
end
assign clk_slow = clk_divider[20]; // ~95Hz for visible changes

// Power-on reset generation
always @(posedge clk) begin
    if (reset_counter < 8'hFF) begin
        reset_counter <= reset_counter + 1;
        reset_n <= 1'b0;
    end else begin
        reset_n <= 1'b1;
    end
end

//---------------------------------------------------------------------
// Button Debouncing
//---------------------------------------------------------------------
reg btnC_prev, btnU_prev, btnD_prev, btnL_prev, btnR_prev;
wire btnC_pulse, btnU_pulse, btnD_pulse, btnL_pulse, btnR_pulse;

always @(posedge clk_slow) begin
    btnC_prev <= btnC;
    btnU_prev <= btnU;
    btnD_prev <= btnD;
    btnL_prev <= btnL;
    btnR_prev <= btnR;
end

assign btnC_pulse = btnC & ~btnC_prev;
assign btnU_pulse = btnU & ~btnU_prev;
assign btnD_pulse = btnD & ~btnD_prev;
assign btnL_pulse = btnL & ~btnL_prev;
assign btnR_pulse = btnR & ~btnR_prev;

// Synchronize btnC_pulse to clk domain
reg btnC_pulse_sync1, btnC_pulse_sync2;
always @(posedge clk) begin
    btnC_pulse_sync1 <= btnC_pulse;
    btnC_pulse_sync2 <= btnC_pulse_sync1;
end

//---------------------------------------------------------------------
// Test State Machine
//---------------------------------------------------------------------
localparam MODE_ADDR_INPUT = 4'h0;
localparam MODE_DATA_INPUT = 4'h1;
localparam MODE_READ_OUTPUT = 4'h2;
localparam MODE_STATUS = 4'h3;
localparam MODE_AUTO_TEST = 4'h4;

reg [3:0] current_mode = MODE_ADDR_INPUT;
reg [15:0] test_address = 16'h0000;
reg [15:0] test_data = 16'h0000;
reg [15:0] read_data = 16'h0000;
reg [3:0] test_state = 4'h0;
reg [15:0] test_patterns [0:7];
reg [2:0] pattern_index = 3'h0;
reg test_pass = 1'b0;
reg test_complete = 1'b0;

//---------------------------------------------------------------------
// APB Interface Signals for DRAM Controller
//---------------------------------------------------------------------
reg [15:0] paddr = 16'h0000;
reg [15:0] pwdata = 16'h0000;
wire [15:0] prdata;
reg pwrite = 1'b0;
reg pselect = 1'b0;
reg penable = 1'b0;
wire pready;

// APB state machine
reg [1:0] apb_state = 2'b00;
reg apb_write_req = 1'b0;
reg apb_read_req = 1'b0;
reg auto_write_req = 1'b0;
reg auto_read_req = 1'b0;

//---------------------------------------------------------------------
// DRAM Controller Instantiation
//---------------------------------------------------------------------
sdr_ctrl_top dut (
    .pclk(clk),
    .preset(reset_n),
    .pselect(pselect),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .sdr_D(sdr_D),
    .sdr_A(sdr_A),
    .sdr_BA(sdr_BA),
    .sdr_CKE(sdr_CKE),
    .sdr_CSn(sdr_CSn),
    .sdr_RASn(sdr_RASn),
    .sdr_CASn(sdr_CASn),
    .sdr_WEn(sdr_WEn),
    .sdr_DQM(sdr_DQM)
);

//---------------------------------------------------------------------
// Initialize Test Patterns
//---------------------------------------------------------------------
initial begin
    test_patterns[0] = 16'h1234;
    test_patterns[1] = 16'h5678;
    test_patterns[2] = 16'h9ABC;
    test_patterns[3] = 16'hDEF0;
    test_patterns[4] = 16'hAAAA;
    test_patterns[5] = 16'h5555;
    test_patterns[6] = 16'hFF00;
    test_patterns[7] = 16'h00FF;
end



//---------------------------------------------------------------------
// APB Transaction State Machine
//---------------------------------------------------------------------
always @(posedge clk) begin
    if (~reset_n) begin
        apb_state <= 2'b00;
        pselect <= 1'b0;
        penable <= 1'b0;
        pwrite <= 1'b0;
        paddr <= 16'h0000;
        pwdata <= 16'h0000;
    end else begin
        case (apb_state)
            2'b00: begin // IDLE
                pselect <= 1'b0;
                penable <= 1'b0;
                if (apb_write_req) begin
                    pselect <= 1'b1;
                    pwrite <= 1'b1;
                    paddr <= test_address;
                    pwdata <= test_data;
                    apb_state <= 2'b01;
                end else if (apb_read_req) begin
                    pselect <= 1'b1;
                    pwrite <= 1'b0;
                    paddr <= test_address;
                    apb_state <= 2'b01;
                end
            end
            
            2'b01: begin // SETUP
                penable <= 1'b1;
                apb_state <= 2'b10;
            end
            
            2'b10: begin // ACCESS
                if (pready) begin
                    if (~pwrite) begin
                        read_data <= prdata;
                    end
                    apb_state <= 2'b00;
                end
            end
            
            default: begin
                apb_state <= 2'b00;
            end
        endcase
    end
end

//---------------------------------------------------------------------
// Manual DRAM Operations
//---------------------------------------------------------------------
reg btnU_prev_fast, btnD_prev_fast;
wire btnU_pulse_fast, btnD_pulse_fast;

always @(posedge clk) begin
    btnU_prev_fast <= btnU;
    btnD_prev_fast <= btnD;
end

assign btnU_pulse_fast = btnU & ~btnU_prev_fast;
assign btnD_pulse_fast = btnD & ~btnD_prev_fast;

always @(posedge clk) begin
    if (~reset_n) begin
        apb_write_req <= 1'b0;
        apb_read_req <= 1'b0;
    end else begin
        if (current_mode != MODE_AUTO_TEST && apb_state == 2'b00) begin
            if (btnU_pulse_fast) begin // Write button
                apb_write_req <= 1'b1;
            end else begin
                apb_write_req <= 1'b0;
            end
            
            if (btnD_pulse_fast) begin // Read button
                apb_read_req <= 1'b1;
            end else begin
                apb_read_req <= 1'b0;
            end
        end else begin
            // In auto test mode, use auto requests
            apb_write_req <= auto_write_req;
            apb_read_req <= auto_read_req;
        end
    end
end

//---------------------------------------------------------------------
// Automatic Test Sequence
//---------------------------------------------------------------------

//---------------------------------------------------------------------
// Mode Selection and Input Handling
//---------------------------------------------------------------------

// Consolidated test_address handling
reg [7:0] test_delay_counter;

always @(posedge clk) begin
    if (~reset_n) begin
        current_mode <= MODE_ADDR_INPUT;
        test_address <= 16'h0000;
        test_data <= 16'h0000;
        test_state <= 4'h0;
        pattern_index <= 3'h0;
        test_pass <= 1'b1;
        test_complete <= 1'b0;
        test_delay_counter <= 8'h00;
        auto_write_req <= 1'b0;
        auto_read_req <= 1'b0;
    end else begin
        current_mode <= sw[15:12]; // Update mode on every clock

        // Default: hold values unless explicitly updated
        test_address <= test_address;
        test_data <= test_data;
        test_state <= test_state;
        pattern_index <= pattern_index;
        test_pass <= test_pass;
        test_complete <= test_complete;
        test_delay_counter <= test_delay_counter;
        auto_write_req <= 1'b0;
        auto_read_req <= 1'b0;

        case (current_mode)
            MODE_ADDR_INPUT: begin
                if (btnC_pulse) begin
                    test_address <= sw[15:0];
                end
            end
            MODE_DATA_INPUT: begin
                if (btnC_pulse) begin
                    test_data <= sw[15:0];
                end
            end
            MODE_READ_OUTPUT: begin
                // No test_address update
            end
            MODE_STATUS: begin
                // No test_address update
            end
            MODE_AUTO_TEST: begin
                case (test_state)
                    4'h0: begin // Initialize
                        pattern_index <= 3'h0;
                        test_pass <= 1'b1;
                        test_complete <= 1'b0;
                        test_delay_counter <= 8'h00;
                        test_state <= 4'h1;
                    end
                    4'h1: begin // Setup write
                        test_address <= {13'h0000, pattern_index};
                        test_data <= test_patterns[pattern_index];
                        test_delay_counter <= 8'h00;
                        test_state <= 4'h2;
                    end
                    4'h2: begin // Initiate write
                        if (apb_state == 2'b00) begin
                            auto_write_req <= 1'b1;
                            test_state <= 4'h3;
                        end
                    end
                    4'h3: begin // Wait for write complete
                        if (apb_state == 2'b00) begin
                            auto_write_req <= 1'b0;
                            test_delay_counter <= 8'h00;
                            test_state <= 4'h4;
                        end
                    end
                    4'h4: begin // Delay before read
                        test_delay_counter <= test_delay_counter + 1;
                        if (test_delay_counter == 8'hFF) begin
                            test_state <= 4'h5;
                        end
                    end
                    4'h5: begin // Initiate read
                        if (apb_state == 2'b00) begin
                            auto_read_req <= 1'b1;
                            test_state <= 4'h6;
                        end
                    end
                    4'h6: begin // Wait for read complete
                        if (apb_state == 2'b00) begin
                            auto_read_req <= 1'b0;
                            test_state <= 4'h7;
                        end
                    end
                    4'h7: begin // Compare data
                        if (read_data != test_patterns[pattern_index]) begin
                            test_pass <= 1'b0;
                        end
                        test_state <= 4'h8;
                    end
                    4'h8: begin // Next pattern or finish
                        if (pattern_index == 3'h7) begin
                            test_complete <= 1'b1;
                            test_state <= 4'h9;
                        end else begin
                            pattern_index <= pattern_index + 1;
                            test_state <= 4'h1;
                        end
                    end
                    4'h9: begin // Test complete
                        // Stay in this state
                    end
                    default: begin
                        test_state <= 4'h0;
                    end
                endcase
            end
            default: begin
                // No updates
            end
        endcase
    end
end

//---------------------------------------------------------------------
// LED Output Multiplexing
//---------------------------------------------------------------------
reg [15:0] led_reg;
assign led = led_reg;

always @(*) begin
    case (current_mode)
        MODE_ADDR_INPUT: begin
            led_reg = test_address;
        end
        
        MODE_DATA_INPUT: begin
            led_reg = test_data;
        end
        
        MODE_READ_OUTPUT: begin
            led_reg = read_data;
        end
        
        MODE_STATUS: begin
            led_reg = {12'h000, pready, (apb_state != 2'b00), pwrite, pselect};
        end
        
        MODE_AUTO_TEST: begin
            if (test_complete) begin
                led_reg = test_pass ? 16'hFFFF : 16'h0000;
            end else begin
                led_reg = {8'h00, test_state, current_mode};
            end
        end
        
        default: begin
            led_reg = sw;
        end
    endcase
end

//---------------------------------------------------------------------
// 7-Segment Display
//---------------------------------------------------------------------
reg [31:0] display_data;
reg [2:0] digit_select = 0;
reg [19:0] refresh_counter = 0;

// Refresh counter for 7-segment display
always @(posedge clk) begin
    refresh_counter <= refresh_counter + 1;
    digit_select <= refresh_counter[19:17];
end

// Select what to display on 7-segment
always @(*) begin
    case (current_mode)
        MODE_ADDR_INPUT: display_data = {16'hADD5, test_address};
        MODE_DATA_INPUT: display_data = {16'hDA7A, test_data};
        MODE_READ_OUTPUT: display_data = {16'h5EAD, read_data};
        MODE_STATUS: display_data = {16'h57A7, 12'h000, pready, (apb_state != 2'b00), pwrite, pselect};
        MODE_AUTO_TEST: begin
            if (test_complete) begin
                display_data = test_pass ? 32'h6A55_6A55 : 32'hFA11_FA11;
            end else begin
                display_data = {16'h7E57, 8'h00, test_state, current_mode};
            end
        end
        default: display_data = {16'h0000, sw};
    endcase
end

// 7-segment decoder
reg [3:0] current_digit;
always @(*) begin
    case (digit_select)
        3'h0: current_digit = display_data[3:0];
        3'h1: current_digit = display_data[7:4];
        3'h2: current_digit = display_data[11:8];
        3'h3: current_digit = display_data[15:12];
        3'h4: current_digit = display_data[19:16];
        3'h5: current_digit = display_data[23:20];
        3'h6: current_digit = display_data[27:24];
        3'h7: current_digit = display_data[31:28];
        default: current_digit = 4'h0;
    endcase
end

// Anode control
assign an = ~(8'h01 << digit_select);

// Segment decoder
reg [6:0] seg_reg;
assign seg = seg_reg;

always @(*) begin
    case (current_digit)
        4'h0: seg_reg = 7'b1000000; // 0
        4'h1: seg_reg = 7'b1111001; // 1
        4'h2: seg_reg = 7'b0100100; // 2
        4'h3: seg_reg = 7'b0110000; // 3
        4'h4: seg_reg = 7'b0011001; // 4
        4'h5: seg_reg = 7'b0010010; // 5
        4'h6: seg_reg = 7'b0000010; // 6
        4'h7: seg_reg = 7'b1111000; // 7
        4'h8: seg_reg = 7'b0000000; // 8
        4'h9: seg_reg = 7'b0010000; // 9
        4'hA: seg_reg = 7'b0001000; // A
        4'hB: seg_reg = 7'b0000011; // b
        4'hC: seg_reg = 7'b1000110; // C
        4'hD: seg_reg = 7'b0100001; // d
        4'hE: seg_reg = 7'b0000110; // E
        4'hF: seg_reg = 7'b0001110; // F
        default: seg_reg = 7'b1111111; // All segments off
    endcase
end

endmodule