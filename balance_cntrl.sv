module balance_cntrl
    #(parameter fast_sim = 1)
    (
    input clk,
    input rst_n,
    input vld,
    input pwr_up,
    input rider_off,
    input signed [15:0] ptch,
    input signed [15:0] ptch_rt,
    input [11:0] steer_pot,
    input en_steer,
    output logic signed [11:0] lft_spd,
    output logic signed [11:0] rght_spd,
    output logic too_fast
);
    // Instantiate PID and SegwayMath modules with fast_sim parameter and connections bewteen them
    logic signed [11:0] PID_cntrl;
    logic [7:0] ss_tmr;

    // Pipeline registers between PID and SegwayMath
    logic signed [11:0] PID_cntrl_pip;
    logic [7:0] ss_tmr_reg;
    logic en_steer_pip;
    logic [11:0] steer_pot_pip;
    
    // Pipeline all inputs to PID together to maintain alignment
    logic signed [15:0] ptch_d, ptch_rt_d;
    logic vld_d;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PID_cntrl_pip <= '0;
            ss_tmr_reg    <= '0;
            en_steer_pip  <= 1'b0;
            steer_pot_pip <= '0;
        end else begin
            PID_cntrl_pip <= PID_cntrl;
            ss_tmr_reg    <= ss_tmr;
            en_steer_pip  <= en_steer;
            steer_pot_pip <= steer_pot;
        end
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptch_d <= '0;
            ptch_rt_d <= '0;
            vld_d <= 1'b0;
        end else begin
            ptch_d <= ptch;
            ptch_rt_d <= ptch_rt;
            vld_d <= vld;
        end
    end

    PID #(fast_sim) u_PID (
        .clk(clk),
        .rst_n(rst_n),
        .vld(vld_d),
        .pwr_up(pwr_up),
        .rider_off(rider_off),
        .ptch(ptch_d),
        .ptch_rt(ptch_rt_d),
        .PID_cntrl(PID_cntrl),
        .ss_tmr(ss_tmr)
    );

    SegwayMath u_SegwayMath (
        .clk(clk),
	.rst_n(rst_n),
        .PID_cntrl(PID_cntrl_pip),
        .ss_tmr(ss_tmr_reg),
        .steer_pot(steer_pot_pip),
        .en_steer(en_steer_pip),
        .pwr_up(pwr_up),
        .lft_spd(lft_spd),
        .rght_spd(rght_spd),
        .too_fast(too_fast)
    );

endmodule
