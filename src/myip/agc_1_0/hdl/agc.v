
`timescale 1 ns / 1 ps

	module agc #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        // AXI-Stream Slave
        input  wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axis_tdata,
        input  wire s00_axis_tvalid,
        output wire s00_axis_tready,
        input  wire [2:0] s00_axis_tid,
        // AXI-Stream Master
        output wire [C_S00_AXI_DATA_WIDTH-1:0] m00_axis_tdata,
        output wire m00_axis_tvalid,
        input  wire m00_axis_tready,
        output wire [2:0] m00_axis_tid,
        // dToFセンサーIF
        input  wire rx,
        output wire tx,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);

	wire [C_S00_AXI_DATA_WIDTH-1 : 0] control_reg;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] dist_sensitivity_reg;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] manual_gain_reg;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_min_reg;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_max_reg;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] alpha_config_reg;
	wire [15 : 0] dist_raw_mm_reg;
	wire [15 : 0] dist_clamp_mm_reg;
	wire [15 : 0] gain_target_reg;
	wire [15 : 0] gain_smooth_reg;
	wire          tof_working;
	wire          clipping_flg;
	wire          uart_packet_err;
	wire          uart_framing_err;

// Instantiation of Axi Bus Interface S00_AXI
	agc_slave_lite_v1_0_S00_AXI # (
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) agc_slave_lite_v1_0_S00_AXI_inst (
        .CONTROL_REG(control_reg),
		.DIST_SENSITIVITY_REG(dist_sensitivity_reg),
		.MANUAL_GAIN(manual_gain_reg),
        .GAIN_MIN_REG(gain_min_reg),
        .GAIN_MAX_REG(gain_max_reg),
        .ALPHA_CONFIG_REG(alpha_config_reg),
		.TOF_WORKING(tof_working),
		.CLIPPING_FLG(clipping_flg),
		.UART_PACKET_ERR(uart_packet_err),
		.UART_FRAMING_ERR(uart_framing_err),
        .DIST_RAW_MM(dist_raw_mm_reg),
        .DIST_CLAMP_MM(dist_clamp_mm_reg),
        .GAIN_TARGET(gain_target_reg),
        .GAIN_SMOOTH(gain_smooth_reg),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
    core #(
        .C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH)
    ) U_core (
        .clk(s00_axi_aclk),
        .reset(~s00_axi_aresetn),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tvalid(s00_axis_tvalid),
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tid(s00_axis_tid),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tready(m00_axis_tready),
        .m00_axis_tid(m00_axis_tid),
        .rx(rx),                                       // in
        .tx(tx),                                       // out
        .control_reg(control_reg),                     // in
        .dist_sensitivity_reg(dist_sensitivity_reg),   // in
		.manual_gain_reg(manual_gain_reg),             // in
        .gain_min_reg(gain_min_reg),                   // in
        .gain_max_reg(gain_max_reg),                   // in
        .alpha_config_reg(alpha_config_reg),           // in
        .dist_raw_mm_reg(dist_raw_mm_reg),             // out
        .dist_clamp_mm_reg(dist_clamp_mm_reg),         // out
        .gain_target_reg(gain_target_reg),             // out
        .gain_smooth_reg(gain_smooth_reg),             // out
        .tof_working(tof_working),                     // out
        .clipping_flg(clipping_flg),                   // out
        .uart_packet_err(uart_packet_err),             // out
        .uart_framing_err(uart_framing_err)            // out
	);
	// User logic ends

	endmodule
