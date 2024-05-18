/**
  ******************************************************************************
  * File Name          : top_Mine_CYHSNN.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : ????????
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
`define use_car
module top_Mine_CYHSNN #(
    parameter N = 2048,                     //?????????????
    parameter M = 10,                       //?????
    parameter Input_ADDR_W = 12,            //????????????1024???
    parameter Process_time = 19,            //???????????? Process_time * 100 uS
    parameter All_time = 500,               //???????????? All_time * 100 uS
    parameter process_isi = 19,             //?????????? ??????Process_time??
    parameter Input = 256,                  //??????
    parameter input_neuron = 1024,


    ////////?????
    //SNN_Process
    parameter TIME_MUL = 16,                //???????????
    parameter INPUT_SYN_NUMS_WIDTH = 14,    //?????????
    parameter NEUR_STATE_WIDTH = 40,        //??????????
    parameter event_out_WIDTH = 7,
    parameter MEMPOTENTIAL_WIDTH = 20,       //????????
    parameter REC_WIDTH = 3,                //??????????????
    parameter MEM_THRESHOLD_WIDTH = 20,      //??????????
    parameter FIXED_WIDTH = 12,             //??????
    parameter TIME_STAMP_WIDTH = 4,         //?????

    //UDP
    parameter HANG_LEN = 64,                //????????????????
    parameter HANG_LEN_B = 6,               //??????????????????
    parameter Synapse_SRAM_DEEPTH = 181248, //????????
    parameter Synapse_SRAM_DEEPTH_W = 18,   //????
    parameter TREF_NEED_CTRL_CNT = 194,

    //attention
    parameter real_input_neuron = 1024,       //????????
    parameter input_len         = 12,
    parameter SYNAPSE_DATA_WIDTH = 256,      //????????
    parameter SYN_WEIGHT_WIDTH = 16,         //??????
    parameter MUL_ADDR_NUMS = 64,            //????
    parameter MUL_NEUR_ADDR_WIDTH = 10,      //??????
    parameter SYNAPSE_WIDTH = 32,            //?????????
    parameter REAL_INPUT_NEUR_WIDTH = 12,    //?????????????SCHE_DATA_OUT?????
    parameter REAL_HANG_WIDTH = 6            //??????????????????

)
(
    /////eth_udp_pin
    // input              sys_rst_n , //???????????? 
    //PL???RGMII??
    input   wire [31:0]  haddr,      
    input   wire        hclk,        
    input   wire[3 :0]  hprot,        
    input   wire        hrst_b,       
    input   wire        hsel,        
    input   wire[2 :0]  hsize,        
    input   wire[1 :0]  htrans,       
    input   wire[31:0]  hwdata,       
    input   wire        hwrite,       
    output  wire[31:0]  hrdata,       
    output  wire        hready,  
    output  wire[1 :0]  hresp,   
    output		    intr,    

    input              eth_rxc   , //RGMII??????
    input              eth_rx_ctl, //RGMII????????
    input       [3:0]  eth_rxd   , //RGMII????
    output             eth_txc   , //RGMII??????    
    output             eth_tx_ctl, //RGMII????????
    output      [3:0]  eth_txd   , //RGMII????          
    output             eth_rst_n,   //???????????????
    input      wire eth_clk,
    /////
    // input wire CLK_20M,
    input  wire SNN_CLK,
    input  wire RST_N,
    input  wire uart_rx,
    output wire fifo_full,
    output wire fifo_empty,
    output wire uart_tx1,
    output wire Tx_done1,
    input  wire Key_Signal,
    output wire LED_Show_Config,
    output wire LED_Show_Car,

    //DDR3 Channel
    output wire [31:0] RD_ADRS,
    input  wire        RD_DONE,
    input  wire [255:0]RD_FIFO_DATA,
    input  wire        RD_FIFO_WE,
    output wire [31:0] RD_LEN,
    output wire        RD_START,
    input  wire                     uart_rx_neuron,
    output wire                     uart_tx_neuron

);

wire        one_time_finish;
wire 		calca_start;
wire        bram_we;
wire [10:0] bram_addr;
wire [31:0] bram_wdata; 
wire      SoC_Test_Choose;
wire      Counter_Clear;
wire [31:0] Process_ALL_Time_set;

wire [3:0] result_class;

wire [31:0] Big_time;
wire [31:0] Small_time;

wire [31:0] Events_Nums_Read;
wire        Spiking_Neuron_Model;

AHB_DMA_Pixel AHB_DMA_Pixel(
    .SNN_CLK(SNN_CLK),
	.haddr(haddr),
    .hclk(hclk),
    .hready(hready),
    .hrst_b(hrst_b),
    .hsel(hsel),
    .hwdata(hwdata),
    .hwrite(hwrite),
    .intr(intr),
    .hresp(hresp),
    .hrdata(hrdata),

    .calca_start(calca_start),//SNN ????????
    .bram_we(bram_we),    //Bram???
    .bram_addr(bram_addr),  //bram???
    .bram_wdata(bram_wdata), //bram???
    .one_time_finish(one_time_finish),//????????uart_time??.

    .SoC_Test_Choose(SoC_Test_Choose),//????????0?uart 1:SoC
    .Counter_Clear(Counter_Clear),   //?????
    .result_class(result_class),
    .Process_ALL_Time_set(Process_ALL_Time_set),
    .Big_time(Big_time),
    .Small_time(Small_time),
    .Events_Nums_Read(Events_Nums_Read),
    .Spiking_Neuron_Model(Spiking_Neuron_Model)
	);

wire Hundred_US_CLK;
wire Memory_CLK;
wire [7:0] dout_pixel/* synthesis syn_keep=1 */;
wire global_leak_time;

