
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
input   wire                                    axis_master_ready,
output  reg                                     axis_slave_ready,
output  reg                                     axis_master_valid, 
output  wire     [31:0]                          axis_master_data_out, 
input   wire    [31:0]                          axis_slave_data_in, 
input 	wire 	[31:0]				InputImageAddress,
input 	wire 	[31:0]				OutputImageAddress,
input 	wire 	[31:0]				StartPixel,
input   wire    [31:0]              NumberOfPixelsPerLine,
input 	wire 	[7:0]				Num_of_Beats,
input 	wire 					BeginOperation,
output 	reg 					ComputationDone,
input 	wire	[3:0]				NumberOfBlocks
);

localparam BE_WIDTH = (PIXEL_WIDTH)/8;

//////////////////////////////////////////////////////
// 
// main fsm - overall operation - read and write blocks wise
//
//////////////////////////////////////////////////////

reg 	        [3:0]		mainFSM_currentState; 
reg		[3:0]		mainFSM_prevState; 

reg		[31:0]		inputImageAddressR; 
reg		[31:0]		outputImageAddressR; 
reg axiMaster_blockReceived_to_BRAM1;
reg axiMaster_blockSent_to_BRAM2;

always @(posedge Clk)
       if ( ! ResetL ) begin 
	      mainFSM_currentState <= `FSM_IDLE; 
	      mainFSM_prevState <= `FSM_IDLE; 
	      
	      inputImageAddressR <= 0; 
	      outputImageAddressR <= 0; 
	      
	      ComputationDone <= 0; 
       end 
       else begin 
	      case ( mainFSM_currentState ) 
	      `FSM_IDLE: begin 
	      
		     if ( BeginOperation ) begin 
			    inputImageAddressR <= InputImageAddress;
			    outputImageAddressR <= OutputImageAddress;
			    
			    mainFSM_currentState <= `FSM_RECEIEVE_BLOCK_BRAM1;
			    mainFSM_prevState <= `FSM_IDLE;
		     end 
		     else begin 
			    inputImageAddressR <= inputImageAddressR;
			    outputImageAddressR <= outputImageAddressR; 
			    
			    mainFSM_currentState <= `FSM_IDLE;
			    mainFSM_prevState <= `FSM_IDLE; 
		     end
		     
		     ComputationDone <= 0; 
	      end 
	      `FSM_RECEIEVE_BLOCK_BRAM1: begin 
			if ( axiMaster_blockReceived_to_BRAM1 ) begin  
				mainFSM_currentState <= `FSM_COMPUTE_BLOCK;
				mainFSM_prevState <= `FSM_RECEIEVE_BLOCK_BRAM1;
			end 
			else begin 
				mainFSM_currentState <= `FSM_RECEIEVE_BLOCK_BRAM1;
				mainFSM_prevState <= `FSM_RECEIEVE_BLOCK_BRAM1;
			end 
	      end 
              `FSM_COMPUTE_BLOCK: begin
                        if ( ComputeDone ) begin
                                mainFSM_currentState <= `FSM_SEND_BLOCK_BRAM2;
                                mainFSM_prevState    <= `FSM_COMPUTE_BLOCK;
                                
                        end
                        else begin
                                mainFSM_currentState <= `FSM_COMPUTE_BLOCK;
                                mainFSM_prevState    <= `FSM_COMPUTE_BLOCK;
                        end

              end
	      `FSM_SEND_BLOCK_BRAM2: begin
	        //ComputeDone <= 1'b0;
 			if ( axiMaster_blockSent_to_BRAM2 ) begin
				if ( ( sendBlockCounter == (NumberOfBlocks-1) )  ) begin 
					mainFSM_currentState <= `FSM_END_OPERATION;
					mainFSM_prevState    <= `FSM_SEND_BLOCK_BRAM2; 
				end 
				else begin 
					mainFSM_currentState <= `FSM_RECEIEVE_BLOCK_BRAM1;
					mainFSM_prevState    <= `FSM_SEND_BLOCK_BRAM2;
				end 
			end 
			else begin
				mainFSM_currentState <= `FSM_SEND_BLOCK_BRAM2;
				mainFSM_prevState    <= `FSM_SEND_BLOCK_BRAM2;
			end 
	      end
	      `FSM_END_OPERATION: begin 
			ComputationDone <= 1; 
			
			mainFSM_currentState <= `FSM_IDLE; 
			mainFSM_prevState    <= `FSM_END_OPERATION; 
	      end 
	      default: begin 
			mainFSM_currentState <= `FSM_IDLE; 
			mainFSM_prevState <= mainFSM_prevState; 
	      end 
	      endcase 
       end 
       
