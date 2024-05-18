/**
  ******************************************************************************
  * File Name          : neuron_core.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : ???????
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
`include "define.v"

module neuron_core #(
    parameter N = 1024,                   //???????
    parameter M = 10,                     //???????
    parameter SYNAPSE_DATA_WIDTH = 64,    //????????
    parameter TIME_MUL = 16,              //???????????
    parameter MUL_ADDR_NUMS = 64,         //????
    parameter MUL_NEUR_ADDR_WIDTH = 7,    //??????
    parameter INPUT_SYN_NUMS_WIDTH = 11,  //?????????
    parameter NEUR_STATE_WIDTH = 36,      //??????????
    parameter event_out_WIDTH = 7,
    parameter SYN_WEIGHT_WIDTH = 4,       //??????
    parameter MEMPOTENTIAL_WIDTH = 9,     //????????
    parameter REC_WIDTH = 3,              //??????????????
    parameter MEM_THRESHOLD_WIDTH = 9,    //??????????
    parameter FIXED_WIDTH = 12,            //??????
    `ifdef USE_LIF
        parameter Neuron_Mode = 2'b01
    `else 
        parameter Neuron_Mode = 2'b10
    `endif
)(

    input  wire                             CTRL_ADDR1_READ,
    input  wire                             RST_N,
    // Global inputs ------------------------------------------
    input  wire                             RSTN_syncn,
    input  wire                             CLK,
    input  wire                             global_leak_time,
    
    // Synaptic inputs ----------------------------------------
    input  wire [SYNAPSE_DATA_WIDTH-1:0]    SYNARRAY_RDATA,
    input  wire [TIME_MUL-1:0]              SYN_SIGN,
    
    // Inputs from controller ---------------------------------
    input  wire                             CTRL_PIPELINE_CHOOSE,
    input  wire [MUL_NEUR_ADDR_WIDTH-1:0]   ADDR_1,
    input  wire [MUL_NEUR_ADDR_WIDTH-1:0]   ADDR_2,
    input  wire                             CTRL_NEUR_EVENT,
    input  wire                             CTRL_NEUR_TREF,
    input  wire                             CTRL_NEURMEM_CS,
    input  wire                             CTRL_NEURMEM_WE,
    input  wire [        M-1:0]             CTRL_NEURMEM_ADDR,
    input  wire [      2*M-1:0]             CTRL_PROG_DATA,
    input  wire                             CTRL_NEUR_DISABLE,
    input  wire                             CTRL_ADDR_1_WE,
    input  wire                             CTRL_ADDR_2_WE,
    input  wire                             CTRL_PIPLINE_START,


    output wire [TIME_MUL-1:0]              NEUR_EVENT_OUT,
    output wire [TIME_MUL-1:0]              NEUR_NETWORK_OUT,

    output reg  [223:0]                     network_neuron,
    output reg  [TIME_MUL-1:0]              output_neuron,
    output wire [63:0]                      output_delay_data,
    input  wire                             pre_empty,
    input  wire                             uart_rx,
    output wire                             uart_tx,
    input  wire                             Spiking_Neuron_Model

);
    // reg [1:0] Neuron_Mode;

    // always@(posedge CLK)begin
    //     if(!RST_N)begin
    //         Neuron_Mode <= 2'b01;
    //     end  
    //     else begin
    //         Neuron_Mode <= !Spiking_Neuron_Model ? 2'b01 : 2'b10; 
    //     end
    // end

    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] NEUR_STATE;

    wire [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] Real_NEUR_STATE;
     
    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] NEUR_STATE_tref;

    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] NEUR_STATE_tref_izh;

    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] NEUR_STATE_tref_izh_reg;

    // Internal regs and wires definitions

    wire [SYNAPSE_DATA_WIDTH-1:0]           syn_weight_int;

    wire [TIME_MUL-1:0]                     syn_sign;
    wire                                    syn_event;
    reg                                    time_ref;

    ////just for pipeline neuron

    wire[(TIME_MUL * NEUR_STATE_WIDTH)-1:0] NEUR_STATE_sram_out;

    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] neuron_data_sram_in;
    reg [(TIME_MUL * NEUR_STATE_WIDTH)-1:0] neuron_data_sram_in_reg;
    reg [319:0] izh_u_sram_in;
    reg [319:0] izh_u_sram_in_reg;

    wire[(TIME_MUL * event_out_WIDTH)-1:0] LIF_neuron_event_out;
    reg [(TIME_MUL * event_out_WIDTH)-1:0] Real_NEUR_EVENT_OUT;
    wire[(TIME_MUL * REC_WIDTH)-1:0]       LIF_neuron_Next_Fractory;
    wire[319:0] izh_u_next;
    wire[(TIME_MUL * MEMPOTENTIAL_WIDTH)-1:0] LIF_neuron_next_NEUR_STATE;

    wire [63:0] delay_data_sram_out;
    reg  [63:0] delay_data_reg0;
    reg  [63:0] delay_data_reg1;
    wire [19:0] thold_sram_out;
    reg  [19:0 ] thold_sram_reg;
    reg  [19:0 ] thold_sram_tref;

    wire [319:0] izh_u_sram_out;
    reg  [319:0] izh_u_reg;
    reg  [319:0] izh_u_trf;

    assign output_delay_data = delay_data_reg1;
    genvar  i;

    generate    
        for(i=0;i<TIME_MUL;i=i+1)begin
            assign  NEUR_EVENT_OUT[i]   = CTRL_NEUR_EVENT ?
                                            (NEUR_STATE_tref[(NEUR_STATE_WIDTH-1)+NEUR_STATE_WIDTH*i]?0:Real_NEUR_EVENT_OUT[event_out_WIDTH*i+(event_out_WIDTH-1)]):
                                            0;
            assign  NEUR_NETWORK_OUT[i] = CTRL_NEUR_EVENT ?
                                            (NEUR_STATE_tref[(NEUR_STATE_WIDTH-1)+NEUR_STATE_WIDTH*i]?Real_NEUR_EVENT_OUT[event_out_WIDTH*i+(event_out_WIDTH-1)]:0):
                                            0;
        end
    endgenerate

    // assign NEUR_EVENT_OUT = Real_NEUR_EVENT_OUT[6:0];

    /****************************/

    assign Real_NEUR_STATE = time_ref ? ((Neuron_Mode != `Izh) ? NEUR_STATE:NEUR_STATE_tref_izh):NEUR_STATE;

    always@(posedge CLK , negedge RSTN_syncn)begin
        if(~RSTN_syncn)begin 
            NEUR_STATE_tref <= 0;
            delay_data_reg1 <= 0;
            izh_u_trf       <= 0;
            thold_sram_reg <= 0;
        end
        else if(CTRL_NEUR_EVENT)begin
            NEUR_STATE_tref <= NEUR_STATE;
            delay_data_reg1 <= delay_data_reg0;
            izh_u_trf       <= izh_u_reg;
            thold_sram_reg <= thold_sram_out;

        end
        else begin
            NEUR_STATE_tref <= 0;
            delay_data_reg1 <= 0;
            thold_sram_reg  <= 0;
            izh_u_trf       <= 0;
        end
    end

    always@(posedge CLK , negedge RSTN_syncn)begin
        if(~RSTN_syncn)begin 
            NEUR_STATE_tref_izh <= 0;
            NEUR_STATE_tref_izh_reg <= 0;
        end
        else begin
            NEUR_STATE_tref_izh <= NEUR_STATE_tref;
            NEUR_STATE_tref_izh_reg <= NEUR_STATE_tref_izh;
        end
    end
    /***************************/

    always@(posedge CLK , negedge RSTN_syncn)begin
        if(~RSTN_syncn)begin 
            NEUR_STATE  <= 0;
            delay_data_reg0 <= 0;
            izh_u_reg <= 0;
        end
        else if(CTRL_NEUR_EVENT)begin
            NEUR_STATE  <= NEUR_STATE_sram_out;
            delay_data_reg0 <= delay_data_sram_out;
            izh_u_reg <= izh_u_sram_out;
        end
        else begin
            NEUR_STATE  <= 0;
            delay_data_reg0 <= 0;
            izh_u_reg <= 0;
        end
    end

    // Processing inputs from the synaptic array and the controller
    
    assign syn_weight_int  = SYNARRAY_RDATA; /*>> ({2'b0,CTRL_NEURMEM_ADDR[2:0]} << 2)*/

    assign syn_sign        =  SYN_SIGN;
    assign syn_event       =  CTRL_NEUR_EVENT;
    always@(posedge CLK) begin
        time_ref        <=  CTRL_NEUR_TREF;
    end
    // assign time_ref        =  CTRL_NEUR_TREF;

    generate
        for(i=0;i<16;i=i+1)begin
            always @(*) begin
                network_neuron[14*i+13:14*i] = NEUR_STATE_tref[NEUR_STATE_WIDTH*i+38:NEUR_STATE_WIDTH*i+25];/////////////////////////////////////////////
            end
        end
    endgenerate

    // assign network_neuron_0 = NEUR_STATE_tref[32:23];

    generate
        for(i=0;i<16;i=i+1)begin
           always @(*) begin
               output_neuron[i] = NEUR_STATE_tref[(NEUR_STATE_WIDTH-1)+NEUR_STATE_WIDTH*i];
           end 
        end
    endgenerate
    // assign output_neuron[0] = NEUR_STATE_tref[35];
    

    // Updated or configured neuron state to be written to the neuron memory

//    assign neuron_data_int = {NEUR_STATE_tref[35:13],LIF_neuron0_Next_Fractory,NEUR_STATE_tref[9],LIF_neuron_next_NEUR_STATE};
   
   generate
       for(i=0;i<16;i=i+1)begin
           always @(posedge CLK) begin
               if(time_ref)begin
                    if(Neuron_Mode != `Izh) begin
                        neuron_data_sram_in[40*i+39:40*i] = {NEUR_STATE_tref[40*i+39:40*i+24],LIF_neuron_Next_Fractory[3*i+2:3*i],NEUR_STATE_tref[40*i+20],LIF_neuron_next_NEUR_STATE[20*i+19:20*i]};
                        izh_u_sram_in[20*i+19:20*i] = izh_u_next[20*i+19:20*i];
                    end 
                    else begin
                        neuron_data_sram_in[40*i+39:40*i] = {NEUR_STATE_tref_izh_reg[40*i+39:40*i+24],LIF_neuron_Next_Fractory[3*i+2:3*i],NEUR_STATE_tref_izh_reg[40*i+20],LIF_neuron_next_NEUR_STATE[20*i+19:20*i]};
                        izh_u_sram_in[20*i+19:20*i] = izh_u_next[20*i+19:20*i];
                    end
                end 
                else begin
                    neuron_data_sram_in[40*i+39:40*i] = {NEUR_STATE_tref[40*i+39:40*i+24],LIF_neuron_Next_Fractory[3*i+2:3*i],NEUR_STATE_tref[40*i+20],LIF_neuron_next_NEUR_STATE[20*i+19:20*i]};
                    izh_u_sram_in[20*i+19:20*i] = izh_u_next[20*i+19:20*i];
                end
           end

        //    always @(posedge CLK)begin
        //     //    if(!RSTN_syncn)begin
        //     //        neuron_data_sram_in_reg[40*i+39:40*i] = 0;
        //     //        izh_u_sram_in_reg[20*i+19:20*i] = 0;
        //     //    end
        //         if(time_ref)begin
        //             neuron_data_sram_in_reg[40*i+39:40*i] <= {NEUR_STATE_tref_izh_reg[40*i+39:40*i+24],LIF_neuron_Next_Fractory[3*i+2:3*i],NEUR_STATE_tref_izh_reg[40*i+20],LIF_neuron_next_NEUR_STATE[20*i+19:20*i]};
        //             izh_u_sram_in_reg[20*i+19:20*i] <= izh_u_next[20*i+19:20*i];
        //         end
        //    end 
       end
   endgenerate
    
   
    generate
        for(i=0;i<16;i=i+1)begin
            always @(*) begin
                 if(NEUR_STATE_tref[40*i+24])begin
                     Real_NEUR_EVENT_OUT[7*i+6:7*i] = 7'b0;
                 end
                 else if(CTRL_NEURMEM_CS & CTRL_PIPLINE_START)begin
                     Real_NEUR_EVENT_OUT[7*i+6:7*i] = LIF_neuron_event_out[7*i+6:7*i];
                 end
                 else begin
                     Real_NEUR_EVENT_OUT[7*i+6:7*i] = 7'b0;
                 end
            end
        end
    endgenerate

    // assign NEUR_EVENT_OUT      = NEUR_STATE_tref[22] ? 7'b0 : ((CTRL_NEURMEM_CS && CTRL_PIPLINE_START) ? (LIF_neuron_event_out[6:0]) : 7'b0);

generate
    for(i=0;i<TIME_MUL;i=i+1)begin

        lif_neuron #(
            .SYN_WEIGHT_WIDTH(SYN_WEIGHT_WIDTH),     //??????
            .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),   //????????
            .REC_WIDTH(REC_WIDTH),           //??????????????
            .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH), //??????????
            .FIXED_WIDTH(FIXED_WIDTH)
        )lif_neuron_group( 
            .CLK(CLK),
            .param_thr(thold_sram_reg),               // neuron firing threshold parameter 20'b0000_0001_0000_0000_0000
            .param_leak_en(Real_NEUR_STATE[40*i+20]),
            .state_core(Real_NEUR_STATE[40*i+19:40*i]),              // membrane potential state from SRAM 
            .state_rec_fractory(Real_NEUR_STATE[40*i+23:40*i+21]),
            .state_core_next(LIF_neuron_next_NEUR_STATE[20*i+19:20*i]),         // next membrane potential state to SRAM
            .state_rec_fractory_next(LIF_neuron_Next_Fractory[3*i+2:3*i]),
            
            .syn_weight(syn_weight_int[16*i+15:16*i]),              // synaptic weight
            .syn_sign(syn_sign[i]),                // inhibitory (!excitatory) configuration bit
            .syn_event(syn_event),               // synaptic event trigger
            .time_ref(time_ref),                // time reference event trigger
            .global_leak_time(global_leak_time),
            ////////////
            .event_out(LIF_neuron_event_out[7*i+6:7*i]),                // neuron spike event output  
            .mul_data_state_core(NEUR_STATE_sram_out[40*i+19:40*i]),
            .pre_empty(pre_empty),
            .mul_izh_u(izh_u_sram_out[20*i+19:20*i]),
            .izh_u(izh_u_reg[20*i+19:20*i]),
            .izh_u_next(izh_u_next[20*i+19:20*i]),
            .Spiking_Neuron_Model(Spiking_Neuron_Model)
);  
    end
