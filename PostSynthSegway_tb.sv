`timescale 1ns/1ps
module PostSynthSegway_tb();

  //////////////////////////////////////////////
  // Interconnects to DUT defined as logic   //
  ////////////////////////////////////////////
  logic SS_n, SCLK, MOSI, MISO, INT;              // Inertial sensor SPI
  logic A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO;   // A2D converter SPI
  logic RX_TX;                                    // UART line
  logic PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft; // Motor PWM outputs
  logic piezo, piezo_n;                           // Piezo buzzer
  logic cmd_sent;                                 // UART TX done
  logic rst_n;                                    // Synchronized reset

  //////////////////////////////////////////////
  // Stimulus signals declared as logic      //
  ////////////////////////////////////////////
  logic clk, RST_n;
  logic [7:0] cmd;                    // Command byte to send via UART
  logic send_cmd;                     // Trigger UART transmission
  logic signed [15:0] rider_lean;     // Rider lean input to physics model
  logic [11:0] ld_cell_lft;           // Left load cell reading
  logic [11:0] ld_cell_rght;          // Right load cell reading
  logic [11:0] steerPot;              // Steering potentiometer
  logic [11:0] batt;                  // Battery voltage reading
  logic OVR_I_lft, OVR_I_rght;        // Over-current flags

  ////////////////////////////////////////////////////////////////
  // Instantiate Physical Model of Segway with Inertial sensor //
  //////////////////////////////////////////////////////////////
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

  /////////////////////////////////////////////////////////
  // Instantiate Model of A2D for load cell and battery //
  ///////////////////////////////////////////////////////
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

  ///////////////////////////
  // Instantiate DUT       //
  ///////////////////////////
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

  //////////////////////////////////////////////////
  // Instantiate UART_tx (mimics BLE module cmd)  //
  ////////////////////////////////////////////////
  UART_tx iTX(
      .clk(clk),
      .rst_n(rst_n),
      .TX(RX_TX),
      .trmt(send_cmd),
      .tx_data(cmd),
      .tx_done(cmd_sent)
  );

  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////
  rst_synch iRST(
      .clk(clk),
      .RST_n(RST_n),
      .rst_n(rst_n)
  );


  //////////////////////////////////////////////////////
  // Helper Task: Send a command byte via UART        //
  //////////////////////////////////////////////////////
  // Initialize all TB-driven regs
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

// Wait for N rising clock edges
task wait_clks(input integer n);
begin
  repeat (n) @(posedge clk);
end
endtask

// Send a single UART command byte (e.g. "G")
task send_uart_cmd(input [7:0] c);
begin
  @(posedge clk);
  cmd      <= c;
  send_cmd <= 1'b1;      // assert trmt
  @(posedge clk);
  send_cmd <= 1'b0;      // deassert trmt
  // wait for UART_tx to finish sending
  wait (cmd_sent == 1'b1);
  @(posedge clk);        // allow tx_done pulse to clear
end
endtask

//////////////////////
// Main test        //
//////////////////////
initial begin
  init_signals();

  // Release reset
  wait_clks(5);
  RST_n = 1'b1;
  wait_clks(20);  // let rst_synch settle

  // Rider weight on board
  ld_cell_lft  = 12'h400;
  ld_cell_rght = 12'h400;

  steerPot     = 12'h800;
  batt         = 12'hC00;
  

  // Enable Segway via 'G'
  $display("[%0t] Sending 'G' command", $time);
  send_uart_cmd("G");

  // Wait ~350k clocks before applying lean
  wait_clks(350_000);

  // Step input in rider lean
  $display("[%0t] Step rider_lean -> 0x0FFF", $time);
  rider_lean = 16'sh0FFF;

  // Hold for ~1,000,000 clocks
  wait_clks(1_000_000);

  // Drop lean back to zero
  $display("[%0t] Step rider_lean -> 0", $time);
  rider_lean = 16'sd0;

  // Watch the recovery for another ~650k clocks
  wait_clks(650_000);  // total ~2,000,000 clocks (~40 ms sim time)

  $display("[%0t] Test complete", $time);
  $stop();
end

// Clock generation
always
  #10 clk = ~clk;

endmodule