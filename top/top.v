`timescale 1ns/1ps 
//`include "comm_defines.sv" 
module  top #
(
PIXEL_WIDTH=32
)
(
input 	wire  					s_axi_aclk,
input 	wire  					s_axi_aresetn,
input 	wire [31:0] 			s_axi_awaddr,
input 	wire [2:0] 				s_axi_awprot,
input 	wire  					s_axi_awvalid,
output 	wire  					s_axi_awready,
input 	wire [31:0] 			s_axi_wdata,
input 	wire [3:0] 				s_axi_wstrb,
input 	wire  					s_axi_wvalid,
output 	wire  					s_axi_wready,
output 	wire [1:0] 				s_axi_bresp,
output 	wire  					s_axi_bvalid,
input 	wire  					s_axi_bready,
input 	wire [31:0] 			s_axi_araddr,
input 	wire [2:0] 				s_axi_arprot,
input 	wire  					s_axi_arvalid,
output 	wire  					s_axi_arready,
output 	wire [31:0] 			s_axi_rdata,
output 	wire [1:0] 				s_axi_rresp,
output 	wire  					s_axi_rvalid,
input 	wire  					s_axi_rready,

input 	wire    				m_axi_aclk,
input 	wire    				m_axi_aresetn,
input 	wire    				m_axi_arready,
output 	wire   					m_axi_arvalid,
output 	wire [31:0]    			m_axi_araddr,
output 	wire [7:0]     			m_axi_arlen,
output 	wire [2:0]     			m_axi_arsize,
output 	wire [1:0]     			m_axi_arburst,
output 	wire [2:0]				m_axi_arprot,
output 	wire [3:0]				m_axi_arcache,
output 	wire 					m_axi_rready,
input 	wire 					m_axi_rvalid,
input 	wire [(PIXEL_WIDTH-1):0]	m_axi_rdata,
input 	wire [1:0]				m_axi_rresp,
input 	wire 					m_axi_rlast,
input 	wire					m_axi_awready,
output 	wire 					m_axi_awvalid,
output 	wire [31:0]				m_axi_awaddr,
output 	wire [7:0]				m_axi_awlen,
output 	wire [2:0]				m_axi_awsize,
output 	wire [1:0]				m_axi_awburst,
output 	wire [2:0]				m_axi_awprot,
output 	wire [3:0] 				m_axi_awcache,
input 	wire 					m_axi_wready,
output 	wire 					m_axi_wvalid,
output 	wire [(PIXEL_WIDTH-1):0]		m_axi_wdata,
output 	wire [7:0]				m_axi_wstrb,
output 	wire 					m_axi_wlast,
output 	wire 					m_axi_bready,
input 	wire 					m_axi_bvalid,
input 	wire [1:0]				m_axi_bresp,
input   wire  					s00_axis_a_aclk,
input   wire  					s00_axis_a_aresetn,
input   wire  					m00_axis_a_aclk,
input   wire  					m00_axis_a_aresetn,
output 	wire 					InterruptToCPU


);


wire m00_axis_a_tvalid;
wire m00_axis_a_tready;
wire m00_axis_a_tlast;
wire [3:0] m00_axis_a_tstrb;
wire [31:0] m00_axis_a_tdata;

wire s00_axis_a_tvalid;
wire s00_axis_a_tready;
wire s00_axis_a_tlast;
wire [3:0] s00_axis_a_tstrb;
wire [31:0] s00_axis_a_tdata;