//////////////////////////////////////////////////////
// 
// received and sent block counters - image is divided into blocks, this module says which block we are operating on
//
//////////////////////////////////////////////////////
// 

reg	[3:0]	receiveBlockCounter; //counters for receiving image, counters for writing image back
reg	[3:0]	sendBlockCounter; 

always @(posedge Clk)
	if ( ! ResetL ) begin 
		receiveBlockCounter <= 0; 
		sendBlockCounter    <= 0;
	end
	else begin
		if ( mainFSM_currentState == `FSM_IDLE ) begin 
			receiveBlockCounter <= 0; 
			sendBlockCounter    <= 0;
		end 
                else if ( (mainFSM_currentState == `FSM_SEND_BLOCK_BRAM2) && (mainFSM_prevState == `FSM_COMPUTE_BLOCK) ) begin //write logic to handle what happens when sending is to start and receiving has ended
                        if ( receiveBlockCounter == (NumberOfBlocks-1) ) begin
                                //receiveBlockCounter <= 0;
                                receiveBlockCounter <= receiveBlockCounter;
                        end
                        else
                        begin
                                receiveBlockCounter <= receiveBlockCounter + 1;
                        end 
                        sendBlockCounter <= sendBlockCounter;                              
		end // end logic 
		else if ( ( mainFSM_currentState == `FSM_RECEIEVE_BLOCK_BRAM1) && (mainFSM_prevState == `FSM_SEND_BLOCK_BRAM2) ) begin //write logic to handle what happens when receiving is to start and sending has ended
			receiveBlockCounter <= receiveBlockCounter; 
			
			if ( sendBlockCounter == (NumberOfBlocks-1) ) begin 
				//sendBlockCounter <= 0; 
				sendBlockCounter <= sendBlockCounter;
                        end  
			else begin 
				sendBlockCounter <= sendBlockCounter + 1; 
			end
  
		end //end logic
		else begin 
			receiveBlockCounter <= receiveBlockCounter;
			sendBlockCounter    <= sendBlockCounter; 
		end 
	end 

//////////////////////////////////////////////////////
// 
// axi master - constant signals (fixed value)
//
//////////////////////////////////////////////////////

assign ip2bus_mst_length = `IMAGE_BLOCK_SIZE * `IMAGE_NO_BYTES_PER_PIXEL;		// every read or write transaction has a length of 120 pixels --> 120 * 2 = 240 bytes. 
//assign ip2bus_mst_length = `IMAGE_BLOCK_SIZE;		// every read or write transaction has a length of 120 pixels --> 120 * 2 = 240 bytes. 
assign ip2bus_mst_type = 1; 		// we always transfer in bursts. 
assign ip2bus_mst_lock = 0; 
assign ip2bus_mstrd_dst_dsc_n = 1; 	// we do never discountinue a transfer (master read destination ready) 
assign ip2bus_mstrd_dst_rdy_n = 0; 	// we are always ready to receive the data
assign ip2bus_mst_be = {BE_WIDTH{1'b1}};			//8'hff; 		// all of the transferred data is always meaningful
assign ip2bus_mstwr_rem = 0; 
assign ip2bus_mst_reset = 0; 
assign ip2bus_mstwr_src_dsc_n = 1;
 
//////////////////////////////////////////////////////
// 
// axi address calculation 
//
//////////////////////////////////////////////////////
wire 	[31:0]	axi_readAddress_offset;
wire 	[31:0]	axi_writeAddress_offset;
assign axi_readAddress_offset                       =     receiveBlockCounter*(`NumofpixelsperBlock) + axiFSM_readRequestCounter*(`Num_of_Beats) + StartPixel;
assign axi_writeAddress_offset                      =     sendBlockCounter*(`NumofpixelsperBlock) + axiFSM_writeRequestCounter*(`Num_of_Beats) + StartPixel;

//////////////////////////////////////////////////////
// 
// axi master fsm
//
//////////////////////////////////////////////////////
// logic to talk to the axi master ipif

//reg 			axiMaster_blockReceived_to_BRAM1;
//reg 			axiMaster_blockSent_to_BRAM2; 
reg 			ComputeDone; 
reg	[3:0]		axiFSM_currentState; 
reg	[3:0]		axiFSM_prevState; 
reg	[7:0]		axiFSM_readRequestCounter; 
reg 	[7:0]		axiFSM_writeRequestCounter; 
reg 	[14:0]		axistream_data_send_count; 
reg 	[14:0]		axistream_data_receive_count; 

always @(posedge Clk) 
	if ( ! ResetL ) begin
		axiFSM_currentState <= `AXI_FSM_IDLE; 
		axiFSM_prevState <= `AXI_FSM_IDLE;
		axiMaster_blockReceived_to_BRAM1 <= 0; 
		axiMaster_blockSent_to_BRAM2 <= 0; 
		ip2bus_mstrd_req <= 0; 
		ip2bus_mstwr_req <= 0; 
		ip2bus_mst_addr  <= 0;
		axis_master_valid <= 0;
		axis_slave_ready  <= 0;
		axiFSM_readRequestCounter <= 0; 
		axiFSM_writeRequestCounter <= 0;
        axistream_data_send_count  <= 0; 
        axistream_data_receive_count  <= 0;
        ComputeDone <= 1'b0; 
	end 
	else begin 
		case ( axiFSM_currentState )
		`AXI_FSM_IDLE : begin 
			if ( (mainFSM_currentState == `FSM_RECEIEVE_BLOCK_BRAM1) && (mainFSM_prevState == `FSM_IDLE) ) begin 
				axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				
				axiFSM_readRequestCounter <= 0; 
			end 
			else if ( (mainFSM_currentState == `FSM_RECEIEVE_BLOCK_BRAM1) && (mainFSM_prevState == `FSM_SEND_BLOCK_BRAM2) ) begin 
				axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				
				axiFSM_readRequestCounter <= 0; 
			end 
			else if ( (mainFSM_currentState == `FSM_SEND_BLOCK_BRAM2) && (mainFSM_prevState == `FSM_COMPUTE_BLOCK) ) begin 
				axiFSM_currentState <= `AXI_FSM_SEND_WRITE_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				
				axiFSM_writeRequestCounter <= 0; 
			end
            else if ( (mainFSM_currentState == `FSM_COMPUTE_BLOCK) && (mainFSM_prevState == `FSM_RECEIEVE_BLOCK_BRAM1) ) begin 
				axiFSM_currentState <= `AXI_FSM_DATA_TRANSFER; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				
				axistream_data_send_count <= 0; 
				axistream_data_receive_count <= 0; 
			end 
			else begin 

				axiFSM_currentState <= `AXI_FSM_IDLE; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
			end 
			
			axiMaster_blockReceived_to_BRAM1 <= 0; 
			axiMaster_blockSent_to_BRAM2 <= 0; 
		end 
		/////////////////////////////////
		// 
		// read req. 
		//
		/////////////////////////////////
		`AXI_FSM_SEND_READ_REQUEST1: begin 
			ip2bus_mstrd_req <= 1; 
			ip2bus_mst_addr <= inputImageAddressR + axi_readAddress_offset*4;
			
			axiFSM_currentState <= `AXI_FSM_WAIT_FOR_READ_ACK1; 
			axiFSM_prevState <= `AXI_FSM_SEND_READ_REQUEST1; 
			
		end 
		`AXI_FSM_WAIT_FOR_READ_ACK1: begin 
			if ( bus2ip_mst_cmdack ) begin 
				ip2bus_mstrd_req <= 0; 
				
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1;
				axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_ACK1;
			end 
			else begin 
				ip2bus_mstrd_req <= ip2bus_mstrd_req; 
				
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_READ_ACK1;
				axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_ACK1;
			end 
		end 
		`AXI_FSM_WAIT_FOR_READ_CMPLT1: begin 
			if ( bus2ip_mst_cmplt ) begin 
			
				if ( axiFSM_readRequestCounter == (`Num_of_Beats - 1) ) begin 
					axiFSM_currentState <= `AXI_FSM_IDLE; 
					axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
					axiMaster_blockReceived_to_BRAM1 <= 1'b1;
				end 
				else begin 	
					axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
					axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
					
					axiMaster_blockReceived_to_BRAM1 <= 0; 
					axiFSM_readRequestCounter <= axiFSM_readRequestCounter + 1; 
				end 
			end 
			else begin 
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
				axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
			end 
		end 
 
                /////////////////////////////////
                //
                //  transfer data to/from stream interface
                ////////////////////////////////
                `AXI_FSM_DATA_TRANSFER: begin
                        axis_master_valid <= 1;
                        axis_slave_ready  <= 1; 
                        //if (axistream_data_receive_count == (`NumofpixelsperBlock - 1) ) hack to make it work need to change back to original
                        if (axistream_data_receive_count == (`NumofpixelsperBlock) )
                        begin                            
			                    axiFSM_currentState          	<= `AXI_FSM_IDLE; 
			                    axiFSM_prevState             	<= `AXI_FSM_DATA_TRANSFER;
                                axis_slave_ready              	<= 0;                           	
                                ComputeDone                  	<= 1'b1;
                                axistream_data_receive_count    <= 0;
                                axistream_data_send_count       <= 0;
                        end
                        else 
                        begin
                               axis_slave_ready  <= 1;
			                   axiFSM_currentState            <= `AXI_FSM_DATA_TRANSFER; 
			                   axiFSM_prevState               <= `AXI_FSM_DATA_TRANSFER;
                                if (axis_slave_valid)
				                begin
                                	axistream_data_receive_count   <= axistream_data_receive_count +1;
				                end
                                else
				                begin
                                	axistream_data_receive_count   <= axistream_data_receive_count;
				                end                                 
                        end    
                        
                        
                                                     
                        if ( axistream_data_send_count == (`NumofpixelsperBlock + 2) )
                        begin
                                axis_master_valid               <= 0;
				                //axistream_data_send_count       <= 0;     
                        end
			            else
			            begin
                                if(axis_master_valid)
                                begin  
					            axistream_data_send_count      <= axistream_data_send_count + 1;
				                end
                                else
				                begin
                                axistream_data_send_count      <= axistream_data_send_count;
				                end	
                        end
                 end
		/////////////////////////////////
		// 
		// write req. 1 
		//
		/////////////////////////////////
		`AXI_FSM_SEND_WRITE_REQUEST1: begin 
			ip2bus_mstwr_req    <= 1;
			ComputeDone         <= 1'b0;
            ip2bus_mst_addr     <= outputImageAddressR + axi_writeAddress_offset*4;  
			axiFSM_currentState <= `AXI_FSM_WAIT_FOR_WRITE_ACK1; 
			axiFSM_prevState    <= `AXI_FSM_SEND_WRITE_REQUEST1; 
		end 
		`AXI_FSM_WAIT_FOR_WRITE_ACK1: begin 
			if ( bus2ip_mst_cmdack ) begin 
				ip2bus_mstwr_req    <= 0; 
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1; 
				axiFSM_prevState    <= `AXI_FSM_WAIT_FOR_WRITE_ACK1; 
			end 
			else begin 
				ip2bus_mstwr_req    <= ip2bus_mstwr_req; 
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_WRITE_ACK1; 
				axiFSM_prevState    <= `AXI_FSM_WAIT_FOR_WRITE_ACK1; 
			end 	
		end 
		`AXI_FSM_WAIT_FOR_WRITE_CMPLT1: begin 
			if ( bus2ip_mst_cmplt ) begin 
				if ( axiFSM_writeRequestCounter == (`Num_of_Beats - 1)) begin 
					axiFSM_currentState     <= `AXI_FSM_IDLE; 
					axiFSM_prevState        <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
					axiMaster_blockSent_to_BRAM2 <= 1'b1; 
				end 
				else begin 
					axiFSM_currentState      <= `AXI_FSM_SEND_WRITE_REQUEST1; 
					axiFSM_prevState         <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1;
					axiFSM_writeRequestCounter <= axiFSM_writeRequestCounter + 1; 
				end 
			end 
			else begin
				axiFSM_currentState               <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1;
				axiFSM_prevState                  <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1;
			end 
		end 
		/////////////////////////////////
		// 
		// default
		//
		/////////////////////////////////
		default : begin 
			axiFSM_currentState <= `AXI_FSM_IDLE; 
			axiFSM_prevState <= `AXI_FSM_IDLE; 
		end
		endcase  
	end 

