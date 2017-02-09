`timescale 1ns/1ps 

`include "comm_defines.sv" 

module  Bramcontroller_top #
(
PIXEL_WIDTH=32
)
(
input 	wire  					s_axi_aclk,
input 	wire  					s_axi_aresetn,
input 	wire [31:0] 				s_axi_awaddr,
input 	wire [2:0] 				s_axi_awprot,
input 	wire  					s_axi_awvalid,
output 	wire  					s_axi_awready,
input 	wire [31:0] 				s_axi_wdata,
input 	wire [3:0] 				s_axi_wstrb,
input 	wire  					s_axi_wvalid,
output 	wire  					s_axi_wready,
output 	wire [1:0] 				s_axi_bresp,
output 	wire  					s_axi_bvalid,
input 	wire  					s_axi_bready,
input 	wire [31:0] 				s_axi_araddr,
input 	wire [2:0] 				s_axi_arprot,
input 	wire  					s_axi_arvalid,
output 	wire  					s_axi_arready,
output 	wire [31:0] 				s_axi_rdata,
output 	wire [1:0] 				s_axi_rresp,
output 	wire  					s_axi_rvalid,
input 	wire  					s_axi_rready,

input 	wire    				m_axi_aclk,
input 	wire    				m_axi_aresetn,
input 	wire    				m_axi_arready,
output 	wire   					m_axi_arvalid,
output 	wire [31:0]    				m_axi_araddr,
output 	wire [7:0]     				m_axi_arlen,
output 	wire [2:0]     				m_axi_arsize,
output 	wire [1:0]     				m_axi_arburst,
output 	wire [2:0]				m_axi_arprot,
output 	wire [3:0]				m_axi_arcache,
output 	wire 					m_axi_rready,
input 	wire 					m_axi_rvalid,
input 	wire [(PIXEL_WIDTH-1):0]		m_axi_rdata,
input 	wire [1:0]				m_axi_rresp,
input 	wire 					m_axi_rlast,
input 						m_axi_awready,
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

// Ports of Axi Master Bus Interface M00_AXIS_A
input   wire  					m00_axis_a_aclk,
input   wire  					m00_axis_a_aresetn,
output  wire  					m00_axis_a_tvalid,
//output  wire [C_M00_AXIS_A_TDATA_WIDTH-1 : 0]   m00_axis_a_tdata,
output  wire [31 : 0]           m00_axis_a_tdata,
//output  wire [(C_M00_AXIS_A_TDATA_WIDTH/8)-1 : 0] m00_axis_a_tstrb,
output  wire [3 : 0] m00_axis_a_tstrb,
output  wire  					m00_axis_a_tlast,
input   wire  					m00_axis_a_tready,

// Ports of Axi Slave Bus Interface S00_AXIS_A
input   wire  					s00_axis_a_aclk,
input   wire  					s00_axis_a_aresetn,
output  wire  					s00_axis_a_tready,
//input   wire [C_S00_AXIS_A_TDATA_WIDTH-1 : 0] 	s00_axis_a_tdata,
input   wire [31 : 0] 	s00_axis_a_tdata,
//input   wire [(C_S00_AXIS_A_TDATA_WIDTH/8)-1 : 0] s00_axis_a_tstrb,
input   wire [3 : 0] s00_axis_a_tstrb,
input 	wire  					s00_axis_a_tlast,
input 	wire  				    s00_axis_a_tvalid,


output 	wire 					InterruptToCPU
//input 	wire 					ILAClk
);

//////////////////////////////////////////////////////////
//
// signals 
//
//////////////////////////////////////////////////////////

