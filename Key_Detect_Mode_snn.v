module Key_Detect_Mode(
	input wire CLK,
	input wire RST_N,
	input wire Key_Signal,

	output reg 		 Run_Mode,
	output reg 		 LED_Show_Config,
	output reg	     LED_Show_Car
	);

localparam Config_Weight = 1'd0;
localparam CarPlatter_TEST = 1'd1;

wire Key_Signal_Posedge;
reg  Key_Signal_int,Key_Signal_delay;
reg  Mode_Count;

assign Key_Signal_Posedge = Key_Signal_int & ~Key_Signal_delay;

always@(posedge CLK or negedge RST_N)begin
	if(!RST_N)begin
		Key_Signal_int <= 1;
		Key_Signal_delay <= 1;
	end
	else begin
		Key_Signal_int <= Key_Signal;
		Key_Signal_delay <= Key_Signal_int;
	end
end

always@(posedge CLK or negedge RST_N)begin
	if(!RST_N)begin
		Mode_Count <= 0;
	end
	else if(Key_Signal_Posedge)begin
		Mode_Count <= Mode_Count + 1;
	end
	else begin
		Mode_Count <= Mode_Count;
	end
end

always@(posedge CLK or negedge RST_N)begin
	if(!RST_N)begin
		Run_Mode <= Config_Weight;
		LED_Show_Config <= 1;
		LED_Show_Car   <= 0;
	end
	else begin
		case(Mode_Count)
			0:		begin 
				`ifdef JUST_for_SIMULATION
					Run_Mode <= Config_Weight;     
				`else
					Run_Mode <= CarPlatter_TEST; 
				`endif
				LED_Show_Config <= 0;LED_Show_Car <= 1;
			end
			1:		begin Run_Mode <= CarPlatter_TEST;	 LED_Show_Config <= 1;LED_Show_Car <= 0;end
			// 2:		begin Run_Mode <= Config_Weight;     LED_Show_Config <= 1;LED_Show_Car <= 0;end
			// 3:		begin Run_Mode <= CarPlatter_TEST;LED_Show_Config <= 0;LED_Show_Car <= 1;end
			default:
					begin Run_Mode <= Config_Weight;     LED_Show_Config <= 1;LED_Show_Car <= 0;end
		endcase
	end
end

endmodule