//////////////////////////////////////////////////////
// 
// pixel buffer
//
//////////////////////////////////////////////////////

reg				pixelbram_writeEnable_0;
reg				pixelbram_writeEnable_1;
wire            pixelbram_writeEn;
reg 	[14:0]			pixelbram_writeAddress_0; 
reg 	[14:0]			pixelbram_writeAddress_1; 
reg	[31:0]	                pixelbram_writeData_0;
reg	[31:0]	                pixelbram_writeData_1;
reg 	[14:0]			pixelbram_readAddress_0; 
reg 	[14:0]			pixelbram_readAddress_1; 
wire 	[31:0]          	pixelbram_readData_0; 
wire 	[31:0]			pixelbram_readData_1; 
wire 				pixelbram_readEnable_0;
wire 				pixelbram_readEnable_1;
reg	[3:0]			pixelbram_readDataSelect;			// this indicates if we are reading one pixel from each block mem. Or we are reading all pixels from the same block mem. 
reg				        pixelbram_readDataOrder; 			// this indicates if the pixels that we read should be send our in a straight order or they should be sent out in the reverse order 
reg 	[1:0]			pixelbram_readAddress_subCounter; 		// this is only used when doing horizontal and vertical flips or copy 

assign pixelbram_readEnable_0  = ( ( axiFSM_currentState == `AXI_FSM_DATA_TRANSFER ) && (axis_master_ready) && (axis_master_valid) );
assign pixelbram_writeEn       = ( ( axiFSM_currentState == `AXI_FSM_DATA_TRANSFER ) && (axis_slave_ready) && (axis_slave_valid) );


