/**
  ******************************************************************************
  * File Name          : uart_byte_tx.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 串口接受模块
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
module uart_byte_tx(
    Clk,
    Reset_n,
    Data,
    Send_Go,
    Baud_set,
    uart_tx,
    Tx_done
);
    input Clk;
    input Reset_n;
    input [7:0]Data;
    input Send_Go;
    input [2:0]Baud_set;
    output reg uart_tx;
    output reg Tx_done;
    
    //Baud_set = 0   ���ò����� = 9600��
    //Baud_set = 1   ���ò����� = 19200
    //Baud_set = 2   ���ò����� = 38400��
    //Baud_set = 3   ���ò����� = 57600��   
    //Baud_set = 4   ���ò����� = 115200�� 

    reg [17:0]bps_DR;
    always@(*)
        case(Baud_set)
            0:bps_DR = 1000000000/9600/10;
            1:bps_DR = 1000000000/19200/10;
            2:bps_DR = 1000000000/38400/10;
            3:bps_DR = 1000000000/57600/10;
            4:bps_DR = 868;
            5:bps_DR = 100;
            default:bps_DR = 1000000000/9600/10;
         endcase

    reg Send_en;
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n)       
        Send_en <= 0;
    else if(Send_Go)
        Send_en <= 1;
    else if(Tx_done)
        Send_en <= 0;
        
    reg [7:0]r_Data;
    always@(posedge Clk)
    if(Send_Go)
        r_Data <= Data;
    else
        r_Data <= r_Data;     

    wire bps_clk;
     reg [17:0]div_cnt;
    assign bps_clk = (div_cnt == 1);
    
   
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n)
        div_cnt <= 0;
    else if(Send_en)begin
        if(div_cnt == bps_DR - 1)
            div_cnt <= 0;
        else 
            div_cnt <= div_cnt + 1'b1;
    end
    else
        div_cnt <= 0;

    reg [3:0]bps_cnt;
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n)
        bps_cnt <= 0;
    else if(Send_en)begin
        if(bps_clk)begin
            if(bps_cnt == 11)
                bps_cnt <= 0;
            else
                bps_cnt <= bps_cnt + 1'b1;
        end
    end
    else
        bps_cnt <= 0;
    
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n) begin
        uart_tx <= 1'b1;
    end
    else begin
        case(bps_cnt)
            1:uart_tx <= 0;
            2:uart_tx <= r_Data[0];
            3:uart_tx <= r_Data[1];
            4:uart_tx <= r_Data[2];
            5:uart_tx <= r_Data[3];
            6:uart_tx <= r_Data[4];
            7:uart_tx <= r_Data[5];
            8:uart_tx <= r_Data[6];
            9:uart_tx <= r_Data[7]; 
            10:uart_tx <= 1;
            11:begin uart_tx <= 1;end
            default:uart_tx <= 1;
        endcase
     end
     
    always@(posedge Clk or negedge Reset_n)
    if(!Reset_n) 
        Tx_done <= 0;
    else if((bps_clk == 1)  && (bps_cnt == 10))
        Tx_done <= 1;
    else
        Tx_done <= 0;

endmodule