wire [31:0] Neuron0_Spike_Counter;
wire [31:0] Neuron1_Spike_Counter;
wire [31:0] Neuron2_Spike_Counter;
wire [31:0] Neuron3_Spike_Counter;
wire [31:0] Neuron4_Spike_Counter;
wire [31:0] Neuron5_Spike_Counter;
wire [31:0] Neuron6_Spike_Counter;
wire [31:0] Neuron7_Spike_Counter;
wire [31:0] Neuron8_Spike_Counter;
wire [31:0] Neuron9_Spike_Counter;

wire [Input_ADDR_W - 1:0] ADDR_PIXEL_uart;
wire       AER_BUSY_uart;

wire AERIN_ACK,AERIN_REQ;
wire [15:0] AERIN_ADDR;

wire [13:0] AER_OUT_ADDR;
wire AER_OUT_REQ;
reg AER_OUT_ACK;
wire uart_tx_decoder,uart_tx_coder;
wire Tx_done_decode;
wire CLK_200M;

wire [Synapse_SRAM_DEEPTH_W-1:0] Synapse_SRAM_ADDR/* synthesis syn_keep=1 */;
wire        Synapse_Sram_We;
wire [SYNAPSE_DATA_WIDTH-1:0] fifo_data_out;

wire udp_rec_clk;

wire [14:0] AER_ADDR;
wire Run_Mode;

`ifndef use_car
    assign Run_Mode = 0;
    assign LED_Show_Config = 1;
    assign LED_Show_Car = 0;
`endif

wire rec_en_out;
wire [7:0] rec_data_out;
wire tx_req;
wire tx_udp;
wire [7:0] car_tx_data;

wire Encode_CLK_Car;
wire [7:0] dout_pixel_Car;
wire global_leak_time_car;
wire udp_tx_clk;

assign uart_tx1 = uart_tx_coder;
wire cal;
wire car_cal;
wire Memory_CLK_Car;

wire                     encode_finish;
wire [3:0]               encode_stamp;
wire                     encode_event_generate;

wire  one_layer_time_driver_uart;
wire  one_layer_time_driver_udp; 

uart_and_time #(
    .Input_ADDR_W(Input_ADDR_W),
    .Process_time(Process_time),
    .All_time(All_time),
    .input_neuron(real_input_neuron)
)
tran_uart_and_time
(
    .one_layer_time_driver(one_layer_time_driver_uart),
    .result_num(result_class),
    .SNN_CLK(SNN_CLK),
    .RST_N(~Run_Mode ?(RST_N):0),
    .uart_rx(uart_rx),
    .addrb(~Run_Mode? ADDR_PIXEL_uart:0),
    .AER_BUSY(~Run_Mode?AER_BUSY_uart:1),

    .Neuron_0_Counter(Neuron0_Spike_Counter[7:0]),
    .Neuron_1_Counter(Neuron1_Spike_Counter[7:0]),
    .Neuron_2_Counter(Neuron2_Spike_Counter[7:0]),
    .Neuron_3_Counter(Neuron3_Spike_Counter[7:0]),
    .Neuron_4_Counter(Neuron4_Spike_Counter[7:0]),
    .Neuron_5_Counter(Neuron5_Spike_Counter[7:0]),
    .Neuron_6_Counter(Neuron6_Spike_Counter[7:0]),
    .Neuron_7_Counter(Neuron7_Spike_Counter[7:0]),
    .Neuron_8_Counter(Neuron8_Spike_Counter[7:0]),
    .Neuron_9_Counter(Neuron9_Spike_Counter[7:0]),

    .encode_event_generate(encode_event_generate),

    .dout_pixel(dout_pixel),
    .fifo_full(fifo_full),
    .fifo_empty(fifo_empty),
    .uart_tx1(uart_tx_coder),
    .Tx_done1(Tx_done1),
    .Hundred_US_CLK_out(Hundred_US_CLK),
    .Memory_CLK_out(Memory_CLK),
    .cal(cal),
    .global_leak_time_out(global_leak_time),

    .one_time_finish(one_time_finish),
	.calca_start(calca_start),
	.bram_we(bram_we),
	.bram_addr(bram_addr),
	.bram_wdata(bram_wdata), 
    .SoC_Test_Choose(SoC_Test_Choose),
    .hclk(hclk),
    .Process_ALL_Time_set(Process_ALL_Time_set)
    );

