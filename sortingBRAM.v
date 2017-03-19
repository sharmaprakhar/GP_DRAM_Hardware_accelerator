/*
Pending:
Use rebinning Visio drawing to write the rebinning scheme into pixel_bram memory - will do 

Development comments: 
double check and set mst_addr and mst_length for every read and write request
see if the pixel_bram memory addresses beiong read correspond to one being written to the DRAM for rebin case

if above two points are good - the design should work as intended
*/
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
reg 	[8:0]				NumofBins; 
reg 	[8:0]				NumofWeightsPerBin; 
reg		[3:0]				mainFSM_prevState; 
reg		[31:0]				temp_var_weight;
reg		[31:0]				binNumber;
reg		[31:0]				bins_DRAM_Base_Address;
reg 						axiSlaveStream_weightsReceived_to_BRAM1; //raw weights from floating point
reg 						onebinfullSent

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
	   `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1: 
		begin 
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
                                //axis_slave_ready              	<= 0;                           	
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
                        else if (rawWeightBinCount < NumofpixelsperBlock-1) 
						begin
								temp_var_weight <= pixelbram_readData_0;
								if ( temp_var_weight[12] ==  1)
								begin //case4
									binNumber <= ((temp_var_weight-256) >> 3) + 448;
								end
								if ( temp_var_weight[12:11] == 2b'1 )
								begin //case3
									binNumber <= ((temp_var_weight-128)>>1)+384;
								end
								if ( temp_var_weight[12:10] == 3b'1 )
								begin //case2
									binNumber <= ((temp_var_weight-64)<<1)+256;
								end
								if ( temp_var_weight[12:10] == 3b'0 )
								begin //case 1
									binNumber <= temp_var_weight << 2;
								end
								if (bramCounterArray[binNumber] == (NumofWeightsPerBin-1) )
								begin //check if bramCounterArray = (NumofWeightsPerBin-1), raise onebinfull
									onebinfull <= 1;
									bramCounterArray[binNumber] <= 0;
									
								end
								else if 
								begin
									//increase counter for that bin
									bramCounterArray[binNumber] <= bramCounterArray[binNumber] + 1;
									pixelbram_readAddress_0 <= pixelbram_readAddress_0 + 1; 
									rawWeightBinCount <= rawWeightBinCount + 1; //rawWeightBinCount is total no of weights per chunk
								end
						end
						//writing to pixelbram_writeData_1 handled separately in input data to bins BRAM
						else if (rawWeightBinCount == NumofpixelsperBlock-1)
						begin
							ComputeDone <= 1;
						end
							
                end

              
	      
			`FSM_SEND_ONE_FULL_BIN: 
			begin
			if ( !onebinfull )
			begin
					mainFSM_currentState <= `FSM_COMPUTE_BINS_BLOCK;
					mainFSM_prevState <= `FSM_SEND_ONE_FULL_BIN;
			end
			if ( onefullBinSent )//basically the bin that was full has been sent
			begin
					onebinfull <= 0;
			end
			else begin
					mainFSM_currentState <= `FSM_SEND_ONE_FULL_BIN;
					mainFSM_prevState <= `FSM_SEND_ONE_FULL_BIN;
			end
			end
  
		   `FSM_SEND_ALL_BINS: begin
 			if ( axiMaster_allBinsSent_to_DRAM ) 
			begin
				if ( sendBlockCounter == (NumberOfBlocks-1))
				begin
					mainFSM_currentState <= `FSM_REBIN_DOWNLOAD; //Re-binning
					mainFSM_prevState    <= `FSM_SEND_ALL_BINS;
				end
				else begin
					mainFSM_currentState <= `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1;
					mainFSM_prevState    <= `FSM_SEND_ALL_BINS
				end
			end 
			else begin
				mainFSM_currentState <= `FSM_SEND_ALL_BINS;
				mainFSM_prevState    <= `FSM_SEND_ALL_BINS;
			end 
	      end
		  
		  
		`FSM_REBIN_DOWNLOAD: begin
		if ( axiMaster_rebin_done )
		begin
				mainFSM_currentState <= `END_OPERATION; 
				mainFSM_prevState    <= `FSM_REBIN;
		end
		else if ( axiFSM_oneRebinDownloaded )
		begin
			mainFSM_currentState <= `FSM_REBIN_UPLOAD;
			mainFSM_prevState <= `FSM_REBIN_DOWNLOAD;
		end
		end
		
		`FSM_REBIN_UPLOAD: begin
		if ( somecounter == number of elements in the bin being uploaded )
			//change state to download
		end
		else begin
			//stay in the same state
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// send block counters - says which weights block we are operating on
////////////////////////////////////////////////////////////////////////////////////////////////////////////

reg	[3:0]	sendBlockCounter; 

always @(posedge Clk)
	if ( ! ResetL ) begin 
		sendBlockCounter    <= 0;
	end
	else begin
		if ( mainFSM_currentState == `FSM_IDLE ) begin 
			sendBlockCounter    <= 0;
		end 
		else if ( ( mainFSM_currentState == `FSM_RECEIEVE_RAW_WEIGHTS_BRAM1) && (mainFSM_prevState == `FSM_SEND_ALL_BINS) ) 
		begin 
				if ( sendBlockCounter == (NumberOfBlocks-1) ) 
				begin 
					sendBlockCounter <= sendBlockCounter;
                end  
				else 
				begin 
					sendBlockCounter <= sendBlockCounter + 1; 
				end
  
		end 
		else begin 
			sendBlockCounter    <= sendBlockCounter; 
		end 
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
		axiMaster_allBinsSent_to_DRAM <= 0; 
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
				axiFSM_writeRequestCounter <= 0; 
				//set ip2bus_mst_length = counter arrays - for all bins - in wait for cmd ack
			end 
			else if ( (mainFSM_currentState == `FSM_REBIN_DOWNLOAD) && (mainFSM_prevState == `FSM_SEND_ALL_BINS) ) begin //rebin - first instance into download
				axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				axiFSM_readRequestCounter <= 0; 
			end
			else if ( (mainFSM_currentState == `FSM_REBIN_DOWNLOAD) && (mainFSM_prevState == `FSM_REBIN_UPLOAD) ) begin //rebin - get a bin from DRAM
				axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				axiFSM_readRequestCounter <= 0; 
			end
			else if ( (mainFSM_currentState == `FSM_REBIN_UPLOAD) && (mainFSM_prevState == `FSM_REBIN_DOWNLOAD) ) begin //rebin - put a bin into DRAM
				axiFSM_currentState <= `AXI_FSM_SEND_WRITE_REQUEST1; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
				axiFSM_readRequestCounter <= 0; 
			end
			else begin 
				axiFSM_currentState <= `AXI_FSM_IDLE; 
				axiFSM_prevState <= `AXI_FSM_IDLE; 
			end 
			
			axiMaster_blockReceived_to_BRAM1 <= 0; 
			axiMaster_binSent_to_DRAM <= 0; 
			axiMaster_allBinsSent_to_DRAM <= 0;
		end 
		/////////////////////////////////
		// 
		// read req. 
		//
		/////////////////////////////////
		`AXI_FSM_SEND_READ_REQUEST1: begin 
			ip2bus_mstrd_req <= 1; 
			ip2bus_mst_addr <= //bin address
			//ip2bus_mst_length <= dramCounterArray[binNumber] //sequentially incremented according to Num_of_Rebin_Chunks [ip2bus_mst_length*(Num_of_Rebin_Chunks-1)+remainder]=dramCounterArray[binNumber]
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
				if ( axiFSM_readRequestCounter < `Num_of_Rebins-1 )
				begin
					if ( internalReadReqCounter == (`Num_of_Rebin_Chunks - 1) ) //internal read req counter keeps track of how many read req need to be sent for a single bin in dram (as it may have more than 256
					begin 
						axiFSM_currentState <= `AXI_FSM_IDLE; //should go to write request by seeing axiFSM_oneRebinDownloaded
						axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
						axiFSM_oneRebinDownloaded <= 1'b1;
					end 
					else begin
						axiFSM_currentState <= `AXI_FSM_SEND_READ_REQUEST1; 
						axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
						internalReadReqCounter <= internalReadReqCounter + 1;
						//set appropriate mst_length
					end
				end
				else if ( axiFSM_readRequestCounter == `Num_of_Rebins - 1 ) 
				begin 	
					axiFSM_currentState <= `AXI_FSM_IDLE; 
					axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
					axiMaster_rebin_done <= 1'b1;
				end 
			end 
			else begin 
				axiFSM_currentState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
				axiFSM_prevState <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
			end 
		end 
		
		///////////////////////////////// 
		// write req. 1
		/////////////////////////////////
		`AXI_FSM_SEND_WRITE_REQUEST1: begin 
			ip2bus_mstwr_req    <= 1;
			//write to appropriate bin address - in case of send one bin/send all bins
			if ( onebinfull && !ComputeDone)
				begin
				ip2bus_mst_addr <=  bins_DRAM_Base_Address + binNumberOffset + dramCounterArray[binNumber];
				pixelbram_readAddress_1 <= binNumber << 9;
				end
		    else if ( ComputeDone )
			begin
				ip2bus_mst_addr <= bins_DRAM_Base_Address + binNumberOffset + dramCounterArray[axiFSM_writeRequestCounter];
				pixelbram_readAddress_1 <= axiFSM_writeRequestCounter << 9; //axiFSM_writeRequestCounter used because when 0th wr_req - send 0th bin | when 1st wr_req - send 1st bin and so on
			end
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
			if ( onebinfull && !ComputeDone)
			begin
					if ( bus2ip_mst_cmplt ) begin 
						if ( axiFSM_writeRequestCounter == 2) begin 
							axiFSM_currentState     <= `AXI_FSM_IDLE; 
							axiFSM_prevState        <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1; 
							axiMaster_binSent_to_DRAM <= 1'b1; 
							onefullBinSent <= 1; //go back to binning
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
						if ( axiFSM_writeRequestCounter == NumofBins-1) begin 
							axiFSM_currentState     <= `AXI_FSM_IDLE; 
							axiFSM_prevState        <= `AXI_FSM_WAIT_FOR_READ_CMPLT1; 
							axiMaster_allBinsSent_to_DRAM <= 1'b1; 
						end 
						else begin 
							axiFSM_currentState      <= `AXI_FSM_SEND_WRITE_REQUEST1; 
							axiFSM_prevState         <= `AXI_FSM_WAIT_FOR_WRITE_CMPLT1;
							
							ip2bus_mst_length = bramCounterArray[axiFSM_writeRequestCounter] // what if elements are more than 256
							axiFSM_writeRequestCounter <= axiFSM_writeRequestCounter + 1;
							//set addr //set burst length
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
		// default
		/////////////////////////////////
		default : begin 
			axiFSM_currentState <= `AXI_FSM_IDLE; 
			axiFSM_prevState <= `AXI_FSM_IDLE; 
		end
		endcase  
	end 
	
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
assign pixelbram_readEnable_1 = ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) ? 1'b1 : 
				( ( ! ip2bus_mstwr_src_rdy_n ) && ( ! bus2ip_mstwr_dst_rdy_n ) && (burstCounter <= (burstLength) ) ) ? 1'b1 : 0; // change read address accordingly

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
						pixelbram_writeAddress_1       <= binNumber << 9 + bramCounterArray[binNumber];
                        pixelbram_writeData_1          <= temp_var_weight;
                        end
                else
                begin 
                        pixelbram_writeAddress_1      <= pixelbram_writeAddress_1;  
                        pixelbram_writeData_1         <= 0;
                        pixelbram_writeEnable_1        <= 1'b0;
                end
             end 	 
			 
			 
