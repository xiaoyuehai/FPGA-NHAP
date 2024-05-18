/**
  ******************************************************************************
  * File Name          : uart_amd_time.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 输入输出串口及加速器时钟管理单元
  * Function List      :
  * History            :
        <author>    <version>    <time>    <desc>
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; Copyright (c) 2020 XXXX.
  * All rights reserved.</center></h2>
  *
  ******************************************************************************
  */
module uart_and_time #(
    parameter Input_ADDR_W = 12,
    parameter Process_time = 99,
    parameter All_time = 149,
    parameter input_neuron = 256
)
(
    input wire [3:0] result_num,
    input wire SNN_CLK,
    input wire RST_N,
    input wire uart_rx,
    input wire [Input_ADDR_W - 1:0] addrb,
    input wire AER_BUSY,

    input wire [7:0] Neuron_0_Counter,
    input wire [7:0] Neuron_1_Counter,
    input wire [7:0] Neuron_2_Counter,
    input wire [7:0] Neuron_3_Counter,
    input wire [7:0] Neuron_4_Counter,
    input wire [7:0] Neuron_5_Counter,
    input wire [7:0] Neuron_6_Counter,
    input wire [7:0] Neuron_7_Counter,
    input wire [7:0] Neuron_8_Counter,
    input wire [7:0] Neuron_9_Counter,

    input wire encode_event_generate,

    output wire [7:0] dout_pixel,
    output wire fifo_full,
    output wire fifo_empty,
    output wire uart_tx1,
    output wire Tx_done1,
    output wire Hundred_US_CLK_out,
    output wire Memory_CLK_out,
    output wire cal,
    output wire global_leak_time_out,

    output wire        one_time_finish,
	input  wire 	   calca_start,
	input  wire        bram_we,
	input  wire [10:0] bram_addr,
	input  wire [31:0] bram_wdata, 
    input  wire        SoC_Test_Choose,
    input  wire        hclk,
    input  wire [31:0] Process_ALL_Time_set,
    output wire         one_layer_time_driver
    // wire      Counter_Clear
    );




reg Hundred_US_CLK;
(* dont_touch="true" *) reg global_leak_time;
(* dont_touch="true" *) reg [31:0] Hundred_US_counter;
(* dont_touch="true" *) reg [31:0] fifty_Ms_counter;
// wire Send_Go1;
wire locked;

wire [7:0] fifo_dout;

reg fifo_read;
reg Memory_CLK;
reg wea;
reg [15:0] addra;

(* dont_touch="true" *) reg Send_10_en;
(* dont_touch="true" *) reg Send_Go_set;
(* dont_touch="true" *) reg [3:0] send_cnt;
(* dont_touch="true" *) reg [3:0] choose_channel;
(* dont_touch="true" *) reg [7:0] choose_tx_data;

(* dont_touch="true" *) reg calculate_one_time;
(* dont_touch="true" *) wire finish;

// assign Send_Go1 = Hundred_US_CLK & (fifty_Ms_counter == 28);
assign global_leak_time_out = global_leak_time;

assign Hundred_US_CLK_out = Hundred_US_CLK;
assign Memory_CLK_out = Memory_CLK;
assign cal = calculate_one_time;

// reg [7:0] Neuron_0_Counter = 0;
// reg [7:0] Neuron_1_Counter = 1;
// reg [7:0] Neuron_2_Counter = 2;
// reg [7:0] Neuron_3_Counter = 3;
// reg [7:0] Neuron_4_Counter = 4;
// reg [7:0] Neuron_5_Counter = 5;
// reg [7:0] Neuron_6_Counter = 6;
// reg [7:0] Neuron_7_Counter = 7;
// reg [7:0] Neuron_8_Counter = 8;
// reg [7:0] Neuron_9_Counter = 9;



always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N)begin
       calculate_one_time <= 0; 
    end
    else if(finish)begin
        calculate_one_time <= 0;
    end
    else if(calca_start)begin
        calculate_one_time <= 1;
    end
    else if(fifo_empty & fifo_read) begin
        calculate_one_time <= 1;
    end
    else begin
        calculate_one_time <= calculate_one_time; 
    end
end