endgenerate


  
neuron_sram neuron_sram0 (
    .clka(CLK),    // input wire clka
    .ena(CTRL_NEURMEM_CS),      // input wire ena
    .wea(CTRL_ADDR_2_WE),      // input wire [0 : 0] wea
    .addra(ADDR_2),  // input wire [9 : 0] addra
    .dina(neuron_data_sram_in),    // input wire [575 : 0] dina

    .clkb(CLK),    // input wire clkb
    .enb(CTRL_ADDR1_READ),      // input wire enb
    .addrb(ADDR_1),  // input wire [9 : 0] addrb
    .doutb(NEUR_STATE_sram_out)  // output wire [575 : 0] doutb
);

`ifdef JUST_for_SIMULATION
    integer dout_file0;
    integer dout_file1;
    integer dout_file2;
    integer dout_file3;
    integer dout_file4;
    integer dout_file5;
    integer dout_file6;
    integer dout_file7;
    integer dout_file8;
    integer dout_file9;

    initial begin
        dout_file0 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test0.txt") ;
        dout_file1 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test1.txt") ;
        dout_file2 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test2.txt") ;
        dout_file3 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test3.txt") ;
        dout_file4 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test4.txt") ;
        dout_file5 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test5.txt") ;
        dout_file6 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test6.txt") ;
        dout_file7 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test7.txt") ;
        dout_file8 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test8.txt") ;
        dout_file9 = $fopen("E:/Python_Project/Acce_Test/2second_paper_plot/test9.txt") ;
    end

    always @(posedge CLK) begin
        if(RSTN_syncn & ADDR_2 == 128 & CTRL_NEURMEM_CS & CTRL_ADDR_2_WE)begin
            $fdisplay(dout_file0,"%b",neuron_data_sram_in[19:0]); 
            $fdisplay(dout_file1,"%b",neuron_data_sram_in[19+40*1:0+40*1]); 
            $fdisplay(dout_file2,"%b",neuron_data_sram_in[19+40*2:0+40*2]); 
            $fdisplay(dout_file3,"%b",neuron_data_sram_in[19+40*3:0+40*3]);
            $fdisplay(dout_file4,"%b",neuron_data_sram_in[19+40*4:0+40*4]); 
            $fdisplay(dout_file5,"%b",neuron_data_sram_in[19+40*5:0+40*5]); 
            $fdisplay(dout_file6,"%b",neuron_data_sram_in[19+40*6:0+40*6]);  
            $fdisplay(dout_file7,"%b",neuron_data_sram_in[19+40*7:0+40*7]); 
            $fdisplay(dout_file8,"%b",neuron_data_sram_in[19+40*8:0+40*8]); 
            $fdisplay(dout_file9,"%b",neuron_data_sram_in[19+40*9:0+40*9]);
        end
    end

`endif

