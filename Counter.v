/**
  ******************************************************************************
  * File Name          : Counter.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 脉冲计数单元
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
module Counter #(
    parameter output_count = 10
)
(
    input wire udp_tx_done_source,
    input wire RST_N,
    input wire [99:0] CarP_Class_Signal,
    input wire Memory_CLK,
    input wire [99:0] Neuron_Out_Spike_10,
    input wire global_leak_time,
    input wire CLK,
    input wire RST_sync,

    output wire [31:0] Neuron0_Spike_Counter,
    output wire [31:0] Neuron1_Spike_Counter,
    output wire [31:0] Neuron2_Spike_Counter,
    output wire [31:0] Neuron3_Spike_Counter,
    output wire [31:0] Neuron4_Spike_Counter,
    output wire [31:0] Neuron5_Spike_Counter,
    output wire [31:0] Neuron6_Spike_Counter,
    output wire [31:0] Neuron7_Spike_Counter,
    output wire [31:0] Neuron8_Spike_Counter,
    output wire [31:0] Neuron9_Spike_Counter,

    input  wire        tx_req,
    input  wire        udp_clk,
    output reg [7:0]   tx_data,
    output wire [3:0]  result_num

);

reg [31:0] count [0:100-1];

assign Neuron0_Spike_Counter = count[0];
assign Neuron1_Spike_Counter = count[1];
assign Neuron2_Spike_Counter = count[2];
assign Neuron3_Spike_Counter = count[3];
assign Neuron4_Spike_Counter = count[4];
assign Neuron5_Spike_Counter = count[5];
assign Neuron6_Spike_Counter = count[6];
assign Neuron7_Spike_Counter = count[7];
assign Neuron8_Spike_Counter = count[8];
assign Neuron9_Spike_Counter = count[9];

reg [7:0]  CarP_count [0:99];

genvar i;
generate
    for(i=0;i<100;i=i+1)begin
        always@(posedge CLK ,posedge RST_sync)begin
           if(RST_sync || Memory_CLK)begin
               count[i] <= 32'b0;
           end
           else if(Neuron_Out_Spike_10[i] && count[i] != 255 && !global_leak_time)begin
               count[i] <= count[i] + 1'b1;
           end
           else begin
               count[i] <= count[i]; 
           end
        end
    end
endgenerate

generate
    for(i=0;i<100;i=i+1)begin
        always@(posedge CLK ,negedge RST_N)begin
           if(!RST_N || udp_tx_done_source)begin
               CarP_count[i] <= 'b0;
           end
           else if(CarP_Class_Signal[i] && CarP_count[i] != 255 && !global_leak_time)begin
               CarP_count[i] <= CarP_count[i] + 1'b1;
           end
           else begin
               CarP_count[i] <= CarP_count[i]; 
           end
        end
    end
endgenerate

reg [6:0] index;

always @(posedge udp_clk or negedge RST_N) begin
    if(!RST_N)begin
        index <= 0;
        tx_data <= 0;
    end
    else if(tx_req)begin
        if(index == 99)begin
            index <= 0;
            tx_data <= CarP_count[index]; 
        end
        else begin
            index <= index + 1;
            tx_data <= CarP_count[index];
        end
    end
    else begin
        index <= 0; 
        tx_data <= 8'h21;
    end
    
end

reg [3:0] state/* synthesis syn_keep=1 */;
reg [7:0] temp_max/* synthesis syn_keep=1 */;
reg       num_can_show;
reg [3:0] index_class/* synthesis syn_keep=1 */;
reg [3:0] real_num/* synthesis syn_keep=1 */;


always@(posedge CLK or negedge RST_N)begin

    if(!RST_N)begin
        state <= 0;
        temp_max <= 0;
        num_can_show <= 0;
    end
    else begin
        case(state)
        0:begin
          if(global_leak_time && !num_can_show)begin
              state <= 1;
              temp_max <= 0;
              index_class <= 0;
          end  
          else if(global_leak_time && num_can_show)begin
              state <= 0;
              num_can_show <= num_can_show;
              temp_max <= 0;
              index_class <= index_class;
          end
          else begin
             num_can_show <= 0;
             state <= 0;
             temp_max <= 0;
             index_class <= index_class;
          end
        end

        1:begin
            if(temp_max < Neuron0_Spike_Counter)begin
                temp_max <= Neuron0_Spike_Counter;
                index_class <= 0;
                state <= 2;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 2;
            end
        end

        2:begin
            if(temp_max < Neuron1_Spike_Counter)begin
                temp_max <= Neuron1_Spike_Counter;
                index_class <= 1;
                state <= 3;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 3;
            end
        end

        3:begin
            if(temp_max < Neuron2_Spike_Counter)begin
                temp_max <= Neuron2_Spike_Counter;
                index_class <= 2;
                state <= 4;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 4;
            end
        end

        4:begin
            if(temp_max < Neuron3_Spike_Counter)begin
                temp_max <= Neuron3_Spike_Counter;
                index_class <= 3;
                state <= 5;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 5;
            end
        end

        5:begin
            if(temp_max < Neuron4_Spike_Counter)begin
                temp_max <= Neuron4_Spike_Counter;
                index_class <= 4;
                state <= 6;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 6;
            end
        end

        6:begin
            if(temp_max < Neuron5_Spike_Counter)begin
                temp_max <= Neuron5_Spike_Counter;
                index_class <= 5;
                state <= 7;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 7;
            end
        end

        7:begin
            if(temp_max < Neuron6_Spike_Counter)begin
                temp_max <= Neuron6_Spike_Counter;
                index_class <= 6;
                state <= 8;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 8;
            end
        end

        8:begin
            if(temp_max < Neuron7_Spike_Counter)begin
                temp_max <= Neuron7_Spike_Counter;
                index_class <= 7;
                state <= 9;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 9;
            end
        end

        9:begin
            if(temp_max < Neuron8_Spike_Counter)begin
                temp_max <= Neuron8_Spike_Counter;
                index_class <= 8;
                state <= 10;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 10;
            end
        end

        10:begin
            if(temp_max < Neuron9_Spike_Counter)begin
                temp_max <= Neuron9_Spike_Counter;
                index_class <= 9;
                state <= 0;
                real_num <= 9;
                num_can_show <= 1;
            end
            else begin
                temp_max <= temp_max;
                index_class <= index_class;
                state <= 0;
                real_num <= index_class;
                num_can_show <= 1;
            end 
        end
        default:state <= 0;
    endcase
    end
    
    // end
end

assign result_num = real_num;

endmodule

// module Easy_Counter(
//     input wire [9:0] Neuron_Out_Spike_10,
//     input wire CLK,
//     input wire RST_sync
// );

// reg [31:0] count [0:9];

// genvar i;
// generate
//     for(i=0;i<10;i=i+1)begin
//         always@(posedge CLK ,posedge RST_sync)begin
//            if(RST_sync)begin
//                count[i] <= 32'b0;
//            end
//            else if(Neuron_Out_Spike_10[i])begin
//                count[i] <= count[i] + 1'b1;
//            end
//         end
//     end
// endgenerate

// endmodule