/**
  ******************************************************************************
  * File Name          : lif_neuron_state.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 
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

`define predict_cut
`include "define.v"
// `define euler_1
// `define multipler
module lif_neuron_state #(
    parameter SYN_WEIGHT_WIDTH = 4,     //??????
    parameter MEMPOTENTIAL_WIDTH = 9,   //????????
    parameter REC_WIDTH = 3,           //??????????????
    parameter MEM_THRESHOLD_WIDTH = 9, //??????????
    parameter FIXED_WIDTH = 12

)( 
    /* input port */

    input  wire                             CLK,                    // ??????
    input  wire                             global_leak_time,
    input  wire                             param_leak_en,          // ????
    input  wire signed  [MEM_THRESHOLD_WIDTH-1:0]   param_thr,              // ???????
    input  wire signed  [MEMPOTENTIAL_WIDTH-1:0 ]   state_core,             // ????????
    input  wire [REC_WIDTH-1:0]             state_rec_fractory,     // ??????????
    input  wire                             event_leak,             // ???????
    input  wire                             event_inh,              // ???????
    input  wire                             event_exc,              // ???????
    input  wire [SYN_WEIGHT_WIDTH-1:0]      syn_weight,             // ????
    input  wire signed [MEMPOTENTIAL_WIDTH-1:0]    mul_data_state_core,              // membrane potential state from SRAM 
    input  wire signed [MEMPOTENTIAL_WIDTH-1:0]    mul_izh_u,
    input  wire signed [MEMPOTENTIAL_WIDTH-1:0]    izh_u,
    output reg signed [MEMPOTENTIAL_WIDTH-1:0]    izh_u_next,
    /* output port */
    output wire signed [MEMPOTENTIAL_WIDTH-1:0]    state_core_next,        // ??????????? 
    output wire [REC_WIDTH-1:0]             state_rec_fractory_next,// ?????????????
    output wire [6:0]                       event_out,               // ???????
    input  wire                             pre_empty,
    input  wire                             Spiking_Neuron_Model
);

    /* reg and wire in this module */
    localparam multipler_Mode = 2'd0;
    localparam izh_Mode = 2'd1;
    localparam euler_1_Mode = 2'd2;
    localparam predict_cut_Mode = 2'd3;

    wire [1:0] Mode;

    reg signed  [MEMPOTENTIAL_WIDTH-1:0] state_core_next_i;
    reg   [REC_WIDTH-1:0]          state_rec_fractory_next_i;

    wire signed [MEMPOTENTIAL_WIDTH-1:0]  state_inh, state_exc;
    reg  signed [MEMPOTENTIAL_WIDTH-1:0]  f_xy,f_xy_1,y_n_1,state_leak;
    wire                           spike_out;
    // reg   [(MEMPOTENTIAL_WIDTH + FIXED_WIDTH)*2 - 1:0]     mul_temp;
    reg spike_out_reg;
    /* ????????????>=??????????????????????0 */
    assign spike_out       = spike_out_reg;

    assign event_out       = {spike_out, 3'b000, 3'b0};
    assign state_core_next =  state_core_next_i;

    assign state_rec_fractory_next = state_rec_fractory_next_i;

    `ifdef USE_LIF
        assign Mode = predict_cut_Mode;
    `else 
        assign Mode = izh_Mode;
    `endif
    // assign Mode = izh_Mode;
    
    // always@(posedge CLK)begin
    //     Mode <= Spiking_Neuron_Model ? 1 : 3;
    // end 

    wire signed  [19:0] v_2;
    wire signed  [19:0] five_v;
    wire signed  [19:0] a_b_v;

    wire signed  [17:0] v_2_temp;

    wire signed  [19:0] a_u;
    reg signed  [19:0] u_next;

    reg [19:0] square_end;
    reg [19:0] cal_five_v;
    /* ?????????? */
    always @(posedge CLK) begin 
        spike_out_reg <= 0;
        izh_u_next <= izh_u;
            if (event_leak && param_leak_en)begin
                if(global_leak_time)begin
                    state_core_next_i <= 0;
                    state_rec_fractory_next_i <= 0;
                    izh_u_next <= 20'h00000;
                end
                else if(state_rec_fractory != {(REC_WIDTH){1'b0}})begin
                    state_rec_fractory_next_i <= state_rec_fractory - 1;
                    state_core_next_i <= state_core;
                end 
                else begin
                    case(Mode)
                        multipler_Mode: state_core_next_i <= state_leak;
                        izh_Mode      : state_core_next_i <= state_core + ((square_end + cal_five_v + 20'h78000 - u_next) >>> 9);
                        euler_1_Mode  : state_core_next_i <= state_core - state_leak;
                        predict_cut_Mode:state_core_next_i <= state_core;// - (f_xy + f_xy_1);
                        default:        state_core_next_i <= state_core;
                    endcase
                    // state_core_next_i <=  state_core - f_xy - f_xy_1;
                    state_rec_fractory_next_i <= state_rec_fractory; 
                end
        
            end

            else if (event_exc) begin//&& ~CTRL_NEUR_DISABLE
                if (state_rec_fractory == 0)begin
                    // state_core_next_i <= state_exc;//20'h08000
                    if((state_exc > 20'b0000_1000_0000_0000_0000) && !state_exc[MEMPOTENTIAL_WIDTH-1] && pre_empty)begin //  && !pre_empty
                        state_rec_fractory_next_i <= 1;
                        state_core_next_i <= 0;
                        spike_out_reg <= 1;
                        izh_u_next <= izh_u + 20'b00000_0000_0010_1000_111;
                    end
                    else if((state_exc > 20'h50000) && !state_exc[MEMPOTENTIAL_WIDTH-1])begin
                        state_rec_fractory_next_i <= state_rec_fractory;
                        state_core_next_i <= state_core;
                    end
                    else begin
                        state_rec_fractory_next_i <= state_rec_fractory;
                        state_core_next_i <= state_exc;
                    end
                end
                else begin
                    state_core_next_i <= state_core;
                    state_rec_fractory_next_i <= state_rec_fractory;
                end
            end
          
            else if(event_inh)begin
                if (state_rec_fractory == 0)begin
                    state_rec_fractory_next_i <= state_rec_fractory;

                    if(state_inh[MEMPOTENTIAL_WIDTH-1])//begin
                        if(state_inh <= 'b1011_0000_0000_0000_0000)//b110011100
                            state_core_next_i <= 'b1011_0000_0000_0000_0000;
                        else 
                            state_core_next_i <= state_inh;
                    else if(!state_inh[MEMPOTENTIAL_WIDTH-1])begin
                        if((state_inh > 20'b0000_1000_0000_0000_0000) && pre_empty)begin
                            state_rec_fractory_next_i <= 1;
                            state_core_next_i <= 0;
                            spike_out_reg <= 1;
                            izh_u_next <= izh_u + 20'b00000_0000_0010_1000_111;
                        end
                        else begin
                           state_core_next_i <= state_inh; 
                        end
                    end
                    else begin
                        state_core_next_i <= state_inh; 
                    end
                        // state_core_next_i <= state_inh; 
                    //end


                end
                else begin
                    state_core_next_i <= state_core;
                    state_rec_fractory_next_i <= state_rec_fractory;
                end
            end
            else begin
                state_core_next_i <= 0;
                state_rec_fractory_next_i <= 0;
            end
    end

    `ifdef predict_cut//40000 0100
        reg signed [MEMPOTENTIAL_WIDTH-1:0] t = 20'b0100_0000_0000_0000_0000;
        always@(posedge CLK)begin
        if(event_leak)begin
            f_xy <= (mul_data_state_core - mul_data_state_core >>> 1 ) >>> 4;//-
            // y_n_1 <= mul_data_state_core - ((mul_data_state_core - 1) >>> 3);
            f_xy_1 <= (mul_data_state_core - ((mul_data_state_core - mul_data_state_core >>> 1 ) >>> 3) 
                        - (mul_data_state_core - ((mul_data_state_core - mul_data_state_core >>> 1 ) >>> 3))>>>1) >>> 4;//
        end 
        end
    `endif
    //Izh
//    (mul_data_state_core - ((mul_data_state_core - mul_data_state_core >>> 1 ) >>> 3))>>>1

    // assign square_end = (v_2) >>> 5;
    // assign u_next = izh_u + ((a_b_v - a_u) >>> 9);

    // state_core + (square_end + 5_v + 140 - u_next) >>> 9;
    reg signed [MEMPOTENTIAL_WIDTH-1:0]    mul_data_state_core_reg;
    reg signed [MEMPOTENTIAL_WIDTH-1:0]    mul_data_state_core_reg_reg;
    reg signed [MEMPOTENTIAL_WIDTH-1:0]    izh_u_reg;
    reg signed [MEMPOTENTIAL_WIDTH-1:0]    mul_izh_u_reg;
    always@(posedge CLK)begin
        if(event_leak)begin
            mul_data_state_core_reg <= mul_data_state_core;
            izh_u_reg <= izh_u;
            mul_izh_u_reg <= mul_izh_u;
            mul_data_state_core_reg_reg <= mul_data_state_core_reg;
        end
        else begin
            mul_data_state_core_reg <= 0;
            izh_u_reg <= 0;
            mul_izh_u_reg <= 0;
            mul_data_state_core_reg_reg <= 0;
        end
        
    end

    square square0 (.CLK(CLK),.A(mul_data_state_core_reg[19:2]),.B(mul_data_state_core_reg[19:2]),.CE(event_leak),.P(v_2_temp));  

    constant_mul constant_mul0 (.CLK(CLK),.A(5'b00101),.B(mul_data_state_core_reg),.CE(event_leak),.P(five_v));  
    constant_mul constant_mul1 (.CLK(CLK),.A(5'b01100),.B(mul_data_state_core_reg),.CE(event_leak),.P(a_b_v));  
    constant_mul constant_mul2 (.CLK(CLK),.A(5'b00101),.B(mul_izh_u_reg),.CE(event_leak),.P(a_u)); 
    assign v_2 = {v_2_temp , 2'b00};
    always@(posedge CLK)begin
        if(event_leak & !mul_data_state_core_reg_reg[19])begin
            square_end <= (v_2) >>> 5;
            u_next <= izh_u_reg + ((a_b_v - a_u) >>> 9);
            cal_five_v <= five_v; 
        end 
        else begin
            square_end <= 0;
            u_next <= 0;
            cal_five_v <= 0;
        end
    end
    
    assign state_inh  = (event_inh)?(state_core - {{(MEMPOTENTIAL_WIDTH-SYN_WEIGHT_WIDTH+1){1'b0}},syn_weight[SYN_WEIGHT_WIDTH-2:0]}):0;
    assign state_exc  = (event_exc)?(state_core + {{(MEMPOTENTIAL_WIDTH-SYN_WEIGHT_WIDTH+1){1'b0}},syn_weight[SYN_WEIGHT_WIDTH-2:0]}):0;



endmodule 