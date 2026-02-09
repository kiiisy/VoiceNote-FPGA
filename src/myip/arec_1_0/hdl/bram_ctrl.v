// bram_ctrl.v
// BRAM controller top
// - contains wr_ctrl / rd_ctrl
// - instantiates xpm_memory_sdpram directly
//
// Memory format: 36-bit packed audio
//   { tid[2:0], tdata[31:0], pad[0] }

module bram_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36
) (
    input  wire clk,
    input  wire reset,

    // -------------------------------
    // Write side (from stream2data)
    // -------------------------------
    input  wire              wr_en,
    input  wire              in_valid,
    output wire              in_ready,
    input  wire [WIDTH-1:0]  in_packed,

    // -------------------------------
    // Read control (from sys_ctrl)
    // -------------------------------
    input  wire              rd_en,
    input  wire              start_dump,
    input  wire [$clog2(DEPTH+1)-1:0] dump_len,
    output wire              dump_done,

    // -------------------------------
    // Read data output (to AF mux)
    // -------------------------------
    output wire [WIDTH-1:0]  out_packed,
    output wire              out_valid,
    input  wire              out_ready
);

    // -------------------------------
    // Local parameters
    // -------------------------------
    localparam ADDR_W = $clog2(DEPTH);

    // XPM parameters
    localparam integer MEMORY_SIZE_BITS = DEPTH * WIDTH;
    localparam integer BYTE_WRITE_W     = 9; // 36bit / 9 = 4 lanes
    localparam integer WEA_W            = (WIDTH + BYTE_WRITE_W - 1) / BYTE_WRITE_W;

    // -------------------------------
    // Internal wires
    // -------------------------------
    // BRAM write
    wire                bram_we;
    wire [ADDR_W-1:0]   bram_waddr;
    wire [WIDTH-1:0]    bram_wdata;

    // BRAM read
    wire                bram_re;
    wire [ADDR_W-1:0]   bram_raddr;
    wire [WIDTH-1:0]    bram_rdata;

    // write pointer
    wire [ADDR_W-1:0]   wr_ptr;
    reg  [ADDR_W-1:0]   r_start_ptr;

    // expand write enable to byte lanes
    wire [WEA_W-1:0] wea = {WEA_W{bram_we}};

    // -------------------------------
    // wr_ctrl
    // -------------------------------
    wr_ctrl #(
        .DEPTH (DEPTH),
        .WIDTH (WIDTH)
    ) u_wr_ctrl (
        .clk        (clk),
        .reset      (reset),

        .en         (wr_en),

        .in_packed  (in_packed),
        .in_valid   (in_valid),
        .in_ready   (in_ready),

        .bram_we    (bram_we),
        .bram_waddr (bram_waddr),
        .bram_wdata (bram_wdata),

        .wr_ptr     (wr_ptr)
    );

    // -------------------------------
    // start pointer latch (dump start)
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_start_ptr <= {ADDR_W{1'b0}};
        end else if (start_dump) begin
            // wr_ptr = next write position = oldest sample
            r_start_ptr <= wr_ptr;
        end
    end

    // -------------------------------
    // rd_ctrl
    // -------------------------------
    rd_ctrl #(
        .DEPTH (DEPTH),
        .WIDTH (WIDTH)
    ) u_rd_ctrl (
        .clk        (clk),
        .reset      (reset),

        .en         (rd_en),

        .start_dump (start_dump),
        .dump_len   (dump_len),
        .start_ptr  (r_start_ptr),

        .bram_re    (bram_re),
        .bram_raddr (bram_raddr),
        .bram_rdata (bram_rdata),

        .out_packed (out_packed),
        .out_valid  (out_valid),
        .out_ready  (out_ready),

        .dump_done  (dump_done)
    );

    // -------------------------------
    // XPM_MEMORY_SDPRAM (direct)
    // -------------------------------
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(ADDR_W),
        .ADDR_WIDTH_B(ADDR_W),
        .AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(BYTE_WRITE_W),
        .CASCADE_HEIGHT(0),
        .CLOCKING_MODE("common_clock"),
        .ECC_MODE("no_ecc"),
        .MEMORY_INIT_FILE("none"),
        .MEMORY_INIT_PARAM("0"),
        .MEMORY_OPTIMIZATION("true"),
        .MEMORY_PRIMITIVE("auto"),   // or "block"
        .MEMORY_SIZE(MEMORY_SIZE_BITS),
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_B(WIDTH),
        .READ_LATENCY_B(1),        // 1-cycle latency
        .READ_RESET_VALUE_B("0"),
        .RST_MODE_A("SYNC"),
        .RST_MODE_B("SYNC"),
        .SIM_ASSERT_CHK(0),
        .USE_EMBEDDED_CONSTRAINT(0),
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(WIDTH),
        .WRITE_MODE_B("read_first")
    ) u_bram (
        .clka(clk),
        .clkb(clk),
        .ena(bram_we),
        .wea(wea),
        .addra(bram_waddr),
        .dina(bram_wdata),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .enb(bram_re),
        .addrb(bram_raddr),
        .doutb(bram_rdata),
        .regceb(1'b1),
        .rsta(1'b0),
        .rstb(1'b0),
        .sleep(1'b0),
        .sbiterrb(),
        .dbiterrb()
    );

endmodule
