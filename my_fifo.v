/**
  ******************************************************************************
  * File Name          : my_fifo.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 输出并行FIFO模块
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
 
module FIFO_BLOCK0 #(
    parameter NEUR_ADDR_DW = 8,
    parameter AER_ADDR_DW = 17
)(
    /* input port */ 
    input wire                  CLK,               // 输入全局时钟信号
    input wire                  RST_N,             // 输入全局清零信号
    input wire [        15:0]   spike,             // 输入16个物理神经元的脉冲信号
    input wire [        15:0]   re,                // 输入FIFO的读信号
    input wire [        9 :0]   din,               // 输入此时复用神经元序号
    input wire [       223:0]   network_neuron,
    input wire                  WTA_En,

    /* output port */
    output reg [        13:0]   dout,              // 输出FIFO数据
    output wire[        15:0]   empty_group,        // 输出FIFO空信号进行仲裁
    input  wire[        63:0]   output_delay_data,
    input  wire[         3:0]   neuron_stamp_from_stamp ,
    output reg [         3:0]   aim_neuron_stamp,
    output wire[   14*16-1:0]   Wait_Compare_Dout 
);

/* reg and wire in this module */
reg [223:0] FIFO_DIN;
wire [14*16-1:0] Compare_Dout;

wire [15:0] empty,full;

wire [223:0] dout_0;


reg [15:0] temp_read;
wire [63:0] fifo_delay_out;

// assign empty_group = {empty15,empty14,empty13,empty12,empty11,empty10,empty9,empty8,empty7,empty6,empty5,empty4,empty3,empty2,empty1,empty};

always@(posedge CLK or negedge RST_N)begin
    if(!RST_N)begin
        temp_read <= 0;
    end
    else begin
        temp_read <= re; 
    end
end



/* 为节约输出端口及节省电路逻辑，采用数据选择器进行输出选择 */
always @(*) begin
    if(!RST_N)begin
       dout = 0; 
    end
    else begin
       case(temp_read)
       16'b0000000000000001: begin dout = dout_0[13:0]; aim_neuron_stamp   = fifo_delay_out[3:0] ; end
       16'b0000000000000010: begin dout = dout_0[27:14];aim_neuron_stamp   = fifo_delay_out[7:4] ; end
       16'b0000000000000100: begin dout = dout_0[41:28];aim_neuron_stamp   = fifo_delay_out[11:8] ;end
       16'b0000000000001000: begin dout = dout_0[55:42];aim_neuron_stamp   = fifo_delay_out[15:12];end
       16'b0000000000010000: begin dout = dout_0[69:56];aim_neuron_stamp   = fifo_delay_out[19:16];end
       16'b0000000000100000: begin dout = dout_0[83:70];aim_neuron_stamp   = fifo_delay_out[23:20];end
       16'b0000000001000000: begin dout = dout_0[97:84];aim_neuron_stamp   = fifo_delay_out[27:24];end
       16'b0000000010000000: begin dout = dout_0[111:98];aim_neuron_stamp  = fifo_delay_out[31:28];end
       16'b0000000100000000: begin dout = dout_0[125:112];aim_neuron_stamp = fifo_delay_out[35:32];end
       16'b0000001000000000: begin dout = dout_0[139:126];aim_neuron_stamp = fifo_delay_out[39:36];end
       16'b0000010000000000: begin dout = dout_0[153:140];aim_neuron_stamp = fifo_delay_out[43:40];end
       16'b0000100000000000: begin dout = dout_0[167:154];aim_neuron_stamp = fifo_delay_out[47:44];end
       16'b0001000000000000: begin dout = dout_0[181:168];aim_neuron_stamp = fifo_delay_out[51:48];end
       16'b0010000000000000: begin dout = dout_0[195:182];aim_neuron_stamp = fifo_delay_out[55:52];end
       16'b0100000000000000: begin dout = dout_0[209:196];aim_neuron_stamp = fifo_delay_out[59:56];end
       16'b1000000000000000: begin dout = dout_0[223:210];aim_neuron_stamp = fifo_delay_out[63:60];end
       default:              begin dout = 0;              aim_neuron_stamp = 0;                    end
       endcase
    end
