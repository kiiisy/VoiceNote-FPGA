module bram_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36
) (
    input  wire              clk,
    input  wire              reset,

    // from stream2data
    input  wire              wr_en,
    input  wire              in_valid,
    output wire              in_ready,
    input  wire [WIDTH-1:0]  in_packed,

    // from core_ctrl
    input  wire              rd_en,
    input  wire              start_dump,
    input  wire              cap_start_ptr,
    input  wire [$clog2(DEPTH+1)-1:0] dump_len,
    output wire              dump_done,

    output wire [WIDTH-1:0]  out_packed,
    output wire              out_valid,
    input  wire              out_ready
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam            ADDR_W    = $clog2(DEPTH);
    localparam [ADDR_W:0] DEPTH_EXT = DEPTH;

    localparam integer MEMORY_SIZE_BITS = DEPTH * WIDTH;
    localparam integer BYTE_WRITE_W     = 9; // 36bit / 9 = 4 lanes
    localparam integer WEA_W            = (WIDTH + BYTE_WRITE_W - 1) / BYTE_WRITE_W;

    // -------------------------------
    // 内部信号
    // -------------------------------
    wire                w_bram_we;
    wire [ADDR_W-1:0]   w_bram_waddr;
    wire [WIDTH-1:0]    w_bram_wdata;

    wire                w_bram_re;
    wire [ADDR_W-1:0]   w_bram_raddr;
    wire [WIDTH-1:0]    w_bram_rdata;

    wire [ADDR_W-1:0]   w_wr_ptr;
    wire [ADDR_W:0]     w_start_ptr_calc1;
    wire [ADDR_W-1:0]   w_start_ptr_calc2;
    wire [ADDR_W-1:0]   w_start_ptr_calc3;
    reg  [ADDR_W-1:0]   r_start_ptr;
    wire [ADDR_W:0]     w_wr_ptr_now;
    wire [ADDR_W:0]     w_dump_len;
    wire [WEA_W-1:0]    w_wea;

    assign w_wea = {WEA_W{w_bram_we}};

    // -------------------------------
    // 開始アドレス算出手順
    // -------------------------------
    assign w_wr_ptr_now  = {1'b0, w_wr_ptr};
    assign w_dump_len    = dump_len;

    // 開始位置計算。負になりそうならリングを先頭へ巻き戻す
    assign w_start_ptr_calc1 = (w_wr_ptr_now >= w_dump_len) ?
                               (w_wr_ptr_now - w_dump_len) : (w_wr_ptr_now + DEPTH_EXT - w_dump_len);

    // 実アドレス取得
    assign w_start_ptr_calc2 = w_start_ptr_calc1[ADDR_W-1:0];

    // L/Rペア境界で開始するため、開始アドレスを偶数（左CH）に揃える
    assign w_start_ptr_calc3 = w_start_ptr_calc2[0] ?
                              ((w_start_ptr_calc2 == DEPTH-1) ?
                              {ADDR_W{1'b0}} : (w_start_ptr_calc2 + 1'b1)) : w_start_ptr_calc2;

    // -------------------------------
    // DUMP遷移確定時点のwr_ptr基準で開始アドレスをラッチ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_start_ptr <= {ADDR_W{1'b0}};
        end else begin
            if (cap_start_ptr) begin
                r_start_ptr <= w_start_ptr_calc3;
            end else begin
                r_start_ptr <= r_start_ptr;
            end
        end
    end

    wr_ctrl #(
        .DEPTH (DEPTH),
        .WIDTH (WIDTH)
    ) U_wr_ctrl (
        .clk        (clk),          // in
        .reset      (reset),        // in
        .en         (wr_en),        // in
        .in_packed  (in_packed),    // in
        .in_valid   (in_valid),     // in
        .in_ready   (in_ready),     // out
        .bram_we    (w_bram_we),    // out
        .bram_waddr (w_bram_waddr), // out
        .bram_wdata (w_bram_wdata), // out
        .wr_ptr     (w_wr_ptr)      // out
    );

    rd_ctrl #(
        .DEPTH (DEPTH),
        .WIDTH (WIDTH)
    ) U_rd_ctrl (
        .clk        (clk),           // in
        .reset      (reset),         // in
        .en         (rd_en),         // in
        .start_dump (start_dump),    // in
        .dump_len   (dump_len),      // in
        .start_ptr  (r_start_ptr),   // in
        .bram_re    (w_bram_re),     // out
        .bram_raddr (w_bram_raddr),  // out
        .bram_rdata (w_bram_rdata),  // in
        .out_packed (out_packed),    // out
        .out_valid  (out_valid),     // out
        .out_ready  (out_ready),     // in
        .dump_done  (dump_done)      // out
    );

    xpm_memory_sdpram #(
       .ADDR_WIDTH_A(ADDR_W),
       .ADDR_WIDTH_B(ADDR_W),
       .AUTO_SLEEP_TIME(0),
       .BYTE_WRITE_WIDTH_A(BYTE_WRITE_W),
       .CASCADE_HEIGHT(0),
       .CLOCKING_MODE("common_clock"),
       .ECC_BIT_RANGE("7:0"),
       .ECC_MODE("no_ecc"),
       .ECC_TYPE("none"),
       .IGNORE_INIT_SYNTH(0),
       .MEMORY_INIT_FILE("none"),
       .MEMORY_INIT_PARAM("0"),
       .MEMORY_OPTIMIZATION("true"),
       .MEMORY_PRIMITIVE("auto"),
       .MEMORY_SIZE(MEMORY_SIZE_BITS),
       .MESSAGE_CONTROL(0),
       .RAM_DECOMP("auto"),
       .READ_DATA_WIDTH_B(WIDTH),
       .READ_LATENCY_B(1),
       .READ_RESET_VALUE_B("0"),
       .RST_MODE_A("SYNC"),
       .RST_MODE_B("SYNC"),
       .SIM_ASSERT_CHK(0),
       .USE_EMBEDDED_CONSTRAINT(0),
       .USE_MEM_INIT(0),
       .USE_MEM_INIT_MMI(0),
       .WAKEUP_TIME("disable_sleep"),
       .WRITE_DATA_WIDTH_A(WIDTH),
       .WRITE_MODE_B("read_first"),
       .WRITE_PROTECT(1)
    ) U_xpm_memory_sdpram (
       .dbiterrb(),
       .doutb(w_bram_rdata),
       .sbiterrb(),
       .addra(w_bram_waddr),
       .addrb(w_bram_raddr),
       .clka(clk),
       .clkb(clk),
       .dina(w_bram_wdata),
       .ena(w_bram_we),
       .enb(w_bram_re),
       .injectdbiterra(1'b0),
       .injectsbiterra(1'b0),
       .regceb(1'b1),
       .rstb(1'b0),
       .sleep(1'b0),
       .wea(w_wea)
    );

endmodule