wire 						ip2bus_mstrd_req;
wire 						ip2bus_mstwr_req;
wire 	[31:0]					ip2bus_mst_addr;
wire 	[19:0] 					ip2bus_mst_length;
wire 	[((PIXEL_WIDTH)/8-1):0] 		ip2bus_mst_be;
wire 						ip2bus_mst_type;
wire 						ip2bus_mst_lock;
wire 						ip2bus_mst_reset;
wire 						bus2ip_mst_cmdack;
wire 						bus2ip_mst_cmplt;
wire 						bus2ip_mst_error;
wire 						bus2ip_mst_rearbitrate;
wire 						bus2ip_mst_cmd_timeout;
wire 	[(PIXEL_WIDTH-1):0]			bus2ip_mstrd_d;
wire 	[7:0]					bus2ip_mstrd_rem;
wire 						bus2ip_mstrd_sof_n;
wire 						bus2ip_mstrd_eof_n;
wire 						bus2ip_mstrd_src_rdy_n;
wire 						bus2ip_mstrd_src_dsc_n;
wire 						ip2bus_mstrd_dst_rdy_n;
wire 						ip2bus_mstrd_dst_dsc_n;
wire 	[(PIXEL_WIDTH-1):0]			ip2bus_mstwr_d;
wire 	[7:0]					ip2bus_mstwr_rem;
wire 						ip2bus_mstwr_sof_n;
wire 						ip2bus_mstwr_eof_n;
wire 						ip2bus_mstwr_src_rdy_n;
wire 						ip2bus_mstwr_src_dsc_n;
wire 						bus2ip_mstwr_dst_rdy_n;
wire 						bus2ip_mstwr_dst_dsc_n;
wire                                    	axis_slave_valid;
wire                                    	axis_master_ready;
wire                                     	axis_slave_ready;
wire                                     	axis_master_valid; 
wire    [31:0]                          	axis_master_data_out;
wire 	[31:0]					InputImageAddress; 
wire 	[31:0] 					OutputImageAddress; 
wire 						BeginOperation;
wire 						ComputationDone; 
wire 	[7:0]					Num_of_Beats; 
wire 	[3:0]					NumberOfBlocks; 
wire 	[31:0]					StartPixel; 
wire 	[31:0]					NumberOfPixelsPerLine; 
wire    [31:0]                  axis_slave_data_in;

// Remove it later, just for testing
//wire master_to_slave_data;
//

//////////////////////////////////////////////////////////
//
// axi slave plug 
//
//////////////////////////////////////////////////////////
// if it is only a simulation, use my sim model for the my_axi_slave module. (functional simulation)

`ifdef THIS_IS_A_SIMULATION_ONLY

sim_AXISlavePlugModel sim_AXISlavePlugModel_Ins (
.Clk 						( m_axi_aclk ), 
.ResetL 					( m_axi_aresetn ), 

.InputImageAddress 				( InputImageAddress ),
.OutputImageAddress 				( OutputImageAddress ),
.InterruptToCPU 				( InterruptToCPU ),
.BeginOperation 				( BeginOperation ),
.ComputationDone 				( ComputationDone ),
.Num_of_Beats					( Num_of_Beats ), 
.NumberOfBlocks					( NumberOfBlocks ),
.StartPixel					( StartPixel ),			// in pixels 
.NumberOfPixelsPerLine				( NumberOfPixelsPerLine )
); 


`else 					// if it is the main synthesizable design

