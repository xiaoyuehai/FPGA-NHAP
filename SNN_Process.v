/**
  ******************************************************************************
  * File Name          : SNN_Process.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : ???????????????
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
module SNN_Process #(
	parameter N = 2048,
	parameter M = 10,
    parameter SYNAPSE_DATA_WIDTH = 64,    //????????
    parameter TIME_MUL = 16,              //???????????
    parameter MUL_ADDR_NUMS = 64,         //????
    parameter MUL_NEUR_ADDR_WIDTH = 6,    //??????
    parameter INPUT_SYN_NUMS_WIDTH = 11,  //?????????
    parameter NEUR_STATE_WIDTH = 36,      //??????????
    parameter event_out_WIDTH = 7,
    parameter SYN_WEIGHT_WIDTH = 4,       //??????
    parameter MEMPOTENTIAL_WIDTH = 9,     //????????
    parameter REC_WIDTH = 3,              //??????????????
    parameter MEM_THRESHOLD_WIDTH = 9,    //??????????
    parameter FIXED_WIDTH = 12,           //??????
    parameter SYNAPSE_WIDTH = 17,         //?????????
    parameter TIME_STAMP_WIDTH = 3,       //?????
    parameter REAL_INPUT_NEUR_WIDTH = 11, //?????????????SCHE_DATA_OUT?????
    parameter REAL_HANG_WIDTH = 6,         //????????????????
    parameter Synapse_SRAM_DEEPTH = 65536,
    parameter TREF_NEED_CTRL_CNT = 69,
    parameter Input_Neuron = 3071
)(
     //DDR3 Channel
    input wire         one_layer_time_driver,
    output wire [31:0] Events_Nums_Read,
    input wire udp_tx_done_source,
    output wire [31:0] RD_ADRS,
    input  wire        RD_DONE,
    input  wire [255:0]RD_FIFO_DATA,
    input  wire        RD_FIFO_WE,
    output wire [31:0] RD_LEN,
    output wire        RD_START,
    ///////////////
    input wire                      All_Time_RST_N,
    input wire                      Train_signal,
    input wire                      Memory_CLK,
    input  wire                     global_leak_time,
    // Global input     -------------------------------
    input  wire                     CLK,
    input  wire                     encode_CLK,
    input  wire                     RST,

	// Input 16-bit AER -------------------------------
	input  wire [   15:0]           AERIN_ADDR,//17 bit 
	input  wire                     AERIN_REQ,
	
    input wire  [SYNAPSE_WIDTH-1:0] Synapse_SRAM_ADDR,
    input wire                      Synapse_Sram_We,
    input wire  [SYNAPSE_DATA_WIDTH-1:0] fifo_data_out,

    ////car platter
    input  wire                     tx_req,
    input  wire                     udp_clk,
    input  wire 	                AER_OUT_ACK,
    // Output 8-bit AER -------------------------------
	output wire[    13:0]           AER_OUT_ADDR,
	output wire 	                AER_OUT_REQ,
    output wire [31:0]              Neuron0_Spike_Counter,
    output wire [31:0]              Neuron1_Spike_Counter,
    output wire [31:0]              Neuron2_Spike_Counter,
    output wire [31:0]              Neuron3_Spike_Counter,
    output wire [31:0]              Neuron4_Spike_Counter,
    output wire [31:0]              Neuron5_Spike_Counter,
    output wire [31:0]              Neuron6_Spike_Counter,
    output wire [31:0]              Neuron7_Spike_Counter,
    output wire [31:0]              Neuron8_Spike_Counter,
    output wire [31:0]              Neuron9_Spike_Counter,
    output wire 		            AERIN_ACK,
    output wire [7:0]               tx_data,

    input  wire                     encode_finish,
    output wire [3:0]               encode_stamp,
    output wire                     encode_event_generate,
    output wire                     global_to_zero,
    input  wire Run_Mode,
    output wire [3:0]  result_num,
    output wire [31:0]              Big_time,
    output wire [31:0]              Small_time,
    input  wire                     uart_rx_neuron,
    output wire                     uart_tx_neuron,
    input  wire                     Spiking_Neuron_Model

);
    wire                 Receive_Tref,Tref_Event_Out;
    wire [15:0]          output_neuron;
    wire                 RSTN_sync;
    reg                  RST_sync_int, RST_sync, RSTN_syncn;

    // AER output
    wire                 AEROUT_CTRL_BUSY = 0;
    
    // Controller
    wire                 CTRL_SYNAPSE_PIPLINE_START;
    wire                 CTRL_PIPLINE_START;  
    wire                 CTRL_PIPELINE_CHOOSE;
    wire [ TIME_MUL-1:0] CTRL_PRE_EN;
    wire                 CTRL_NEUR_DISABLE;
    wire [        M-1:0] CTRL_NEURMEM_ADDR;
    wire                 CTRL_SYNARRAY_CS;
    wire                 CTRL_NEURMEM_CS;
    wire                 CTRL_NEUR_EVENT; 
    wire                 CTRL_NEUR_TREF;  

    wire                 CTRL_SCHED_POP_N;
    wire [        INPUT_SYN_NUMS_WIDTH-1:0] CTRL_SCHED_ADDR;
    wire [          6:0] CTRL_SCHED_EVENT_IN;
    wire                 CTRL_AEROUT_POP_NEUR;
    // wire                 CTRL_PIPELINE_CHOOSE;
    wire [MUL_NEUR_ADDR_WIDTH-1:0] ADDR_1;
    wire [MUL_NEUR_ADDR_WIDTH-1:0] ADDR_2;
    wire                 CTRL_ADDR_1_WE;
    wire                 CTRL_ADDR_2_WE;
    
    wire                 CTRL_ADDR1_READ;
    wire [SYNAPSE_WIDTH-1:0] SYNAPSE_ADDR_1/* synthesis syn_keep=1 */;
    wire [SYNAPSE_WIDTH-1:0] SYNAPSE_ADDR_2;
    wire                 CTRL_SYNAPSE_ADDR_1_WE;
    wire                 CTRL_SYNAPSE_ADDR_2_WE;
    // Synaptic core
    wire [SYNAPSE_DATA_WIDTH-1:0] SYNARRAY_RDATA;
    wire [SYNAPSE_DATA_WIDTH-1:0] SYNARRAY_WDATA;
    wire [TIME_MUL-1:0]                SYN_SIGN;
    

    // Scheduler
    wire                 SCHED_EMPTY;
    wire                 SCHED_FULL;
    wire                 SCHED_BURST_END;
    wire [13:0] SCHED_DATA_OUT;
    
   
    wire [TIME_MUL-1:0] NEUR_EVENT_OUT;
    wire [TIME_MUL-1:0] NEUR_NETWORK_OUT;

    wire [223:0 ]  network_neuron;

    wire [9:0]  MULTI_ADDR;

    wire signal_from_arbit;

    wire [TIME_MUL-1:0] spike_group;
    wire [TIME_MUL-1:0] spike_group_out;
    wire [13:0] DOUT;
    wire [TIME_MUL-1:0] empty_group;
    wire                AER_OUT_BUSY;
    wire [TIME_MUL-1:0 ]fifo_read;

    wire [TIME_STAMP_WIDTH-1:0] neurontimestamp;
    wire [TIME_STAMP_WIDTH-1:0] Input_timestamp;
    
    wire [3:0] CTRL_STATE,CTRL_NEXT_STATE;
    //----------------------------------------------------------------------------------
	//	Reset (with double sync barrier)
	//----------------------------------------------------------------------------------
    
    always @(*) begin
        RST_sync_int = RST;
		RST_sync     = RST_sync_int;
	end
    
    assign RSTN_sync = ~RST_sync;
    
    always @(*) begin
        RSTN_syncn = RSTN_sync;
    end
    
    wire tref_event_generate;
    wire fifo_0_empty,fifo_1_empty;
    

    wire [3:0] neuron_stamp;
    //----------------------------------------------------------------------------------
	//	Controller
	//----------------------------------------------------------------------------------
    wire [7:0] tx_data_empty;
    wire [7:0] tx_data_use;
    wire AER_IN_BUSY;
    assign tx_data = All_Time_RST_N?tx_data_use:tx_data_empty;

    reg         RD_DONE_reg;
    reg [255:0]RD_FIFO_DATA_reg;
    reg        RD_FIFO_WE_reg;

    always@(posedge CLK or negedge All_Time_RST_N)begin
        if(!All_Time_RST_N)begin
            RD_DONE_reg <= 0;
            RD_FIFO_DATA_reg <= 0;
            RD_FIFO_WE_reg <= 0;
        end  
        else begin
            RD_DONE_reg <= RD_DONE;
            RD_FIFO_DATA_reg <= RD_FIFO_DATA;
            RD_FIFO_WE_reg <= RD_FIFO_WE;
        end
    end

    wire event_fifo_empty;
    wire [13:0] SCHED_DATA_OUT_Next;
    wire FIFO_Read_Choose,FIFO_Write_Choose;
    controller #(
        .N(N),
        .M(M),

        .SYNAPSE_DATA_WIDTH(SYNAPSE_DATA_WIDTH),            //????????
        .TIME_MUL(TIME_MUL),                                //???????????
        .MUL_ADDR_NUMS(MUL_ADDR_NUMS),                      //????
        .MUL_NEUR_ADDR_WIDTH(MUL_NEUR_ADDR_WIDTH),          //??????
        .INPUT_SYN_NUMS_WIDTH(INPUT_SYN_NUMS_WIDTH),        //?????????
        .NEUR_STATE_WIDTH(NEUR_STATE_WIDTH),                //??????????
        .event_out_WIDTH(event_out_WIDTH),
        .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),                //??????
        .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),            //????????
        .REC_WIDTH(REC_WIDTH),                              //??????????????
        .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH),          //??????????
        .FIXED_WIDTH(FIXED_WIDTH),                          //??????
        .SYNAPSE_WIDTH(SYNAPSE_WIDTH),                      //?????????
        .TIME_STAMP_WIDTH(TIME_STAMP_WIDTH),                //?????
        .REAL_INPUT_NEUR_WIDTH(REAL_INPUT_NEUR_WIDTH),      //?????????????SCHE_DATA_OUT?????
        .REAL_HANG_WIDTH(REAL_HANG_WIDTH),                  //????????????????
        .TREF_NEED_CTRL_CNT(TREF_NEED_CTRL_CNT)
    ) controller_0 (
        .Tref_Event_generate(tref_event_generate),
        .Events_Nums_Read(Events_Nums_Read),
        .Run_Mode(Run_Mode),
        .RD_ADRS(RD_ADRS),
        .RD_DONE(RD_DONE_reg),
        .RD_LEN(RD_LEN),
        .RD_START(RD_START),
        .RST_N(All_Time_RST_N),
        .udp_clk(udp_clk),
        .tx_req(tx_req),
        .tx_data(tx_data_empty),
        .global_leak_time(global_leak_time),
        .CTRL_STATE(CTRL_STATE),
        .CTRL_NEXT_STATE(CTRL_NEXT_STATE),
        .CTRL_ADDR1_READ(CTRL_ADDR1_READ),
        .SYNAPSE_ADDR_1(SYNAPSE_ADDR_1),
        .SYNAPSE_ADDR_2(SYNAPSE_ADDR_2),
        .CTRL_SYNAPSE_ADDR_1_WE(CTRL_SYNAPSE_ADDR_1_WE),
        .CTRL_SYNAPSE_ADDR_2_WE(CTRL_SYNAPSE_ADDR_2_WE),
        .CTRL_SYNAPSE_PIPLINE_START(CTRL_SYNAPSE_PIPLINE_START),
        .CTRL_PIPLINE_START(CTRL_PIPLINE_START),
        .CTRL_PIPELINE_CHOOSE(CTRL_PIPELINE_CHOOSE),

        .CTRL_NEUR_DISABLE(CTRL_NEUR_DISABLE),
        // Global inputs ------------------------------------------
        .CLK(CLK),
        .RST(RST_sync),
    
        // Inputs from AER ----------------------------------------
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),
        
        // Inputs from scheduler ----------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_BURST_END(SCHED_BURST_END),
        .SCHED_DATA_OUT(SCHED_DATA_OUT),
        
        // Input from AER output ----------------------------------
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        

        .Receive_Tref(Receive_Tref),

        .Tref_Event_Out(Tref_Event_Out),
        // Outputs to synaptic core -------------------------------
        .CTRL_PRE_EN(CTRL_PRE_EN),
        
        .CTRL_SYNARRAY_CS(CTRL_SYNARRAY_CS),

        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .CTRL_NEURMEM_CS(CTRL_NEURMEM_CS),
        
        // Outputs to neurons -------------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT), 
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),

        //.CTRL_NEUR_BURST_END(CTRL_NEUR_BURST_END),
        //.CTRL_PIPELINE_CHOOSE(CTRL_PIPELINE_CHOOSE),
        .ADDR_1(ADDR_1),
        .ADDR_2(ADDR_2),
        .CTRL_ADDR_1_WE(CTRL_ADDR_1_WE),
        .CTRL_ADDR_2_WE(CTRL_ADDR_2_WE),
        
        // Outputs to scheduler -----------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        //.CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),

        // Output to AER output -----------------------------------
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR),
        .Input_timestamp(Input_timestamp),
        .neurontimestamp(neurontimestamp),
        .neuron_stamp_from_stamp(neuron_stamp),
        .AER_IN_BUSY_out(AER_IN_BUSY),
        .global_to_zero(global_to_zero),
        .Big_time(Big_time),
        .Small_time(Small_time),
        /////////////////
        .event_fifo_empty(event_fifo_empty),
        .SCHED_DATA_OUT_Next(SCHED_DATA_OUT_Next),
        .FIFO_Read_Choose_out(FIFO_Read_Choose),
        .FIFO_Write_Choose_out(FIFO_Write_Choose),
        .Spiking_Neuron_Model(Spiking_Neuron_Model)
    );
    
    // wire [31:0]              Big_time
    //----------------------------------------------------------------------------------
	//	Scheduler
	//----------------------------------------------------------------------------------
    wire [3:0] aim_neuron_stamp;
    wire       pre_empty;
    scheduler #(
        // .prio_num(57),
        .N(N),
        .M(M),
        .Input_Neuron(Input_Neuron)
    ) scheduler_0 (
        
        // Global inputs ------------------------------------------
        .one_layer_time_driver(one_layer_time_driver),
        .CLK(CLK),
        .RSTN(RSTN_sync),
    
        // Inputs from controller ---------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        
        // Inputs from neurons ------------------------------------
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        
        // Inputs from SPI configuration registers ----------------
        // .SPI_OPEN_LOOP(SPI_OPEN_LOOP),
        // .SPI_BURST_TIMEREF(SPI_BURST_TIMEREF),
        
        // Outputs ------------------------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_BURST_END(SCHED_BURST_END),
        .SCHED_DATA_OUT(SCHED_DATA_OUT),
        .input_neuron_addr(DOUT),
        .signal_from_arbit(signal_from_arbit),
        .input_timestamp(Input_timestamp),
        .neuron_timestamp(neurontimestamp),

        .fifo_0_empty(fifo_0_empty),
        .fifo_1_empty(fifo_1_empty),
        .aim_neuron_stamp(aim_neuron_stamp),
        .pre_empty_schedule(pre_empty),
        .event_fifo_empty_schedule(event_fifo_empty),
        .SCHED_DATA_OUT_Next(SCHED_DATA_OUT_Next)
    );
    
    
    //----------------------------------------------------------------------------------
	//	Synaptic core
	//----------------------------------------------------------------------------------
   

    
    ddr_weight_fifo #(
    .N(N),
    .M(M),
    .SYNAPSE_DATA_WIDTH(SYNAPSE_DATA_WIDTH),    //????????
    .TIME_MUL(TIME_MUL),              //???????????
    .MUL_ADDR_NUMS(MUL_ADDR_NUMS),         //????
    .MUL_NEUR_ADDR_WIDTH(MUL_NEUR_ADDR_WIDTH),    //??????
    .INPUT_SYN_NUMS_WIDTH(INPUT_SYN_NUMS_WIDTH),  //?????????
    .NEUR_STATE_WIDTH(NEUR_STATE_WIDTH),      //??????????
    .event_out_WIDTH(event_out_WIDTH),
    .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),       //??????
    .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),     //????????
    .REC_WIDTH(REC_WIDTH),              //??????????????
    .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH),    //??????????
    .FIXED_WIDTH(FIXED_WIDTH),           //??????
    .SYNAPSE_WIDTH(SYNAPSE_WIDTH),         //?????????
    .TIME_STAMP_WIDTH(TIME_STAMP_WIDTH),       //?????
    .REAL_INPUT_NEUR_WIDTH(REAL_INPUT_NEUR_WIDTH),
    .REAL_HANG_WIDTH(REAL_HANG_WIDTH),
    .Synapse_SRAM_DEEPTH(Synapse_SRAM_DEEPTH)
    )
    ddr_weight_fifo_0(
    .STATE(CTRL_STATE),
    .CTRL_ADDR1_READ(CTRL_ADDR1_READ),
    // Global inputs ------------------------------------------
    .RSTN_syncn(RSTN_syncn),
    .CLK(CLK),

    // Outputs ------------------------------------------------
    .SYNARRAY_RDATA(SYNARRAY_RDATA),
    .SYN_SIGN(SYN_SIGN),

    //Input From AXI DDR3 READ Channel Signal
    .RD_FIFO_WE(RD_FIFO_WE_reg),
    .RD_FIFO_DATA(RD_FIFO_DATA_reg),
    .FIFO_Write_Choose(FIFO_Write_Choose),
    .FIFO_Read_Choose(FIFO_Read_Choose)

    );

    stamp aim_stamp(
    .CLK(CLK),
    .RST_N(~RST),

    .fifo_0_empty(fifo_0_empty),
    .fifo_1_empty(fifo_1_empty),
    .encode_finish(encode_finish),
    .empty_group(empty_group),
    .global_to_zero(global_to_zero),
    .global_leak_time(global_leak_time),
    .Run_Mode(Run_Mode),
    .Control_State(CTRL_STATE),


    .encode_stamp(encode_stamp),
    .neuron_stamp(neuron_stamp),
    .tref_event_generate(tref_event_generate),
    .encode_event_generate(encode_event_generate)    
);
    //----------------------------------------------------------------------------------
	//	Neural core
	//----------------------------------------------------------------------------------
    wire [63:0]                      output_delay_data;  
    neuron_core #(
        .N(N),                   //???????
        .M(M),                     //???????
        .SYNAPSE_DATA_WIDTH(SYNAPSE_DATA_WIDTH),    //????????
        .TIME_MUL(TIME_MUL),              //???????????
        .MUL_ADDR_NUMS(MUL_ADDR_NUMS),         //????
        .MUL_NEUR_ADDR_WIDTH(MUL_NEUR_ADDR_WIDTH),    //??????
        .INPUT_SYN_NUMS_WIDTH (INPUT_SYN_NUMS_WIDTH),  //?????????
        .NEUR_STATE_WIDTH(NEUR_STATE_WIDTH),      //??????????
        .event_out_WIDTH(event_out_WIDTH),
        .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),       //??????
        .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),     //????????
        .REC_WIDTH(REC_WIDTH),              //??????????????
        .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH),    //??????????
        .FIXED_WIDTH(FIXED_WIDTH)           //??????
    ) neuron_core_0 (
        .RST_N(All_Time_RST_N),
        .uart_rx(uart_rx_neuron),
        .uart_tx(uart_tx_neuron),
        .pre_empty(pre_empty),
        .global_leak_time(global_leak_time),
        .CTRL_ADDR1_READ(CTRL_ADDR1_READ),
        // Global inputs ------------------------------------------
        //.Neuron_Out_Spike(Neuron_Out_Spike),
        .RSTN_syncn(RSTN_syncn),
        .CLK(CLK),
        .CTRL_NEUR_DISABLE(CTRL_NEUR_DISABLE),
        // Inputs from SPI configuration registers ----------------
        
		
        // Synaptic inputs ----------------------------------------
        .SYNARRAY_RDATA(SYNARRAY_RDATA),
        .SYN_SIGN(SYN_SIGN),
        
        // Inputs from controller ---------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        
        .CTRL_NEURMEM_WE(CTRL_NEURMEM_WE),
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .CTRL_NEURMEM_CS(CTRL_NEURMEM_CS),

        .CTRL_PIPELINE_CHOOSE(CTRL_PIPELINE_CHOOSE),
        .ADDR_1(ADDR_1),
        .ADDR_2(ADDR_2),
        .CTRL_ADDR_1_WE(CTRL_ADDR_1_WE),
        .CTRL_ADDR_2_WE(CTRL_ADDR_2_WE),
        .CTRL_PIPLINE_START(CTRL_PIPLINE_START),
        
        // Inputs from scheduler ---------------------------------
        
        // Outputs ------------------------------------------------
        
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .NEUR_NETWORK_OUT(NEUR_NETWORK_OUT),
        .network_neuron(network_neuron),
        
        .output_neuron(output_neuron),
        .output_delay_data(output_delay_data),
        .Spiking_Neuron_Model(Spiking_Neuron_Model)
    );
    (* dont_touch="true"*) wire [1023:0] Neuron_Out_Spike;
    
    out_spike out_view(
        .CLK(CLK),
        .RST_sync(RST),
        .LIF_neuron_event_out(NEUR_NETWORK_OUT),//NEUR_EVENT_OUT | 

        .CTRL_PIPLINE_START(CTRL_PIPLINE_START),
        .CTRL_NEURMEM_ADDR(MULTI_ADDR),

        .Neuron_Out_Spike(Neuron_Out_Spike)
    );

    Tref_Event_generate Tref_Event_generate_1(
        .CLK(CLK),
        .RST_N(~RST),
        .Receive_Tref(Receive_Tref),
        .tref_event_generate(tref_event_generate),
        .Tref_Event_Out(Tref_Event_Out)

    );

    Counter mycounter(
        .global_leak_time(global_leak_time),
        .udp_tx_done_source(udp_tx_done_source),
        .RST_N(All_Time_RST_N),
        .CarP_Class_Signal({Neuron_Out_Spike[99:0]}),
        .Neuron_Out_Spike_10(Neuron_Out_Spike[99:0]),
        .CLK(CLK),
        .RST_sync(RST),
        .Memory_CLK(Memory_CLK),
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

        .tx_req(tx_req),
        .udp_clk(udp_clk),
        .tx_data(tx_data_use),
        .result_num(result_num)
    );

    assign MULTI_ADDR = CTRL_NEURMEM_ADDR;// >= 64 ? (CTRL_NEURMEM_ADDR >= 128 ?CTRL_NEURMEM_ADDR - 128 :CTRL_NEURMEM_ADDR - 64) : CTRL_NEURMEM_ADDR

    AER_out #(
        .N(N),
        .M(M)
    )
    AER_out_1(
        .CLK(CLK),
        .RST_N(~RST),
        .output_spike(NEUR_NETWORK_OUT),
        .MULTI_ADDR(MULTI_ADDR),
        .neurontimestamp(neurontimestamp),

        ///////AER_Out BUS

        .AER_OUT_REQ(AER_OUT_REQ),
        .AER_OUT_ADDR(AER_OUT_ADDR),
        .AER_OUT_ACK(AER_OUT_ACK)
    );

    wire [16*14-1:0] Wait_Compare_Dout;
    FIFO_BLOCK0 #(
        .NEUR_ADDR_DW(8),
        .AER_ADDR_DW(17)
    )outset_fifo(
        .CLK(CLK),
        .RST_N(~RST),
        .spike(NEUR_EVENT_OUT),//we[15:0]
        .re(fifo_read),
        .din(MULTI_ADDR),
        .dout(DOUT),
        .empty_group(empty_group),
        .network_neuron(network_neuron),
        .output_delay_data(output_delay_data),
        .neuron_stamp_from_stamp(neuron_stamp),
        .aim_neuron_stamp(aim_neuron_stamp),
        .Wait_Compare_Dout(Wait_Compare_Dout)

    );

    // arbitrary out_arbit(
    //     .CLK(CLK), 
    //     .RST_N(~RST), 
    //     .empty_group(empty_group),

    //     .grant_out(fifo_read),
    //     .signal_from_arbit(signal_from_arbit),
    //     .CTRL_STATE(CTRL_STATE),
    //     .CTRL_NEXT_STATE(CTRL_NEXT_STATE),
    //     .AER_IN_BUSY(AER_IN_BUSY)
    // );

      arbitrary_NEW out_arbit(
        .CLK(CLK), 
        .RST_N(~RST), 
        .empty_group(empty_group),

        .grant_out(fifo_read),
        .signal_from_arbit(signal_from_arbit),
        .CTRL_STATE(CTRL_STATE),
        .CTRL_NEXT_STATE(CTRL_NEXT_STATE),
        .AER_IN_BUSY(AER_IN_BUSY),
        .Wait_Compare_Dout(Wait_Compare_Dout)
    );



    
endmodule