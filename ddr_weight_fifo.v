`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/02 17:45:56
// Design Name: 
// Module Name: ddr_weight_fifo
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


module ddr_weight_fifo #(
    parameter N = 256,
    parameter M = 8,
    parameter SYNAPSE_DATA_WIDTH = 64,    //突触阵列占用位宽
    parameter TIME_MUL = 16,              //时分复用基础并行神经元
    parameter MUL_ADDR_NUMS = 64,         //复用次数
    parameter MUL_NEUR_ADDR_WIDTH = 6,    //复用次数位宽
    parameter INPUT_SYN_NUMS_WIDTH = 11,  //加速器输入个数位宽
    parameter NEUR_STATE_WIDTH = 36,      //单个神经元参数的位宽
    parameter event_out_WIDTH = 7,
    parameter SYN_WEIGHT_WIDTH = 4,       //突触权重位宽
    parameter MEMPOTENTIAL_WIDTH = 9,     //神经元膜电位位宽
    parameter REC_WIDTH = 3,              //神经元发放脉冲时间窗时间位宽
    parameter MEM_THRESHOLD_WIDTH = 9,    //神经元膜电位阈值位宽
    parameter FIXED_WIDTH = 12,           //定点小数位宽
    parameter SYNAPSE_WIDTH = 17,         //突触存储器地址位宽
    parameter TIME_STAMP_WIDTH = 3,       //时间轴位宽
    parameter REAL_INPUT_NEUR_WIDTH = 10,
    parameter REAL_HANG_WIDTH = 6 ,
    parameter Synapse_SRAM_DEEPTH = 65536
)
(
    input wire                             CTRL_ADDR1_READ,
    // Global inputs ------------------------------------------
    input  wire                            RSTN_syncn,
    input  wire                            CLK,

    // input  wire [   SYNAPSE_WIDTH-1:0]     SYNAPSE_ADDR_1,

    // Outputs ------------------------------------------------
    output reg [   SYNAPSE_DATA_WIDTH-1:0] SYNARRAY_RDATA,
    output reg [   15:0] SYN_SIGN,

    //Input From AXI DDR3 READ Channel Signal
    input  wire RD_FIFO_WE,
    input  wire [255:0] RD_FIFO_DATA,
    input  wire FIFO_Write_Choose,
    input  wire FIFO_Read_Choose,
    input  wire [3:0] STATE

);

    // Internal regs and wires definitions

    wire  [SYNAPSE_DATA_WIDTH-1:0] SYNARRAY_RDATA_sram_out;
    wire  [SYNAPSE_DATA_WIDTH-1:0] SYNARRAY_RDATA_sram_out2;
    wire                           FIFO_Read;

    assign FIFO_Read = (STATE == 4'd1)?1'b0:CTRL_ADDR1_READ;
    
    always@(posedge CLK or negedge RSTN_syncn)begin
        if(~RSTN_syncn)begin
           SYNARRAY_RDATA <= 0; 
        end
        else begin
            case(FIFO_Read_Choose) 
                0:      SYNARRAY_RDATA <= SYNARRAY_RDATA_sram_out; 
                1:      SYNARRAY_RDATA <= SYNARRAY_RDATA_sram_out2; 
            endcase
        end
    end
    genvar  i;
    generate
      for(i=0;i<16;i=i+1)begin
          always @(posedge CLK or negedge RSTN_syncn) begin
              if(!RSTN_syncn)begin
                  SYN_SIGN[i] <= 0;
              end 
              else begin
                  case(FIFO_Read_Choose)
                    0:     SYN_SIGN[i] <= SYNARRAY_RDATA_sram_out[SYN_WEIGHT_WIDTH*i+SYN_WEIGHT_WIDTH-1];
                    1:     SYN_SIGN[i] <= SYNARRAY_RDATA_sram_out2[SYN_WEIGHT_WIDTH*i+SYN_WEIGHT_WIDTH-1];
                  endcase
              end
          end
      end
    endgenerate


    sfifo
    #(
    .DW(256),
    .AW(6),
    .Depth(64)
    )
    synapse_weight_fifo(
        .clk(CLK),
        .rst_n(RSTN_syncn),
        .we(!FIFO_Write_Choose?RD_FIFO_WE:0),
        .re(!FIFO_Read_Choose?FIFO_Read:0),
        .din(RD_FIFO_DATA),
        .dout(SYNARRAY_RDATA_sram_out),
        .empty(),
        .full()
        );

    sfifo
    #(
    .DW(256),
    .AW(6),
    .Depth(64)
    )
    synapse_weight_fifo2(
        .clk(CLK),
        .rst_n(RSTN_syncn),
        .we(FIFO_Write_Choose?RD_FIFO_WE:0),
        .re(FIFO_Read_Choose?FIFO_Read:0),
        .din(RD_FIFO_DATA),
        .dout(SYNARRAY_RDATA_sram_out2),
        .empty(),
        .full()
        );

endmodule
