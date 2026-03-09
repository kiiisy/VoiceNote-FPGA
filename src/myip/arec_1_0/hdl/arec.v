
`timescale 1 ns / 1 ps

	module arec #
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
		input  wire                            s00_axis_tvalid,
		output wire                            s00_axis_tready,
		input  wire [2:0]                      s00_axis_tid,
		// AXI-Stream Master
		output wire [C_S00_AXI_DATA_WIDTH-1:0] m00_axis_tdata,
		output wire                            m00_axis_tvalid,
		input  wire                            m00_axis_tready,
		output wire [2:0]                      m00_axis_tid,
		output wire                            irq,

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

	wire [C_S00_AXI_DATA_WIDTH-1:0] w_control_reg;
	wire [C_S00_AXI_DATA_WIDTH-1:0] w_threshold_reg;
	wire [C_S00_AXI_DATA_WIDTH-1:0] w_window_samples_reg;
	wire [C_S00_AXI_DATA_WIDTH-1:0] w_required_windows_reg;
	wire [C_S00_AXI_DATA_WIDTH-1:0] w_pretrig_samples_reg;
	wire                            w_irq_clear;
	wire [15:0]                     w_status_reg;
	wire [2:0]                      w_state_reg;
	wire                            w_irq;
// Instantiation of Axi Bus Interface S00_AXI
	arec_slave_lite_v1_0_S00_AXI # (
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) arec_slave_lite_v1_0_S00_AXI_inst (
		.CONTROL_REG(w_control_reg),
		.THRESHOLD_REG(w_threshold_reg),
		.WINDOW_SAMPLES_REG(w_window_samples_reg),
		.REQUIRED_WINDOWS_REG(w_required_windows_reg),
		.PRETRIG_SAMPLES_REG(w_pretrig_samples_reg),
		.IRQ_CLEAR(w_irq_clear),
		.STATUS_REG(w_status_reg),
		.STATE_REG(w_state_reg),
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
	arec_core #(
		.C_S00_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH)
	) U_core (
		.clk                (s00_axi_aclk),
		.reset              (~s00_axi_aresetn),
		.s00_axis_tdata     (s00_axis_tdata),
		.s00_axis_tvalid    (s00_axis_tvalid),
		.s00_axis_tready    (s00_axis_tready),
		.s00_axis_tid       (s00_axis_tid),
		.m00_axis_tdata     (m00_axis_tdata),
		.m00_axis_tvalid    (m00_axis_tvalid),
		.m00_axis_tready    (m00_axis_tready),
		.m00_axis_tid       (m00_axis_tid),
		.control_reg        (w_control_reg),
		.threshold_reg      (w_threshold_reg),
		.window_samples_reg (w_window_samples_reg),
		.required_windows_reg(w_required_windows_reg),
		.pretrig_samples_reg(w_pretrig_samples_reg),
		.irq_clear          (w_irq_clear),
		.status_reg         (w_status_reg),
		.state_reg          (w_state_reg),
		.irq                (w_irq)
	);

	assign irq = w_irq;

	// User logic ends

	endmodule
