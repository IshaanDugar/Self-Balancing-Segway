module timer #(parameter bit fast_sim = 1'b0)(
    input  logic clk,
    input  logic rst_n,
    input  logic clr,
    output logic full
);

    // 1.34 seconds at 50 MHz = 67,000,000 cycles
    localparam int unsigned TERM_NORMAL = 26'd67_000_000;
    // Fast-sim threshold, using only the low 15 bits
    localparam int unsigned TERM_FAST   = 15'h56C0;

    logic [25:0] cnt;

    // Counter: clears on reset or clr, stops incrementing once full is asserted
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= '0;
        else if (clr)
            cnt <= '0;
        else if (!full)
            cnt <= cnt + 1'b1;
    end

    // Timer full logic: use fast_sim to choose how we check cnt
    generate
        if (fast_sim) begin : GEN_FAST
            // Only look at bits [14:0] in fast-sim mode
            assign full = (cnt[14:0] >= TERM_FAST);
        end else begin : GEN_REAL
            // Full 26-bit compare for real-time 1.34s timer
            assign full = (cnt >= TERM_NORMAL);
        end
    endgenerate

endmodule
