// ============================================================
//  Testbench : tb_kmeans_top  (FIXED v3)
//  Tests     : kmeans_top.v - Full K-Means Hardware Accelerator
//  Step      : 7 of 7  (FINAL - ACCURATE VALIDATION)
// ------------------------------------------------------------
//  FIX: Centroids are loaded via init_load/init_sel ports
//       AFTER reset completes, so FSM LOAD state cannot
//       overwrite them. Hardware and Python now start from
//       identical initial centroids → comparable results.
// ============================================================

`timescale 1ns / 1ps

module tb_kmeans_top;

    reg clk   = 0;
    reg rst   = 1;
    reg start = 0;

    // ── Centroid init ports ──
    reg        init_load = 0;
    reg [1:0]  init_sel  = 0;
    reg [7:0]  init_r    = 0;
    reg [7:0]  init_g    = 0;
    reg [7:0]  init_b    = 0;

    wire [1:0] cluster_id;
    wire       pixel_valid;
    wire       done;

    always #5 clk = ~clk;

    kmeans_top uut (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .init_load  (init_load),
        .init_sel   (init_sel),
        .init_r     (init_r),
        .init_g     (init_g),
        .init_b     (init_b),
        .cluster_id (cluster_id),
        .pixel_valid(pixel_valid),
        .done       (done)
    );

    integer pixel_count  = 0;
    integer iter_num     = 0;
    integer clust_cnt_0  = 0;
    integer clust_cnt_1  = 0;
    integer clust_cnt_2  = 0;
    integer clust_cnt_3  = 0;
    integer total_pixels = 0;
    integer sim_done     = 0;
    integer k;

    // ── Main sequence ──
    initial begin
        $display("============================================");
        $display(" K-Means Accelerator - Fixed v3            ");
        $display("============================================");

        // Step 1 - Reset
        rst = 1; start = 0;
        repeat(10) @(posedge clk);
        #2; rst = 0;
        repeat(4) @(posedge clk);

        // Step 2 - Load centroids via init_load port
        // Reads centroids.mem and writes one centroid per cycle
        begin : load_cents
            reg [23:0] cent_data [0:3];
            $readmemh("centroids.mem", cent_data);

            $display("Loading centroids from centroids.mem:");
            for (k = 0; k < 4; k = k + 1) begin
                @(negedge clk);
                init_load = 1;
                init_sel  = k[1:0];
                init_r    = cent_data[k][23:16];
                init_g    = cent_data[k][15:8];
                init_b    = cent_data[k][7:0];
                @(posedge clk); #1;
                $display("  C%0d: R=%0d G=%0d B=%0d",
                    k, cent_data[k][23:16],
                    cent_data[k][15:8],
                    cent_data[k][7:0]);
            end
            @(negedge clk);
            init_load = 0;
        end

        repeat(2) @(posedge clk);

        // Step 3 - Start accelerator
        $display("--------------------------------------------");
        $display("Asserting start...");
        repeat(4) begin
            @(negedge clk); start = 1;
        end
        @(negedge clk); start = 0;
        $display("Running...");
        $display("--------------------------------------------");

        // Step 4 - Wait for done
        wait(done === 1'b1 || sim_done === 1);

        if (done === 1'b1) begin
            repeat(3) @(posedge clk);
            $display("============================================");
            $display(" DONE - all iterations complete            ");
            $display("============================================");
            $display("Total pixels processed: %0d", total_pixels);
            $display("");
            $display("Final centroids (hardware):");
            $display("  C0: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[0],
                uut.u_cent_regs.cent_g[0],
                uut.u_cent_regs.cent_b[0]);
            $display("  C1: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[1],
                uut.u_cent_regs.cent_g[1],
                uut.u_cent_regs.cent_b[1]);
            $display("  C2: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[2],
                uut.u_cent_regs.cent_g[2],
                uut.u_cent_regs.cent_b[2]);
            $display("  C3: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[3],
                uut.u_cent_regs.cent_g[3],
                uut.u_cent_regs.cent_b[3]);
            $display("============================================");
            $display(" Copy above values into validate_kmeans.py ");
            $display("============================================");
        end
        $finish;
    end

    // ── Pixel monitor ──
    always @(posedge clk) begin
        if (pixel_valid && !done) begin
            if (pixel_count < 5)
                $display("  iter=%0d pixel=%0d cluster=%0d",
                         iter_num, pixel_count, cluster_id);
            if (pixel_count == 5)
                $display("  iter=%0d ... (remaining omitted)", iter_num);

            case (cluster_id)
                2'd0: clust_cnt_0 = clust_cnt_0 + 1;
                2'd1: clust_cnt_1 = clust_cnt_1 + 1;
                2'd2: clust_cnt_2 = clust_cnt_2 + 1;
                2'd3: clust_cnt_3 = clust_cnt_3 + 1;
            endcase

            pixel_count  = pixel_count  + 1;
            total_pixels = total_pixels + 1;

            if (pixel_count == 1024) begin
                $display("--------------------------------------------");
                $display("Iter %0d done | C0:%0d C1:%0d C2:%0d C3:%0d px",
                    iter_num,
                    clust_cnt_0, clust_cnt_1,
                    clust_cnt_2, clust_cnt_3);
                $display("--------------------------------------------");
                pixel_count = 0;
                iter_num    = iter_num + 1;
                clust_cnt_0 = 0; clust_cnt_1 = 0;
                clust_cnt_2 = 0; clust_cnt_3 = 0;
            end
        end
    end

    // ── Timeout watchdog ──
    initial begin
        #300_000_000;
        $display("TIMEOUT - FSM state: %0d", uut.u_fsm.state);
        sim_done = 1;
    end

endmodule