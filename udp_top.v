module udp_top#(
    parameter SYNAPSE_DATA_WIDTH = 32,
    // parameter SYNAPSE_WIDTH = 17,
    parameter HANG_LEN = 256,
    parameter HANG_LEN_B = 8
    // parameter Synapse_SRAM_DEEPTH = 131072,
    // parameter Synapse_SRAM_DEEPTH_W = 17
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
    input wire hclk,//读数据时钟
    input wire eth_clk,//以太网时钟

    output wire [31:0] fifo_data_out,
    input  wire fifo_read,
    output wire Send_interrupt,
    input  wire udp_tx_req,
    output wire led_show_full


);
    // wire clk_100m;
    (*mark_debug="true"*)wire rec_pkt_done;
    (*mark_debug="true"*)wire rec_en;
    (*mark_debug="true"*)wire [7:0] rec_data;
    (*mark_debug="true"*)wire [15:0] rec_byte_num;

    (*mark_debug="true"*)wire [15:0] tx_byte_num;
    (*mark_debug="true"*)wire        udp_tx_done;
    // (*mark_debug="true"*)wire        tx_req;
    (*mark_debug="true"*)wire [7:0]  tx_data;
    (*mark_debug="true"*)wire        tx_start_en;
    wire        udp_rec_clk;

    (*mark_debug="true"*)wire read_fifo_empty;
    (*mark_debug="true"*)wire write_fifo_full;
    // (*mark_debug="true"*)wire fifo_read;
    
    wire read_fifo_empty_udp_rec;
    // assign tx_start_en = udp_tx_req;
    assign tx_byte_num = 16'd4;
    assign tx_data = 8'h21;

    eth_udp_loop udp0(
    // .sys_clk(sys_clk)   , //系统时钟
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
    // .clk_100m(clk_100m),
    .clk_200m(eth_clk)

    );

    nsync_fifo#(
    .SRAM_DATA_W(32),                //写入存储器的数据位宽
    .SRAM_DATA_BYTES(4),             //单位数据共多少个字节
    .SRAM_DATA_BYTES_B(2),           //字节个数的二进制表示
    .HANG_LEN(HANG_LEN),                   //单次传输共多少个数据
    .HANG_LEN_B(HANG_LEN_B)                  //单次传输数据总数的二进制表示
    )fifo_0
    (
        .src_clk(udp_rec_clk),                              //数据输入时钟
        .rst_n(sys_rst_n),                                //全局清零信号
        .des_clk(hclk),                              //数据读取时钟
        .fifo_data_in(rec_data),                 //输入单字节数据
        .fifo_data_in_vaild(rec_en),                   //输入数据有效信号

        .fifo_read(fifo_read),                           //FIFO读信号
        .fifo_data_out_vaild(),            //读数据有效信号
        .fifo_data_out(fifo_data_out) ,  //FIFO读取的数据
        .read_fifo_empty_out(read_fifo_empty_udp_rec),
        .read_fifo_empty(read_fifo_empty),
        .write_fifo_full(write_fifo_full)

    );
    assign led_show_full = write_fifo_full;
    wire write_fifo_full_clr;
    reg  triger_flag,temp_flag;

    assign write_fifo_full_clr = !sys_rst_n | triger_flag;

    always@(posedge write_fifo_full or posedge write_fifo_full_clr)begin
        if(write_fifo_full_clr)begin
            temp_flag <= 0;
        end
        else begin
            temp_flag <= 1;
        end
    end

    always@(posedge hclk or negedge sys_rst_n)begin
        if(!sys_rst_n)begin
            triger_flag <= 0;
        end
        else begin
            triger_flag <= temp_flag;
        end
    end

    assign Send_interrupt = triger_flag;

    wire udp_tx_clr;
    reg  udp_tx_flag,udp_tx_temp_flag;

    assign udp_tx_clr = !sys_rst_n | udp_tx_flag;

    always@(posedge udp_tx_req or posedge udp_tx_clr)begin
        if(udp_tx_clr)begin
            udp_tx_temp_flag <= 0;
        end
        else begin
            udp_tx_temp_flag <= 1;
        end
    end

    always@(posedge udp_tx_clk or negedge sys_rst_n)begin
        if(!sys_rst_n)begin
            udp_tx_flag <= 0;
        end
        else begin
            udp_tx_flag <= udp_tx_temp_flag;
        end
    end

    assign tx_start_en = udp_tx_flag;


endmodule