`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/01 17:51:14
// Design Name: 
// Module Name: ahb_ethnet_1G
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define INTCLEAR_OFFSET          7'b0000000
`define DMACTRANOK_OFFSET        7'b0000001
// `define pwminverttrig_OFFSET   7'b0000001

module ahb_ethnet_1G(
    haddr,
    hclk,
    hprot,
    hrdata,
    hready,
    hresp,
    hrst_b,
    hsel,
    hsize,
    htrans,
    hwdata,
    hwrite,
    intr,

    RST_N,
    eth_clk,
    LED,

    eth_rxc   , //RGMII接收数据时钟
    eth_rx_ctl, //RGMII输入数据有效信号
    eth_rxd   , //RGMII输入数据
    eth_txc   , //RGMII发送数据时钟    
    eth_tx_ctl, //RGMII输出数据有效信号
    eth_txd   , //RGMII输出数据          
    eth_rst_n   //以太网芯片复位信号，低电平有效
    );
    input RST_N;
    input eth_clk;
    input              eth_rxc   ; //RGMII接收数据时钟
    input              eth_rx_ctl; //RGMII输入数据有效信号
    input       [3:0]  eth_rxd   ; //RGMII输入数据
    output             eth_txc   ; //RGMII发送数据时钟    
    output             eth_tx_ctl; //RGMII输出数据有效信号
    output      [3:0]  eth_txd   ; //RGMII输出数据          
    output             eth_rst_n ;   //以太网芯片复位信号，低电平有效

    input   [31:0]  haddr;        
    input           hclk;         
    input   [3 :0]  hprot;        
    input           hrst_b;       
    input           hsel;         
    input   [2 :0]  hsize;        
    input   [1 :0]  htrans;       
    input   [31:0]  hwdata;       
    input           hwrite;       
    output  [31:0]  hrdata;       
    output          hready;  
    output  [1 :0]  hresp;    
    output		intr;    
    wire  [31:0]  hrdata;       
    wire          hready;  
    wire  [1 :0]  hresp;    
    wire          intr;
    output reg LED;
    
    wire [31:0] fifo_data_out;
    wire fifo_read;
    wire Send_interrupt;
    wire udp_tx_req;

    udp_top #(
    .SYNAPSE_DATA_WIDTH(32),
    // parameter SYNAPSE_WIDTH = 17,
    .HANG_LEN(256),
    .HANG_LEN_B(8)
    // parameter Synapse_SRAM_DEEPTH = 131072,
    // parameter Synapse_SRAM_DEEPTH_W = 17
    ) udp_top0(
    .sys_rst_n(RST_N), //系统复位信号，低电平有效 
    //PL以太网RGMII接口   
    .eth_rxc(eth_rxc)   , //RGMII接收数据时钟
    .eth_rx_ctl(eth_rx_ctl), //RGMII输入数据有效信号
    .eth_rxd(eth_rxd)   , //RGMII输入数据
    .eth_txc(eth_txc)   , //RGMII发送数据时钟    
    .eth_tx_ctl(eth_tx_ctl), //RGMII输出数据有效信号
    .eth_txd(eth_txd)   , //RGMII输出数据          
    .eth_rst_n(eth_rst_n),   //以太网芯片复位信号，低电平有效

    /////时钟信号
    .hclk(hclk),//读数据时钟
    .eth_clk(eth_clk),//以太网时钟 200M
    .fifo_data_out(fifo_data_out),
    .fifo_read(fifo_read),
    .Send_interrupt(Send_interrupt),
    .udp_tx_req(udp_tx_req)
    // .led_show_full(led_show_full)

);

wire intclr_en;
reg  intr_reg;
reg  udp_tx_data;
wire udp_tx_en/* synthesis syn_keep=1 */;

assign intclr_en = hwrite & hsel & (haddr[8:2] == `INTCLEAR_OFFSET);
assign udp_tx_en = hwrite & hsel & (haddr[8:2] == `DMACTRANOK_OFFSET);

always @(posedge hclk or negedge hrst_b) begin
    if(!hrst_b)begin
        intr_reg <= 0; 
    end
    else if(intclr_en)begin
        intr_reg <= 0; 
    end
    else if(Send_interrupt)begin
        intr_reg <= 1; 
    end
    else begin
        intr_reg <= intr_reg; 
    end
end

always@(posedge hclk or negedge hrst_b)begin
    if(!hrst_b)begin
        udp_tx_data <= 0; 
    end 
    else if(udp_tx_en)begin
        udp_tx_data <= 1; 
    end
    else begin
       udp_tx_data <= 0; 
    end
end

assign udp_tx_req = udp_tx_data;

assign intr = intr_reg;

always @(posedge hclk or negedge RST_N) begin
    if(!RST_N)begin
        LED <= 0; 
    end
    else if(Send_interrupt) begin
        LED <= 1;
    end
    else begin
        LED <= LED; 
    end
end

assign fifo_read = hsel & ~hwrite;

reg hready_reg;
always @(posedge hclk or negedge hrst_b) begin
    if(!hrst_b)begin
        // hrdata_reg <= 32'b0; 
        hready_reg <= 1'b1;
    end
    else if(fifo_read)begin
        hready_reg <= 1'b1;
    end
    else begin
        hready_reg <= 1'b1;
    end
end

assign hready = hready_reg;

assign hrdata = fifo_data_out;

assign hresp = 2'b00;
endmodule
