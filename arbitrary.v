/**
  ******************************************************************************
  * File Name          : aribitrary.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 输出仲裁器
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
module arbitrary(
    /* input port */
    input wire                  CLK,                // 输入全局时钟信号       
    input wire                  RST_N,              // 输入全局置位信号
    input wire          [15:0]  empty_group,        // 输入16个FIFO的空信号，进行毒性好仲裁
    input wire          [3: 0]  CTRL_STATE,         // 输入控制核心当前状态
    input wire          [3: 0]  CTRL_NEXT_STATE,    // 输入控制核心下一状态
    input wire                  AER_IN_BUSY,

    /* output port */
    output wire         [15:0]  grant_out,          // 仲裁器仲裁的FIFO读信号
    output wire                 signal_from_arbit   // 产生读信号标志位
);
    
    /* reg and wire in this module */
    reg [15:0] grant;
    reg [15:0] grant_temp;
    wire enable;

    assign grant_out = grant;
    /* 该线输入到 scheduler，告知加速器单元内部已产生时钟，即存入fifo中待处理*/
    assign signal_from_arbit = |grant_temp;
    
    always@(posedge CLK or negedge RST_N)begin
        if(!RST_N)begin
            grant_temp <= 0;
        end
        else begin
            grant_temp <= grant;
        end
    end

    assign enable = (|grant) || (|grant_temp);

    /* 仲裁器核心逻辑 */
    always @(posedge CLK or negedge RST_N) begin
        if(!RST_N)begin
           grant <= 16'b0; 
        end
        else if(!enable && (CTRL_STATE == CTRL_NEXT_STATE) && !AER_IN_BUSY)begin//else if(!enable && (((CTRL_STATE == 0) && (CTRL_NEXT_STATE == 0)) || (CTRL_STATE==9 && CTRL_NEXT_STATE==9)))begin
            if(!empty_group[0])begin
                grant <= 16'b0000_0000_0000_0001;
            end
            else if(!empty_group[1])begin
                grant <= 16'b0000_0000_0000_0010;
            end
            else if(!empty_group[2])begin
                grant <= 16'b0000_0000_0000_0100;
            end
            else if(!empty_group[3])begin
                grant <= 16'b0000_0000_0000_1000;
            end
            else if(!empty_group[4])begin
                grant <= 16'b0000_0000_0001_0000;
            end
            else if(!empty_group[5])begin
                grant <= 16'b0000_0000_0010_0000;
            end
            else if(!empty_group[6])begin
                grant <= 16'b0000_0000_0100_0000;
            end
            else if(!empty_group[7])begin
                grant <= 16'b0000_0000_1000_0000;
            end
            else if(!empty_group[8])begin
                grant <= 16'b0000_0001_0000_0000;
            end
            else if(!empty_group[9])begin
                grant <= 16'b0000_0010_0000_0000;
            end
            else if(!empty_group[10])begin
                grant <= 16'b0000_0100_0000_0000;
            end
            else if(!empty_group[11])begin
                grant <= 16'b0000_1000_0000_0000;
            end
            else if(!empty_group[12])begin
                grant <= 16'b0001_0000_0000_0000;
            end
            else if(!empty_group[13])begin
                grant <= 16'b0010_0000_0000_0000;
            end
            else if(!empty_group[14])begin
                grant <= 16'b0100_0000_0000_0000;
            end
            else if(!empty_group[15])begin
                grant <= 16'b1000_0000_0000_0000;
            end
            else begin
                grant <= 16'b0000_0000_0000_0000; 
            end
        end
        else begin
           grant <= 16'b0; 
        end
    end

endmodule

