`include "comm_defines.sv" 

module bram_controller #
(
PIXEL_WIDTH=32
)
(
input 	wire 					Clk, 
input 	wire					ILAClk, 
input 	wire 					ResetL, 
output 	reg 					ip2bus_mstrd_req, 
output 	reg 					ip2bus_mstwr_req,
output 	reg 	[31:0]				ip2bus_mst_addr,//address
output 	wire 	[19:0] 				ip2bus_mst_length, //what length eg 256
output 	wire 	[((PIXEL_WIDTH)/8-1):0] 	ip2bus_mst_be, //which bytes read 
output 	wire 					ip2bus_mst_type, //type - only 1 chuck or large chunk (bit or burst)
output 	wire 					ip2bus_mst_lock,
output 	wire 					ip2bus_mst_reset,
input 	wire 					bus2ip_mst_cmdack,
input 	wire 					bus2ip_mst_cmplt,//complete signal
input 	wire 					bus2ip_mst_error, // user logic to IPIF 
input 	wire 					bus2ip_mst_rearbitrate,
input 	wire 					bus2ip_mst_cmd_timeout,
input 	wire 	[(PIXEL_WIDTH-1):0]		bus2ip_mstrd_d,
input 	wire 	[7:0]				bus2ip_mstrd_rem,
input 	wire 					bus2ip_mstrd_sof_n, //master read start of frame - bus to user logic - after dst_rdy
input 	wire 					bus2ip_mstrd_eof_n, //enf of frame goes down with final frame
input 	wire 					bus2ip_mstrd_src_rdy_n, // active low when IPIF is providing valid chunk of data
input 	wire 					bus2ip_mstrd_src_dsc_n,
output 	wire 					ip2bus_mstrd_dst_rdy_n, //ready to accept the read data - user logic is always the destination - active low
output 	wire 					ip2bus_mstrd_dst_dsc_n,
output 	wire 	[(PIXEL_WIDTH-1):0]		ip2bus_mstwr_d, //data to be put on the data bus 
output 	wire 	[7:0]				ip2bus_mstwr_rem,
output 	reg 					ip2bus_mstwr_sof_n, // gets activated with ip2bus_mstwr_d to indicate start
output 	reg 					ip2bus_mstwr_eof_n, //e o frame
output 	reg 					ip2bus_mstwr_src_rdy_n, // active low 
output 	wire 					ip2bus_mstwr_src_dsc_n,
input 	wire 					bus2ip_mstwr_dst_rdy_n, //IPIF brings this down when it is ready - active low
input 	wire 					bus2ip_mstwr_dst_dsc_n,
//user ports
input   wire                                    axis_slave_valid,
output  reg                                     axis_slave_ready,
input   wire    [31:0]                          axis_slave_data_in, 
);