reg leak_1,leak_2;
always @(posedge SNN_CLK or negedge RST_N) begin
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
assign one_time_finish = finish;
uart_block #(
    .input_neuron(input_neuron)
)
uart(
    .CLK(SNN_CLK),
    .RST_N(RST_N),
    .Send_Go1((Send_Go_set | finish)),//SoC_Test_Choose?finish:(Send_Go_set | finish)
    .fifo_read(fifo_read),
    .uart_rx1(uart_rx),
    .send_data(choose_tx_data),

    .fifo_dout(fifo_dout),
    .fifo_empty(fifo_empty),
    .fifo_full(fifo_full),
    .uart_tx1(uart_tx1),
    .Tx_done1(Tx_done1)
);

wire [7:0] doutb;

virtual_SRAM virtual_SRAM_01 (
  .clka(SNN_CLK),    // input wire clka
  .ena(1'b1),      // input wire ena
  .wea(wea),      // input wire [0 : 0] wea
  .addra(addra),  // input wire [7 : 0] addra
  .dina(fifo_dout),    // input wire [7 : 0] dina


  .clkb(SNN_CLK),    // input wire clkb
  .enb(~AER_BUSY & (calculate_one_time)),      // input wire enb
  .addrb(addrb),  // input wire [7 : 0] addrb
  .doutb(doutb)  // output wire [7 : 0] doutb
);

    reg [31:0] pixel_count;
	reg compare_result;

	always @(posedge SNN_CLK or negedge RST_N) begin
		if(!RST_N)begin
			pixel_count <= 0;
		end
		else if(wea)begin
			if(fifo_dout != 0)begin
				pixel_count <= pixel_count + 1;
			end
			else begin
				pixel_count <= pixel_count;
			end
		end
		else begin
			pixel_count <= pixel_count;
		end
	end

	always@(posedge SNN_CLK or negedge RST_N)begin
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



wire [31:0] doutb_soc;
// SoC_BRAM SoC_BRAM0 (
//   .clka(hclk),    // input wire clka
//   .ena(bram_we),      // input wire ena
//   .wea(bram_we),      // input wire [0 : 0] wea
//   .addra(bram_addr),  // input wire [7 : 0] addra
//   .dina(bram_wdata),    // input wire [31 : 0] dina

//   .clkb(SNN_CLK),    // input wire clkb
//   .enb(~AER_BUSY & (calculate_one_time) & SoC_Test_Choose),      // input wire enb
//   .addrb(addrb[10:2]),  // input wire [7 : 0] addrb
//   .doutb(doutb_soc)  // output wire [31 : 0] doutb
// );


reg [10:0] temp_addr;

always@(posedge SNN_CLK or negedge RST_N)begin
    if(!RST_N)begin
        temp_addr <= 0; 
    end 
    else if(!AER_BUSY)begin
        temp_addr <= addrb; 
    end
    else begin
        temp_addr <= temp_addr; 
    end
end
reg [7:0] dout_pixel_1;

// assign dout_pixel_1 = dou
always @(*) begin
    // if(global_leak_time)begin
    //    dout_pixel = 0; 
    // end
    // else if(SoC_Test_Choose)begin
        case(temp_addr[1:0])
            2'b00:dout_pixel_1 = doutb_soc[7:0];
            2'b01:dout_pixel_1 = doutb_soc[15:8];
            2'b10:dout_pixel_1 = doutb_soc[23:16];
            2'b11:dout_pixel_1 = doutb_soc[31:24];
            default:dout_pixel_1 = 0;
        endcase
    // end
    // else begin
    //     dout_pixel = doutb;
    // end
end

// assign dout_pixel = global_leak_time?0:(!SoC_Test_Choose?doutb:dout_pixel_1);

assign dout_pixel = global_leak_time?0:doutb;


// assign fifo_read = global_leak_time?(fifo_empty?0:1):0;

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N )begin
       fifo_read <= 0; 
    end
    else if(fifo_empty)begin
        fifo_read <= 0;
    end
    else if(fifo_full)begin
        fifo_read <= 1;
    end
    else begin
        fifo_read <= fifo_read;
    end 
end

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N)begin
       wea <= 0; 
    end
    else if(fifo_empty)begin
        wea <= 0;
    end
    else if(fifo_full & fifo_read)begin
        wea <= 1;
    end
    
    else begin
        wea <= wea;
    end
end

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N)begin
       addra <= 0; 
    end
    else if(wea)begin
        addra <= addra + 1;
    end
    else begin
        addra <= 0;
    end
end

