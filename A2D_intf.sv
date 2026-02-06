module A2D_intf(
    input clk,
    input rst_n,
    input logic nxt,
    input logic MISO,
    output logic [11:0] lft_ld,
    output logic [11:0] rght_ld,
    output logic [11:0] steer_pot,
    output logic [11:0] batt,
    output logic SS_n,
    output logic SCLK,
    output logic MOSI
);
    logic wrt;
    logic [15:0] wt_data;
    logic done;
    logic [15:0] rd_data;

    logic update;
    logic store;

    // Instantiate SPI Monarch to communicate with A2D converter
    SPI_mnrch SPI_inst(
        .clk(clk),
        .rst_n(rst_n),
        .MISO(MISO),
        .wrt(wrt),
        .wt_data(wt_data),
        .done(done),
        .rd_data(rd_data),
        .SS_n(SS_n),
        .SCLK(SCLK),
        .MOSI(MOSI)
    );

    // Round Robin Counter to cycle through A2D channels
    typedef enum logic [2:0] {
        CH_LFT_LD = 3'h0,
        CH_RGHT_LD = 3'h4,
        CH_STEER_POT = 3'h5,
        CH_BATT = 3'h6
    } channel_t;

    channel_t current_channel;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_channel <= CH_LFT_LD;
        end else if (update) begin
            // Update current channel in round robin fashion
            case (current_channel)
                CH_LFT_LD: current_channel <= CH_RGHT_LD;
                CH_RGHT_LD: current_channel <= CH_STEER_POT;
                CH_STEER_POT: current_channel <= CH_BATT;
                CH_BATT: current_channel <= CH_LFT_LD;
            endcase
        end
    end

    // States in transaction
    typedef enum logic [1:0] {
        IDLE,
        SND_CHNL,
        WAIT_DATA
    } state_t;

    state_t current_state, next_state;

    // Control logic to initiate SPI transactions and map data to outputs
    always_comb begin
        // Default assignments
        update = 1'b0;
        store = 1'b0;
        wrt = 1'b0;

        next_state = current_state;
        case (current_state)
            IDLE: begin
                if(nxt) begin
                    next_state = SND_CHNL;
                end
                wrt = 1'b1;
            end
            SND_CHNL: begin
                if(done) begin
                    next_state = WAIT_DATA;
                    wrt = 1'b1;
                end
            end
            WAIT_DATA: begin
                if(done) begin
                    store = 1'b1;
                    next_state = IDLE;
                    update = 1'b1;
                end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    assign wt_data = {2'b00, current_channel, 11'h000};
    // Map received data to appropriate output based on current channel
    // 4 holding registers to store outputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lft_ld <= 12'h000;
            rght_ld <= 12'h000;
            steer_pot <= 12'h000;
            batt <= 12'h000;
        end else if (store) begin
            case (current_channel)
                CH_LFT_LD: lft_ld <= rd_data[11:0];
                CH_RGHT_LD: rght_ld <= rd_data[11:0];
                CH_STEER_POT: steer_pot <= rd_data[11:0];
                CH_BATT: batt <= rd_data[11:0];
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
endmodule