comm_SlavePlug_v1_0 #
(
.C_S_AXI_DATA_WIDTH 		(32),
.C_S_AXI_ADDR_WIDTH 		(7)
)
my_axi_slave_plug_v1_0_Ins   
(
.InputImageAddress 		( InputImageAddress ),
.OutputImageAddress 		( OutputImageAddress ),
.InterruptToCPU 		( InterruptToCPU ),
.BeginOperation 		( BeginOperation ),
.ComputationDone 		( ComputationDone ),
.Num_of_Beats			( Num_of_Beats ), 
.NumberOfBlocks			( NumberOfBlocks ),
.StartPixel			( StartPixel ),			// in pixels 
.NumberOfPixelsPerLine		( NumberOfPixelsPerLine ), 

// Ports of Axi Slave Bus Interface S_AXI
.s_axi_aclk				(m_axi_aclk),
.s_axi_aresetn			(m_axi_aresetn),
.s_axi_awaddr			(s_axi_awaddr),
.s_axi_awprot			(s_axi_awprot),
.s_axi_awvalid			(s_axi_awvalid),
.s_axi_awready			(s_axi_awready),
.s_axi_wdata			(s_axi_wdata),
.s_axi_wstrb			(s_axi_wstrb),
.s_axi_wvalid			(s_axi_wvalid),
.s_axi_wready			(s_axi_wready),
.s_axi_bresp			(s_axi_bresp),
.s_axi_bvalid			(s_axi_bvalid),
.s_axi_bready			(s_axi_bready),
.s_axi_araddr			(s_axi_araddr),
.s_axi_arprot			(s_axi_arprot),
.s_axi_arvalid			(s_axi_arvalid),
.s_axi_arready			(s_axi_arready),
.s_axi_rdata			(s_axi_rdata),
.s_axi_rresp			(s_axi_rresp),
.s_axi_rvalid			(s_axi_rvalid),
.s_axi_rready			(s_axi_rready)
);


`endif 

//////////////////////////////////////////////////////////
//
// axi master plug 
//
//////////////////////////////////////////////////////////
// if this is a simulation use my model for the axi master plug, otherwise if it is synthesis time use the main rtl. 

`ifdef THIS_IS_A_SIMULATION_ONLY

sim_AXIMasterPlugModel sim_AXIMasterPlugModel_Ins (
.Clk				( m_axi_aclk ), 
.ResetL 			( m_axi_aresetn ),

.ip2bus_mstrd_req          	( ip2bus_mstrd_req       ),  
.ip2bus_mstwr_req          	( ip2bus_mstwr_req       ),  
.ip2bus_mst_addr           	( ip2bus_mst_addr        ),  
.ip2bus_mst_length         	( ip2bus_mst_length      ),  
.ip2bus_mst_be             	( ip2bus_mst_be          ),  
.ip2bus_mst_type           	( ip2bus_mst_type        ),  
.ip2bus_mst_lock           	( ip2bus_mst_lock        ),  
.ip2bus_mst_reset          	( ip2bus_mst_reset       ),  
.bus2ip_mst_cmdack         	( bus2ip_mst_cmdack      ),  
.bus2ip_mst_cmplt          	( bus2ip_mst_cmplt       ),  
.bus2ip_mst_error          	( bus2ip_mst_error       ),  
.bus2ip_mst_rearbitrate    	( bus2ip_mst_rearbitrate ),  
.bus2ip_mst_cmd_timeout    	( bus2ip_mst_cmd_timeout ),  
.bus2ip_mstrd_d            	( bus2ip_mstrd_d         ),  
.bus2ip_mstrd_rem          	( bus2ip_mstrd_rem       ),  
.bus2ip_mstrd_sof_n        	( bus2ip_mstrd_sof_n     ),  
.bus2ip_mstrd_eof_n        	( bus2ip_mstrd_eof_n     ),  
.bus2ip_mstrd_src_rdy_n    	( bus2ip_mstrd_src_rdy_n ),  
.bus2ip_mstrd_src_dsc_n    	( bus2ip_mstrd_src_dsc_n ),  
.ip2bus_mstrd_dst_rdy_n    	( ip2bus_mstrd_dst_rdy_n ),  
.ip2bus_mstrd_dst_dsc_n    	( ip2bus_mstrd_dst_dsc_n ),  
.ip2bus_mstwr_d            	( ip2bus_mstwr_d         ),  
.ip2bus_mstwr_rem          	( ip2bus_mstwr_rem       ),  
.ip2bus_mstwr_sof_n        	( ip2bus_mstwr_sof_n     ),  
.ip2bus_mstwr_eof_n        	( ip2bus_mstwr_eof_n     ),  
.ip2bus_mstwr_src_rdy_n    	( ip2bus_mstwr_src_rdy_n ),  
.ip2bus_mstwr_src_dsc_n    	( ip2bus_mstwr_src_dsc_n ),  
.bus2ip_mstwr_dst_rdy_n    	( bus2ip_mstwr_dst_rdy_n ),  
.bus2ip_mstwr_dst_dsc_n    	( bus2ip_mstwr_dst_dsc_n )  
); 