module arbitrary_NEW(
    /* input port */
    input wire                  CLK,                // 输入全局时钟信号       
    input wire                  RST_N,              // 输入全局置位信号
    input wire          [15:0]  empty_group,        // 输入16个FIFO的空信号，进行毒性好仲裁
    input wire          [3: 0]  CTRL_STATE,         // 输入控制核心当前状态
    input wire          [3: 0]  CTRL_NEXT_STATE,    // 输入控制核心下一状态
    input wire                  AER_IN_BUSY,

    /* output port */
    output wire         [15:0]  grant_out,          // 仲裁器仲裁的FIFO读信号
    output wire                 signal_from_arbit,   // 产生读信号标志位
    input wire [14*16-1:0]      Wait_Compare_Dout
);
    
    /* reg and wire in this module */
    reg [15:0] grant;
    reg [15:0] grant_temp;
    wire enable;

    assign grant_out = grant;
    /* 该线输入到 scheduler，告知加速器单元内部已产生时钟，即存入fifo中待处理*/
    assign signal_from_arbit = |grant_temp;
    
    always@(posedge CLK or negedge RST_N)begin
        if(!RST_N)begin
            grant_temp <= 0;
        end
        else begin
            grant_temp <= grant;
        end
    end
    
    reg [31:0] ari_state;
    reg [7:0] max_1,max_2,max_3,max_4,max_5,max_6,max_7,max_8;

    assign enable = (|grant) || (|grant_temp);
    reg [31:0] Priority;
    /* 仲裁器核心逻辑 */
    always @(posedge CLK or negedge RST_N) begin
        if(!RST_N)begin
            grant <= 16'b0; 
            Priority <= 0;
        end
        else if(!enable && (CTRL_STATE == CTRL_NEXT_STATE) && !AER_IN_BUSY)begin//else if(!enable && (((CTRL_STATE == 0) && (CTRL_NEXT_STATE == 0)) || (CTRL_STATE==9 && CTRL_NEXT_STATE==9)))begin
            grant <= 16'b0;
            if(!(&empty_group))begin
                if(ari_state == 5)begin
                    grant[max_1] <= 1;
                end
                else begin
                    grant <= 0;
                end
            end
            
        end
        else begin
           grant <= 16'b0; 
        end
    end

    genvar i;
    reg [13:0] fifo_out [0:15];
    generate
        for(i=0;i<16;i=i+1)begin
            always@(posedge CLK or negedge RST_N)begin
                if(!RST_N)begin
                    fifo_out[i] <= 0;
                end 
                else if(!(&empty_group) && ari_state==0)begin
                    fifo_out[i] <= Wait_Compare_Dout[14*i+13:14*i];
                end
            end
        end 

    endgenerate

    always @(posedge CLK or negedge RST_N) begin
        if(!RST_N)begin
            ari_state <= 0;
        end
        else begin
            case(ari_state)
                0:begin
                    if(!(&empty_group))begin
                        ari_state <= 1; 
                    end 
                end
                1:begin
                    if(fifo_out[0] <= fifo_out[1])begin
                        max_1 <= 0; 
                    end
                    else begin
                        max_1 <= 1; 
                    end

                    if(fifo_out[2] <= fifo_out[3])begin
                        max_2 <= 2; 
                    end
                    else begin
                        max_2 <= 3; 
                    end

                    if(fifo_out[4] <= fifo_out[5])begin
                        max_3 <= 4; 
                    end
                    else begin
                        max_3 <= 5; 
                    end

                    if(fifo_out[6] <= fifo_out[7])begin
                        max_4 <= 6; 
                    end
                    else begin
                        max_4 <= 7; 
                    end

                    if(fifo_out[8] <= fifo_out[9])begin
                        max_5 <= 8; 
                    end
                    else begin
                        max_5 <= 9; 
                    end

                    if(fifo_out[10] <= fifo_out[11])begin
                        max_6 <= 10; 
                    end
                    else begin
                        max_6 <= 11; 
                    end

                    if(fifo_out[12] <= fifo_out[13])begin
                        max_7 <= 12; 
                    end
                    else begin
                        max_7 <= 13; 
                    end

                    if(fifo_out[14] <= fifo_out[15])begin
                        max_8 <= 14; 
                    end
                    else begin
                        max_8 <= 15; 
                    end
                    ari_state <= 2;
                end

                2:begin
                    if(fifo_out[max_1] <= fifo_out[max_2])begin
                        max_1 <= max_1; 
                    end 
                    else begin
                        max_1 <= max_2; 
                    end

                    if(fifo_out[max_3] <= fifo_out[max_4])begin
                        max_2 <= max_3; 
                    end 
                    else begin
                        max_2 <= max_4; 
                    end

                    if(fifo_out[max_5] <= fifo_out[max_6])begin
                        max_3 <= max_5; 
                    end 
                    else begin
                        max_3 <= max_6; 
                    end

                    if(fifo_out[max_7] <= fifo_out[max_8])begin
                        max_4 <= max_7; 
                    end 
                    else begin
                        max_4 <= max_8; 
                    end
                    ari_state <= 3;
                end

                3:begin
                        if(fifo_out[max_1] <= fifo_out[max_2])begin
                            max_1 <= max_1; 
                        end 
                        else begin
                            max_1 <= max_2; 
                        end

                        if(fifo_out[max_3] <= fifo_out[max_4])begin
                            max_2 <= max_3; 
                        end 
                        else begin
                            max_2 <= max_4; 
                        end  
                        ari_state <= 4;                  
                end

                4:begin
                        if(fifo_out[max_1] <= fifo_out[max_2])begin
                            max_1 <= max_1; 
                        end 
                        else begin
                            max_1 <= max_2; 
                        end
                        ari_state <= 5;
                end

                5:begin
                    if(|grant)begin
                        ari_state <= 0;
                    end 
                end 


            endcase
        end
    end

endmodule