module piezo_drv #(parameter fast_sim = 0)(
    input wire clk,
    input wire rst_n,
    input wire en_steer,
    input wire too_fast,
    input wire batt_low,
    output logic piezo,
    output logic piezo_n
);


logic [25:0] duration_timer;
logic synch_reset_duration;
logic unsigned two_22_CLKS, two_23_CLKS, two_25_CLKS;
logic unsigned freq_1565HZ, freq_2093HZ, freq_2637HZ, freq_3136HZ;
logic repeat_timer_reset;
logic timer_synch_reset;
logic synch_reset_freq;
logic two_23_PLUS_22_CLKS;



// Duration timer logic
generate if (fast_sim) begin
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        duration_timer <= 0;
    end else if (synch_reset_duration) begin
        duration_timer <= 0;
    end else begin
        duration_timer <= duration_timer + 64;
    end
end
end else begin
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        duration_timer <= 0;
    end else if (synch_reset_duration) begin
        duration_timer <= 0;
    end else begin
        duration_timer <= duration_timer + 1;
    end
end
end
endgenerate


assign two_22_CLKS = (duration_timer >= 25'd4194304);   // 2^22
assign two_23_CLKS = (duration_timer >= 25'd8388608);   // 2^23
assign two_25_CLKS = (duration_timer >= 25'd33554431);  // 2^25
assign two_23_PLUS_22_CLKS = (duration_timer >= 25'd12582912); // 2^23 + 2^22



logic [14:0] frequency_timer;
// Frequency timer logic
generate if (fast_sim) begin
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frequency_timer <= 0;
    end else if (synch_reset_freq) begin
        frequency_timer <= 0;
    end else begin
        frequency_timer <= frequency_timer + 64;
    end
end
end else begin
    always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frequency_timer <= 0;
    end else if (synch_reset_freq) begin
        frequency_timer <= 0;
    end else begin
        frequency_timer <= frequency_timer + 1;
    end
end
end
endgenerate


assign freq_1565HZ = (frequency_timer >= 15'd31888);
assign freq_2093HZ = (frequency_timer >= 15'd23890);
assign freq_2637HZ = (frequency_timer >= 15'd18961);
assign freq_3136HZ = (frequency_timer >= 15'd15944);

logic [27:0] repeat_timer;
// Repeat timer logic
generate if (fast_sim) begin
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        repeat_timer <= 0;
    end else if (timer_synch_reset) begin
        repeat_timer <= 0;
    end else begin
        repeat_timer <= repeat_timer + 64;
    end
end
end else begin
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        repeat_timer <= 0;
    end else if (timer_synch_reset) begin
        repeat_timer <= 0;
    end else begin
        repeat_timer <= repeat_timer + 1;
    end
end
end
endgenerate

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    piezo <= 1'b0;
  end else if (synch_reset_freq) begin
    piezo   <= ~piezo;
  end
end

assign piezo_n = ~piezo;



assign repeat_timer_reset = (repeat_timer >= 28'd150000000);
typedef enum logic [1:0] { MODE_NONE, MODE_EN, MODE_FAST, MODE_BATT } mode_t;
mode_t mode, mode_n;

// latch mode
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) mode <= MODE_NONE;
  else        mode <= mode_n;
end


// Create 7 state enum tyoe
typedef enum logic [2:0] {
    IDLE,
    G6,
    C7,
    E7,
    G7,
    E7_2,
    G7_2
} piezo_state_t;

piezo_state_t state, nxt_state;

// State register
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= nxt_state;
    end
end

// Next state logic
always_comb begin
    // Default assignments
    nxt_state = state;
    mode_n = mode;
    synch_reset_duration = 1'b0;
    synch_reset_freq = 1'b0;
    timer_synch_reset = 1'b0;   

    case (state)
        IDLE: begin
            if (too_fast) begin
                mode_n = MODE_FAST;
                nxt_state = G6;
            end
            else if (repeat_timer_reset) begin
                timer_synch_reset = 1'b1;
                if (batt_low) begin
                    mode_n = MODE_BATT;
                    nxt_state = G7_2;
                end
                else if (en_steer) begin
                    mode_n = MODE_EN;
                    nxt_state = G6;
                end
            end
            else begin
                mode_n = MODE_NONE;
                nxt_state = IDLE;
            end
        end
        G6: begin
            if (freq_1565HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_23_CLKS) begin
                    synch_reset_duration = 1'b1;
                    synch_reset_freq = 1'b1;
                    if (mode == MODE_FAST || mode == MODE_EN)
                        nxt_state = C7;
                    else
                        nxt_state = IDLE;
            end
        end
        C7: begin
            if (freq_2093HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_23_CLKS) begin
                synch_reset_duration = 1'b1;
                synch_reset_freq = 1'b1;
                if (mode == MODE_BATT)
                    nxt_state = G6;
                else
                    nxt_state = E7;
            end
        end
        E7: begin
            if (freq_2637HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_23_CLKS) begin
                synch_reset_duration = 1'b1;
                synch_reset_freq = 1'b1;
                if (mode == MODE_FAST)
                    nxt_state = IDLE;
                else if (mode == MODE_BATT)
                    nxt_state = C7;
                else if (mode == MODE_EN)
                    nxt_state = G7;
            end
        end
        G7: begin
            if (freq_3136HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_23_PLUS_22_CLKS) begin
                synch_reset_duration = 1'b1;
                synch_reset_freq = 1'b1;
                if (mode == MODE_BATT)
                    nxt_state = E7;
                else if (mode == MODE_EN)
                    nxt_state = E7_2;
            end
        end
        E7_2: begin
            if (freq_2637HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_22_CLKS) begin
                synch_reset_duration = 1'b1;
                synch_reset_freq = 1'b1;
                if (mode == MODE_BATT)
                    nxt_state = G7;
                else if (mode == MODE_EN)
                    nxt_state = G7_2;
            end
        end
        G7_2: begin
            if (freq_3136HZ) begin
                synch_reset_freq = 1'b1;
            end
            if (two_25_CLKS) begin
                synch_reset_duration = 1'b1;
                synch_reset_freq = 1'b1;
                if (mode == MODE_BATT)
                    nxt_state = G7;
                else if (mode == MODE_EN)
                    nxt_state = IDLE;
            end
        end
    endcase
end



endmodule