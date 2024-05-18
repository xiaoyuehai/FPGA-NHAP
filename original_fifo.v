/**
  ******************************************************************************
  * File Name          : fifo.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 一种可以直接读的FIFO，读出数据后需给出POP信号
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
module original_fifo #(
	parameter width      = 9,
    parameter depth      = 4,
    parameter depth_addr = 2
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push_req_n,
    input  wire              pop_req_n,
    input  wire [width-1: 0] data_in,
    input  wire              fifo_0empty_fifo_1noempty,
    output reg               empty,
    output wire              full,
    output reg [width-1: 0] data_out,
    output reg               pre_empty,
    //////////////////////////////////////////
    output reg [width-1: 0] next_data_out
    // output wire             time_driver_en
);
  
    reg [width-1:0] mem [0:depth-1]; 

    reg [depth_addr-1:0] write_ptr;
    reg [depth_addr-1:0] read_ptr;
    reg [depth_addr-1:0] fill_cnt;

    genvar i;

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            write_ptr <= 2'b0;
        else if (!push_req_n)
            write_ptr <= write_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            write_ptr <= write_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            read_ptr <= 2'b0;
        else if (!pop_req_n)
            read_ptr <= read_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            read_ptr <= read_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            fill_cnt <= 2'b0;
        else if (!push_req_n && pop_req_n)
            fill_cnt <= fill_cnt + {{(depth_addr-1){1'b0}},1'b1};
        else if (!push_req_n && !pop_req_n)
            fill_cnt <= fill_cnt;
        else if (!pop_req_n && |fill_cnt)
            fill_cnt <= fill_cnt - {{(depth_addr-1){1'b0}},1'b1};
        else
            fill_cnt <= fill_cnt;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            empty <= 1'b1;
        else if (!push_req_n)
            empty <= 1'b0;
        else if (!pop_req_n)
            empty <= fill_cnt == 1; 
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pre_empty <= 0; 
        end 
        else if(fill_cnt == 0)begin
            pre_empty <= 1; 
        end
        else begin
            pre_empty <= 0;
        end
    end 

    assign full  =  &fill_cnt;


    // generate

        // for (i=0; i<depth; i=i+1) begin
            
            always @(posedge clk) begin
                if (!push_req_n)
                    mem[write_ptr] <= data_in;
                else 
                    mem[write_ptr] <= mem[write_ptr];
            end
            
        // end
        
    // endgenerate

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            data_out <= 0; 
        end 
        else if(!pop_req_n & fill_cnt != 0)begin
            data_out <= mem[read_ptr]; 
        end
        else if(fifo_0empty_fifo_1noempty)begin
            data_out <= mem[read_ptr];
        end
        else begin
            data_out <= data_out; 
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            next_data_out <= 0; 
        end 
        else if(!pop_req_n & fill_cnt > 1)begin
            if(read_ptr == depth-1) begin
                next_data_out <= mem[0]; 
            end
            else begin
                next_data_out <= mem[read_ptr + 1];
            end
        end
        else begin
            next_data_out <= next_data_out; 
        end
    end

    // assign data_out = mem[read_ptr];
    // assign next_data_out = (fill_cnt != 0) ? mem[read_ptr + 1]  : 0;

    // reg time_driver;
    // reg flag;

    // always@(posedge clk or negedge rst_n)begin
    //     if(!rst_n)begin
    //         flag <= 0;
    //         time_driver <= 0; 
    //     end 
    //     else if(fill_cnt > 333 && !flag)begin
    //         flag <= 1;
    //         time_driver <= 1; 
    //     end
    //     else if(empty)begin
    //         flag <= 0;
    //         time_driver <= 0; 
    //     end
    //     else begin
    //         flag <= flag;
    //         time_driver <= time_driver; 
    //     end
    // end

    // assign time_driver_en = time_driver;
endmodule 

module original_fifo1 #(
	parameter width      = 9,
    parameter depth      = 4,
    parameter depth_addr = 2
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push_req_n,
    input  wire              pop_req_n,
    input  wire [width-1: 0] data_in,
    output reg               empty,
    output wire              full,
    output wire [width-1: 0] data_out,
    output reg               pre_empty,
    //////////////////////////////////////////
    output wire [width-1: 0] next_data_out
    // output wire             time_driver_en
);
  
    reg [width-1:0] mem [0:depth-1]; 

    reg [depth_addr-1:0] write_ptr;
    reg [depth_addr-1:0] read_ptr;
    reg [depth_addr-1:0] fill_cnt;

    genvar i;



    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            write_ptr <= 2'b0;
        else if (!push_req_n)
            write_ptr <= write_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            write_ptr <= write_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            read_ptr <= 2'b0;
        else if (!pop_req_n)
            read_ptr <= read_ptr + {{(depth_addr-1){1'b0}},1'b1};
        else
            read_ptr <= read_ptr;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            fill_cnt <= 2'b0;
        else if (!push_req_n && pop_req_n && !empty)
            fill_cnt <= fill_cnt + {{(depth_addr-1){1'b0}},1'b1};
        else if (!push_req_n && !pop_req_n)
            fill_cnt <= fill_cnt;
        else if (!pop_req_n && |fill_cnt)
            fill_cnt <= fill_cnt - {{(depth_addr-1){1'b0}},1'b1};
        else
            fill_cnt <= fill_cnt;
    end

    always @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            empty <= 1'b1;
        else if (!push_req_n)
            empty <= 1'b0;
        else if (!pop_req_n)
            empty <= ~|fill_cnt; 
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            pre_empty <= 0; 
        end 
        else if(fill_cnt == 0)begin
            pre_empty <= 1; 
        end
        else begin
            pre_empty <= 0;
        end
    end 

    assign full  =  &fill_cnt;


    // generate

        // for (i=0; i<depth; i=i+1) begin
            
            always @(posedge clk) begin
                if (!push_req_n)
                    mem[write_ptr] <= data_in;
                else 
                    mem[write_ptr] <= mem[write_ptr];
            end
            
        // end
        
    // endgenerate

    // always@(posedge clk or negedge rst_n)begin
    //     if(!rst_n)begin
    //         data_out <= 0; 
    //     end 
    //     else if(!pop_req_n & fill_cnt != 0)begin
    //         data_out <= mem[read_ptr + 1]; 
    //     end
    //     else begin
    //         data_out <= data_out; 
    //     end
    // end

    // always@(posedge clk or negedge rst_n)begin
    //     if(!rst_n)begin
    //         next_data_out <= 0; 
    //     end 
    //     else if(!pop_req_n & fill_cnt > 1)begin
    //         next_data_out <= mem[read_ptr + 2]; 
    //     end
    //     else begin
    //         next_data_out <= next_data_out; 
    //     end
    // end

    assign data_out = mem[read_ptr];
    assign next_data_out = (fill_cnt != 0) ? mem[read_ptr + 1]  : 0;

    // reg time_driver;
    // reg flag;

    // always@(posedge clk or negedge rst_n)begin
    //     if(!rst_n)begin
    //         flag <= 0;
    //         time_driver <= 0; 
    //     end 
    //     else if(fill_cnt > 333 && !flag)begin
    //         flag <= 1;
    //         time_driver <= 1; 
    //     end
    //     else if(empty)begin
    //         flag <= 0;
    //         time_driver <= 0; 
    //     end
    //     else begin
    //         flag <= flag;
    //         time_driver <= time_driver; 
    //     end
    // end

    // assign time_driver_en = time_driver;
endmodule 