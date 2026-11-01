// ============================================================
//  Module  : kmeans_top  (FIXED v3)
//  Project : K-Means Hardware Accelerator
// ------------------------------------------------------------
//  FIX: Wires centroid read ports (c0..c3) also to accumulator
//       prev_c* inputs so empty clusters retain their values.
// ============================================================

`timescale 1ns / 1ps

module kmeans_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,

    input  wire        init_load,
    input  wire [1:0]  init_sel,
    input  wire [7:0]  init_r,
    input  wire [7:0]  init_g,
    input  wire [7:0]  init_b,

    output wire [1:0]  cluster_id,
    output wire        pixel_valid,
    output wire        done
);

    wire [9:0]  pixel_addr;
    wire        rd_en, accum_en, clear_en, update_en;
    wire        wr_en;
    wire [1:0]  wr_sel;
    wire        update_rdy;
    wire [2:0]  state_out;

    wire [7:0]  pixel_r, pixel_g, pixel_b;
    wire [7:0]  c0_r, c0_g, c0_b;
    wire [7:0]  c1_r, c1_g, c1_b;
    wire [7:0]  c2_r, c2_g, c2_b;
    wire [7:0]  c3_r, c3_g, c3_b;
    wire [17:0] dist0, dist1, dist2, dist3;
    wire [7:0]  new_c0_r, new_c0_g, new_c0_b;
    wire [7:0]  new_c1_r, new_c1_g, new_c1_b;
    wire [7:0]  new_c2_r, new_c2_g, new_c2_b;
    wire [7:0]  new_c3_r, new_c3_g, new_c3_b;

    reg [7:0] wr_r, wr_g, wr_b;
    always @(*) begin
        case (wr_sel)
            2'd0: begin wr_r=new_c0_r; wr_g=new_c0_g; wr_b=new_c0_b; end
            2'd1: begin wr_r=new_c1_r; wr_g=new_c1_g; wr_b=new_c1_b; end
            2'd2: begin wr_r=new_c2_r; wr_g=new_c2_g; wr_b=new_c2_b; end
            2'd3: begin wr_r=new_c3_r; wr_g=new_c3_g; wr_b=new_c3_b; end
        endcase
    end

    fsm_control u_fsm (
        .clk(clk),.rst(rst),.start(start),
        .update_rdy(update_rdy),
        .pixel_addr(pixel_addr),.rd_en(rd_en),
        .accum_en(accum_en),.clear_en(clear_en),
        .update_en(update_en),.wr_en(wr_en),
        .wr_sel(wr_sel),.done(done),.state_out(state_out)
    );

    pixel_mem u_pixel_mem (
        .clk(clk),.rd_en(rd_en),.addr(pixel_addr),
        .pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),
        .pixel_valid(pixel_valid)
    );

    centroid_regs u_cent_regs (
        .clk(clk),.rst(rst),
        .wr_en(wr_en),.wr_sel(wr_sel),
        .wr_r(wr_r),.wr_g(wr_g),.wr_b(wr_b),
        .init_load(init_load),.init_sel(init_sel),
        .init_r(init_r),.init_g(init_g),.init_b(init_b),
        .c0_r(c0_r),.c0_g(c0_g),.c0_b(c0_b),
        .c1_r(c1_r),.c1_g(c1_g),.c1_b(c1_b),
        .c2_r(c2_r),.c2_g(c2_g),.c2_b(c2_b),
        .c3_r(c3_r),.c3_g(c3_g),.c3_b(c3_b)
    );

    dist_unit u_dist0 (.pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),.cent_r(c0_r),.cent_g(c0_g),.cent_b(c0_b),.dist_sq(dist0));
    dist_unit u_dist1 (.pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),.cent_r(c1_r),.cent_g(c1_g),.cent_b(c1_b),.dist_sq(dist1));
    dist_unit u_dist2 (.pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),.cent_r(c2_r),.cent_g(c2_g),.cent_b(c2_b),.dist_sq(dist2));
    dist_unit u_dist3 (.pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),.cent_r(c3_r),.cent_g(c3_g),.cent_b(c3_b),.dist_sq(dist3));

    min_finder_k4 u_min_finder (
        .dist0(dist0),.dist1(dist1),.dist2(dist2),.dist3(dist3),
        .cluster_id(cluster_id)
    );

    // ── accumulator - prev centroid ports wired from centroid_regs ──
    accumulator u_accum (
        .clk(clk),.rst(rst),
        .accum_en(accum_en),.clear_en(clear_en),.update_en(update_en),
        .pixel_r(pixel_r),.pixel_g(pixel_g),.pixel_b(pixel_b),
        .cluster_id(cluster_id),
        .prev_c0_r(c0_r),.prev_c0_g(c0_g),.prev_c0_b(c0_b),
        .prev_c1_r(c1_r),.prev_c1_g(c1_g),.prev_c1_b(c1_b),
        .prev_c2_r(c2_r),.prev_c2_g(c2_g),.prev_c2_b(c2_b),
        .prev_c3_r(c3_r),.prev_c3_g(c3_g),.prev_c3_b(c3_b),
        .new_c0_r(new_c0_r),.new_c0_g(new_c0_g),.new_c0_b(new_c0_b),
        .new_c1_r(new_c1_r),.new_c1_g(new_c1_g),.new_c1_b(new_c1_b),
        .new_c2_r(new_c2_r),.new_c2_g(new_c2_g),.new_c2_b(new_c2_b),
        .new_c3_r(new_c3_r),.new_c3_g(new_c3_g),.new_c3_b(new_c3_b),
        .update_rdy(update_rdy)
    );

endmodule