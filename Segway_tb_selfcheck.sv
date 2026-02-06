`timescale 1ns/1ps

module Segway_tb_selfcheck;

// Interconnects
logic SS_n, SCLK, MOSI, MISO, INT;
logic A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;
logic RX_TX;
logic PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
logic piezo, piezo_n;
logic cmd_sent, rst_n;

// Stimulus
// Stimulus signals mirror prior exercises: UART cmd, rider lean, load cells, steering pot, battery
logic clk, RST_n;
logic [7:0] cmd;
logic send_cmd;
logic signed [15:0] rider_lean;
logic [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt;
logic OVR_I_lft, OVR_I_rght;

int pass_cnt, fail_cnt;
int test_num; // current test index for waveform viewing
int signed max_forward_tilt, min_backward_tilt;
int signed theta_now, omega_delta;

task automatic WaitCycles(input int cycles);
    repeat(cycles) @(posedge clk);
endtask

task automatic CapturePeak(input int cycles, output int signed max_theta, output int signed min_theta);
    max_theta = -32'sh7FFF_FFFF; // track largest forward tilt
    min_theta =  32'sh7FFF_FFFF; // track largest backward tilt
    repeat(cycles) begin
        @(posedge clk);
        if (int'(iPHYS.theta_platform) > max_theta) max_theta = int'(iPHYS.theta_platform);
        if (int'(iPHYS.theta_platform) < min_theta) min_theta = int'(iPHYS.theta_platform);
    end
endtask

task automatic SendCmd(input logic [7:0] value);
    @(posedge clk) begin
        cmd = value;
        send_cmd = 1'b1;
    end
    @(posedge clk) send_cmd = 1'b0;
    @(posedge cmd_sent);
endtask

// Instantiations
SegwayModel iPHYS(
    .clk(clk),
    .RST_n(RST_n),
    .SS_n(SS_n),
    .SCLK(SCLK),
    .MISO(MISO),
    .MOSI(MOSI),
    .INT(INT),
    .PWM1_lft(PWM1_lft),
    .PWM2_lft(PWM2_lft),
    .PWM1_rght(PWM1_rght),
    .PWM2_rght(PWM2_rght),
    .rider_lean(rider_lean)
);

ADC128S_FC iA2D(
    .clk(clk),
    .rst_n(RST_n),
    .SS_n(A2D_SS_n),
    .SCLK(A2D_SCLK),
    .MISO(A2D_MISO),
    .MOSI(A2D_MOSI),
    .ld_cell_lft(ld_cell_lft),
    .ld_cell_rght(ld_cell_rght),
    .steerPot(steerPot),
    .batt(batt)
);

Segway iDUT(
    .clk(clk),
    .RST_n(RST_n),
    .INERT_SS_n(SS_n),
    .INERT_MOSI(MOSI),
    .INERT_SCLK(SCLK),
    .INERT_MISO(MISO),
    .INERT_INT(INT),
    .A2D_SS_n(A2D_SS_n),
    .A2D_MOSI(A2D_MOSI),
    .A2D_SCLK(A2D_SCLK),
    .A2D_MISO(A2D_MISO),
    .PWM1_lft(PWM1_lft),
    .PWM2_lft(PWM2_lft),
    .PWM1_rght(PWM1_rght),
    .PWM2_rght(PWM2_rght),
    .OVR_I_lft(OVR_I_lft),
    .OVR_I_rght(OVR_I_rght),
    .piezo_n(piezo_n),
    .piezo(piezo),
    .RX(RX_TX)
);

UART_tx iTX(
    .clk(clk),
    .rst_n(rst_n),
    .TX(RX_TX),
    .trmt(send_cmd),
    .tx_data(cmd),
    .tx_done(cmd_sent)
);

rst_synch iRST(
    .clk(clk),
    .RST_n(RST_n),
    .rst_n(rst_n)
);

// Clock
always #10 clk = ~clk;

// Simple check helper (optional labeled value on failure)
task Check(string name, bit pass, string label="", int signed val=0);
    if (pass) begin
        pass_cnt++;
        $display("[%0t] PASS: %s", $time, name);
    end else begin
        fail_cnt++;
        if (label == "")
            $error("[%0t] FAIL: %s", $time, name);
        else
            $error("[%0t] FAIL: %s %s=%0d", $time, name, label, val);
    end
endtask

// Main test
initial begin
    clk = 1'b0;
    RST_n = 1'b0;
    send_cmd = 1'b0;
    cmd = 8'h00;
    rider_lean = 16'sd0;
    steerPot = 12'h800;
    batt = 12'hFFF;
    ld_cell_lft = 12'h200;
    ld_cell_rght = 12'h200;
    OVR_I_lft = 1'b0;
    OVR_I_rght = 1'b0;
    pass_cnt = 0;
    fail_cnt = 0;
    test_num = 0;
    max_forward_tilt = 0;
    min_backward_tilt = 0;
    theta_now = 0;
    omega_delta = 0;
    
    WaitCycles(40);
    RST_n = 1'b1;
    WaitCycles(40);
    
    $display("\n==== Segway Testbench ====");
    
    // Test 1: Power up
    test_num = 1;
    // Power-up command (same as older benches): enable controller state machines
    SendCmd(8'h47);
    WaitCycles(500_000);
    
    // Wait for inertial sensor calibration (shorter wait - don't wait for full soft-start)
    WaitCycles(300_000);
    
    // Test 2: Positive step
    test_num = 2;
    // Forward lean step: provoke PID response and measure overshoot
    rider_lean = 16'sh0FFF;
    CapturePeak(800_000, max_forward_tilt, min_backward_tilt);
    Check("Forward lean overshoot", (max_forward_tilt > 16'sd150) && (max_forward_tilt < 16'sd12000), "theta", max_forward_tilt);
    
    // Remove lean: expect platform to settle near zero tilt
    rider_lean = 0;
    WaitCycles(3_600_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Positive settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Clear integrator and let platform settle
    ld_cell_lft = 0; ld_cell_rght = 0;
    WaitCycles(50_000);
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    WaitCycles(400_000);
    
    // Test 3: Negative step
    test_num = 3;
    // Backward lean step: mirror of forward test
    rider_lean = -16'sh0FFF;
    CapturePeak(800_000, max_forward_tilt, min_backward_tilt);
    Check("Backward lean overshoot", (min_backward_tilt < -16'sd150) && (min_backward_tilt > -16'sd12000), "theta", min_backward_tilt);
    
    // Remove lean: settle check after backward step
    rider_lean = 0;
    WaitCycles(2_400_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Negative settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    ld_cell_lft = 0; ld_cell_rght = 0;
    WaitCycles(50_000);
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    
    // Allow time for steer_en FSM
    WaitCycles(110_000);
    WaitCycles(10_000);
    
    // Test 4: Stop command (allow steer_en time before stop)
    test_num = 4;
    // Stop command (from prior benches): request controller to quiet outputs
    WaitCycles(150_000);
    SendCmd(8'h53);
    
    ld_cell_lft = 0; ld_cell_rght = 0;
    WaitCycles(1_200_000);
    
    WaitCycles(800_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Stop settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Test 5: Restart
    test_num = 5;
    // Soft restart without hard reset: reapply weight and power-up
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    SendCmd(8'h47);
    
    WaitCycles(300_000);
    
    WaitCycles(300_000);
    // Wait for soft-start ramp to be near max to avoid saturation
    WaitCycles(200_000);
    WaitCycles(500_000);
    ld_cell_lft = 0; ld_cell_rght = 0;
    WaitCycles(50_000);
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    WaitCycles(800_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Restart settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Test 6: Steering
    test_num = 6;
    // Steering right: bias pot high, expect left wheel faster
    steerPot = 12'hC00;
    WaitCycles(300_000);
    omega_delta = int'(iPHYS.omega_lft) - int'(iPHYS.omega_rght);
    Check("Steer right", omega_delta > 200, "delta", omega_delta);
    
    // Steering left: bias pot low, expect right wheel faster
    steerPot = 12'h400;
    WaitCycles(300_000);
    omega_delta = int'(iPHYS.omega_rght) - int'(iPHYS.omega_lft);
    Check("Steer left", omega_delta > 200, "delta", omega_delta);

    // Center steering -> back to normal 
    steerPot = 12'h800;
    WaitCycles(100_000);
    
    // Test 7: Rider removal
    test_num = 7;
    // Rider steps off: remove load cells, expect tilt to settle
    WaitCycles(150_000);
    ld_cell_lft = 0; ld_cell_rght = 0;
    WaitCycles(400_000);
    WaitCycles(5_000_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Rider off settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Test 8: Rider returns
    test_num = 8;
    // Rider steps back on: restore load cells
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    WaitCycles(300_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Rider on resumes balance", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Test 9: Power cycle then recover
    test_num = 9;
    // Hard power cycle: drop reset, reapply defaults, and power-up
    RST_n = 1'b0;
    WaitCycles(50);
    RST_n = 1'b1;
    WaitCycles(40);
    rider_lean = 16'sd0;
    steerPot = 12'h800;
    batt = 12'hFFF;
    ld_cell_lft = 12'h200; ld_cell_rght = 12'h200;
    SendCmd(8'h47);
    WaitCycles(500_000);
    theta_now = int'(iPHYS.theta_platform);
    Check("Power cycle settles", (theta_now < 16'sd2000) && (theta_now > -16'sd2000), "theta", theta_now);
    
    // Test 10: Battery
    test_num = 10;
    batt = 12'h400;
    WaitCycles(800_000);

    Check("Low battery alert", iDUT.batt_low, "batt", batt);
    
    batt = 12'hFFF;
    WaitCycles(10_000_000);
    
    $display("\n==== %0d PASS / %0d FAIL ====\n", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display("YAHOO! All checks passed.");
    $stop;
end
endmodule
