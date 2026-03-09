module data2stream (
    input  wire         clk,
    input  wire         reset,

    input  wire         en,

    // from bram_ctrl
    input  wire [35:0]  in_packed,
    input  wire         in_valid,
    output wire         in_ready,

    // AXI-Stream Master
    output wire [31:0]  m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire [ 2:0]  m_axis_tid
);
    // -------------------------------
    // 内部信号
    // -------------------------------
    reg        r_valid;
    reg [31:0] r_tdata;
    reg [ 2:0] r_tid;

    wire w_accept;
    wire w_out_handshake;
    wire w_in_handshake;

    // バッファが空、または同サイクルで消費される場合に入力受付可能とする
    assign w_accept = (~r_valid) | w_out_handshake;
    assign in_ready = en & w_accept;

    // 入力側のハンドシェイク成立
    assign w_out_handshake = r_valid & m_axis_tready;
    // 出力側のハンドシェイク成立
    assign w_in_handshake = in_valid & in_ready;

    // 入力パック展開
    wire [ 2:0] w_in_tid   = in_packed[35:33];
    wire [31:0] w_in_tdata = in_packed[32:1];

    // -------------------------------
    // 1ワードバッファ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_valid <= 1'b0;
            r_tdata <= 32'd0;
            r_tid   <= 3'd0;
        end else begin
            case ({w_in_handshake, w_out_handshake})
            2'b10: begin
                r_valid <= 1'b1;
                r_tdata <= w_in_tdata;
                r_tid   <= w_in_tid;
            end
            2'b01: begin
                r_valid <= 1'b0;
            end
            2'b11: begin
                r_valid <= 1'b1;
                r_tdata <= w_in_tdata;
                r_tid   <= w_in_tid;
            end
            default: begin
                r_valid <= r_valid;
            end
            endcase
        end
    end

    // -------------------------------
    // M AXIS出力
    // -------------------------------
    assign m_axis_tvalid = r_valid;
    assign m_axis_tdata  = r_tdata;
    assign m_axis_tid    = r_tid;

endmodule
