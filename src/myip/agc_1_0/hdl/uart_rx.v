module uart_rx (
    input  wire        clk,
    input  wire        reset,

    // from dToF
    input  wire        rx,

    // to frame_parser
    output wire [ 7:0] data,
    output wire        valid,

    // to register
    output wire        frame_error
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    localparam integer BAUD_CNT_MAX = 868; // 1bit時間 = 868クロック @ 100MHz/115200

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [ 1:0] r_state;

    reg [ 3:0] r_bit_idx;
    reg [ 7:0] r_shift_reg;
    reg [ 7:0] r_data;
    reg        r_valid;
    reg        r_frame_error;

    reg [15:0] r_baud_cnt;
    reg        r_baud_tick;


    // -------------------------------
    // ボーレートカウンタ
    // 受信中のみ動作。IDLEでstartを検出したら半bit遅延で位相合わせ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_baud_cnt  <= 16'd0;
            r_baud_tick <= 1'b0;
        end else begin
            if (r_state == S_IDLE) begin
                if (!rx) begin
                    r_baud_cnt <= (BAUD_CNT_MAX >> 1);
                end else begin
                    r_baud_cnt <= 16'd0;
                end
                r_baud_tick <= 1'b0;
            end else if (r_baud_cnt == (BAUD_CNT_MAX-1)) begin
                r_baud_cnt  <= 16'd0;
                r_baud_tick <= 1'b1;
            end else begin
                r_baud_cnt <= r_baud_cnt + 16'd1;
                r_baud_tick <= 1'b0;
            end
        end
    end

    // -------------------------------
    // ステートマシン
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state       <= S_IDLE;
            r_bit_idx     <= 4'd0;
            r_shift_reg   <= 8'd0;
            r_data        <= 8'd0;
            r_valid       <= 1'b0;
            r_frame_error <= 1'b0;
        end else begin
            case (r_state)
            // -------------------------------
            // IDLE：RX=1（待ち状態）
            // -------------------------------
            S_IDLE: begin
                if (!rx) begin  // 受信開始
                    r_bit_idx <= 4'd0;
                    r_state   <= S_START;
                end
                r_valid <= 1'd0;
            end
            // -------------------------------
            // START： スタートビット検出
            // -------------------------------
            S_START: begin
                if (r_baud_tick) begin
                    if (!rx) begin
                        r_state <= S_DATA;
                    end else begin
                        r_state <= S_IDLE;
                    end
                end
                r_valid <= 1'd0;
            end
            // -------------------------------
            // DATA：データビット検出 (8bit)
            // -------------------------------
            S_DATA: begin
                if (r_baud_tick) begin
                    r_shift_reg[r_bit_idx] <= rx; // LSB からシフト
                    if (r_bit_idx == 4'd7) begin
                        r_state <= S_STOP;
                    end else begin
                        r_bit_idx <= r_bit_idx + 4'd1;
                    end
                end
                r_valid <= 1'd0;
            end
            // -------------------------------
            // STOP： ストップビット検出
            // -------------------------------
            S_STOP: begin
                if (r_baud_tick) begin
                    if (rx) begin
                        r_data  <= r_shift_reg;
                        r_valid <= 1'b1; // 受信完了
                        r_frame_error <= 1'b0;
                    end else begin
                        r_data  <= r_data;
                        r_valid <= 1'b0;
                        r_frame_error <= 1'b1;
                    end
                    r_state <= S_IDLE;
                end else begin
                    r_valid <= 1'b0;
                    r_state <= S_STOP;
                end
            end
            endcase
        end
    end

    assign data        = r_data;
    assign valid       = r_valid;
    assign frame_error = r_frame_error;

endmodule
