// ============================================================
//  Module  : dist_unit
//  Project : K-Means Hardware Accelerator
//  Step    : 1 of 7
// ------------------------------------------------------------
//  Purpose : Computes the squared Euclidean distance between
//            one input pixel (R,G,B) and one centroid (Cr,Cg,Cb).
//
//  Python equivalent (your reference model):
//      d = (pixel[0]-c[0])**2 + (pixel[1]-c[1])**2 + (pixel[2]-c[2])**2
//
//  Why squared (no sqrt)?
//      Comparison only needs relative magnitude.
//      Dropping sqrt saves a large combinational block with
//      zero effect on which centroid wins.
//
//  Bit-width analysis:
//      Each channel : 8-bit unsigned  → difference : 9-bit signed
//      Each square  : 9b × 9b         → 18-bit product (always ≥ 0)
//      Sum of three : 18b + 18b + 18b → 20-bit result max
//        worst case : 3 × (255)²  = 3 × 65025 = 195075 < 2^18 = 262144
//      → dist output is 18 bits wide  (fits comfortably)
//
//  This module is PURELY COMBINATIONAL.
//  No clock, no reset, no state - output updates same cycle as input.
//  The min_finder (Step 2) latches these outputs on a clock edge.
//
//  Ports:
//      pixel_r, pixel_g, pixel_b  [7:0]  - current pixel channels
//      cent_r,  cent_g,  cent_b   [7:0]  - one centroid's channels
//      dist_sq                   [17:0]  - output: squared distance
// ============================================================

`timescale 1ns / 1ps

module dist_unit (
    // ── Pixel input (from pixel_mem, broadcast to all K units) ──
    input  wire [7:0] pixel_r,
    input  wire [7:0] pixel_g,
    input  wire [7:0] pixel_b,

    // ── Centroid input (from centroid_regs, one entry per unit) ──
    input  wire [7:0] cent_r,
    input  wire [7:0] cent_g,
    input  wire [7:0] cent_b,

    // ── Distance output ──
    output wire [17:0] dist_sq
);

    // ----------------------------------------------------------
    //  Stage 1 : Signed subtraction per channel
    //
    //  Expand both operands to 9-bit signed before subtracting
    //  so the difference is never truncated.
    //  {1'b0, pixel_r} pads a zero MSB → treats 8-bit as positive.
    //
    //  Python: diff_r = pixel[0] - c[0]
    // ----------------------------------------------------------
    wire signed [8:0] diff_r = $signed({1'b0, pixel_r}) - $signed({1'b0, cent_r});
    wire signed [8:0] diff_g = $signed({1'b0, pixel_g}) - $signed({1'b0, cent_g});
    wire signed [8:0] diff_b = $signed({1'b0, pixel_b}) - $signed({1'b0, cent_b});

    // ----------------------------------------------------------
    //  Stage 2 : Square each difference
    //
    //  9-bit signed × 9-bit signed → 18-bit product.
    //  Result is always non-negative (x² ≥ 0), so the top bit
    //  is never a sign bit in practice - safe to treat as [17:0].
    //
    //  Python: diff_r ** 2
    // ----------------------------------------------------------
    wire [17:0] sq_r = diff_r * diff_r;
    wire [17:0] sq_g = diff_g * diff_g;
    wire [17:0] sq_b = diff_b * diff_b;

    // ----------------------------------------------------------
    //  Stage 3 : Sum the three squares
    //
    //  Max value = 3 × 65025 = 195075 → fits in 18 bits (max 262143).
    //  A simple adder tree is enough - no overflow possible.
    //
    //  Python: d = diff_r**2 + diff_g**2 + diff_b**2
    // ----------------------------------------------------------
    assign dist_sq = sq_r + sq_g + sq_b;

endmodule