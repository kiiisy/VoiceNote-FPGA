module stream2data (
    input  wire               clk,
    input  wire               reset,

    // AXI-Stream Slave
    input  wire [31:0]        s_axis_tdata,
    input  wire               s_axis_tvalid,
    input  wire               s_axis_tready,
    input  wire [ 2:0]        s_axis_tid,

    // to internal
    output wire               sample_stb,
    output wire [35:0]        packed_data,
    output wire signed [15:0] sample16_data
);
    // ハンドシェイク成立検出
    assign sample_stb = s_axis_tvalid & s_axis_tready;

    // BRAM格納用データ生成
    assign packed_data = {
        s_axis_tid,        // [35:33]
        s_axis_tdata,      // [32:1]
        1'b0               // [0] pad
    };

    // 16bitサンプル抽出
    assign sample16_data = s_axis_tdata[27:12];

endmodule