`else 

axi_master_burst #( 
.C_M_AXI_ADDR_WIDTH 		( 32 ),
.C_M_AXI_DATA_WIDTH 		( 32 ),
.C_MAX_BURST_LEN			( 256 ),
.C_ADDR_PIPE_DEPTH			( 1 ),
.C_NATIVE_DATA_WIDTH		( 32 ),
.C_LENGTH_WIDTH				( 20 ),
.C_FAMILY					( "virtex7" ) 
)
axi_master_burst_Ins (
.m_axi_aclk              	( m_axi_aclk    ),  
.m_axi_aresetn          	( m_axi_aresetn ),  
.md_error                	( md_error      ),  
.m_axi_arready           	( m_axi_arready ),  
.m_axi_arvalid             	( m_axi_arvalid ),  
.m_axi_araddr              	( m_axi_araddr  ),  
.m_axi_arlen               	( m_axi_arlen   ),
.m_axi_arsize              	( m_axi_arsize  ),  
.m_axi_arburst             	( m_axi_arburst ),  
.m_axi_arprot              	( m_axi_arprot  ),  
.m_axi_arcache             	( m_axi_arcache ),  
.m_axi_rready              	( m_axi_rready  ),  
.m_axi_rvalid              	( m_axi_rvalid  ),  
.m_axi_rdata               	( m_axi_rdata   ),  
.m_axi_rresp               	( m_axi_rresp   ),  
.m_axi_rlast               	( m_axi_rlast   ),  
.m_axi_awready             	( m_axi_awready ),  
.m_axi_awvalid             	( m_axi_awvalid ),  
.m_axi_awaddr              	( m_axi_awaddr  ),  
.m_axi_awlen               	( m_axi_awlen   ),  
.m_axi_awsize              	( m_axi_awsize  ),  
.m_axi_awburst            	( m_axi_awburst ),  
.m_axi_awprot             	( m_axi_awprot  ),  
.m_axi_awcache            	( m_axi_awcache ),  
.m_axi_wready             	( m_axi_wready  ),  
.m_axi_wvalid             	( m_axi_wvalid  ),  
.m_axi_wdata              	( m_axi_wdata   ),  
.m_axi_wstrb              	( m_axi_wstrb   ),  
.m_axi_wlast              	( m_axi_wlast   ),  
.m_axi_bready             	( m_axi_bready  ),  
.m_axi_bvalid             	( m_axi_bvalid  ),  
.m_axi_bresp              	( m_axi_bresp   ),  

.ip2bus_mstrd_req          	( ip2bus_mstrd_req       ),  
.ip2bus_mstwr_req          	( ip2bus_mstwr_req       ),  
.ip2bus_mst_addr          	( ip2bus_mst_addr        ),  
.ip2bus_mst_length         	( ip2bus_mst_length      ),  
.ip2bus_mst_be             	( ip2bus_mst_be          ),  
.ip2bus_mst_type           	( ip2bus_mst_type        ),  
.ip2bus_mst_lock           	( ip2bus_mst_lock        ),  
.ip2bus_mst_reset          	( ip2bus_mst_reset       ),  
.bus2ip_mst_cmdack         	( bus2ip_mst_cmdack      ),  
.bus2ip_mst_cmplt          	( bus2ip_mst_cmplt       ),  
.bus2ip_mst_error          	( bus2ip_mst_error       ),  
.bus2ip_mst_rearbitrate    	( bus2ip_mst_rearbitrate ),  
.bus2ip_mst_cmd_timeout    	( bus2ip_mst_cmd_timeout ),  
.bus2ip_mstrd_d            	( bus2ip_mstrd_d         ),  
.bus2ip_mstrd_rem          	( bus2ip_mstrd_rem       ),  
.bus2ip_mstrd_sof_n        	( bus2ip_mstrd_sof_n     ),  
.bus2ip_mstrd_eof_n        	( bus2ip_mstrd_eof_n     ),  
.bus2ip_mstrd_src_rdy_n    	( bus2ip_mstrd_src_rdy_n ),  
.bus2ip_mstrd_src_dsc_n    	( bus2ip_mstrd_src_dsc_n ),  
.ip2bus_mstrd_dst_rdy_n    	( ip2bus_mstrd_dst_rdy_n ),  
.ip2bus_mstrd_dst_dsc_n    	( ip2bus_mstrd_dst_dsc_n ),  
.ip2bus_mstwr_d            	( ip2bus_mstwr_d         ),  
.ip2bus_mstwr_rem         	( ip2bus_mstwr_rem       ),  
.ip2bus_mstwr_sof_n        	( ip2bus_mstwr_sof_n     ),  
.ip2bus_mstwr_eof_n        	( ip2bus_mstwr_eof_n     ),  
.ip2bus_mstwr_src_rdy_n    	( ip2bus_mstwr_src_rdy_n ),  
.ip2bus_mstwr_src_dsc_n    	( ip2bus_mstwr_src_dsc_n ),  
.bus2ip_mstwr_dst_rdy_n    	( bus2ip_mstwr_dst_rdy_n ),  
.bus2ip_mstwr_dst_dsc_n    	( bus2ip_mstwr_dst_dsc_n )  
);


`endif 


