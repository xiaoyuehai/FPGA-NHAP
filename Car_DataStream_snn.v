module Car_DataStream_SNN#(
	parameter All_time = 25,
	parameter Process_time = 24,
	parameter real_input_neuron = 3072,
	parameter input_len = 12
)(
		input wire CLK,
		input wire udp_tx_clk,
		input wire RST_N,

		input wire Key_Signal,

		input wire udp_rec_clk,
		input wire [7:0] rec_data,
		input wire 		 rec_en,

		output wire LED_Show_Config,
		output wire LED_Show_Car,
		output wire Run_Mode,
		output wire tx_udp_out,

		output wire Encode_CLK_Car,
		input wire [11:0] ADDR_PIXEL,
		input wire AER_BUSY,
		output wire [7:0] dout_pixel,
		output wire global_leak_time_car,
		output reg  car_cal,
		output wire Memory_CLK_out,
		input wire encode_event_generate,
		input wire udp_tx_done_source,
		input wire global_to_zero,
		input wire [31:0] Process_ALL_Time_set,
		output wire one_layer_time_driver
);
	reg tx_udp;
	wire rec_en_car;
	reg [3:0]state,next_state;
    reg fifo_read;
    wire write_fifo_full_clr;
    reg triger_flag;
    reg temp_flag;
    wire write_fifo_full;
	reg SNN_Process_signal;
	wire [7:0] fifo_data_out;
	reg Hundred_US_CLK;
	reg [31:0] Hundred_US_counter;

	reg [31:0] ctrl_cnt;
	reg ADDR_W_clr;
	reg global_leak_time;
	reg [31:6] process_cnt;
	wire finish;
	wire [7:0] dout_pixel_car;

	assign dout_pixel = global_leak_time?0:dout_pixel_car;

	assign Encode_CLK_Car = Hundred_US_CLK;
	assign global_leak_time_car = global_leak_time;


	Key_Detect_Mode Key_Detect(
	.CLK(CLK),
	.RST_N(RST_N),
	.Key_Signal(Key_Signal),

	.Run_Mode(Run_Mode),
	.LED_Show_Config(LED_Show_Config),
	.LED_Show_Car(LED_Show_Car)
	);

	assign rec_en_car = Run_Mode?rec_en:0;

	nsync_fifo #(
    .SRAM_DATA_W(8),                		//写入存储器的数据位宽
    .SRAM_DATA_BYTES(1),            		//单位数据共多少个字节
    .SRAM_DATA_BYTES_B(1),           		//字节个数的二进制表示
    .HANG_LEN(real_input_neuron),                   		//单次传输共多少个数据
    .HANG_LEN_B(input_len)                  		//单次传输数据总数的二进制表示
    )
    fifo_0 (
        .src_clk(udp_rec_clk),              //数据输入时钟
        .rst_n(RST_N),                      //全局清零信号
        .des_clk(CLK),                      //数据读取时钟
        .fifo_data_in(rec_data),            //输入单字节数据
        .fifo_data_in_vaild(rec_en_car),    //输入数据有效信号

        .fifo_read(fifo_read),              //FIFO读信号
        .fifo_data_out_vaild(),             //读数据有效信号
        .fifo_data_out(fifo_data_out) ,     //FIFO读取的数据
        .read_fifo_empty(),
        .write_fifo_full(write_fifo_full)
    );

	reg [11:0] ADDR_W;
	reg Pixel_We;

    virtual_SRAM Car_Pixels(
	  .clka(CLK),    						// input wire clka
	  .ena(1),      						// input wire ena
	  .wea(Pixel_We),      					// input wire [0 : 0] wea
	  .addra(ADDR_W),  						// input wire [10 : 0] addra
	  .dina(fifo_data_out),    				// input wire [7 : 0] dina

	  .clkb(CLK),   					    // input wire clkb
	  .enb(~AER_BUSY),      							// input wire enb
	  .addrb(ADDR_PIXEL),  							// input wire [10 : 0] addrb
	  .doutb(dout_pixel_car)  							// output wire [7 : 0] doutb
	);

	localparam IDLE = 0;
	localparam Start_Process = 1;
	localparam POP_400_Pixel = 2;
	localparam POP_Save_Finish = 3;
	localparam WAIT_FINISH = 4;

	assign write_fifo_full_clr = !RST_N | triger_flag;

    always@(posedge write_fifo_full or posedge write_fifo_full_clr)begin
        if(write_fifo_full_clr)begin
            temp_flag <= 0;
        end
        else begin
            temp_flag <= 1;
        end
    end

    always@(posedge CLK or negedge RST_N)begin
        if(!RST_N)begin
            triger_flag <= 0;
        end
        else begin
            triger_flag <= temp_flag;
        end
    end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			state <= IDLE;
		end
		else begin
			state <= next_state;
		end
	end

	reg [31:0] pixel_count;
	reg compare_result;

	always @(posedge CLK or negedge RST_N) begin
		if(!RST_N | state == Start_Process)begin
			pixel_count <= 0;
		end
		else if(Pixel_We)begin
			if(fifo_data_out != 0)begin
				pixel_count <= pixel_count + 1;
			end
			else begin
				pixel_count <= pixel_count;
			end
		end
		else if(global_leak_time)begin
			pixel_count <= 0;
		end	
		else begin
			pixel_count <= pixel_count;
		end
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			compare_result <= 0;
		end
		else if(pixel_count > 300)begin
			compare_result <= 1;
		end
		else begin
			compare_result <= 0;
		end
	end

	assign one_layer_time_driver = compare_result;

	always@(*)begin
		SNN_Process_signal = 0;
		// tx_udp = 0;
		case(state)
			IDLE:begin
				if(triger_flag)begin
					next_state = Start_Process;
				end
				else begin
					next_state = IDLE;
				end
			end

			Start_Process:begin
				SNN_Process_signal = 0;
				ADDR_W_clr = 1;
				next_state = POP_400_Pixel;
			end

			POP_400_Pixel:begin
				ADDR_W_clr = 0;
				if(ctrl_cnt == real_input_neuron)begin
					next_state = POP_Save_Finish;
				end
				else begin
					next_state = POP_400_Pixel;
				end
			end

			POP_Save_Finish:begin
				if(global_leak_time)begin
					// tx_udp = 0;
					next_state = WAIT_FINISH;
				end
				else begin
					// tx_udp = 0;
					next_state = POP_Save_Finish;
				end
			end

			WAIT_FINISH:begin
				// tx_udp = 0;
				// SNN_Process_signal = 1;
				if(finish)begin
						next_state = IDLE;
						SNN_Process_signal = 0;
				end
				else begin
					next_state = WAIT_FINISH;
					// tx_udp = 0;
				end
			end

		endcase
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			process_cnt <= 0;
		end
		else if(state == IDLE)begin
			process_cnt <= 0;
		end
		else if(SNN_Process_signal)begin
			process_cnt <= process_cnt + 1;
		end
		else begin
			process_cnt <= process_cnt;
		end
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			ctrl_cnt <= 0;
		end
		else if(next_state == POP_400_Pixel)begin
			ctrl_cnt <= ctrl_cnt + 1;
		end
		else begin
			ctrl_cnt <= 0;
		end
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			ADDR_W <= 0;
		end
		else if(ADDR_W_clr)begin
			ADDR_W <= 0;
		end
		else if(state == POP_400_Pixel) begin
			ADDR_W <= ADDR_W + 1;
		end
		else begin
			ADDR_W <= ADDR_W;
		end
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			Pixel_We <= 0;
		end
		else if(next_state == POP_400_Pixel)begin
			Pixel_We <= 1;
		end
		else begin
			Pixel_We <= 0;
		end
	end

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			fifo_read <= 0;
		end
		else if(next_state == Start_Process)begin
			fifo_read <= 1;
		end
		else if(ctrl_cnt == real_input_neuron-1) begin
			fifo_read <= 0;
		end
		else begin
			fifo_read <= fifo_read;
		end
	end
	reg [31:0] fifty_Ms_counter;
	always@(posedge CLK or negedge RST_N)begin
	    if(!RST_N | (state != POP_Save_Finish && state != WAIT_FINISH))begin
	        Hundred_US_CLK <= 1'b0;
	    end
	    else if(fifty_Ms_counter == 0 || encode_event_generate)begin
	       	Hundred_US_CLK <= 1'b1;
	    end
	    else begin
	        Hundred_US_CLK <= 0;
	    end
	end

	
	// reg global_leak_time;
	reg Memory_CLK;
	reg udp_tx_done_source_cap;
	always @(posedge CLK or negedge RST_N)begin
		tx_udp <= 0;
	    if(!RST_N | (state != POP_Save_Finish && state != WAIT_FINISH))begin
	        fifty_Ms_counter <= 0;
	        global_leak_time <= 0;
	        Memory_CLK       <= 0;
			car_cal <= 0;
	    end
	    else if(Hundred_US_CLK)begin
	        if(fifty_Ms_counter == Process_time + 1)begin
	           	fifty_Ms_counter <= 0; 
	           	global_leak_time <= 0;
	           	Memory_CLK <= 1;
				car_cal <= 0;
				tx_udp <= 1;
	        end
	        else if(fifty_Ms_counter == Process_time)begin
	            global_leak_time <= 1'b1;
				
	            fifty_Ms_counter <= fifty_Ms_counter + 1;
	            Memory_CLK <= 0;
				car_cal <= 1;
				// tx_udp <= 1;
	        end
			else begin
	           	fifty_Ms_counter <= fifty_Ms_counter + 1;         
	           	global_leak_time <= global_leak_time;   
	           	Memory_CLK <= 0;
			    car_cal <= 1;
	        end
	    end
	    else begin
	        Memory_CLK <= 0;
	    end
	end

	assign Memory_CLK_out = Memory_CLK;
	reg leak_1,leak_2;
	always @(posedge CLK or negedge RST_N) begin
	    if(!RST_N)begin
	       leak_1 <= 0;
	       leak_2 <= 0;
	    end
	    else begin
	       leak_1 <= global_leak_time;
	       leak_2 <= leak_1; 
	    end
	end

	assign finish = ~leak_1 & leak_2; 
	///////////////////////////////////////////////////
	wire tx_clr;
    reg tx_temp_flag;
	reg tx_result_udp;

    assign tx_clr = !RST_N | tx_result_udp;

    always@(posedge tx_udp or posedge tx_clr)begin
        if(tx_clr)begin
            tx_temp_flag <= 0; 
        end 
        else begin
            tx_temp_flag <= 1; 
        end
    end

    always @(posedge udp_tx_clk or negedge RST_N) begin
        if(!RST_N)begin
            tx_result_udp <= 0; 
        end
        else begin
            tx_result_udp <= tx_temp_flag; 
        end
    end

	assign tx_udp_out = tx_result_udp;

endmodule