end

/* 由于使用并行神经元工作，因此需要根据输入
   神经元的需要获得当前真实神经元地址 0 - 1023 */
genvar i;
reg [13:0] x[15:0];
generate
    for(i=0;i<16;i=i+1)begin
        always @(*) begin
            if(!RST_N)begin
                FIFO_DIN[14*i+13:14*i] = 0;
            end
            else if(spike[i] & !full[i])begin
                FIFO_DIN[14*i+13:14*i] = ({4'b0,din}<<4) + i + network_neuron[14*i+13:14*i];
                x[i] = network_neuron[14*i+13:14*i];
            end
            else begin
                FIFO_DIN[14*i+13:14*i] = 0; 
            end
        end

        assign Wait_Compare_Dout[13+14*i:14*i] = !empty_group[i]?Compare_Dout[13+14*i:14*i]:14'd10000;
    end

    
endgenerate



/* FIFO initial*/

generate
    for(i=0;i<16;i=i+1)begin
        sfifo #(.DW(14),.AW(6))
        fifo_0(
            .clk(CLK),
            .rst_n(RST_N),
            .we(spike[i]),
            .re(re[i]),
            .din(FIFO_DIN[14*i+13:14*i]),
            .dout(dout_0[14*i+13:14*i]),
            .empty(empty_group[i]),
            .full(full[i]),
            .Compare_Dout(Compare_Dout[13+14*i:14*i])
            );
    end

    for(i=0;i<16;i=i+1)begin
        sfifo #(.DW(64),.AW(6))
        fifo_delay(
            .clk(CLK),
            .rst_n(RST_N),
            .we(spike[i]),
            .re(re[i]),
            .din(neuron_stamp_from_stamp + output_delay_data[4*i+3:4*i]),
            .dout(fifo_delay_out[4*i+3:4*i]),
            .empty(),
            .full()
            );
    end


endgenerate

endmodule

module sfifo
#(parameter DW = 8,AW = 4,Depth=256)//默认数据宽度8，FIFO深度16
(
    input clk,
    input rst_n,
    input we,
    input re,
    input [DW-1:0]din,
    output reg [DW-1:0]dout,
    output wire [DW-1:0] Compare_Dout,
    output empty,
    output full
    );
// internal signal
// parameter Depth = 1 << AW;//depth of FIFO 
reg [DW-1:0]ram[0:Depth-1];
reg [AW:0]cnt;
reg [AW-1:0]wp;
reg [AW-1:0]rp;
// FIFO declaration
// 空满检测
assign empty = (cnt==0)?1'b1:1'b0;
assign full = (cnt==Depth)?1'b1:1'b0;
// cnt 计数
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        cnt <= 1'd0;
    else if(!empty & re & !full & we)//同时读写
        cnt <= cnt;
    else if(!full & we)//写
        cnt <= cnt+1;
    else if(!empty & re)//读
        cnt <= cnt-1;
    else 
        cnt <= cnt;
end
// 读指针
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        rp <= 1'b0;
    else if(!empty & re)
        rp <= rp+1'b1;
    else
        rp <= rp;
end
//写指针
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        wp <= 1'b0;
    else if(!full & we)
        wp <= wp+1'b1;
    else
        wp <= wp;
end
// 读操作
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        dout <= {DW{1'b0}};
    else if(!empty & re)
        dout <= ram[rp];
    else
        dout <= dout;
end
//写操作
always@(posedge clk)
begin
    if(!full & we)
        ram[wp] <= din;
    else
        ram[wp] <= ram[wp];
end

assign Compare_Dout = ram[rp];

endmodule