wire global_leak_time_posedge;
reg global_leak_time_reg;
wire [31:0] Max_Neuron_Index;

always@(posedge SNN_CLK or negedge RST_N) begin
    if(!RST_N)begin
        global_leak_time_reg <= 0; 
    end
    else begin
        global_leak_time_reg <= global_leak_time;
    end 
end 

assign global_leak_time_posedge = global_leak_time & !global_leak_time_reg;

`ifdef JUST_for_SIMULATION
    Get_Max i_Get_Max(
        .CLK(SNN_CLK),
        .RST_N(RST_N),
        .Get_Max_Index(global_leak_time_posedge),
        .Neuron_0_Counter(Neuron0_Spike_Counter),
        .Neuron_1_Counter(Neuron1_Spike_Counter),
        .Neuron_2_Counter(Neuron2_Spike_Counter),
        .Neuron_3_Counter(Neuron3_Spike_Counter),
        .Neuron_4_Counter(Neuron4_Spike_Counter),
        .Neuron_5_Counter(Neuron5_Spike_Counter),
        .Neuron_6_Counter(Neuron6_Spike_Counter),
        .Neuron_7_Counter(Neuron7_Spike_Counter),
        .Neuron_8_Counter(Neuron8_Spike_Counter),
        .Neuron_9_Counter(Neuron9_Spike_Counter),

        .Max_Neuron_Index(Max_Neuron_Index)

        );
`endif

encoder_Neuron #(
    .Input(Input),
    .N(N),
    .M(M),
    .Input_ADDR_W(Input_ADDR_W),
    .process_isi(process_isi),
    .input_neuron(input_neuron)
) encoder(
    .RST_N(~Run_Mode?(RST_N & cal):(RST_N & car_cal)),
    .CLK(SNN_CLK),
    .encode_CLK(~Run_Mode?Hundred_US_CLK:Encode_CLK_Car),
    .AER_ACK(AERIN_ACK),
    .pixel_value(~Run_Mode? dout_pixel:dout_pixel_Car),
    .timestamp(encode_stamp),

    .AER_ADDR(AERIN_ADDR),
    .AER_REQ(AERIN_REQ),
    .AER_BUSY_out(AER_BUSY_uart),
    .ADDR_PIXEL(ADDR_PIXEL_uart),
    .encode_finish(encode_finish)

);

// PC_decode PC_decode0(
// 	.CLK(CLK_100M),
// 	.RST_N(use_AER_Package?RST_N:0),
// 	.uart_rx(uart_rx),
// 	.AER_ACK(AERIN_ACK),
//     .Neuron_data0(Neuron0_Spike_Counter[7:0]),
//     .Neuron_data1(Neuron1_Spike_Counter[7:0]),
//     .Neuron_data2(Neuron2_Spike_Counter[7:0]),
//     .Neuron_data3(Neuron3_Spike_Counter[7:0]),
//     .Neuron_data4(Neuron4_Spike_Counter[7:0]),
//     .Neuron_data5(Neuron5_Spike_Counter[7:0]),
//     .Neuron_data6(Neuron6_Spike_Counter[7:0]),
//     .Neuron_data7(Neuron7_Spike_Counter[7:0]),
//     .Neuron_data8(Neuron8_Spike_Counter[7:0]),
//     .Neuron_data9(Neuron9_Spike_Counter[7:0]),