// always@(posedge SNN_CLK or negedge RST_N)begin
//     if(!RST_N | !calculate_one_time)begin
//         Hundred_US_CLK <= 1'b0;
//         Hundred_US_counter <= 0;
//     end
//     else if(Hundred_US_counter == 1)begin
//        Hundred_US_CLK <= 1'b1;
//        Hundred_US_counter <= Hundred_US_counter + 1;  
//     end
//     else if(Hundred_US_counter == 249999)begin
//        Hundred_US_CLK <= 1'b0;
//        Hundred_US_counter <= 0; 
//     end
//     else begin
//         Hundred_US_CLK <= 0;
//         Hundred_US_counter <= Hundred_US_counter + 1;
//     end
// end

always@(posedge SNN_CLK or negedge RST_N)begin
    if(!RST_N | !calculate_one_time)begin
        Hundred_US_CLK <= 1'b0;
    end
    else if(fifty_Ms_counter == 0 || encode_event_generate)begin
       Hundred_US_CLK <= 1'b1;
    end
    else begin
        Hundred_US_CLK <= 0;
    end
end

always @(posedge SNN_CLK or negedge RST_N)begin
    if(!RST_N | !calculate_one_time)begin
        fifty_Ms_counter <= 0;
        global_leak_time <= 0;
        Memory_CLK       <= 0;
    end
    else if(Hundred_US_CLK)begin
        if(fifty_Ms_counter == All_time)begin
           fifty_Ms_counter <= 0; 
           global_leak_time <= 0;
           Memory_CLK <= 1;
        end
        else if(fifty_Ms_counter == Process_time)begin
            global_leak_time <= 1'b1;
            fifty_Ms_counter <= fifty_Ms_counter + 1;
            Memory_CLK <= 0;
        end
        else begin
           fifty_Ms_counter <= fifty_Ms_counter + 1;         
           global_leak_time <= global_leak_time;   
           Memory_CLK <= 0; 
        end
    end
    else begin
        Memory_CLK <= 0;
    end
end

always@(posedge SNN_CLK or negedge RST_N)begin
   if(!RST_N | !calculate_one_time)begin
      Send_10_en <= 0; 
   end 
   else if(global_leak_time)begin
       Send_10_en <= 1;
   end
   else begin
       Send_10_en <= 0;
   end  
end

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N | !calculate_one_time)begin
       Send_Go_set <= 0;
    end
    else if(Send_10_en)begin
        if (Tx_done1 && send_cnt != 10) begin
            Send_Go_set <= 1;
        end
        else if(send_cnt == 0 && !Send_Go_set)begin
            Send_Go_set <= 1;
        end
        else begin
            Send_Go_set <= 0;
        end
    end
    else begin
       Send_Go_set <= 0; 
    end
end

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N | !calculate_one_time)begin
        send_cnt <= 0;
    end
    else if(Send_10_en)begin
        if(Send_Go_set)begin
            if(send_cnt == 9 || send_cnt == 10)begin
                send_cnt <= 10;
            end
            else begin
                send_cnt <= send_cnt + 1;
            end
        end
        else begin
            send_cnt <= send_cnt;
        end  
    end
    else begin
        send_cnt <= 0;
    end
end

always @(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N | !calculate_one_time)begin
       choose_channel <= 0; 
    end
    else if(Send_10_en)begin
        if(Tx_done1 && send_cnt != 10)begin
            choose_channel <= send_cnt;
        end
        else begin
           choose_channel <= choose_channel; 
        end
    end
    else begin
       choose_channel <= 0; 
    end 
end

always @(*) begin
    if(!RST_N | !calculate_one_time)begin
       choose_tx_data = {4'b0,result_num}; 
    end
    else if(SoC_Test_Choose)begin
       choose_tx_data = {4'b0,result_num}; 
    end
    else if(Send_10_en)begin
       case(choose_channel)
       4'd0:    choose_tx_data = Neuron_0_Counter;
       4'd1:    choose_tx_data = Neuron_1_Counter;
       4'd2:    choose_tx_data = Neuron_2_Counter;
       4'd3:    choose_tx_data = Neuron_3_Counter;
       4'd4:    choose_tx_data = Neuron_4_Counter;
       4'd5:    choose_tx_data = Neuron_5_Counter;
       4'd6:    choose_tx_data = Neuron_6_Counter;
       4'd7:    choose_tx_data = Neuron_7_Counter;
       4'd8:    choose_tx_data = Neuron_8_Counter;
       4'd9:    choose_tx_data = Neuron_9_Counter;
       default: choose_tx_data = {4'b0,result_num};
       endcase 
    end
    else begin
       choose_tx_data = {4'b0,result_num}; 
    end
end

endmodule