module wr_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36
) (
    input  wire                     clk,
    input  wire                     reset,

    // from core_ctrl
    input  wire                     en,

    // from stream2data
    input  wire [WIDTH-1:0]         in_packed,
    input  wire                     in_valid,
    output wire                     in_ready,

    // to bram
    output wire                     bram_we,
    output wire [$clog2(DEPTH)-1:0] bram_waddr,
    output wire [WIDTH-1:0]         bram_wdata,

    output wire [$clog2(DEPTH)-1:0] wr_ptr
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam integer ADDR_W = $clog2(DEPTH);

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [ADDR_W-1:0] r_waddr;
    reg [WIDTH-1:0]  r_wdata;
    reg [ADDR_W-1:0] r_wr_ptr;
    reg              r_bram_we;

    wire w_accept;

    // en有効中は常時受信可能
    assign in_ready = en;
    assign w_accept = en && in_valid;

    // -------------------------------
    // BRAM書き込みイネーブル
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_bram_we <= 1'b0;
        end else begin
            r_bram_we <= w_accept;
        end
    end

    assign bram_we = r_bram_we;

    // -------------------------------
    // BRAM書き込みアドレス
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_waddr <= {ADDR_W{1'b0}};
        end else begin
            if (w_accept) begin
                r_waddr <= r_wr_ptr;
            end else begin
                r_waddr <= r_waddr;
            end
        end
    end

    assign bram_waddr = r_waddr;

    // -------------------------------
    // BRAM書き込みデータ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_wdata <= {WIDTH{1'b0}};
        end else begin
            if (w_accept) begin
                r_wdata <= in_packed;
            end else begin
                r_wdata <= r_wdata;
            end
        end
    end

    assign bram_wdata = r_wdata;

    // -------------------------------
    // 書き込みポインタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_wr_ptr <= {ADDR_W{1'b0}};
        end else begin
            if (w_accept) begin
                if (r_wr_ptr == DEPTH-1) begin
                    r_wr_ptr <= {ADDR_W{1'b0}};
                end else begin
                    r_wr_ptr <= r_wr_ptr + 1'b1;
                end
            end else begin
                r_wr_ptr <= r_wr_ptr;
            end
        end
    end

    assign wr_ptr = r_wr_ptr;

endmodule
