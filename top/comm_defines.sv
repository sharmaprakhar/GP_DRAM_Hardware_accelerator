

`define PIXEL_WIDTH			32
`define C_M00_AXIS_A_START_COUNT        32
`define C_M00_AXIS_A_TDATA_WIDTH        32
`define C_S00_AXIS_A_TDATA_WIDTH        32
// synthesis translate_off
`define THIS_IS_A_SIMULATION_ONLY	1
// synthesis translate_on 


//////////////////////////////////////////////////////
// 
// definitions 
//
//////////////////////////////////////////////////////

`define FSM_IDLE 				   4'd0 
`define FSM_RECEIEVE_BLOCK_BRAM1   4'd1
`define FSM_COMPUTE_BLOCK          4'd2
`define FSM_SEND_BLOCK_BRAM2	   4'd3
`define FSM_END_OPERATION		   4'd4

`define AXI_FSM_IDLE			5'd0 

`define AXI_FSM_SEND_READ_REQUEST1	5'd1
`define AXI_FSM_WAIT_FOR_READ_ACK1	5'd2
`define AXI_FSM_WAIT_FOR_READ_CMPLT1	5'd3
`define AXI_FSM_DATA_TRANSFER 5'd4
`define AXI_FSM_SEND_WRITE_REQUEST1	5'd5
`define AXI_FSM_WAIT_FOR_WRITE_ACK1	5'd6
`define AXI_FSM_WAIT_FOR_WRITE_CMPLT1	5'd7



`define IMAGE_BLOCK_SIZE    160 
`define Num_of_Beats		160
`define NumofpixelsperBlock 25600 
`define IMAGE_NO_BYTES_PER_PIXEL	4



