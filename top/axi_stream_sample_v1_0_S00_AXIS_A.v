
`timescale 1 ns / 1 ps

	module axi_stream_sample_v1_0_S00_AXIS_A #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// AXI4Stream sink: Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH	= 32
	)
	(
		// Users to add ports here
                output   wire AXIS_SLAVE_VAILD,
		input    wire AXIS_SLAVE_READY,
	        output   wire [C_S_AXIS_TDATA_WIDTH-1 : 0] AXIS_SLAVE_DATA_OUT, 
		// User ports ends
		// Do not modify the ports beyond this line

		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);


	// Add user logic here
	   reg [C_S_AXIS_TDATA_WIDTH-1 : 0] data_out;
           always @(posedge S_AXIS_ACLK or negedge S_AXIS_ARESETN)
	   begin
           	if (!S_AXIS_ARESETN)
           	begin
		    data_out <= 32'b0;
           	end
           	else if (S_AXIS_TVALID && S_AXIS_TREADY)
           	begin
		    data_out <= S_AXIS_TDATA;
           	end
           end
	   assign AXIS_SLAVE_VAILD       = S_AXIS_TVALID;
	   assign S_AXIS_TREADY          = AXIS_SLAVE_READY;
	   assign AXIS_SLAVE_DATA_OUT    = data_out;  
	// User logic ends

	endmodule
