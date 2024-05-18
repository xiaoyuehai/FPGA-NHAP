module CP_Controler_FSM(
	input wire CLK,
	input wire RST_N,
	input wire [3:0] Main_FSM_state,
	input wire event_fifo_empty,
	input wire RD_Done,

	output wire CP_IN_WAIT,
	output wire CP_IN_DDR_PRE,
	output wire CP_IN_DDR_READ,
	output wire CP_IN_DDR_READ_Finish,
	output wire CP_IN_Check_Empty

	);

	localparam WAIT = 4'd0;
	localparam Check_Empty = 4'd1;
	localparam DDR_PRE = 4'd2;
	localparam DDR_READ = 4'd3;
	localparam DDR_READ_Finish = 4'd4;

	reg [3:0] state,nextstate;

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			state <= WAIT;
		end
		else begin
			state <= nextstate;
		end
	end

	always@(*)begin
		case(state)
			WAIT:begin
				if(Main_FSM_state == 4'd2)begin
					nextstate <= Check_Empty;
				end
				else begin
					nextstate <= WAIT;
				end
			end

			Check_Empty:begin
				if(!event_fifo_empty)begin
					nextstate <= DDR_PRE;
				end
				else if(Main_FSM_state == 4'd0)begin
					nextstate <= WAIT;
				end
				else begin
					nextstate <= Check_Empty;
				end
			end

			DDR_PRE:begin
				nextstate <= DDR_READ;
			end

			DDR_READ:begin
				if(RD_Done)begin
					nextstate <= DDR_READ_Finish;
				end
				else begin
					nextstate <= DDR_READ;
				end
			end

			DDR_READ_Finish:begin
				if(Main_FSM_state == 4'd3)begin
					nextstate <= Check_Empty;
				end
				else begin
					nextstate <= DDR_READ_Finish;
				end
			end
		endcase
	end

	assign CP_IN_WAIT = (state == WAIT);
	assign CP_IN_DDR_PRE = (state == DDR_PRE);
	assign CP_IN_DDR_READ = (state == DDR_READ);
	assign CP_IN_Check_Empty = (state == Check_Empty);
	assign CP_IN_DDR_READ_Finish = (state == DDR_READ_Finish);

	

endmodule