// Instantiation of Axi Bus Interface M00_AXIS_A
	axi_stream_sample_v1_0_M00_AXIS_A # ( 
		.C_M_AXIS_TDATA_WIDTH(32),
		.C_M_START_COUNT(32)
	) axi_stream_sample_v1_0_M00_AXIS_A_inst (
		.M_AXIS_ACLK(m00_axis_a_aclk),
		.M_AXIS_ARESETN(m00_axis_a_aresetn),
		.M_AXIS_TVALID(m00_axis_a_tvalid),
		.M_AXIS_TDATA(m00_axis_a_tdata),
		.M_AXIS_TSTRB(m00_axis_a_tstrb),
		.M_AXIS_TLAST(m00_axis_a_tlast),
		.M_AXIS_TREADY(m00_axis_a_tready),
		.AXIS_MASTER_VALID(axis_master_valid),
		.AXIS_MASTER_READY(axis_master_ready),
		.AXIS_MASTER_DATA_IN(axis_master_data_out)
	);

// Instantiation of Axi Bus Interface S00_AXIS_A
	axi_stream_sample_v1_0_S00_AXIS_A # ( 
		.C_S_AXIS_TDATA_WIDTH(32)
	) axi_stream_sample_v1_0_S00_AXIS_A_inst (
		.S_AXIS_ACLK(s00_axis_a_aclk),
		.S_AXIS_ARESETN(s00_axis_a_aresetn),
		.S_AXIS_TREADY(s00_axis_a_tready),
		.S_AXIS_TDATA(s00_axis_a_tdata),
		.S_AXIS_TSTRB(s00_axis_a_tstrb),
		.S_AXIS_TLAST(s00_axis_a_tlast),
		.S_AXIS_TVALID(s00_axis_a_tvalid),
		.AXIS_SLAVE_VAILD(axis_slave_valid),
		.AXIS_SLAVE_READY(axis_slave_ready),
		.AXIS_SLAVE_DATA_OUT(axis_slave_data_in)
	);

