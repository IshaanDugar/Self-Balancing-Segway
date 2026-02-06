module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_1_4,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY HOFFMAN...you are a moron.  sum_gt_min would simply be ~sum_lt_min. 
  // Why have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's weight is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  input diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// held high in intitial state when waiting for sum_gt_min
  
  // You fill out the rest...use good SM coding practices ///
  
  // State type definition
  typedef enum logic [1:0] { IDLE, WAIT_BALANCE, STEER_EN } state_t;
  
  state_t state, nxt_state;
  
  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= nxt_state;
  end
  
  // Next state and output logic
  always_comb begin
    nxt_state = state;
    clr_tmr = 1'b0;
    en_steer = 1'b0;
    // rider_off either if we are in IDLE, or if the sum is below sum_lt_min
    rider_off = (state == IDLE) || sum_lt_min;
    
    case (state)
      IDLE: begin
        rider_off = 1'b1;
        if (sum_gt_min) begin
          clr_tmr = 1'b1;
          nxt_state = WAIT_BALANCE;
        end
      end
      
      WAIT_BALANCE: begin
        if (sum_lt_min) begin
          nxt_state = IDLE;
        end else if (diff_gt_1_4) begin
          clr_tmr = 1'b1;
        end else if (tmr_full) begin
          nxt_state = STEER_EN;
        end
      end
      
      STEER_EN: begin
        en_steer = 1'b1;
        if (sum_lt_min) begin
          nxt_state = IDLE;
        end else if (diff_gt_15_16) begin
          nxt_state = WAIT_BALANCE;
        end
      end
      
      default: nxt_state = IDLE;
    endcase
  end
  
endmodule