////////////////////////////////////////////////////////////////////////////////	
// output data - BRAM2 to DRAM - used in onebinfull, send all bins, rebinning
////////////////////////////////////////////////////////////////////////////////

always @(posedge Clk) 
	if ( ! ResetL ) begin
		pixelbram_readAddress_1    <= 0; 
	end 
	else begin 
		if ( axiFSM_currentState == `AXI_FSM_IDLE ) begin 
			pixelbram_readAddress_1 <= 0; 
		end
		//handle different binfull/rebin conditions here
		else if ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && bus2ip_mst_cmdack) 
		begin 
			pixelbram_readAddress_1 <= pixelbram_readAddress_1;
		end 
		else if ( pixelbram_readEnable_1 && (! ( ( axiFSM_prevState == `AXI_FSM_WAIT_FOR_WRITE_ACK1 ) && ( axiFSM_currentState == `AXI_FSM_WAIT_FOR_WRITE_CMPLT1 ) ) ) ) 
		begin 	 
			//address initialized with wr_req. onebinfull and ComputeDone not handled separately as with proper initialization, need to only increment add with 1
			pixelbram_readAddress_1 <= pixelbram_readAddress_1 + 1;
		end 
		else begin 
		pixelbram_readAddress_1 <= pixelbram_readAddress_1;
	    end 
	end 
	
////////////////////////////////////////////////////////////////////
//register read enable
////////////////////////////////////////////////////////////////////	
reg 		pixelbram_readEnableR;

always @(posedge Clk) 
	if ( ! ResetL ) begin 
		pixelbram_readEnableR <= 0; 
	end 
	else begin 
		pixelbram_readEnableR <= pixelbram_readEnable_1; 
	end 
	
////////////////////////////////////////////////////////////////////
//write burst counter
////////////////////////////////////////////////////////////////////
wire 	[7:0]	burstLength; 
reg 	[7:0]	burstCounter; 

assign burstLength = ip2bus_mst_length / (PIXEL_WIDTH/8); //why was this done??



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
// ip2bus_mstwr_src_rdy_n
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
// write start of frame 
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
// write end of frame 
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
// write start of frame and end of frame and data 
//////////////////////////////////////////////////////////////////////////////////////////

assign ip2bus_mstwr_d = pixelbram_readData_1;
