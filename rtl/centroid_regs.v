// ============================================================
//  Module  : centroid_regs  (FIXED v2)
//  Project : K-Means Hardware Accelerator
// ------------------------------------------------------------
//  FIX: rst no longer resets centroid values.
//       Centroids are only written via wr_en (from accumulator)
//       or via init_load (from testbench at startup).
//       This ensures centroids.mem values are preserved
//       through the FSM LOAD state.
// ============================================================

`timescale 1ns / 1ps

module centroid_regs (
    input  wire        clk,
    input  wire        rst,        // system reset - does NOT clear centroids

    // ── Write interface (from accumulator after UPDATE) ──
    input  wire        wr_en,
    input  wire [1:0]  wr_sel,
    input  wire [7:0]  wr_r,
    input  wire [7:0]  wr_g,
    input  wire [7:0]  wr_b,

    // ── Init load (from testbench - loads centroids.mem values) ──
    input  wire        init_load,  // pulse high for 4 cycles at startup
    input  wire [1:0]  init_sel,   // which centroid to init (0,1,2,3)
    input  wire [7:0]  init_r,
    input  wire [7:0]  init_g,
    input  wire [7:0]  init_b,

    // ── Read ports ──
    output wire [7:0]  c0_r, c0_g, c0_b,
    output wire [7:0]  c1_r, c1_g, c1_b,
    output wire [7:0]  c2_r, c2_g, c2_b,
    output wire [7:0]  c3_r, c3_g, c3_b
);

    reg [7:0] cent_r [0:3];
    reg [7:0] cent_g [0:3];
    reg [7:0] cent_b [0:3];

    always @(posedge clk) begin
        if (init_load) begin
            // Load initial centroids from testbench
            cent_r[init_sel] <= init_r;
            cent_g[init_sel] <= init_g;
            cent_b[init_sel] <= init_b;
        end
        else if (wr_en) begin
            // Write updated centroids from accumulator
            cent_r[wr_sel] <= wr_r;
            cent_g[wr_sel] <= wr_g;
            cent_b[wr_sel] <= wr_b;
        end
        // rst intentionally does NOT reset centroid values
        // so centroids.mem data is preserved through FSM LOAD state
    end

    assign c0_r = cent_r[0]; assign c0_g = cent_g[0]; assign c0_b = cent_b[0];
    assign c1_r = cent_r[1]; assign c1_g = cent_g[1]; assign c1_b = cent_b[1];
    assign c2_r = cent_r[2]; assign c2_g = cent_g[2]; assign c2_b = cent_b[2];
    assign c3_r = cent_r[3]; assign c3_g = cent_g[3]; assign c3_b = cent_b[3];

endmodule