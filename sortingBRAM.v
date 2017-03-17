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


localparam BE_WIDTH = (PIXEL_WIDTH)/8;

reg 	[3:0]				mainFSM_currentState; 
reg		[3:0]				mainFSM_prevState; 
reg		[10:0]				currentWeight;
reg		[31:0]				binNumber;
reg		[31:0]				bins_DRAM_Base_Address;
reg 						axiSlaveStream_weightsReceived_to_BRAM1; //raw weights from floating point
reg 						temp_var_weight;

/////////////////////////////////////
// counters for bins - 9 bits each
/////////////////////////////////////	   

bramCounterArray[511:0][8:0] //to count number of weights stored in the BRAM bins
dramCounterArray[511:0][8:0] //to count number of weights stored in the DRAM bins

always @(posedge Clk)
       if ( ! ResetL ) begin 
	      mainFSM_currentState <= `FSM_IDLE;  
	      mainFSM_prevState <= `FSM_IDLE; 
	      ComputationDone <= 0; 
       end 
       else begin 
	      case ( mainFSM_currentState ) 
	      `FSM_IDLE: begin 
	       if ( BeginOperation ) begin 
			    mainFSM_currentState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1; //FSM_RECEIEVE_BLOCK_BRAM1
			    mainFSM_prevState <= `FSM_IDLE;
		     end 
		     else begin 
			    mainFSM_currentState <= `FSM_IDLE;
			    mainFSM_prevState <= `FSM_IDLE; 
		     end
		     ComputationDone <= 0; 
	      end 
		  
