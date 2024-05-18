module udp_top_snn#(
    parameter SYNAPSE_DATA_WIDTH = 64,
    parameter SYNAPSE_WIDTH = 17,
    parameter HANG_LEN = 64,
    parameter HANG_LEN_B = 6,
    parameter Synapse_SRAM_DEEPTH = 131072,
    parameter Synapse_SRAM_DEEPTH_W = 17
)(
    // input              sys_clk   , //系统时钟
    input              sys_rst_n , //系统复位信号，低电平有效 
    //PL以太网RGMII接口   
    input              eth_rxc   , //RGMII接收数据时钟
    input              eth_rx_ctl, //RGMII输入数据有效信号
    input       [3:0]  eth_rxd   , //RGMII输入数据
    output             eth_txc   , //RGMII发送数据时钟    
    output             eth_tx_ctl, //RGMII输出数据有效信号
    output      [3:0]  eth_txd   , //RGMII输出数据          
    output             eth_rst_n,   //以太网芯片复位信号，低电平有效

    /////时钟信号
    input wire clk_200m,

    input wire car_module_tx,
    input wire [15:0] car_module_tx_num,
    input wire [7:0 ] car_module_tx_data,
    output wire       udp_rec_clk_out,
    output wire       udp_tx_clk,
    output wire       rec_en_out,
    output wire[7:0 ] rec_data_out,

    output wire tx_req,
    output reg udp_tx_done_source,
    input  wire SNN_CLK
);
    wire rec_pkt_done;
    wire rec_en;
    wire [7:0] rec_data;
    wire [15:0] rec_byte_num;

    wire [15:0] tx_byte_num;
    wire        udp_tx_done;
    // wire        tx_req;
    wire [7:0]  tx_data;
    wire        tx_start_en;
    wire        udp_rec_clk;

    wire read_fifo_empty;
    wire write_fifo_full;
    wire fifo_read;

    wire read_fifo_empty_udp_rec;

    assign tx_start_en = car_module_tx;
    assign tx_byte_num = car_module_tx_num;
    assign tx_data = car_module_tx_data;

    assign udp_rec_clk_out = udp_rec_clk;
    assign rec_en_out = rec_en;
    assign rec_data_out = rec_data;

    eth_udp_loop_snn udp0_snn(
    .sys_rst_n(sys_rst_n) , //系统复位信号，低电平有效 
    //PL以太网RGMII接口   
    .eth_rxc(eth_rxc)   , //RGMII接收数据时钟
    .eth_rx_ctl(eth_rx_ctl), //RGMII输入数据有效信号
    .eth_rxd(eth_rxd)   , //RGMII输入数据
    .eth_txc(eth_txc)   , //RGMII发送数据时钟    
    .eth_tx_ctl(eth_tx_ctl), //RGMII输出数据有效信号
    .eth_txd(eth_txd)   , //RGMII输出数据          
    .eth_rst_n(eth_rst_n),   //以太网芯片复位信号，低电平有效

    //user interface
    .rec_pkt_done(rec_pkt_done), //UDP单包数据接收完成信号
    .rec_en(rec_en)      , //UDP接收的数据使能信号
    .rec_data(rec_data)    , //UDP接收的数据
    .rec_byte_num(rec_byte_num), //UDP接收的有效字节数 单位:byte 

    .tx_byte_num(tx_byte_num) , //UDP发送的有效字节数 单位:byte 
    .udp_tx_done(udp_tx_done) , //UDP发送完成信号
    .tx_req(tx_req)      , //UDP读数据请求信号
    .tx_data(tx_data) ,      //UDP待发送数据
    .tx_start_en(tx_start_en),
    .udp_rec_clk(udp_rec_clk),
    .udp_tx_clk(udp_tx_clk),
    .clk_200m(clk_200m)

    );

    wire udp_tx_done_clr;
    reg temp_flag;

    assign udp_tx_done_clr = !sys_rst_n | udp_tx_done_source;

    always@(posedge udp_tx_done or posedge udp_tx_done_clr)begin
        if(udp_tx_done_clr)begin
            temp_flag <= 0; 
        end 
        else begin
            temp_flag <= 1; 
        end
    end

    always @(posedge SNN_CLK or negedge sys_rst_n) begin
        if(!sys_rst_n)begin
            udp_tx_done_source <= 0; 
        end
        else begin
            udp_tx_done_source <= temp_flag; 
        end
    end



endmodule