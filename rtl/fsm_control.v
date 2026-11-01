// ============================================================
//  Module  : fsm_control  (FIXED v3)
//  Project : K-Means Hardware Accelerator
// ------------------------------------------------------------
//  FIXES:
//    - Added CLEAR state between WRITE and COMPUTE
//      so accumulator banks are zeroed before each iteration
//    - This stops cluster oscillation between iterations
//    - 20 iterations retained
// ============================================================

`timescale 1ns / 1ps

module fsm_control (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        update_rdy,

    output reg  [9:0]  pixel_addr,
    output reg         rd_en,
    output reg         accum_en,
    output reg         clear_en,
    output reg         update_en,
    output reg         wr_en,
    output reg  [1:0]  wr_sel,
    output reg         done,
    output reg  [2:0]  state_out
);

    localparam IDLE    = 3'd0;
    localparam LOAD    = 3'd1;
    localparam COMPUTE = 3'd2;
    localparam UPDATE  = 3'd3;
    localparam WRITE   = 3'd4;
    localparam CLEAR   = 3'd5;  // NEW - clears accumulator between iters
    localparam DONE    = 3'd6;

    localparam MAX_PIXELS = 10'd1023;
    localparam MAX_ITER   = 5'd20;

    reg [2:0]  state;
    reg [4:0]  iter_count;
    reg [1:0]  wr_phase;
    reg        accum_delay;
    reg        update_fired;

    always @(posedge clk) begin
        if (rst) begin
            state        <= IDLE;
            pixel_addr   <= 0;
            iter_count   <= 0;
            wr_phase     <= 0;
            accum_delay  <= 0;
            update_fired <= 0;
        end else begin
            case (state)

                IDLE: begin
                    if (start) state <= LOAD;
                end

                // First LOAD: clear accumulator, start from pixel 0
                LOAD: begin
                    state        <= COMPUTE;
                    pixel_addr   <= 0;
                    accum_delay  <= 0;
                    update_fired <= 0;
                end

                COMPUTE: begin
                    if (pixel_addr < MAX_PIXELS) begin
                        pixel_addr  <= pixel_addr + 1;
                        accum_delay <= 1;
                    end else begin
                        pixel_addr   <= 0;
                        accum_delay  <= 0;
                        state        <= UPDATE;
                        update_fired <= 0;
                    end
                end

                UPDATE: begin
                    if (!update_fired) begin
                        update_fired <= 1;
                    end else if (update_rdy) begin
                        state    <= WRITE;
                        wr_phase <= 0;
                    end
                end

                WRITE: begin
                    if (wr_phase < 2'd3) begin
                        wr_phase <= wr_phase + 1;
                    end else begin
                        iter_count <= iter_count + 1;
                        if (iter_count >= MAX_ITER - 1) begin
                            state <= DONE;
                        end else begin
                            // Go to CLEAR before next COMPUTE
                            state <= CLEAR;
                        end
                    end
                end

                // CLEAR: one cycle to zero accumulator banks
                CLEAR: begin
                    state       <= COMPUTE;
                    pixel_addr  <= 0;
                    accum_delay <= 0;
                    update_fired<= 0;
                end

                DONE: state <= DONE;

            endcase
        end
    end

    // ── Output decode ──
    always @(*) begin
        rd_en     = 0;
        accum_en  = 0;
        clear_en  = 0;
        update_en = 0;
        wr_en     = 0;
        wr_sel    = 0;
        done      = 0;
        state_out = state;

        case (state)
            IDLE:    begin end

            LOAD:    begin
                clear_en = 1;   // clear before first iteration
            end

            COMPUTE: begin
                rd_en    = 1;
                accum_en = accum_delay;
            end

            UPDATE:  begin
                update_en = ~update_fired;
            end

            WRITE: begin
                wr_en  = 1;
                wr_sel = wr_phase;
            end

            CLEAR: begin
                clear_en = 1;   // clear before each subsequent iteration
            end

            DONE: begin
                done = 1;
            end
        endcase
    end

endmodule