blk_mem_gen_0 pixel_buffer_blk_mem_Ins0 (
  .clka			( Clk ),    				// input wire clka
  .ena			( 1'b1 ),      				// input wire ena
  .wea			( pixelbram_writeEnable_0 ),      	// input wire [0 : 0] wea
  .addra		( pixelbram_writeAddress_0 ),  	// input wire [11 : 0] addra
  .dina			( pixelbram_writeData_0 ),  	        // input wire [31 : 0] dina
  .clkb			( Clk ),    				// input wire clkb
  .enb			( pixelbram_readEnable_0 ), 		//pixelbram_readPortEnabled ),  	// input wire enb
  .addrb		( pixelbram_readAddress_0 ),  	// input wire [9 : 0] addrb
  .doutb		( pixelbram_readData_0 )  		// output wire [31 : 0] doutb
);

blk_mem_gen_0 pixel_buffer_blk_mem_Ins1 (
  .clka			( Clk ),
  .ena			( 1'b1 ),
  .wea			( pixelbram_writeEnable_1 ),
  .addra		( pixelbram_writeAddress_1 ),
  .dina			( pixelbram_writeData_1 ),
  .clkb			( Clk ),
  .enb			( pixelbram_readEnable_1 ),
  .addrb		( pixelbram_readAddress_1 ),
  .doutb		( pixelbram_readData_1 )
);


//////////////////////////////////////////////////////
// 
// input data 
//
//////////////////////////////////////////////////////

always @(posedge Clk)
	if ( ! ResetL ) begin 
		pixelbram_writeEnable_0  <= 0; 
		pixelbram_writeAddress_0 <= 0; 
		pixelbram_writeData_0    <= 0; 
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			pixelbram_writeEnable_0   <= 0; 
			pixelbram_writeAddress_0  <= 0; 
			pixelbram_writeData_0     <= 0; 
		end 
		else if ( axiFSM_currentState == `AXI_FSM_SEND_READ_REQUEST1 ) begin 
			//pixelbram_writeAddress_0  <= pixelbram_writeAddress_0 + axiFSM_readRequestCounter; 
			pixelbram_writeAddress_0  <= pixelbram_writeAddress_0; 
			pixelbram_writeData_0     <= pixelbram_writeData_0; 
		end 
		else if ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_READ_CMPLT1 ) begin 
			if ( ! bus2ip_mstrd_src_rdy_n && (pixelbram_writeAddress_0 < `NumofpixelsperBlock)) begin 
				pixelbram_writeEnable_0   <= 1;
				pixelbram_writeAddress_0  <= pixelbram_writeAddress_0 + 1; 
				pixelbram_writeData_0     <= bus2ip_mstrd_d; 
			end
			else begin 
				pixelbram_writeEnable_0   <= 0; 
				pixelbram_writeAddress_0  <= pixelbram_writeAddress_0; 
				pixelbram_writeData_0     <= pixelbram_writeData_0; 
			end 
		end 
		else begin 
			pixelbram_writeEnable_0  <= 0; 
			pixelbram_writeAddress_0 <= pixelbram_writeAddress_0; 
			pixelbram_writeData_0    <= pixelbram_writeData_0; 
		end 
	end 
	

//////////////////////////////////////////////////////
// 
// output data to master stream interface 
//
//////////////////////////////////////////////////////

always @(posedge Clk) 
	if ( ! ResetL ) 
        begin 
		pixelbram_readAddress_0    <= 0; 
	end 
	else 
	begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) 
            begin 
			pixelbram_readAddress_0 <= 0; 
			//axis_master_data_out    <= 0;
		    end
		else if ( pixelbram_readEnable_0)
		        begin
		            if (axistream_data_send_count > (`NumofpixelsperBlock))
		                pixelbram_readAddress_0       <= 0;
		            else    
                	    pixelbram_readAddress_0       <= axistream_data_send_count;
                	   //pixelbram_readAddress_0       <= pixelbram_readAddress_0 + 1;                	
                	   //axis_master_data_out          <= pixelbram_readData_0;
                end
                else
                begin 
                        pixelbram_readAddress_0      <= pixelbram_readAddress_0;  
                        //axis_master_data_out         <= pixelbram_readData_0;
                end
    end
assign axis_master_data_out = pixelbram_readData_0;
//////////////////////////////////////////////////////
// 
// input data to slave stream interface 
//
//////////////////////////////////////////////////////
always @(posedge Clk)
	if ( ! ResetL ) begin 
		pixelbram_writeAddress_1 <= 0; 
		pixelbram_writeData_1    <= 0; 
		pixelbram_writeEnable_1  <= 0;
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) 
		begin 
			//pixelbram_writeAddress_1  <= 0; 
			pixelbram_writeData_1     <= 0; 
			pixelbram_writeEnable_1   <= 0;
		end
                else if ( pixelbram_writeEn ) 
                begin
                	    //pixelbram_writeAddress_1       <= pixelbram_writeAddress_1 + axistream_data_receive_count;
                	    pixelbram_writeEnable_1        <= 1'b1;
                	    pixelbram_writeAddress_1       <= axistream_data_receive_count;
                        pixelbram_writeData_1          <= axis_slave_data_in;
                        end
                else
                begin 
                        pixelbram_writeAddress_1      <= pixelbram_writeAddress_1;  
                        pixelbram_writeData_1         <= 0;
                        pixelbram_writeEnable_1        <= 1'b0;
                end
             end 
//////////////////////////////////////////////////////
// 
// output data 
//
//////////////////////////////////////////////////////
// default block size is 160 x 160 pixels, 25600 pixels 
// generate suitable read address and config signals for reading the data back from the dual port memory. 

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		pixelbram_readAddress_1    <= 0; 
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			pixelbram_readAddress_1 <= 0; 
		end
		else if ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && bus2ip_mst_cmdack) begin 
			//pixelbram_readAddress_1 <= axiFSM_writeRequestCounter * Num_of_Beats;
			pixelbram_readAddress_1 <= pixelbram_readAddress_1;
		end 
		else if ( pixelbram_readEnable_1 && (! ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) ) ) 
		begin 	 
			pixelbram_readAddress_1 <= pixelbram_readAddress_1 + 1;
		end 
		else begin 
		pixelbram_readAddress_1 <= pixelbram_readAddress_1;
	        end 
	end 


////////////////////////////////////////////////////////////////////////////////////////////////////////////
// register readEnable, dataselect and data order and subcounter since the block memory has a latency of one clock cycle 
// and then it provided the data for a specific input address 
// you need the above values to put the data out to the axi master plug 

reg 		pixelbram_readEnableR;

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		pixelbram_readEnableR <= 0; 
	end 
	else begin 
		pixelbram_readEnableR <= pixelbram_readEnable_1; 
	end 

//////////////////////////////////////////////////////////////////////////////////////////
//
// pixel buffer read enable 
//
//////////////////////////////////////////////////////////////////////////////////////////

assign pixelbram_readEnable_1 = ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) ? 1'b1 : 
				( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && (burstCounter <= (burstLength) ) ) ? 1'b1 : 0;
//assign pixelbram_readEnable_1 = ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) ? 1'b1 : 
//				( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && (burstCounter < (burstLength) ) ) ? 1'b1 : 0;
//assign pixelbram_readEnable_1 = ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) && ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && (burstCounter < (burstLength) ) ) ) ? 1'b1 : 0;
//				( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && (burstCounter < (burstLength) ) ) ? 1'b1 : 0;                                
//assign pixelbram_readEnable_1 = ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) && ( ( ! ip2bus_mstwr_src_rdy_n ) && ( bus2ip_mstwr_dst_rdy_n ) && (burstCounter <= (burstLength) ) ) ) ? 1'b1 :0;
//////////////////////////////////////////////////////////////////////////////////////////
//
// wirte burst counter
//
//////////////////////////////////////////////////////////////////////////////////////////
// generate signals to axi master block
wire 	[7:0]	burstLength; 
reg 	[7:0]	burstCounter; 

//assign burstLength = ip2bus_mst_length / (PIXEL_WIDTH*4/8);
assign burstLength = ip2bus_mst_length / (PIXEL_WIDTH/8);



always @(posedge Clk) 
	if ( ! ResetL ) begin 
		burstCounter <= 0; 
	end 
	else begin 
		if ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) begin 
			burstCounter <= 0; 
		end 
		else if ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) ) begin 
			burstCounter <= burstCounter + 1; 
		end 
		else begin 
			burstCounter <= burstCounter; 
		end 
	end 
	
//////////////////////////////////////////////////////////////////////////////////////////
//
// ip2bus_mstwr_src_rdy_n
//
//////////////////////////////////////////////////////////////////////////////////////////
// source ready signal. goes down in the beginning of data transfer and comes up at its end. 	

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		ip2bus_mstwr_src_rdy_n <= 1;
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			ip2bus_mstwr_src_rdy_n <= 1;
		end 
		else if ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) begin 
			if ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && ( burstCounter == (burstLength-1) ) ) begin 
				ip2bus_mstwr_src_rdy_n <= 1; 
			end 
			else if ( pixelbram_readEnableR && (burstCounter == 0) ) begin 		
				ip2bus_mstwr_src_rdy_n <= 0; 
			end 
			else begin 
				ip2bus_mstwr_src_rdy_n <= ip2bus_mstwr_src_rdy_n;
			end 
		end 
	end 
	
//////////////////////////////////////////////////////////////////////////////////////////
//
// write start of frame 
//
//////////////////////////////////////////////////////////////////////////////////////////

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		ip2bus_mstwr_sof_n <= 1; 
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			ip2bus_mstwr_sof_n <= 1; 
		end
		else if ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) begin 
			if ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) ) begin 
				ip2bus_mstwr_sof_n <= 1; 
			end 
			else if ( pixelbram_readEnableR && (burstCounter == 0) ) begin 		
				ip2bus_mstwr_sof_n <= 0; 
			end 
			else 
				ip2bus_mstwr_sof_n <= ip2bus_mstwr_sof_n; 
		end 
		else begin 
			ip2bus_mstwr_sof_n <= ip2bus_mstwr_sof_n; 
		end
	end 

//////////////////////////////////////////////////////////////////////////////////////////
//
// write end of frame 
//
//////////////////////////////////////////////////////////////////////////////////////////

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		ip2bus_mstwr_eof_n <= 1;
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			ip2bus_mstwr_eof_n <= 1;
		end
		else if ( ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) begin
			if ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && ( burstCounter == (burstLength-2) ) ) 
				ip2bus_mstwr_eof_n <= 0;
			else if ( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) ) 
				ip2bus_mstwr_eof_n <= 1;
			else 
				ip2bus_mstwr_eof_n <= ip2bus_mstwr_eof_n;
		end 
		else begin 
			ip2bus_mstwr_eof_n <= ip2bus_mstwr_eof_n;
		end 
	end 
	
//////////////////////////////////////////////////////////////////////////////////////////
//
// write start of frame and end of frame and data 
//
//////////////////////////////////////////////////////////////////////////////////////////

assign ip2bus_mstwr_d = pixelbram_readData_1;
endmodule 


