
`timescale 1 ns / 1 ps

	module axi_stream_sample_v1_0_M00_AXIS_A #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
		// Start count is the numeber of clock cycles the master will wait before initiating/issuing any transaction.
		parameter integer C_M_START_COUNT	= 32
	)
	(
		// Users to add ports here
            input  wire AXIS_MASTER_VALID,
		    output wire AXIS_MASTER_READY,
	        input  wire [C_M_AXIS_TDATA_WIDTH-1 : 0] AXIS_MASTER_DATA_IN,	
		// User ports ends
		// Do not modify the ports beyond this line

		// Global ports
		input wire  M_AXIS_ACLK,
		// 
		input wire  M_AXIS_ARESETN,
		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
		output wire  M_AXIS_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
		// TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
		// TLAST indicates the boundary of a packet.
		output wire  M_AXIS_TLAST,
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		input wire  M_AXIS_TREADY
	);
                           

	// Add user logic here
	   reg [C_M_AXIS_TDATA_WIDTH-1 : 0] data_in;
	   reg m_axis_valid;
	   reg m_axis_valid_1;
	   reg m_axis_valid_2;
	   reg m_axis_valid_3;
           always @(posedge M_AXIS_ACLK or negedge M_AXIS_ARESETN)
	   begin
           	if (!M_AXIS_ARESETN)
           	begin
		         data_in <= 31'b0;
		         m_axis_valid <= 0;
		         m_axis_valid_1 <= 0;
		         m_axis_valid_2 <= 0;
		         m_axis_valid_3 <= 0;
           	end
           	else if (AXIS_MASTER_VALID && M_AXIS_TREADY)
           	begin
		         data_in <= AXIS_MASTER_DATA_IN;
		         m_axis_valid_1 <= AXIS_MASTER_VALID;
		         m_axis_valid_2 <= m_axis_valid_1;
		         m_axis_valid_3 <= m_axis_valid_2;
		         m_axis_valid   <= m_axis_valid_3;
           	end
           	     else
           	     begin
                 data_in        <= data_in;
                 m_axis_valid_1 <= 0;
                 m_axis_valid_2 <= m_axis_valid_1;
                 m_axis_valid_3 <= m_axis_valid_2;
                 m_axis_valid   <= m_axis_valid_3;
                 end
           end
                assign  AXIS_MASTER_READY = M_AXIS_TREADY;
                assign  M_AXIS_TVALID     = m_axis_valid;
		        assign  M_AXIS_TDATA      = data_in;
	// User logic ends

	endmodule