//////////////////////////////////////////////////////////
//
// Main Controller
//
//////////////////////////////////////////////////////////

bram_controller #
(
.PIXEL_WIDTH(PIXEL_WIDTH)
)
bram_controller_Ins 
(
.Clk				( m_axi_aclk ),
//.ILAClk				( ILAClk ), 
.ResetL				( m_axi_aresetn ),

.ip2bus_mstrd_req          	( ip2bus_mstrd_req       ),  
.ip2bus_mstwr_req          	( ip2bus_mstwr_req       ),  
.ip2bus_mst_addr           	( ip2bus_mst_addr        ),  
.ip2bus_mst_length         	( ip2bus_mst_length      ),  
.ip2bus_mst_be             	( ip2bus_mst_be          ),  
.ip2bus_mst_type           	( ip2bus_mst_type        ),  
.ip2bus_mst_lock           	( ip2bus_mst_lock        ),  
.ip2bus_mst_reset          	( ip2bus_mst_reset       ),  
.bus2ip_mst_cmdack         	( bus2ip_mst_cmdack      ),  
.bus2ip_mst_cmplt          	( bus2ip_mst_cmplt       ),  
.bus2ip_mst_error          	( bus2ip_mst_error       ),  
.bus2ip_mst_rearbitrate    	( bus2ip_mst_rearbitrate ),  
.bus2ip_mst_cmd_timeout    	( bus2ip_mst_cmd_timeout ),  
.bus2ip_mstrd_d            	( bus2ip_mstrd_d         ),  
.bus2ip_mstrd_rem          	( bus2ip_mstrd_rem       ),  
.bus2ip_mstrd_sof_n        	( bus2ip_mstrd_sof_n     ),  
.bus2ip_mstrd_eof_n        	( bus2ip_mstrd_eof_n     ),  
.bus2ip_mstrd_src_rdy_n    	( bus2ip_mstrd_src_rdy_n ),  
.bus2ip_mstrd_src_dsc_n    	( bus2ip_mstrd_src_dsc_n ),  
.ip2bus_mstrd_dst_rdy_n    	( ip2bus_mstrd_dst_rdy_n ),  
.ip2bus_mstrd_dst_dsc_n    	( ip2bus_mstrd_dst_dsc_n ),  
.ip2bus_mstwr_d            	( ip2bus_mstwr_d         ),  
.ip2bus_mstwr_rem          	( ip2bus_mstwr_rem       ),  
.ip2bus_mstwr_sof_n        	( ip2bus_mstwr_sof_n     ),  
.ip2bus_mstwr_eof_n        	( ip2bus_mstwr_eof_n     ),  
.ip2bus_mstwr_src_rdy_n    	( ip2bus_mstwr_src_rdy_n ),  
.ip2bus_mstwr_src_dsc_n    	( ip2bus_mstwr_src_dsc_n ),  
.bus2ip_mstwr_dst_rdy_n    	( bus2ip_mstwr_dst_rdy_n ),  
.bus2ip_mstwr_dst_dsc_n    	( bus2ip_mstwr_dst_dsc_n ),  
.axis_slave_valid               ( axis_slave_valid ), 
.axis_slave_ready               ( axis_slave_ready ), 
.axis_slave_data_in             ( axis_slave_data_in ), 
.axis_master_valid              ( axis_master_valid ), 
.axis_master_ready              ( axis_master_ready ), 
.axis_master_data_out           ( axis_master_data_out ), 
.InputImageAddress 		( InputImageAddress ),
.OutputImageAddress 		( OutputImageAddress ),
.BeginOperation 		( BeginOperation ),
.ComputationDone 		( ComputationDone ),
.Num_of_Beats			( Num_of_Beats ), 
.NumberOfBlocks			( NumberOfBlocks ),
.StartPixel			( StartPixel ),			// in pixels 
.NumberOfPixelsPerLine		( NumberOfPixelsPerLine )
); 

endmodule 