Bramcontroller_top Bramcontroller_Ins(
.s_axi_aclk (s_axi_clk),
.s_axi_aresetn(s_axi_aresetn),
.s_axi_awaddr(s_axi_awaddr), //wa channel
.s_axi_awprot(s_axi_awprot),
.s_axi_awvalid(s_axi_awvalid),
.s_axi_awready(s_axi_awready),
.s_axi_wdata(s_axi_wdata), //wd channel
.s_axi_wstrb(s_axi_wstrb),
.s_axi_wvalid(s_axi_wvalid),
.s_axi_wready(s_axi_wready),
.s_axi_bresp(s_axi_bresp), //wresp channel
.s_axi_bvalid(s_axi_bvalid),
.s_axi_bready(s_axi_bready),
.s_axi_araddr(s_axi_araddr), //ra
.s_axi_arprot(s_axi_arprot),
.s_axi_arvalid(s_axi_arvalid),
.s_axi_arready(s_axi_arready),
.s_axi_rdata(s_axi_rdata), //r resp
.s_axi_rresp(s_axi_rresp),
.s_axi_rvalid(s_axi_rvalid),
.s_axi_rready(s_axi_rready),


.m_axi_aclk(m_axi_aclk),
.m_axi_aresetn(m_axi_aresetn),
.m_axi_arready(m_axi_arready),
.m_axi_arvalid(m_axi_arvalid),
.m_axi_araddr(m_axi_araddr),
.m_axi_arlen(m_axi_arlen),
.m_axi_arsize(m_axi_arsize),
.m_axi_arburst(m_axi_arburst),
.m_axi_arprot(m_axi_arprot),
.m_axi_arcache(m_axi_arcache),
.m_axi_rready(m_axi_rready),
.m_axi_rvalid(m_axi_rvalid),
.m_axi_rdata(m_axi_rdata),
.m_axi_rresp(m_axi_rresp),
.m_axi_rlast(m_axi_rlast),
.m_axi_awready(m_axi_awready),
.m_axi_awvalid(m_axi_awvalid),
.m_axi_awaddr(m_axi_awaddr),
.m_axi_awlen(m_axi_awlen),
.m_axi_awsize(m_axi_awsize),
.m_axi_awburst(m_axi_awburst),
.m_axi_awprot(m_axi_awprot),
.m_axi_awcache(m_axi_awcache),
.m_axi_wready(m_axi_wready),
.m_axi_wvalid(m_axi_wvalid),
.m_axi_wdata(m_axi_wdata),
.m_axi_wstrb(m_axi_wstrb),
.m_axi_wlast(m_axi_wlast),
.m_axi_bready(m_axi_bready),
.m_axi_bvalid(m_axi_bvalid),
.m_axi_bresp(m_axi_bresp),

.m00_axis_a_aclk(m00_axis_a_aclk),
.m00_axis_a_aresetn(m00_axis_a_aresetn),
.m00_axis_a_tvalid(m00_axis_a_tvalid),
.m00_axis_a_tdata(m00_axis_a_tdata),
.m00_axis_a_tstrb(m00_axis_a_tstrb),
.m00_axis_a_tlast(m00_axis_a_tlast),
.m00_axis_a_tready(m00_axis_a_tready),

// Ports of Axi Slave Bus Interface S00_AXIS_A
.s00_axis_a_aclk(s00_axis_a_aclk),
.s00_axis_a_aresetn(s00_axis_a_aresetn),
.s00_axis_a_tready(s00_axis_a_tready),
.s00_axis_a_tdata(s00_axis_a_tdata),
.s00_axis_a_tstrb(s00_axis_a_tstrb),
.s00_axis_a_tlast(s00_axis_a_tlast),
.s00_axis_a_tvalid(s00_axis_a_tvalid),
.InterruptToCPU (InterruptToCPU)
);

normalization_ip_wrapper_0 normalization_ins(
.M00_AXIS_RESULT_tdata(s00_axis_a_tdata),
.M00_AXIS_RESULT_tready(s00_axis_a_tready),
.M00_AXIS_RESULT_tvalid(s00_axis_a_tvalid),
.M00_AXIS_RESULT_tstrb(),
.M00_AXIS_RESULT_tlast(),
.S_AXIS_A_tdata(m00_axis_a_tdata),
.S_AXIS_A_tlast(m00_axis_a_tlast),
.S_AXIS_A_tready(m00_axis_a_tready),
.S_AXIS_A_tstrb(m00_axis_a_tstrb),
.S_AXIS_A_tvalid(m00_axis_a_tvalid),
.S_AXIS_B_tdata(m00_axis_a_tdata),
.S_AXIS_B_tlast(m00_axis_a_tlast),
.S_AXIS_B_tready(m00_axis_a_tready),
.S_AXIS_B_tstrb(m00_axis_a_tstrb),
.S_AXIS_B_tvalid(m00_axis_a_tvalid),
.aclk(m00_axis_a_aclk),
.aresetn(m00_axis_a_aresetn),
.s00_axis_b_tlast(1'b0),
.s00_axis_b_tstrb(4'b1111),
.s01_axis_g_tlast(1'b0),
.s01_axis_g_tstrb(4'b1111),
.s02_axis_r_tlast(1'b0),
.s02_axis_r_tstrb(4'b1111),
.s_axis_a_tlast_1(1'b0),
.s_axis_a_tstrb_1(4'b1111)
);

endmodule