izh_u_save your_instance_name (
  .clka(CLK),    // input wire clka
  .ena(CTRL_NEURMEM_CS),      // input wire ena
  .wea((time_ref & !global_leak_time)?0:CTRL_ADDR_2_WE),      // input wire [0 : 0] wea
  .addra(ADDR_2),  // input wire [9 : 0] addra
  .dina(neuron_data_sram_in),    // input wire [319 : 0] dina
  .clkb(CLK),    // input wire clkb
  .enb(CTRL_ADDR1_READ),      // input wire enb
  .addrb(ADDR_1),  // input wire [9 : 0] addrb
  .doutb(izh_u_sram_out)  // output wire [319 : 0] doutb
);

delay_bram delay_bram0 (
  .clka(CLK),    // input wire clka
  .ena(CTRL_ADDR1_READ),      // input wire ena
  .addra(ADDR_1),  // input wire [9 : 0] addra
  .douta(delay_data_sram_out)  // output wire [63 : 0] douta
);

wire Sram_We;
wire [1:0] Sram_addr;
wire [7:0] Sram_Data;
wire [19:0] Write_data;

assign Write_data = {4'b0,Sram_Data,8'b0};

TholdSet TholdSet0(
	.CLK(CLK),
	.RST_N(RST_N),
	.uart_rx(uart_rx),


	.uart_tx(uart_tx),

	.Sram_We(Sram_We),
	.Sram_addr(Sram_addr),
	.Sram_Data(Sram_Data)
	);

threhold_sram threhold_sram0 (
    .clka(CLK),    // input wire clka
    .ena(Sram_We),      // input wire ena
    .wea(Sram_We),      // input wire [0 : 0] wea
    .addra(Sram_addr),  // input wire [1 : 0] addra
    .dina(Write_data),    // input wire [7 : 0] dina
    .clkb(CLK),    // input wire clkb
    .enb(CTRL_ADDR1_READ),      // input wire enb
    .addrb(ADDR_1[7:6]),  // input wire [1 : 0] addrb
    .doutb(thold_sram_out)  // output wire [7 : 0] doutb
);


endmodule