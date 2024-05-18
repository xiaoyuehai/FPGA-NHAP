module nsync_fifo#(
    parameter  SRAM_DATA_W = 64,                //写入存储器的数据位宽
    parameter  SRAM_DATA_BYTES = 8,             //单位数据共多少个字节
    parameter  SRAM_DATA_BYTES_B = 3,           //字节个数的二进制表示
    parameter  HANG_LEN = 64,                   //单次传输共多少个数据
    parameter  HANG_LEN_B = 6                   //单次传输数据总数的二进制表示
)
(
    input src_clk,                              //数据输入时钟
    input rst_n,                                //全局清零信号
    input des_clk,                              //数据读取时钟
    input [8-1:0] fifo_data_in,                 //输入单字节数据
    input fifo_data_in_vaild,                   //输入数据有效信号

    input  fifo_read,                           //FIFO读信号
    output reg  fifo_data_out_vaild,            //读数据有效信号
    output [SRAM_DATA_W - 1 :0] fifo_data_out ,  //FIFO读取的数据
    output reg read_fifo_empty_out,
    output reg read_fifo_empty,
    output reg write_fifo_full

);

// write fifo

reg [SRAM_DATA_BYTES_B:0] buffer_wr_addr;   //FIFO写入的数据，共多少个字节
(*mark_debug="true"*)reg [SRAM_DATA_W - 1:0] temp_buffer;            //基本位数的写入数据
(*mark_debug="true"*)reg fifo_wr;
always @(posedge src_clk or negedge rst_n)
begin
    if (!rst_n)
        begin
            buffer_wr_addr <= 'd0;
            fifo_wr <= 0;
        end
    else if(fifo_data_in_vaild)
        begin
            if(buffer_wr_addr == SRAM_DATA_BYTES - 1)begin
               buffer_wr_addr <= 0;
               fifo_wr <= 1; 
            end
            else begin
                buffer_wr_addr <= buffer_wr_addr + 1'b1;
                fifo_wr <= 0;
            end
        end
    else begin
        buffer_wr_addr <= buffer_wr_addr;
        fifo_wr <= 0;
    end
end

genvar i;
generate 
    for(i=0;i<SRAM_DATA_BYTES;i=i+1)begin
       always@(posedge src_clk or negedge rst_n)begin 
            if(!rst_n)begin
                temp_buffer[i*8+7:i*8] <= 0; 
            end 
            else if(fifo_data_in_vaild && buffer_wr_addr == i)begin
                temp_buffer[i*8+7:i*8] <= fifo_data_in;
            end
            else begin
                temp_buffer[i*8+7:i*8] <= temp_buffer[i*8+7:i*8];
            end
       end
    end
endgenerate

//src_clk write to fifo

(*mark_debug="true"*)reg [HANG_LEN_B-1:0] recv_fifo_wr_addr;

always @(posedge src_clk or negedge rst_n)
begin
    if (!rst_n)begin
        recv_fifo_wr_addr <= 'd0;
        write_fifo_full <= 0;
    end
    else if(fifo_wr)begin
        if(recv_fifo_wr_addr == HANG_LEN - 1)begin 
            recv_fifo_wr_addr <= 0;
            write_fifo_full <= 1;
        end
        else begin
            recv_fifo_wr_addr <=  recv_fifo_wr_addr + 1'b1;
            write_fifo_full <= 0;
        end
    end
    else begin
        recv_fifo_wr_addr <= recv_fifo_wr_addr;
        write_fifo_full <= 0;
    end
end

// assign write_fiof_full = (recv_fifo_wr_addr-recv_fifo_rd_addr) == (HANG_LEN-1);
// sync fifo data
reg [SRAM_DATA_W-1:0] fifo_0 [0:HANG_LEN-1];

// reg [32-1:0] fifo_1;
always @(posedge src_clk)
begin
    if (fifo_wr)  // only buffer_wr_addr == 3 gen
        begin
            fifo_0[recv_fifo_wr_addr] <= temp_buffer;
        end
end

// read data from recv fifo
wire [HANG_LEN_B-1:0] recv_fifo_cnt;
wire recv_fifo_full;
wire recv_fifo_ready;
reg [HANG_LEN_B:0] recv_fifo_rd_addr;

assign recv_fifo_ready = | recv_fifo_cnt;
assign recv_fifo_full = recv_fifo_cnt == HANG_LEN; // 2'b11 = 3

assign recv_fifo_cnt = recv_fifo_wr_addr - recv_fifo_rd_addr;

always @(posedge des_clk or negedge rst_n)
begin
    if (!rst_n)begin
        recv_fifo_rd_addr <= 'd0;
        read_fifo_empty <= 0;
    end
    else if(fifo_read & !read_fifo_empty)begin
        if(recv_fifo_rd_addr == HANG_LEN-1)begin
            recv_fifo_rd_addr <= 0;
            read_fifo_empty <= 1;
        end
        else begin
            recv_fifo_rd_addr <= recv_fifo_rd_addr + 1'b1;
            read_fifo_empty <= 0;
        end
    end
    else begin
        recv_fifo_rd_addr <= recv_fifo_rd_addr; 
        read_fifo_empty <= 0;
    end
end

wire read_fifo_empty_clr;
reg temp_flag;

assign read_fifo_empty_clr = !rst_n | read_fifo_empty_out;

always@(posedge read_fifo_empty or posedge read_fifo_empty_clr)begin
    if(read_fifo_empty_clr)begin
       temp_flag <= 0; 
    end
    else begin
        temp_flag <= 1;
    end
end

always @(posedge src_clk or negedge rst_n) begin
    if(!rst_n)begin
       read_fifo_empty_out <= 0;
    end
    else begin
        read_fifo_empty_out <= temp_flag;
    end
end

reg [SRAM_DATA_W - 1:0] recv_fifo_data;

always @(posedge des_clk or negedge rst_n)
begin  
    if(!rst_n)begin
       recv_fifo_data <= 0; 
    end
    else if(fifo_read && !read_fifo_empty)begin
       recv_fifo_data <= fifo_0[recv_fifo_rd_addr]; 
    end
    else begin
        recv_fifo_data <= 0; 
    end
end

// out 

assign fifo_data_out = recv_fifo_data;


// always @(posedge des_clk or negedge rst_n)
// begin
//     if(!rst_n)
//         begin
//             fifo_data_out_vaild <= 1'b0;
//         end
//     else
//         begin
//             fifo_data_out_vaild <= recv_fifo_ready;
//         end
// end



endmodule