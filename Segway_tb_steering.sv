module Segway_tb_steer();

    ////////////////////////////////////
    // Interconnects to DUT/support   //
    ////////////////////////////////////
    wire SS_n, SCLK, MOSI, MISO, INT;         // to inertial sensor
    wire A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;  // to A2D converter
    wire RX_TX;
    wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
    wire piezo, piezo_n;
    wire cmd_sent;
    wire rst_n;                                // synchronized global reset

    ////////////////////////////////////
    // Stimulus Signals               //
    ////////////////////////////////////
    reg clk, RST_n;
    reg [7:0] cmd;                 // command byte sent to DUT
    reg send_cmd;                  // asserted to initiate UART transmit
    reg signed [15:0] rider_lean;
    reg [11:0] ld_cell_lft, ld_cell_rght, steerPot, batt;
    reg OVR_I_lft, OVR_I_rght;

    ////////////////////////////////////
    // Instantiate Physical Model     //
    ////////////////////////////////////
    SegwayModel iPHYS(
        .clk(clk), .RST_n(rst_n),
        .SS_n(SS_n), .SCLK(SCLK),
        .MISO(MISO), .MOSI(MOSI), .INT(INT),
        .PWM1_lft(PWM1_lft), .PWM2_lft(PWM2_lft),
        .PWM1_rght(PWM1_rght), .PWM2_rght(PWM2_rght),
        .rider_lean(rider_lean)
    );

    ////////////////////////////////////
    // Instantiate Model of A2D       //
    ////////////////////////////////////
    ADC128S_FC iA2D(
        .clk(clk), .rst_n(RST_n),
        .SS_n(A2D_SS_n), .SCLK(A2D_SCLK),
        .MISO(A2D_MISO), .MOSI(A2D_MOSI),
        .ld_cell_lft(ld_cell_lft), .ld_cell_rght(ld_cell_rght),
        .steerPot(steerPot), .batt(batt)
    );

    ////////////////////////////////////
    // Instantiate Segway DUT         //
    ////////////////////////////////////
    Segway iDUT(
        .clk(clk), .RST_n(RST_n),
        .INERT_SS_n(SS_n), .INERT_MOSI(MOSI),
        .INERT_SCLK(SCLK), .INERT_MISO(MISO), .INERT_INT(INT),
        .A2D_SS_n(A2D_SS_n), .A2D_MOSI(A2D_MOSI),
        .A2D_SCLK(A2D_SCLK), .A2D_MISO(A2D_MISO),
        .PWM1_lft(PWM1_lft), .PWM2_lft(PWM2_lft),
        .PWM1_rght(PWM1_rght), .PWM2_rght(PWM2_rght),
        .OVR_I_lft(OVR_I_lft), .OVR_I_rght(OVR_I_rght),
        .piezo_n(piezo_n), .piezo(piezo),
        .RX(RX_TX)
    );

    ////////////////////////////////////
    // Instantiate UART_tx Model      //
    ////////////////////////////////////
    UART_tx iTX(
        .clk(clk), .rst_n(rst_n),
        .TX(RX_TX), .trmt(send_cmd),
        .tx_data(cmd), .tx_done(cmd_sent)
    );

    ////////////////////////////////////
    // Instantiate reset synchronizer //
    ////////////////////////////////////
    rst_synch iRST(.clk(clk), .RST_n(RST_n), .rst_n(rst_n));

    ////////////////////////////////////
    // Initialize TB signals          //
    ////////////////////////////////////
    task init_signals;
    begin
    clk         = 1'b0;
    RST_n       = 1'b0;
    send_cmd    = 1'b0;
    cmd         = 8'h00;
    rider_lean  = 16'sd0;
    ld_cell_lft = 12'd0;
    ld_cell_rght= 12'd0;
    steerPot    = 12'd0;
    batt        = 12'd0;
    OVR_I_lft   = 1'b0;
    OVR_I_rght  = 1'b0;
    end
    endtask

    ////////////////////////////////////
    // Simple N-cycle wait            //
    ////////////////////////////////////
    task wait_clks(input integer n);
    begin
    repeat (n) @(posedge clk);
    end
    endtask

    ////////////////////////////////////
    // UART command helper task       //
    ////////////////////////////////////
    task send_uart_cmd(input [7:0] c);
    begin
    @(posedge clk);
    cmd      <= c;
    send_cmd <= 1'b1;
    @(posedge clk);
    send_cmd <= 1'b0;
    wait(cmd_sent == 1'b1);
    @(posedge clk);
    end
    endtask

    ////////////////////////////////////
    // Steering Test Sequence         //
    ////////////////////////////////////
    initial begin
    init_signals();

    // Release reset
    wait_clks(5);
    RST_n = 1'b1;
    wait_clks(20);

    // Basic rider info and battery setup
    ld_cell_lft  = 12'h400;   // rider weight on board
    ld_cell_rght = 12'h400;
    batt         = 12'hC00;   
    steerPot     = 12'h800;   // centered steering
    rider_lean   = 16'sd0;

    // Enable Segway
    $display("[%0t] Sending 'G' command", $time);
    send_uart_cmd("G");

    // Allow system to stabilize before steering
    wait_clks(300_000);
    
    ////////////////////////////////////
    // Short rider lean test          //
    ////////////////////////////////////
    $display("\n=== Applying +4095 Lean Step ===");
    rider_lean = 12'hfff;
    wait_clks(1_000_000);
    
    // Return lean to 0
    $display("\n=== Returning Lean to Zero ===");
    rider_lean = 12'h000;
    wait_clks(500_000);
    
    // Applying large negative lean
    $display("\n=== Applying -4095 Lean Step (Backward Lean) ===");
    rider_lean = 16'shf000;
    wait_clks(1_000_000);
    
    // Return lean to 0
    $display("\n=== Returning Lean to Zero ===");
    rider_lean = 12'h000;
    wait_clks(500_000);

    ////////////////////////////////////
    // Right Turn Test                //
    ////////////////////////////////////
    $display("\n[%0t] === Right Turn ===", $time);
    steerPot = 12'h900;       // slight right turn
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d",
            $time, iDUT.lft_spd, iDUT.rght_spd);

    ////////////////////////////////////
    // Left Turn Test                 //
    ////////////////////////////////////
    $display("\n[%0t] === Left Turn ===", $time);
    steerPot = 12'h700;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d",
            $time, iDUT.lft_spd, iDUT.rght_spd);

    ////////////////////////////////////
    // Back to Center                 //
    ////////////////////////////////////
    $display("\n[%0t] === Bring Wheel to Center ===", $time);
    steerPot = 12'h800;
    wait_clks(500_000);

    // Small step input in rider lean
    $display("[%0t] Step rider_lean -> 0x09C4", $time);
    rider_lean = 16'sh09C4;
    wait_clks(1_000_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d",
            $time, iDUT.lft_spd, iDUT.rght_spd);

    ////////////////////////////////////
    // Right Turn Test 2               //
    ////////////////////////////////////
    $display("\n[%0t] === Right Turn ===", $time);
    steerPot = 12'h900;       // slight right turn
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d",
            $time, iDUT.lft_spd, iDUT.rght_spd);

    ////////////////////////////////////
    // Left Turn Test 2                //
    ////////////////////////////////////
    $display("\n[%0t] === Left Turn ===", $time);
    steerPot = 12'h700;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d",
            $time, iDUT.lft_spd, iDUT.rght_spd);

    ////////////////////////////////////
    // Back to Center 2                //
    ////////////////////////////////////
    $display("\n[%0t] === Bring Wheel to Center ===", $time);
    steerPot = 12'h800;
    wait_clks(500_000);

    $display("\n[%0t] === Steering Test Complete ===", $time);
    
    /////////////////////////////////////////////////////////////////////
    // THIRD TEST: Get too_fast to assert by ramping up the rider lean //
    //  too_fast is asserted when lft_spd or rght_spd > d1536 (h600)   //
    /////////////////////////////////////////////////////////////////////
    
    $display("\n[%0t] === TEST 3: too_fast ===", $time);
    
    // Set rider lean to decimal 4600
    $display("[%0t] Step rider_lean -> 0x11F8", $time);
    rider_lean = 16'sh11F8;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to deimal 5000
    $display("[%0t] Step rider_lean -> 0x01388", $time);
    rider_lean = 16'sh1388;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
    
    
    // Set rider lean to decimal 6000
    $display("[%0t] Step rider_lean -> 0x1770", $time);
    rider_lean = 16'sh1770;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 7000
    $display("[%0t] Step rider_lean -> 0x1B58", $time);
    rider_lean = 16'sh1B58;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 8000        
    $display("[%0t] Step rider_lean -> 0x1F40", $time);
    rider_lean = 16'sh1F40;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 9000
    $display("[%0t] Step rider_lean -> 0x2328", $time);
    rider_lean = 16'sh2328;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
            // Set rider lean to decimal 10000
    $display("[%0t] Step rider_lean -> 0x2710", $time);
    rider_lean = 16'sh2710;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 11000        
    $display("[%0t] Step rider_lean -> 0x2AF8", $time);
    rider_lean = 16'sh2AF8;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 12000
    $display("[%0t] Step rider_lean -> 0x2EE0", $time);
    rider_lean = 16'sh2EE0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 13000        
    $display("[%0t] Step rider_lean -> 0x32C8", $time);
    rider_lean = 16'sh32C8;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 14000
    $display("[%0t] Step rider_lean -> 0x36B0", $time);
    rider_lean = 16'sh36B0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 16000        
    $display("[%0t] Step rider_lean -> 0x3E80", $time);
    rider_lean = 16'sh3E80;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 18000
    $display("[%0t] Step rider_lean -> 0x4650", $time);
    rider_lean = 16'sh4650;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 20000        
    $display("[%0t] Step rider_lean -> 0x4E20", $time);
    rider_lean = 16'sh4E20;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 22000
    $display("[%0t] Step rider_lean -> 0x55F0", $time);
    rider_lean = 16'sh55F0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 24000        
    $display("[%0t] Step rider_lean -> 0x5DC0", $time);
    rider_lean = 16'sh5DC0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 26000
    $display("[%0t] Step rider_lean -> 0x6590", $time);
    rider_lean = 16'sh6590;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
        // Set rider lean to decimal 28000       
    $display("[%0t] Step rider_lean -> 0x6D60", $time);
    rider_lean = 16'sh6D60;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 30000
    $display("[%0t] Step rider_lean -> 0x7530", $time);
    rider_lean = 16'sh7530;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 32000       
    $display("[%0t] Step rider_lean -> 0x7D00", $time);
    rider_lean = 16'sh7D00;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 34000
    $display("[%0t] Step rider_lean -> 0x84D0", $time);
    rider_lean = 16'sh84D0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 36000
    $display("[%0t] Step rider_lean -> 0x8CA0", $time);
    rider_lean = 16'sh8CA0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
        // Set rider lean to decimal 38000       
    $display("[%0t] Step rider_lean -> 0x9470", $time);
    rider_lean = 16'sh9470;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 40000
    $display("[%0t] Step rider_lean -> 0x9C40", $time);
    rider_lean = 16'sh9C40;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 42000       
    $display("[%0t] Step rider_lean -> 0xA410", $time);
    rider_lean = 16'shA410;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
            
    // Set rider lean to decimal 44000
    $display("[%0t] Step rider_lean -> 0xABE0", $time);
    rider_lean = 16'shABE0;
    wait_clks(500_000);

    $display("[%0t] Wheel speeds: L=%0d  R=%0d, too_fast=%0b",
            $time, iDUT.lft_spd, iDUT.rght_spd, iDUT.too_fast);
    $stop();
    end

    ////////////////////////////////////
    // Clock Generation               //
    ////////////////////////////////////
    always #10 clk = ~clk;

endmodule
