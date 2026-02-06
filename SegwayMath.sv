// SegwayMath: Combines PID output with steering, applies a soft-start ramp,
// introduces a low-torque gain zone (deadband assist), minimum duty kick,
// and final saturation plus overspeed detect.
module SegwayMath (
    input clk,
    input rst_n,
    input signed [11:0] PID_cntrl,
    input [7:0] ss_tmr,
    input [11:0] steer_pot,
    input en_steer,
    input pwr_up,
    output signed [11:0] lft_spd,
    output signed [11:0] rght_spd,
    output too_fast
);

    // MIN_DUTY: bias to overcome static friction once outside low torque band
    localparam signed [12:0] MIN_DUTY = 13'h0A8;      // 0x0A8 = 168
    // LOW_TORQUE_BAND: region where we amplify torque instead of adding MIN_DUTY
    localparam unsigned [6:0] LOW_TORQUE_BAND = 7'h2A; // 0x2A = 42
    // GAIN_MULT: linear gain applied in low torque band for finer control
    localparam unsigned [3:0] GAIN_MULT = 4'h4;        // x4 gain
    
    logic signed [11:0] PID_ss_wire;
    logic signed [20:0] PID_ss_temp;
    logic signed [11:0] PID_ss;

    // Soft-start scaling: multiply PID by ramp (0..255) then >>8 to normalize
    assign PID_ss_temp = PID_cntrl * $signed({1'b0, ss_tmr});
    assign PID_ss_wire = PID_ss_temp >>> 8;

    logic unsigned [11:0] limit_steer;
    // Constrain raw steering pot into allowed window before centering
    assign limit_steer = steer_pot > 12'hE00 ? 12'hE00 :
                         steer_pot < 12'h200 ? 12'h200 :
                         steer_pot;

    logic signed [11:0] steer_adj;
    // Center around mid-scale (design choice: 0x7FF center)
    assign steer_adj = $signed(limit_steer) - $signed(12'h7ff);

    logic signed [11:0] steer_ss_wire;
    logic signed [11:0] steer_ss;
    // Scale steering (3/16) without a multiplier: (1/8 + 1/16)
    assign steer_ss_wire = (steer_adj >>> 3) + (steer_adj >>> 4);

    // Pipeline registers
    logic en_steer_reg;
    logic pwr_up_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PID_ss <= '0;
            steer_ss <= '0;
            en_steer_reg <= 1'b0;
            pwr_up_reg <= 1'b0;
        end else begin
            PID_ss <= PID_ss_wire;
            steer_ss <= steer_ss_wire;
            en_steer_reg <= en_steer;
            pwr_up_reg <= pwr_up;
        end
    end

    logic signed [12:0] lft_torque;
    logic signed [12:0] rght_torque;

    // Combine drive (PID) with steering; extend sign to 13 bits
    assign lft_torque  = en_steer_reg ? {PID_ss[11], PID_ss} + {steer_ss[11], steer_ss} : {PID_ss[11], PID_ss};
    assign rght_torque = en_steer_reg ? {PID_ss[11], PID_ss} - {steer_ss[11], steer_ss} : {PID_ss[11], PID_ss};

    logic signed [12:0] lft_torque_comp;
    logic signed [12:0] rght_torque_comp;
    // Add (or subtract) MIN_DUTY outside low torque band to ensure movement
    assign lft_torque_comp = lft_torque[12] ? lft_torque - MIN_DUTY :
                                               lft_torque + MIN_DUTY;
                                
    // Deadzone shaping: inside band -> amplified small signal; outside -> add MIN_DUTY
    logic signed [12:0] lft_shaped;
    assign lft_shaped = pwr_up_reg ? ((lft_torque > $signed(LOW_TORQUE_BAND)) || (lft_torque < -$signed(LOW_TORQUE_BAND)) ? lft_torque_comp :
                                ($signed(GAIN_MULT) * lft_torque)) :
                                13'h0000;

    // Saturate to signed 12-bit range
    assign lft_spd =  (!lft_shaped[12] && |lft_shaped[12:11] ) ? 12'h7FF :
                      (lft_shaped[12] && !(&lft_shaped[12:11])) ? 12'h800 :
                      lft_shaped[11:0];

    assign rght_torque_comp = rght_torque[12] ? rght_torque - MIN_DUTY :
                                                rght_torque + MIN_DUTY;
                                
    logic signed [12:0] rght_shaped;
    assign rght_shaped = pwr_up_reg ? ((rght_torque > $signed(LOW_TORQUE_BAND)) || (rght_torque < -$signed(LOW_TORQUE_BAND)) ? rght_torque_comp :
                                ($signed(GAIN_MULT) * rght_torque)) :
                                13'h0000;

    // Saturate right motor similarly
    assign rght_spd =  (!rght_shaped[12] && |rght_shaped[12:11]) ? 12'h7FF :
                      (rght_shaped[12] && !(&rght_shaped[12:11])) ? 12'h800 :
                      rght_shaped[11:0];

    // Overspeed flag (positive only per current spec usage) 1536 = 0x600
    assign too_fast = (lft_spd > 12'sd1536) ||
                      (rght_spd > 12'sd1536);
endmodule