///////////////////////////////////////////////////////////////////
// stream data transfer from weight generator to first BRAM memory
///////////////////////////////////////////////////////////////////
	      `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1: begin 
		    axis_slave_ready  <= 1; 
			if ( axiSlaveStream_weightsReceived_to_BRAM1 ) begin  
				mainFSM_currentState <= `FSM_COMPUTE_BINS_BLOCK; //FSM_COMPUTE_BLOCK
				mainFSM_prevState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
			end 
			//if (axistream_data_receive_count == (`NumofpixelsperBlock - 1) ) hack to make it work need to change back to original
                        if (axistream_data_receive_count == (`NumofweightssperBlock) ) //should be 160*160*4
                        begin                            
			                    mainFSM_currentState          	<= `FSM_COMPUTE_BINS_BLOCK; 
			                    mainFSM_prevStateFSM_prevState             	<= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
                                axis_slave_ready              	<= 0;                           	
                                ComputeDone                  	<= 1'b1;
								axiSlaveStream_weightsReceived_to_BRAM1 <= 1;
                                axistream_data_receive_count    <= 0;
                                axistream_data_send_count       <= 0;
                        end
                        else 
                        begin
                               axis_slave_ready  <= 1;
			                   axiFSM_currentState            <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1; 
			                   axiFSM_prevState               <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
                                if (axis_slave_valid)
				                begin
                                	axistream_data_receive_count   <= axistream_data_receive_count +1;
				                end
                                else
				                begin
                                	axistream_data_receive_count   <= axistream_data_receive_count;
				                end                                 
                        end    
			else begin 
				mainFSM_currentState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
				mainFSM_prevState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
			end 
	        end 
			
			
              `FSM_COMPUTE_BINS_BLOCK: 
			    begin
                        if ( onebinfull ) begin
						mainFSM_currentState <= `FSM_SEND_ONE_FULL_BIN; //`FSM_SEND_BLOCK_BRAM2;
						mainFSM_prevState    <= `FSM_COMPUTE_BINS_BLOCK;
						//remember to get the mainFSM state back to FSM_COMPUTE_BINS_BLOCK from FSM_SEND_ONE_FULL_BIN if ComputeDone = 0, basically reset onebinfull = 0
						end
						else if ( ComputeDone ) begin
                                mainFSM_currentState <= `FSM_SEND_ALL_BINS; //`FSM_SEND_BLOCK_BRAM2;
                                mainFSM_prevState    <= `FSM_COMPUTE_BINS_BLOCK;
                                
                        end
                        else if (rawWeightBinCount < NumofpixelsperBlock) 
							begin
								temp_var_weight <= pixelbram_readData_0;
								if ( temp_var_weight[12:11] = 2b'0 )
								begin
									if ( temp_var_weight[12:10] = 3b'0 )
									begin
											if ( temp_var_weight[12:10] = 4b'0 )
											begin
												currentWeight <= pixelbram_readData_0; //calculate bin number 
												binNumber <= currentWeight*4;
												bramCounterArray[binNumber] <= bramCounterArray[binNumber] + 1; //increase counter for that bin
												//check if bramCounterArray = (NumofWeightsPerBin-1), raise onebinfull 
													if (bramCounterArray[binNumber] == (NumofWeightsPerBin-1) )
													begin
														onebinfull <= onebinfull + 1;
														bramCounterArray[binNumber] <= 0;
													end
													//writing to pixelbram_writeData_1 handled separately in input data to bins BRAM
											end
											else begin 
											
											//send to bins corresponding to 000
											end
									end
									else begin
									//send to bins correspondingto 00
									end
								end
								else begin
								//send to bins corresponding to 0
								end
							pixelbram_readAddress_0 <= pixelbram_readAddress_0 + 1; 
							end
						else begin
							ComputeDone <= 1;
						end
							
                end

              
	      
			`FSM_SEND_ONE_FULL_BIN: begin
				if ( !onebinfull )
				begin
					mainFSM_currentState <= `FSM_COMPUTE_BINS_BLOCK;
					mainFSM_prevState <= `FSM_SEND_ONE_FULL_BIN;
				end
				if ( onebinfullSent )//basically the bin that was full has been sent
				begin
					onebinfull <= 0;
				end
				else begin
					mainFSM_currentState <= `FSM_SEND_ONE_FULL_BIN;
					mainFSM_prevState <= `FSM_SEND_ONE_FULL_BIN;
				end
			end
  
		   `FSM_SEND_ALL_BINS: begin
	        //ComputeDone <= 1'b0; // ALSO - REBINNING !!!
 			if ( axiMaster_allBinsSent_to_DRAM ) begin
				//if ( ( sendBlockCounter == (NumberOfBlocks-1) )  ) begin 
					mainFSM_currentState <= `FSM_END_OPERATION;
					mainFSM_prevState    <= `FSM_SEND_ALL_BINS; 
				//end 
/* 				else begin //no longer transferring chunks - just sending all the bin data 
					mainFSM_currentState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
					mainFSM_prevState    <= `FSM_SEND_ALL_BINS;
				end  */
			end 
			else begin
				mainFSM_currentState <= `FSM_SEND_ALL_BINS;
				mainFSM_prevState    <= `FSM_SEND_ALL_BINS;
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
// axi master - constant signals (fixed value)
//////////////////////////////////////////////////////

//assign ip2bus_mst_length = //dynamic for every send - depends on the  bram and dram counter arrays
assign ip2bus_mst_type = 1; // we always transfer in bursts. 
assign ip2bus_mst_lock = 0; 
assign ip2bus_mstrd_dst_dsc_n = 1; 	// we do never discountinue a transfer (master read destination ready) 
assign ip2bus_mstrd_dst_rdy_n = 0; 	// we are always ready to receive the data
assign ip2bus_mst_be = {BE_WIDTH{1'b1}}; //8'hff; // all of the transferred data is always meaningful
assign ip2bus_mstwr_rem = 0; 
assign ip2bus_mst_reset = 0; 
assign ip2bus_mstwr_src_dsc_n = 1;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AXI MASTER FSM - ALSO INCLUDES COMPUTE BINS, TRANSFER ONE FULL BIN and TRANSFER ALL BINS
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// logic to talk to the axi master ipif

//reg 			axiMaster_blockReceived_to_BRAM1;
reg 			axiMaster_binSent_to_DRAM; 
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
		axiMaster_binSent_to_DRAM <= 0; 
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
			if ( (mainFSM_currentState == `FSM_SEND_ONE_FULL_BIN) && (mainFSM_prevState == `FSM_COMPUTE_BINS_BLOCK) ) begin 
				axiFSM_currentState <= `AXI_FSM_SEND_WRITE_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				ip2bus_mst_length <= NumofWeightsPerBin/2; //as one full bin - check if 256 needed
				axiFSM_writeRequestCounter <= 0; 
			end 
			else if ( (mainFSM_currentState == `FSM_SEND_ALL_BINS) && (mainFSM_prevState == `FSM_COMPUTE_BINS_BLOCK) ) begin 
				
				axiFSM_currentState <= `AXI_FSM_SEND_WRITE_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				//set ip2bus_mst_length = counter arrays - for all bins
				axiFSM_writeRequestCounter <= 0; 
			end 
			else if ( (mainFSM_currentState == `REBINNING) && (mainFSM_prevState == `FSM_COMPUTE_BINS_BLOCK) ) begin ///Set vars to control 
				axiFSM_currentState <= `AXI_FSM_SEND_WRITE_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				
				axiFSM_writeRequestCounter <= 0; 
			end
            
			else begin 

				axiFSM_currentState <= `AXI_FSM_IDLE; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
			end 
			
			axiMaster_blockReceived_to_BRAM1 <= 0; 
			axiMaster_binSent_to_DRAM <= 0; 
		end 
		/////////////////////////////////
		// 
		// read req. 
		//
		/////////////////////////////////
		`AXI_FSM_SEND_READ_REQUEST1: begin 
			ip2bus_mstrd_req <= 1; 
			ip2bus_mst_addr <= //bin address
			
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
		// write req. 1 
		//
		/////////////////////////////////
		`AXI_FSM_SEND_WRITE_REQUEST1: begin 
			ip2bus_mstwr_req    <= 1;
			
            ip2bus_mst_addr     <=  bins_DRAM_Base_Address + binNumberOffset + dramCounterArray[binNumber]//write to appropriate bin address - in case of send one bin/send all bins
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
			if ( onebinfull )
			begin
					if ( bus2ip_mst_cmplt ) begin 
						if ( axiFSM_writeRequestCounter == 2) begin 
							axiFSM_currentState     <= `AXI_FSM_IDLE; 
							axiFSM_prevState        <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
							axiMaster_binSent_to_DRAM <= 1'b1; 
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
			end
			else if ( ComputeDone )
			begin
					if ( bus2ip_mst_cmplt ) begin 
						if ( axiFSM_writeRequestCounter == 2) begin 
							axiFSM_currentState     <= `AXI_FSM_IDLE; 
							axiFSM_prevState        <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
							axiMaster_binSent_to_DRAM <= 1'b1; 
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
	
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////	

////////////////////////////////////////////////////// 
// BRAM instantiation
//////////////////////////////////////////////////////

reg						pixelbram_writeEnable_0;
reg						pixelbram_writeEnable_1;
wire            		pixelbram_writeEn;
reg 	[14:0]			pixelbram_writeAddress_0; 
reg 	[14:0]			pixelbram_writeAddress_1; 
reg		[31:0]	        pixelbram_writeData_0;
reg		[31:0]	        pixelbram_writeData_1;
reg 	[14:0]			pixelbram_readAddress_0; 
reg 	[14:0]			pixelbram_readAddress_1; 
wire 	[31:0]          pixelbram_readData_0; 
wire 	[31:0]			pixelbram_readData_1; 
wire 					pixelbram_readEnable_0;
wire 					pixelbram_readEnable_1;
reg		[3:0]			pixelbram_readDataSelect;			// doesnt matter 
reg				        pixelbram_readDataOrder; 			// doesnt matter 
reg 	[1:0]			pixelbram_readAddress_subCounter; 		// doesnt matter 

assign pixelbram_writeEnable_0  = ( ( mainFSM_currentState == `FSM_RECEIEVE_BLOCK_BRAM1 ) && (axis_slave_ready) && (axis_slave_valid) );
assign pixelbram_readEnable_0  = ( ( mainFSM_currentState == `FSM_COMPUTE_BINS_BLOCK ) && ( !onebinfull ) && ( !ComputeDone ) );
assign pixelbram_writeEnable_1       = ( ( mainFSM_currentState = `FSM_COMPUTE_BINS_BLOCK ) && ( !onebinfull ) && ( !ComputeDone ) );
assign pixelbram_readEnable_1       = ( ( mainFSM_currentState = `REBINNING )  ); // change accordingly


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
// input data - from stream to BRAM1
//
//////////////////////////////////////////////////////

always @(posedge Clk)
	if ( ! ResetL ) begin 
		pixelbram_writeEnable_0  <= 0; 
		pixelbram_writeAddress_0 <= 0; 
		pixelbram_writeData_0    <= 0; 
	end 
	else begin 
		if ( mainFSM_currentState == `AXI_FSM_IDLE ) begin 
			pixelbram_writeEnable_0   <= 0; 
			pixelbram_writeAddress_0  <= 0; 
			pixelbram_writeData_0     <= 0; 
		end 
		else if ( mainFSM_currentState == `FSM_RECEIEVE_BLOCK_BRAM1 ) begin 
			if ( axis_slave_ready && axis_slave_valid ) begin 
				pixelbram_writeEnable_0   <= 1;
				pixelbram_writeAddress_0  <= pixelbram_writeAddress_0 + 1; 
				pixelbram_writeData_0     <= axis_slave_data_in; 
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
	

////////////////////////////////////////////////////////////
// 
// input data to bins BRAM - used in the compute bins block
//
////////////////////////////////////////////////////////////
always @(posedge Clk)
	if ( ! ResetL ) begin 
		pixelbram_writeAddress_1 <= 0; 
		pixelbram_writeData_1    <= 0; 
		pixelbram_writeEnable_1  <= 0;
	end 
	else begin 
		if ( mainFSM_currentState == `FSM_IDLE ) 
		begin 
			pixelbram_writeAddress_1  <= 0; 
			pixelbram_writeData_1     <= 0; 
			pixelbram_writeEnable_1   <= 0;
		end
                else if ( pixelbram_writeEnable_1 ) //write conditions for writing - calculate write address here
                begin
						pixelbram_writeAddress_1       <= binNumber*512 + bramCounterArray[binNumber];
                        pixelbram_writeData_1          <= currentWeight;
                        end
                else
                begin 
                        pixelbram_writeAddress_1      <= pixelbram_writeAddress_1;  
                        pixelbram_writeData_1         <= 0;
                        pixelbram_writeEnable_1        <= 1'b0;
                end
             end 	 
			 
			 
////////////////////////////////////////////////////////////////////////////////			 