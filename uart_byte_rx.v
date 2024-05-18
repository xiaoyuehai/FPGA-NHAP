/**
  ******************************************************************************
  * File Name          : uart_byte_rx.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 串口低速和高速接受模块 115200/2000000
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
module uart_rx(
	input 						sclk,         //系统输入时钟  
	input 						s_rst_n,         //系统复位信号
	
	input			 				rx,         //Rs232串口接收信号
	
	output	reg 	[7:0] 	rx_data,         //接收到的数据
	output	reg  				po_flag 					 //传输完成信号
 
);
 
	//同步缓存数据
	reg 					rx_r1;
	reg					rx_r2;
	reg               rx_r3;
	
	reg					rx_flag;             //传输数据标志信号
	reg 		[12:0]	baud_cnt;
	reg  					bit_flag;
	reg		[3:0]		bit_cnt;
	
//-----------------定义参数-----------------------------
//localparam BAUD_END			=			13'd5207			;
localparam BAUD_END			=			13'd868;
localparam BIT_END			=			4'd8;
 
assign rx_negetive			= 			~rx_r2&rx_r3;  //捕获rx的下降沿，确定传输开始
 
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)begin
		rx_r1 <= 1'b1;
		rx_r2 <= 1'b1;
		rx_r3 <= 1'b1;
		end
	else begin
		rx_r1 <= rx;
		rx_r2 <= rx_r1;
		rx_r3 <= rx_r2;
	end
		
//rx_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		rx_flag			<=				1'b0;
	else if(rx_negetive==1'b1)
		rx_flag			<=				1'b1;
	else if((baud_cnt==BAUD_END)&&(bit_cnt==4'd0))
		rx_flag			<= 			1'b0;
	else
		rx_flag 			<= 			rx_flag;
		
//baud_cnt
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		baud_cnt			<=				'd0;
	else if(baud_cnt==BAUD_END)
		baud_cnt			<=				'd0;
	else if(rx_flag==1'b1)
		baud_cnt			<= 			baud_cnt + 1'b1;
	else
		baud_cnt <= baud_cnt;
		
//bit_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		bit_flag <= 1'b0;
	else if(baud_cnt==(BAUD_END/2))
		bit_flag <= 1'b1;
	else
		bit_flag <= 1'b0;
 
//bit_cnt
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		bit_cnt <= 'd0;
	else if((bit_cnt==BIT_END)&&(bit_flag==1'b1))
		bit_cnt <= 'd0;
	else if(bit_flag)
		bit_cnt <= bit_cnt + 1'b1;
	else 
		bit_cnt <= bit_cnt;
		
//rx_data
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		rx_data <= 'd0;
	else if((bit_flag==1'b1)&&(bit_cnt>=1'b1))
		rx_data <= {rx_r2,rx_data[7:1]};
	else
		rx_data <= rx_data;
		
//po_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		po_flag <= 1'b0;
	else if((bit_cnt==BIT_END)&&(bit_flag==1'b1))
		po_flag <= 1'b1;
	else
		po_flag <= 1'b0;
 
endmodule

module uart_rx_high(
	input 						sclk,         //系统输入时钟  
	input 						s_rst_n,         //系统复位信号
	
	input			 				rx,         //Rs232串口接收信号
	
	output	reg 	[7:0] 	rx_data,         //接收到的数据
	output	reg  				po_flag 					 //传输完成信号
 
);
 
	//同步缓存数据
	reg 					rx_r1;
	reg					rx_r2;
	reg               rx_r3;
	
	reg					rx_flag;             //传输数据标志信号
	reg 		[12:0]	baud_cnt;
	reg  					bit_flag;
	reg		[3:0]		bit_cnt;
	
//-----------------定义参数-----------------------------
//localparam BAUD_END			=			13'd5207			;
localparam BAUD_END			=			13'd100;
localparam BIT_END			=			4'd8;
 
assign rx_negetive			= 			~rx_r2&rx_r3;  //捕获rx的下降沿，确定传输开始
 
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)begin
		rx_r1 <= 1'b1;
		rx_r2 <= 1'b1;
		rx_r3 <= 1'b1;
		end
	else begin
		rx_r1 <= rx;
		rx_r2 <= rx_r1;
		rx_r3 <= rx_r2;
	end
		
//rx_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		rx_flag			<=				1'b0;
	else if(rx_negetive==1'b1)
		rx_flag			<=				1'b1;
	else if((baud_cnt==BAUD_END)&&(bit_cnt==4'd0))
		rx_flag			<= 			1'b0;
	else
		rx_flag 			<= 			rx_flag;
		
//baud_cnt
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		baud_cnt			<=				'd0;
	else if(baud_cnt==BAUD_END)
		baud_cnt			<=				'd0;
	else if(rx_flag==1'b1)
		baud_cnt			<= 			baud_cnt + 1'b1;
	else
		baud_cnt <= baud_cnt;
		
//bit_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		bit_flag <= 1'b0;
	else if(baud_cnt==(BAUD_END/2))
		bit_flag <= 1'b1;
	else
		bit_flag <= 1'b0;
 
//bit_cnt
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		bit_cnt <= 'd0;
	else if((bit_cnt==BIT_END)&&(bit_flag==1'b1))
		bit_cnt <= 'd0;
	else if(bit_flag)
		bit_cnt <= bit_cnt + 1'b1;
	else 
		bit_cnt <= bit_cnt;
		
//rx_data
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		rx_data <= 'd0;
	else if((bit_flag==1'b1)&&(bit_cnt>=1'b1))
		rx_data <= {rx_r2,rx_data[7:1]};
	else
		rx_data <= rx_data;
		
//po_flag
always @(posedge sclk or negedge s_rst_n)
	if(!s_rst_n)
		po_flag <= 1'b0;
	else if((bit_cnt==BIT_END)&&(bit_flag==1'b1))
		po_flag <= 1'b1;
	else
		po_flag <= 1'b0;
 
endmodule
