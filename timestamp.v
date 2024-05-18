/**
  ******************************************************************************
  * File Name          : timestamp.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 分别产生编码的时间戳信号和神经元的时间戳信号
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

module encode_timestamp(
    input wire CLK,
    input wire RST_N,
    input wire  encode_finish,

    output wire [2:0] timestamp
);

reg [2:0] timestamp_reg;


assign timestamp = timestamp_reg;

always @(posedge CLK or negedge RST_N) begin
    if(!RST_N)begin
        timestamp_reg <= 0;
    end
    else if(encode_finish)begin
        if(timestamp_reg == 7)begin
            timestamp_reg <= 0;
        end
        else begin
            timestamp_reg <= timestamp_reg + 1;             
        end
    end
    else begin
       timestamp_reg <= timestamp_reg;
    end
end

endmodule


module neuron_timestamp(
    input wire CLK,
    input wire RST_N,

    output wire [2:0] neurontimestamp
);

reg [31:0] count;
reg [2 :0] neurontimestamp_reg;

assign neurontimestamp = neurontimestamp_reg;

always @(posedge CLK or negedge RST_N) begin
    if(!RST_N)begin
       count <= 0; 
       neurontimestamp_reg <= 0;
    end
    else if(count == 249999)begin//49999
        if(neurontimestamp_reg == 7)begin
            neurontimestamp_reg <= 0; 
            count <= 0;
        end
        else begin
            neurontimestamp_reg <= neurontimestamp_reg + 1;
            count <= 0;
        end 
    end
    else begin
        count <= count + 1;
        neurontimestamp_reg <= neurontimestamp_reg;
    end
end
endmodule


module stamp(
    input  wire       CLK,
    input  wire       RST_N,

    input  wire       fifo_0_empty,
    input  wire       fifo_1_empty,
    input  wire       encode_finish,
    input  wire [15:0]empty_group,
    input  wire       global_to_zero,
    input  wire       global_leak_time,
    input  wire       Run_Mode,
    input  wire [3:0] Control_State,


    output wire [3:0] encode_stamp,
    output wire [3:0] neuron_stamp,
    output wire       tref_event_generate,
    output wire       encode_event_generate    
);

    reg [3:0] encode_stamp_reg;
    reg [3:0] neuron_stamp_reg;
    reg       encode_finish_cap;
    reg       tref_event_generate_reg;
    reg       encode_event_generate_reg;
    reg       global_to_zero_cap;
    wire mux_fifo_empty;

    // assign mux_fifo_empty = (neuron_stamp_reg[0] == 0)?fifo_0_empty:fifo_1_empty; 
    assign mux_fifo_empty = fifo_0_empty;
    always@(posedge CLK or negedge RST_N)begin
        if(!RST_N)begin
            encode_stamp_reg <= 0;
            neuron_stamp_reg <= 15; 
            encode_finish_cap <= 0;
            tref_event_generate_reg <= 0;
            encode_event_generate_reg <= 0;
            global_to_zero_cap <= 0;
        end
        else if(global_leak_time && Run_Mode == 1)begin
            if(encode_finish_cap & global_to_zero_cap)begin
                // encode_stamp_reg <= encode_stamp_reg + 1;
                // neuron_stamp_reg <= neuron_stamp_reg + 1;
                encode_finish_cap <= 0;
                global_to_zero_cap <= 0;
                tref_event_generate_reg <= 0;
                encode_event_generate_reg <= 1; 
            end
            else if(encode_finish)begin
                encode_finish_cap <= 1; 
                tref_event_generate_reg <= 0;
                encode_event_generate_reg <= 0;
            end    
            else if(global_to_zero)begin
                global_to_zero_cap <= 1;
                tref_event_generate_reg <= 0;
                encode_event_generate_reg <= 0; 
            end
            else begin
                tref_event_generate_reg <= 0;
                encode_event_generate_reg <= 0; 
            end
        end

        else if(encode_finish_cap & mux_fifo_empty & (&empty_group) & Control_State == 0)begin
            encode_stamp_reg <= encode_stamp_reg + 1;
            neuron_stamp_reg <= neuron_stamp_reg;
            encode_finish_cap <= 0;
            tref_event_generate_reg <= 1;
            encode_event_generate_reg <= 1;
        end
        else if(tref_event_generate_reg)begin
            neuron_stamp_reg <= neuron_stamp_reg + 1;
            encode_stamp_reg <= encode_stamp_reg;
            tref_event_generate_reg <= 0;
            encode_event_generate_reg <= 0;
            encode_finish_cap <= encode_finish_cap;
        end
        else if(encode_finish)begin
            encode_finish_cap <= 1;
            encode_stamp_reg <= encode_stamp_reg;
            neuron_stamp_reg <= neuron_stamp_reg;  
            tref_event_generate_reg <= 0;
            encode_event_generate_reg <= 0;
        end
        else begin
            encode_stamp_reg <= encode_stamp_reg;
            neuron_stamp_reg <= neuron_stamp_reg;
            encode_finish_cap <= encode_finish_cap;
            tref_event_generate_reg <= 0;
            encode_event_generate_reg <= 0;
        end 
    end

    assign encode_stamp = encode_stamp_reg;
    assign neuron_stamp = neuron_stamp_reg;
    assign tref_event_generate = tref_event_generate_reg;
    assign encode_event_generate = encode_event_generate_reg;

endmodule