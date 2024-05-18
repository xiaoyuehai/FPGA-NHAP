/**
  ******************************************************************************
  * File Name          : UART_block.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 串口核心单元
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
module uart_block #(
    parameter input_neuron = 256
)(
    input wire CLK,
    input wire RST_N,
    input wire Send_Go1,
    input wire fifo_read,
    input wire uart_rx1,
    input wire [7:0] send_data,

    output wire [7:0] fifo_dout,
    output wire fifo_empty,
    output wire fifo_full,
    output wire uart_tx1,
    output wire Tx_done1
);

wire [7:0] uart_r_data;
wire       rx_done;
reg [9:0] counter;
// uart_byte_rx u_r(
//     .Clk(CLK),
//     .Reset_n(RST_N),
//     .Baud_Set(3'b100),
//     .uart_rx(uart_rx1),
//     .Data(uart_r_data),
//     .Rx_Done(rx_done)
// );


// uart_recv r(
//     .sys_clk(CLK),                  //ϵͳʱ��
//     .sys_rst_n(RST_N),                //ϵͳ��λ���͵�ƽ��Ч
    
//     .uart_rxd(uart_rx1),                 //UART���ն˿�
//     .uart_done(rx_done),                //����һ֡������ɱ�־

//     .uart_data(uart_r_data)                 //���յ�����
//     );

uart_rx_high u_r(
	.sclk(CLK),         //系统输入时钟  
	.s_rst_n(RST_N),         //系统复位信号
	
	.rx(uart_rx1),         //Rs232串口接收信号
	
	.rx_data(uart_r_data),         //接收到的数据
	.po_flag(rx_done) 					 //传输完成信号
 
);

uart_byte_tx u_t(
    .Clk(CLK),
    .Reset_n(RST_N),
    .Data(send_data),
    .Send_Go(Send_Go1),
    .Baud_set(3'b101),
    .uart_tx(uart_tx1),
    .Tx_done(Tx_done1)
);

always @(posedge CLK or negedge RST_N) begin
    if(!RST_N)begin
       counter <= 0; 
    end
    else if(rx_done)begin
       counter <= counter + 1; 
    end
    else begin
       counter <= counter; 
    end
end

sfifo #(
    .DW(8),.AW(12),.Depth(input_neuron)
    )
    uart_fifo(
    .clk(CLK),
    .rst_n(RST_N),
    .we(rx_done),
    .re(fifo_read),
    .din(uart_r_data),
    .dout(fifo_dout),
    .empty(fifo_empty),
    .full(fifo_full)
    );

// ila_0 your_instance_name (
// 	.clk(CLK), // input wire clk


// 	.probe0(fifo_full), // input wire [0:0]  probe0  
// 	.probe1(uart_rx1), // input wire [0:0]  probe1
//     .probe2(counter)
// );

// ila_0 ila (
// 	.clk(CLK), // input wire clk


// 	.probe0(rx_done), // input wire [0:0]  probe0  
// 	.probe1(uart_r_data) // input wire [7:0]  probe1
// );
endmodule 