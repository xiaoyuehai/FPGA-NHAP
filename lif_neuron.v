/**
  ******************************************************************************
  * File Name          : lif_neuron.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : lif?????
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
module lif_neuron #(
    parameter SYN_WEIGHT_WIDTH = 4,     //??????
    parameter MEMPOTENTIAL_WIDTH = 9,   //????????
    parameter REC_WIDTH = 3,           //??????????????
    parameter MEM_THRESHOLD_WIDTH = 9, //??????????
    parameter FIXED_WIDTH = 12
)( 
    input  wire                 CLK,
    input  wire [MEM_THRESHOLD_WIDTH-1:0]   param_thr,               // neuron firing threshold parameter
    input  wire                             param_leak_en,
    input  wire [MEMPOTENTIAL_WIDTH-1:0]    state_core,              // membrane potential state from SRAM 
    input  wire [REC_WIDTH-1:0]             state_rec_fractory,
    output wire [MEMPOTENTIAL_WIDTH-1:0]    state_core_next,         // next membrane potential state to SRAM
    output wire [REC_WIDTH-1:0]             state_rec_fractory_next,
    
    input  wire [SYN_WEIGHT_WIDTH-1:0]      syn_weight,              // synaptic weight
    input  wire                 syn_sign,                // inhibitory (!excitatory) configuration bit
    input  wire                 syn_event,               // synaptic event trigger
    input  wire                 time_ref,                // time reference event trigger
    input  wire                 global_leak_time,
    input  wire [MEMPOTENTIAL_WIDTH-1:0]    mul_data_state_core,              // membrane potential state from SRAM 
    input  wire signed [MEMPOTENTIAL_WIDTH-1:0]    mul_izh_u,
    input  wire signed [MEMPOTENTIAL_WIDTH-1:0]    izh_u,
    output wire signed [MEMPOTENTIAL_WIDTH-1:0]    izh_u_next,

    ////////////
    output wire [          6:0] event_out,                // neuron spike event output 
    input  wire                 pre_empty ,
    input  wire                 Spiking_Neuron_Model
);

    reg       event_leak, event_tref;
    wire       event_inh;
    wire       event_exc;

    always @(*) begin
        event_leak <=  syn_event  & time_ref;
        //event_tref <=  syn_event  & time_ref;
    end
    // assign event_leak =  syn_event  & time_ref;
    // assign event_tref =  event_leak;
    assign event_exc  = ~event_leak & (syn_event & ~syn_sign);
    assign event_inh  = ~event_leak & (syn_event &  syn_sign);


    lif_neuron_state #(
    .SYN_WEIGHT_WIDTH (SYN_WEIGHT_WIDTH),     //??????
    .MEMPOTENTIAL_WIDTH(MEMPOTENTIAL_WIDTH),   //????????
    .REC_WIDTH(REC_WIDTH),           //??????????????
    .MEM_THRESHOLD_WIDTH(MEM_THRESHOLD_WIDTH), //??????????
    .FIXED_WIDTH(FIXED_WIDTH)
    )neuron_state_0 (
        .state_rec_fractory(state_rec_fractory),
        .state_rec_fractory_next(state_rec_fractory_next),
        .CLK(CLK),
        .global_leak_time(global_leak_time),
        .param_leak_en(param_leak_en),
        .param_thr(param_thr),
        .state_core(state_core),
        .event_leak(event_leak),
        .event_inh(event_inh),
        .event_exc(event_exc),
        .syn_weight(syn_weight),
        .state_core_next(state_core_next),
        .event_out(event_out),
        .mul_data_state_core(mul_data_state_core),
        .pre_empty(pre_empty),
        .mul_izh_u(mul_izh_u),
        .izh_u(izh_u),
        .izh_u_next(izh_u_next),
        .Spiking_Neuron_Model(Spiking_Neuron_Model)
    );


endmodule
