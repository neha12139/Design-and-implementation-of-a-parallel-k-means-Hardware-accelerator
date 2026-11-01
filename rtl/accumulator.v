// ============================================================
//  Module  : accumulator  (FIXED v3)
//  Project : K-Means Hardware Accelerator
// ------------------------------------------------------------
//  FIXES:
//    - Latches prev centroid values when update_en fires
//      (before any writes happen) so empty cluster fallback
//      uses the correct pre-update values
//    - clear_en now also clears update_rdy
// ============================================================

`timescale 1ns / 1ps

module accumulator (
    input  wire        clk,
    input  wire        rst,
    input  wire        accum_en,
    input  wire        clear_en,
    input  wire        update_en,

    input  wire [7:0]  pixel_r,
    input  wire [7:0]  pixel_g,
    input  wire [7:0]  pixel_b,
    input  wire [1:0]  cluster_id,

    // Previous centroid values from centroid_regs
    input  wire [7:0]  prev_c0_r, prev_c0_g, prev_c0_b,
    input  wire [7:0]  prev_c1_r, prev_c1_g, prev_c1_b,
    input  wire [7:0]  prev_c2_r, prev_c2_g, prev_c2_b,
    input  wire [7:0]  prev_c3_r, prev_c3_g, prev_c3_b,

    output reg  [7:0]  new_c0_r, new_c0_g, new_c0_b,
    output reg  [7:0]  new_c1_r, new_c1_g, new_c1_b,
    output reg  [7:0]  new_c2_r, new_c2_g, new_c2_b,
    output reg  [7:0]  new_c3_r, new_c3_g, new_c3_b,

    output reg         update_rdy
);

    reg [17:0] sum_r [0:3];
    reg [17:0] sum_g [0:3];
    reg [17:0] sum_b [0:3];
    reg [10:0] count  [0:3];

    // Latched prev values - captured when update_en fires
    reg [7:0] latch_r [0:3];
    reg [7:0] latch_g [0:3];
    reg [7:0] latch_b [0:3];

    always @(posedge clk) begin
        if (rst || clear_en) begin
            sum_r[0]<=0; sum_g[0]<=0; sum_b[0]<=0; count[0]<=0;
            sum_r[1]<=0; sum_g[1]<=0; sum_b[1]<=0; count[1]<=0;
            sum_r[2]<=0; sum_g[2]<=0; sum_b[2]<=0; count[2]<=0;
            sum_r[3]<=0; sum_g[3]<=0; sum_b[3]<=0; count[3]<=0;
            update_rdy <= 0;
        end
        else if (accum_en) begin
            sum_r[cluster_id] <= sum_r[cluster_id] + {10'b0, pixel_r};
            sum_g[cluster_id] <= sum_g[cluster_id] + {10'b0, pixel_g};
            sum_b[cluster_id] <= sum_b[cluster_id] + {10'b0, pixel_b};
            count[cluster_id] <= count[cluster_id] + 1;
            update_rdy <= 0;
        end
        else if (update_en) begin
            // Latch current centroid values BEFORE any writes
            // so empty cluster fallback is correct
            latch_r[0] <= prev_c0_r; latch_g[0] <= prev_c0_g; latch_b[0] <= prev_c0_b;
            latch_r[1] <= prev_c1_r; latch_g[1] <= prev_c1_g; latch_b[1] <= prev_c1_b;
            latch_r[2] <= prev_c2_r; latch_g[2] <= prev_c2_g; latch_b[2] <= prev_c2_b;
            latch_r[3] <= prev_c3_r; latch_g[3] <= prev_c3_g; latch_b[3] <= prev_c3_b;

            // Compute new centroids
            // C0
            if (count[0] > 0) begin
                new_c0_r <= sum_r[0] / count[0];
                new_c0_g <= sum_g[0] / count[0];
                new_c0_b <= sum_b[0] / count[0];
            end else begin
                new_c0_r <= latch_r[0];
                new_c0_g <= latch_g[0];
                new_c0_b <= latch_b[0];
            end

            // C1
            if (count[1] > 0) begin
                new_c1_r <= sum_r[1] / count[1];
                new_c1_g <= sum_g[1] / count[1];
                new_c1_b <= sum_b[1] / count[1];
            end else begin
                new_c1_r <= latch_r[1];
                new_c1_g <= latch_g[1];
                new_c1_b <= latch_b[1];
            end

            // C2
            if (count[2] > 0) begin
                new_c2_r <= sum_r[2] / count[2];
                new_c2_g <= sum_g[2] / count[2];
                new_c2_b <= sum_b[2] / count[2];
            end else begin
                new_c2_r <= latch_r[2];
                new_c2_g <= latch_g[2];
                new_c2_b <= latch_b[2];
            end

            // C3
            if (count[3] > 0) begin
                new_c3_r <= sum_r[3] / count[3];
                new_c3_g <= sum_g[3] / count[3];
                new_c3_b <= sum_b[3] / count[3];
            end else begin
                new_c3_r <= latch_r[3];
                new_c3_g <= latch_g[3];
                new_c3_b <= latch_b[3];
            end

            update_rdy <= 1;
        end
        else begin
            update_rdy <= 0;
        end
    end

endmodule