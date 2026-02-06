module PWM11(
    input clk, 
    input rst_n, 
    input [10:0] duty, 
    output logic PWM1, PWM2,
    output logic PWM_synch, 
    output logic ovr_I_blank
);

    // Non-overlap time inserted between high-side and low-side PWMs
    localparam NONOVERLAP = 11'h040;
    // Internal blanking windows used to disable current sensing
    logic blank1, blank2;

    // Free-running 11-bit counter for PWM timing (0..2047)
    logic [10:0] cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 11'h000;
        else
            cnt <= cnt + 11'h001;
    end

    // Generate complementary PWM1 / PWM2 with deadtime (NONOVERLAP)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            PWM1 <= 1'b0;
            PWM2 <= 1'b0;
        end 
        else begin
            // PWM1 turns on after initial NONOVERLAP delay and off at duty
            if (cnt >= duty)
                PWM1 <= 1'b0;
            else if (cnt >= NONOVERLAP)
                PWM1 <= 1'b1;

            // PWM2 starts new cycle low and turns on after PWM1 plus NONOVERLAP
            if (cnt == 11'h7FF)
                PWM2 <= 1'b0; 
            else if (cnt >= (duty + NONOVERLAP))
                PWM2 <= 1'b1;
        end
    end

    // Combinational logic: sync pulse and over-current blanking windows
    always_comb begin
        // One-cycle sync at start of PWM period
        PWM_synch = (cnt == 11'h000);
        // Blanking window around PWM1 turn-on
        blank1 = (cnt >= NONOVERLAP) && (cnt < (NONOVERLAP + 128));
        // Blanking window around PWM2 turn-on
        blank2 = (cnt >= (duty + NONOVERLAP)) && (cnt < (duty + NONOVERLAP + 128));
    end

    // Overall over-current blanking output
    assign ovr_I_blank = blank1 || blank2;
endmodule