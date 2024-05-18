/**
  ******************************************************************************
  * File Name          : NPU_AER_Out.v
  * Author             : Chen Yuehai
  * Version            : 2.0
  * date               : 2021/3/9
  * Description        : 输出控制AER总线
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
module AER_out #(
    parameter N = 1024,
    parameter M = 10
)
(
    input wire CLK,
    input wire RST_N,
    input wire [ 15:0] output_spike,
    input wire [7:0] MULTI_ADDR,
    input wire [2:0] neurontimestamp,

    ///////AER_Out BUS

    output reg AER_OUT_REQ,
    output reg [13 : 0] AER_OUT_ADDR,
    input wire AER_OUT_ACK,
    input wire AER_IN_BUSY
);

wire [10:0 ] DOUT;

// wire [15:0] fifo_read;
reg  [15:0] temp_read;

wire [15:0] empty_group;
wire [15:0] grant_out;
reg AER_ACK_int,AER_ACK_syn;
reg AER_OUT_BUSY;


wire AER_ACK_syn_posedge;

assign AER_ACK_syn_posedge = ~AER_ACK_syn & AER_ACK_int;

always@(posedge CLK or negedge RST_N)begin
    if(!RST_N)begin
        temp_read <= 0;
    end
    else begin
        temp_read <= grant_out; 
    end
end


arbitrary_ourspike arbitrary_ourspike1(
    .CLK(CLK), 
    .RST_N(RST_N), 
    .AER_OUT_BUSY(AER_OUT_BUSY),
    .empty_group(empty_group),

    .grant_out(grant_out)
);


FIFO_BLOCK0 #(
    .NEUR_ADDR_DW(8),
    .AER_ADDR_DW(14)
)outspike_fifo(
    .CLK(CLK),
    .RST_N(RST_N),
    .spike(output_spike),//we[15:0]
    .re(grant_out),
    .din(MULTI_ADDR),
    .dout(DOUT),
    .empty_group(empty_group),
    .network_neuron(176'b0)

);


always @(posedge CLK,negedge RST_N) begin
    if(!RST_N)begin
       AER_ACK_int <= 1'b0;
       AER_ACK_syn <= 1'b0;
    end
    else begin
        AER_ACK_int <= AER_OUT_ACK;
        AER_ACK_syn <= AER_ACK_int;
    end
end

always @(posedge CLK , negedge RST_N) begin
    if(!RST_N)begin
       AER_OUT_REQ <= 1'b0;
       AER_OUT_BUSY <= 1'b0;
       AER_OUT_ADDR <= 0;
    end

    else if(AER_ACK_syn_posedge)begin
        AER_OUT_REQ <= 1'b0;
        AER_OUT_BUSY <= 1'b0; 
        AER_OUT_ADDR <= 0;
    end

    else if(|grant_out && ~AER_OUT_REQ)begin
        AER_OUT_REQ <= 1'b0;
        AER_OUT_ADDR <= AER_OUT_ADDR;
        AER_OUT_BUSY <= 1'b1;
    end

    else if(|temp_read && ~AER_OUT_REQ)begin
       AER_OUT_REQ <= 1'b1;
       AER_OUT_ADDR <= {neurontimestamp,DOUT};
       AER_OUT_BUSY <= AER_OUT_BUSY; 
    end

end


endmodule


module arbitrary_ourspike(
    input wire CLK, 
    input wire RST_N, 
    input wire AER_OUT_BUSY,
    input wire [15:0] empty_group,

    output wire [15:0] grant_out
);

    reg [15:0] grant;
    assign grant_out = grant;

    wire enable;
    assign enable = AER_OUT_BUSY?AER_OUT_BUSY:(|grant);

 always @(posedge CLK or negedge RST_N) begin
    if(!RST_N)begin
           grant <= 16'b0; 
        end
        else if(!enable)begin
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
