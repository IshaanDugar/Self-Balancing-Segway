module steer_en #(parameter fast_sim = 1)
(input clk, rst_n, [11:0] lft_ld, rght_ld, output en_steer, rider_off);

    localparam MIN_RIDER_WT = 12'h200;
    localparam WT_HYSTERESIS = 12'h40;

    logic sum_lt_min;
    logic sum_gt_min;
    logic diff_gt_1_4;
    logic diff_gt_15_16;

    logic full;
    logic clr;


    // Intermediates
    logic [12:0] ld_sum;
    logic [11:0] ld_diff_noabs;
    logic [11:0] ld_diff;

    logic [12:0] sum_scale_1_4;
    logic [12:0] sum_scale_15_16;


    steer_en_SM DUT (
        .clk(clk),
        .rst_n(rst_n),
        .tmr_full(full),
        .clr_tmr(clr),
        .sum_lt_min(sum_lt_min),
        .sum_gt_min(sum_gt_min),
        .diff_gt_1_4(diff_gt_1_4),
        .diff_gt_15_16(diff_gt_15_16),
        .en_steer(en_steer), 
        .rider_off(rider_off)
    );

    // add fast_sim parameter to timer instantiation
    timer #( .fast_sim(fast_sim) ) DUT2 (
        .clk(clk),
        .rst_n(rst_n),
        .clr(clr),
        .full(full)
    );

    assign ld_sum = lft_ld + rght_ld;
    assign ld_diff_noabs = lft_ld - rght_ld;
    assign ld_diff = (ld_diff_noabs[11]) ? -ld_diff_noabs : ld_diff_noabs;

    assign sum_scale_1_4 = (ld_sum >> 2); // divide by 4
    assign sum_scale_15_16 = (ld_sum * 15) >> 4; // multiply by 15/16

    assign sum_lt_min = (ld_sum < (MIN_RIDER_WT - WT_HYSTERESIS));
    assign sum_gt_min = (ld_sum > (MIN_RIDER_WT + WT_HYSTERESIS));

    assign diff_gt_1_4 = (ld_diff > sum_scale_1_4);
    assign diff_gt_15_16 = (ld_diff > sum_scale_15_16);


endmodule