// 	.uart_tx(uart_tx_decoder),
// 	.AER_ADDR(AER_ADDR),
// 	.AER_REQ(AER_REQ_decode),
//     .Tx_done(Tx_done_decode)
// 	);
// // wire car_cal;
// // wire Memory_CLK_Car;

wire global_to_zero;
wire udp_tx_done_source;
SNN_Process #(
	.N(N),
	.M(M),
    .SYNAPSE_DATA_WIDTH(SYNAPSE_DATA_WIDTH),        //????????
    .TIME_MUL(TIME_MUL),                            //???????????
    .MUL_ADDR_NUMS(MUL_ADDR_NUMS),                  //????
    .MUL_NEUR_ADDR_WIDTH(MUL_NEUR_ADDR_WIDTH),      //??????
    .INPUT_SYN_NUMS_WIDTH(INPUT_SYN_NUMS_WIDTH),    //?????????
    .NEUR_STATE_WIDTH(NEUR_STATE_WIDTH),            //??????????
    .event_out_WIDTH(event_out_WIDTH),
    .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),            //??????
    .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),        //????????
    .REC_WIDTH(REC_WIDTH),                          //??????????????
    .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH),      //??????????
    .FIXED_WIDTH(FIXED_WIDTH),                      //??????
    .SYNAPSE_WIDTH(SYNAPSE_WIDTH),                  //?????????
    .TIME_STAMP_WIDTH(TIME_STAMP_WIDTH),            //?????
    .REAL_INPUT_NEUR_WIDTH(REAL_INPUT_NEUR_WIDTH),  //?????????????SCHE_DATA_OUT?????
    .REAL_HANG_WIDTH(REAL_HANG_WIDTH),              //????????????????
    .Synapse_SRAM_DEEPTH(Synapse_SRAM_DEEPTH),
    .TREF_NEED_CTRL_CNT(TREF_NEED_CTRL_CNT),
    .Input_Neuron(input_neuron-1)
) SNN_Process_New(
    .Events_Nums_Read(Events_Nums_Read),
    .result_num(result_class),
    .Run_Mode(Run_Mode),
    .udp_tx_done_source(udp_tx_done_source),
    .RD_ADRS(RD_ADRS),
    .RD_DONE(RD_DONE),
    .RD_FIFO_DATA(RD_FIFO_DATA),
    .RD_FIFO_WE(RD_FIFO_WE),
    .RD_LEN(RD_LEN),
    .RD_START(RD_START),
    // Global input     -------------------------------
    .All_Time_RST_N(RST_N),
    .one_layer_time_driver(~Run_Mode? one_layer_time_driver_uart:one_layer_time_driver_udp),
    .global_leak_time(~Run_Mode? global_leak_time:global_leak_time_car),
    .Train_signal(1'b0),
    .CLK(SNN_CLK),
    .encode_CLK(Hundred_US_CLK),
    .RST(~Run_Mode?(~RST_N | ~cal):(~RST_N | ~car_cal)),
    // .Neuron_Out_Spike(Neuron_Out_Spike),
	// Input 16-bit AER -------------------------------
	.AERIN_ADDR(AERIN_ADDR),//17 bit 
	.AERIN_REQ(AERIN_REQ),
	.AERIN_ACK(AERIN_ACK),

	// Output 8-bit AER -------------------------------
	.AER_OUT_ADDR(AER_OUT_ADDR),
	.AER_OUT_REQ(AER_OUT_REQ),
	.AER_OUT_ACK(AER_OUT_ACK),
    .Memory_CLK(~Run_Mode?Memory_CLK:Memory_CLK_Car),
    .Neuron0_Spike_Counter(Neuron0_Spike_Counter),
    .Neuron1_Spike_Counter(Neuron1_Spike_Counter),
    .Neuron2_Spike_Counter(Neuron2_Spike_Counter),
    .Neuron3_Spike_Counter(Neuron3_Spike_Counter),
    .Neuron4_Spike_Counter(Neuron4_Spike_Counter),
    .Neuron5_Spike_Counter(Neuron5_Spike_Counter),
    .Neuron6_Spike_Counter(Neuron6_Spike_Counter),
    .Neuron7_Spike_Counter(Neuron7_Spike_Counter),
    .Neuron8_Spike_Counter(Neuron8_Spike_Counter),
    .Neuron9_Spike_Counter(Neuron9_Spike_Counter),

    ///////udp_write_sram
    .Synapse_SRAM_ADDR(Synapse_SRAM_ADDR),
    .Synapse_Sram_We(Synapse_Sram_We),
    .fifo_data_out(fifo_data_out),

    .tx_req(tx_req),
    .udp_clk(udp_tx_clk),
    .tx_data(car_tx_data),

    .encode_finish(encode_finish),
    .encode_stamp(encode_stamp),
    .encode_event_generate(encode_event_generate),
    .global_to_zero(global_to_zero),
    .Big_time(Big_time),
    .Small_time(Small_time),
    .uart_rx_neuron(uart_rx_neuron),
    .uart_tx_neuron(uart_tx_neuron),
    .Spiking_Neuron_Model(Spiking_Neuron_Model)

);

udp_top_snn #(
    .SYNAPSE_DATA_WIDTH(SYNAPSE_DATA_WIDTH),
    .SYNAPSE_WIDTH(SYNAPSE_WIDTH),
    .HANG_LEN(HANG_LEN),
    .HANG_LEN_B(HANG_LEN_B),
    .Synapse_SRAM_DEEPTH(Synapse_SRAM_DEEPTH),
    .Synapse_SRAM_DEEPTH_W(Synapse_SRAM_DEEPTH_W)
)udp_top0_snn(
    // input              sys_clk   , //????
    .sys_rst_n (RST_N), //???????????? 
    //PL???RGMII??   
    .eth_rxc   (eth_rxc), //RGMII??????
    .eth_rx_ctl(eth_rx_ctl), //RGMII????????
    .eth_rxd   (eth_rxd), //RGMII????
    .eth_txc   (eth_txc), //RGMII??????    
    .eth_tx_ctl(eth_tx_ctl), //RGMII????????
    .eth_txd   (eth_txd), //RGMII????          
    .eth_rst_n (eth_rst_n),   //???????????????

    /////????
    .clk_200m(eth_clk),

    /////car
    .car_module_tx(tx_udp),
    .car_module_tx_num(16'd100),
    .car_module_tx_data(car_tx_data),
    .udp_rec_clk_out(udp_rec_clk),
    .udp_tx_clk(udp_tx_clk),
    .rec_en_out(rec_en_out),
    .rec_data_out(rec_data_out),
    .tx_req(tx_req),
    .udp_tx_done_source(udp_tx_done_source),
    .SNN_CLK(SNN_CLK)
);

`ifdef use_car
Car_DataStream_SNN #(
    .All_time(All_time),
	.Process_time(Process_time),
    .real_input_neuron(real_input_neuron),
    .input_len(input_len)
)Car_DataStream0(
        .one_layer_time_driver(one_layer_time_driver_udp),
		.CLK(SNN_CLK),
		.RST_N(RST_N),

		.Key_Signal(Key_Signal),

		.udp_rec_clk(udp_rec_clk),
		.rec_data(rec_data_out),//rec_data_out
		.rec_en(rec_en_out),//rec_en_out

		.LED_Show_Config(LED_Show_Config),
		.LED_Show_Car(LED_Show_Car),
		.Run_Mode(Run_Mode),
        .tx_udp_out(tx_udp),

        .Encode_CLK_Car(Encode_CLK_Car),
		.ADDR_PIXEL(Run_Mode?ADDR_PIXEL_uart:0),
		.AER_BUSY(Run_Mode?AER_BUSY_uart:1),
		.dout_pixel(dout_pixel_Car),
        .global_leak_time_car(global_leak_time_car),
        .car_cal(car_cal),
		.Memory_CLK_out(Memory_CLK_Car),
        .encode_event_generate(encode_event_generate),
        .udp_tx_done_source(udp_tx_done_source),
        .global_to_zero(global_to_zero),
        .udp_tx_clk(udp_tx_clk),
        .Process_ALL_Time_set(Process_ALL_Time_set)
	);
    `endif 

reg AER_REQ_int,AER_REQ_syn;
always @(posedge SNN_CLK , negedge RST_N) begin
    if(!RST_N)begin
        AER_REQ_int <= 1'b0;
        AER_REQ_syn <= 1'b0;
    end
    else begin
        AER_REQ_int <= AER_OUT_REQ;
        AER_REQ_syn <= AER_REQ_int;
    end
end

always@(posedge SNN_CLK,negedge RST_N)begin
   if(!RST_N)begin
       AER_OUT_ACK <= 1'b0;
   end
   else if(AER_REQ_syn) begin
       AER_OUT_ACK <= 1'b1;
   end 
   else begin
       AER_OUT_ACK <= 1'b0;
   end
end

endmodule