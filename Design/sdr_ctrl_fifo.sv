
// SDR Controller FIFO Module
module sdr_ctrl_fifo #(
    parameter FIFO_DEPTH = 8
)(
    input logic pclk,
    input logic preset,
    
    // APB interface for pushing commands
    input logic pselect,
    input logic penable,
    input logic pwrite,
    input logic [15:0] paddr,
    input logic [15:0] pwdata,
    
    // FIFO status and control
    input logic cmd_done,           // Command completion signal
    input logic sys_init_done,      // System initialization done
    output logic fifo_empty,
    output logic fifo_full,
    
    // Command output interface
    output logic cmd_in_progress,
    output logic [32:0] current_cmd,
    
    // APB response
    output logic pready_reg,
    output logic apb_req_pending
);

    // FIFO storage and pointers
    reg [32:0] fifo [FIFO_DEPTH-1:0];
    reg [2:0] wr_ptr = 0;
    reg [2:0] rd_ptr = 0;
    
    // Internal registers
    reg fifo_full_reg = 0;
    reg fifo_empty_reg = 1;
    reg cmd_in_progress_reg = 0;
    reg [32:0] current_cmd_reg = 0;
    reg pready_reg_int = 0;
    reg apb_req_pending_reg = 0;
    
    // Assign outputs
    assign fifo_full = fifo_full_reg;
    assign fifo_empty = fifo_empty_reg;
    assign cmd_in_progress = cmd_in_progress_reg;
    assign current_cmd = current_cmd_reg;
    assign pready_reg = pready_reg_int;
    assign apb_req_pending = apb_req_pending_reg;

    always_ff @(posedge pclk or posedge preset) begin
        if (preset) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            fifo_full_reg <= 0;
            fifo_empty_reg <= 1;
            cmd_in_progress_reg <= 0;
            current_cmd_reg <= 0;
            pready_reg_int <= 0;
            apb_req_pending_reg <= 0;
        end else begin
            // Update FIFO status flags
            fifo_empty_reg <= (wr_ptr == rd_ptr) && !fifo_full_reg;
            fifo_full_reg <= ((wr_ptr + 1) % FIFO_DEPTH) == rd_ptr;

            // Push command into FIFO on APB access
            if (pselect && penable && !fifo_full_reg) begin
                fifo[wr_ptr] <= {pwrite, paddr, pwdata};
                wr_ptr <= (wr_ptr + 1) % FIFO_DEPTH;
                pready_reg_int <= 1;
                apb_req_pending_reg <= 1;
            end
            
            if (!penable && apb_req_pending_reg) begin
                pready_reg_int <= 0;
            end
            
            if (!cmd_in_progress_reg && fifo_empty_reg) begin
                pready_reg_int <= 1;
                apb_req_pending_reg <= 0;
            end

            // When controller signals done, clear in-progress
            if (cmd_in_progress_reg && cmd_done) begin
                cmd_in_progress_reg <= 0;
            end
            
            // If not processing a command and FIFO not empty, pop and issue
            // Only process commands when SDRAM is initialized
            if (!cmd_in_progress_reg && !fifo_empty_reg && sys_init_done) begin
                current_cmd_reg <= fifo[rd_ptr];
                $display("[POP] is_write=%b, cmd_addr=0x%h, cmd_data=0x%h, raw=0x%h", 
                         fifo[rd_ptr][32], fifo[rd_ptr][31:16], fifo[rd_ptr][15:0], fifo[rd_ptr]);
                cmd_in_progress_reg <= 1;
                rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
            end
        end
    end

endmodule
