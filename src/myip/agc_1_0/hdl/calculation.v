module calculation (
    input  wire         clk,
    input  wire         reset,

    // AXI-Stream Slave
    input  wire [31:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire [ 2:0]  s_axis_tid,

    // AXI-Stream Master
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire [ 2:0]  m_axis_tid,

    // from iir_filter
    input  wire signed [15:0] smooth_gain,

    // to register
    output wire         clip_flg
);

    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam signed [15:0] MAX16 = 16'h7FFF;  // +32767
    localparam signed [15:0] MIN16 = 16'h8000;  // -32768

    // -------------------------------
    // 内部信号
    // -------------------------------
    // Stage0関連
    reg        r_s0_valid;
    reg [ 2:0] r_s0_tid;

    reg        r_s0_P, r_s0_C, r_s0_U, r_s0_V;
    reg [ 3:0] r_s0_preamble;
    reg signed [15:0] r_s0_sample;
    wire        w_handshake_s0;

    // Stage1関連
    reg        r_s1_valid;
    reg [ 2:0] r_s1_tid;
    reg        r_s1_P, r_s1_C, r_s1_U, r_s1_V;
    reg [ 3:0] r_s1_preamble;

    reg signed [31:0] r_product_reg;

    // Stage2関連
    reg        r_s2_valid;
    reg [ 2:0] r_s2_tid;
    reg [31:0] r_s2_tdata;

    reg        r_s2_clip;
    wire       w_clip_hi;
    wire       w_clip_lo;
    wire       w_clip_any;

    wire signed [31:0] w_shifted;
    wire signed [15:0] w_sample_sat;

    // -------------------------------
    // Stage0: 入力キャプチャ
    // -------------------------------
    assign w_handshake_s0 = s_axis_tvalid & s_axis_tready;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_s0_valid    <= 1'b0;
            r_s0_tid      <= 3'd0;
            r_s0_P        <= 1'b0;
            r_s0_C        <= 1'b0;
            r_s0_U        <= 1'b0;
            r_s0_V        <= 1'b0;
            r_s0_preamble <= 4'd0;
            r_s0_sample   <= 16'd0;
        end else begin
            if (w_handshake_s0) begin
                r_s0_valid    <= 1'b1;
                r_s0_tid      <= s_axis_tid;
                r_s0_P        <= s_axis_tdata[31];
                r_s0_C        <= s_axis_tdata[30];
                r_s0_U        <= s_axis_tdata[29];
                r_s0_V        <= s_axis_tdata[28];
                r_s0_sample   <= s_axis_tdata[27:12];
                r_s0_preamble <= s_axis_tdata[3:0];
            end else if (m_axis_tready == 1'b0) begin
                r_s0_valid <= r_s0_valid;
            end else begin
                r_s0_valid <= 1'b0;
            end
        end
    end

    // -------------------------------
    // Stage1: 16 x 16 乗算
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_s1_valid    <= 1'b0;
            r_s1_tid      <= 3'd0;
            r_s1_P        <= 1'b0;
            r_s1_C        <= 1'b0;
            r_s1_U        <= 1'b0;
            r_s1_V        <= 1'b0;
            r_s1_preamble <= 4'd0;
            r_product_reg <= 32'd0;
        end else begin
            r_s1_valid    <= r_s0_valid;
            r_s1_tid      <= r_s0_tid;
            r_s1_P        <= r_s0_P;
            r_s1_C        <= r_s0_C;
            r_s1_U        <= r_s0_U;
            r_s1_V        <= r_s0_V;
            r_s1_preamble <= r_s0_preamble;
            r_product_reg <= r_s0_sample * smooth_gain;  // 16 x 16 → 32bit signed
        end
    end

    // -------------------------------
    // Stage2: シフト & 飽和 & パッキング
    // -------------------------------
    assign w_shifted = r_product_reg >>> 14;

    assign w_clip_hi  = (w_shifted > MAX16);
    assign w_clip_lo  = (w_shifted < MIN16);
    assign w_clip_any = w_clip_hi | w_clip_lo;

    assign w_sample_sat =
        (w_shifted > MAX16) ? MAX16 :
        (w_shifted < MIN16) ? MIN16 : w_shifted[15:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_s2_valid    <= 1'b0;
            r_s2_tid      <= 3'd0;
            r_s2_tdata    <= 32'd0;
            r_s2_clip     <= 1'b0;
        end else begin
            r_s2_valid    <= r_s1_valid;
            r_s2_tid      <= r_s1_tid;
            r_s2_clip     <= r_s1_valid & w_clip_any;
            r_s2_tdata <= {
                r_s1_P,              // [31]
                r_s1_C,              // [30]
                r_s1_U,              // [29]
                r_s1_V,              // [28]
                w_sample_sat,        // [27:12] ゲイン適用後サンプル
                8'd0,                // [11:4]
                r_s1_preamble        // [3:0]
            };
        end
    end

    // -------------------------------
    // 出力たち
    // -------------------------------
    assign m_axis_tdata  = r_s2_tdata;
    assign m_axis_tvalid = r_s2_valid;
    assign m_axis_tid    = r_s2_tid;
    // readyはそのままパススルー
    assign s_axis_tready = m_axis_tready;

    assign clip_flg      = r_s2_clip;

endmodule
