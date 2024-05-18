/**
  ******************************************************************************
  * File Name          : encoder_Neuron.v
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
module encoder_Neuron #(
    parameter Input = 256,
    parameter N = 1024,
    parameter M = 10,
    parameter Input_ADDR_W = 11,
    parameter process_isi = 99,
    parameter input_neuron = 2048 
)(
    input wire                      CLK,
    input wire                      RST_N,
    input wire                      encode_CLK ,
    input wire                      AER_ACK,
    input wire [                7:0]pixel_value,
    input wire [                3:0]timestamp,

    output reg [               15:0]AER_ADDR,//21 4+12 = 16
    output reg                      AER_REQ,
    output wire                      AER_BUSY_out,
    output reg [   Input_ADDR_W-1:0]ADDR_PIXEL,
    output reg                      encode_finish

);

//reg and wire in this module
reg AER_BUSY;
// (* dont_touch="true"*) reg encode_finish;

// (* dont_touch="true"*) wire [2:0] timestamp;
(* dont_touch="true"*)reg AER_ACK_int,AER_ACK_syn,AER_ACK_delete;
(* dont_touch="true"*)wire AER_ACK_syn_posedge;
(* dont_touch="true"*)reg load_data,gen_random;
(* dont_touch="true"*)reg [31:0] ctrl_cnt;


// wire [7:0] pixel_value;
(* dont_touch="true"*)wire [11:0] rand_num;
(* dont_touch="true"*)reg spike;
//FSM_states
(* dont_touch="true"*)reg [1:0] state,next_state;
(* dont_touch="true"*)localparam WAIT = 2'b00;
(* dont_touch="true"*)localparam Before_Encode = 2'b01;
(* dont_touch="true"*)localparam Encoding = 2'b10;

random_gen random_test(
    .CLK(CLK),
    .RST_N(RST_N),
    .gen_random(!AER_BUSY_out & gen_random & ctrl_cnt != input_neuron),
    .load_data(load_data),
    
    .rand_num(rand_num)
);

always @(posedge CLK,negedge RST_N) begin
    if(!RST_N)begin
       AER_ACK_int <= 0;
       AER_ACK_syn <= 0;
       AER_ACK_delete <= 0; 
    end
    else begin
        AER_ACK_int <= AER_ACK;
        AER_ACK_syn <= AER_ACK_int;
        AER_ACK_delete <= AER_ACK_syn;
    end
end

assign AER_ACK_syn_posedge = ~AER_ACK_delete & AER_ACK_syn;

always @(posedge CLK , negedge RST_N) begin
    if(!RST_N)begin
       AER_REQ <= 0;
       AER_ADDR <= 0; 
       AER_BUSY <= 0;
    end
    else if(AER_ACK_syn_posedge)begin
        AER_ADDR <= 0;
        AER_REQ <= 0;
        AER_BUSY <= 0; 
    end
    // else if(encode_CLK)begin
    //     AER_REQ <= 1'b1;
    //     AER_ADDR <= {13'b0,8'b0111_1111};
    //     AER_BUSY <= 1'b1;
    // end
    else if(spike && ~AER_REQ)begin
        AER_REQ <= 1'b1;
        AER_ADDR <= {timestamp,ADDR_PIXEL-2'b10};//4+
        AER_BUSY <= 1'b1;
    end
    else begin
       AER_REQ <= AER_REQ;
       AER_ADDR <= AER_ADDR;
       AER_BUSY <= AER_BUSY; 
    end
end

wire [19:0] temp_random;
// wire [19:0] See_
assign temp_random = {pixel_value,12'b0}>>8;
always @(posedge CLK) begin
    if(state == Encoding && !AER_BUSY)begin
        if(rand_num < {pixel_value,12'b0}>>8)begin
            spike <= 1'b1;
        end        
        else begin
            spike <= 1'b0;
        end
    end
    else begin
        spike <= 1'b0;
    end
end
assign AER_BUSY_out = AER_BUSY | spike;

reg [31:0] counter;
reg need_load;

always @(posedge CLK,negedge RST_N) begin
    if(!RST_N)begin
       counter <= 32'b0; 
       need_load <= 1'b1;
    end
    else if(encode_CLK)begin
        if(counter == process_isi)begin
            counter <= 32'b0;
            need_load <= 1'b1;
        end
        else begin
            counter <= counter + 1'b1; 
            need_load <= 1'b0;
        end
    end
    else begin
       counter <= counter;
       need_load <= need_load; 
    end
    
end

always @(posedge CLK or negedge RST_N) begin
    if(!RST_N)begin
        state <= WAIT; 
        // Record_Signal <= 0;
        load_data <= 0;
    end
    else begin
        case(state)
        WAIT:    
            begin
                if(encode_CLK)  begin 
                    state <= Before_Encode;

                    if(ADDR_PIXEL == 0) begin
                        gen_random <= 0;
                        encode_finish <= 0;
                        if(counter == 32'd0)begin load_data <= 1'b0;end
                        else load_data <= 0;
                    end 
                    else begin
                       load_data <= 1'b0;
                       gen_random <= 1'b0;
                       encode_finish <= 0;
                    end
                end
                else  begin      
                    state <= WAIT;
                    load_data <= 1'b0;
                    gen_random <= 1'b0;
                    encode_finish <= 0;
                end
            end

        Before_Encode:
        if(!AER_BUSY)
            begin
                gen_random <= 1'b1;
                state <= Encoding;
            end
        else begin
            state <= Before_Encode;
        end

        Encoding:
            begin
            //    if(ctrl_cnt == 0)
            //         gen_random <= 1'b1;
            //    else begin
               gen_random <= 1'b1;
            //    end
               load_data <= 1'b0;
               if(ctrl_cnt == input_neuron)begin
                  state <= WAIT; 
                  encode_finish <= 1;
                  gen_random <= 1'b0;
               end 
            end
    endcase
    end
    
end

// (* dont_touch="true"*)
// encode_timestamp encode_timestamp_1(
//     .CLK(CLK),
//     .RST_N(RST_N),
//     .encode_finish(encode_finish),

//     .timestamp(timestamp)
// );

always@(posedge CLK,negedge RST_N) begin
    if(!RST_N)begin
       ctrl_cnt <= 32'b0; 
    end
    else if(state == WAIT) begin ctrl_cnt <= 32'b0; end
    else if(state == Encoding && !AER_BUSY && !spike) begin ctrl_cnt <= ctrl_cnt + 1'b1; end
    else begin
        ctrl_cnt <= ctrl_cnt;
    end
end

always @(posedge CLK,negedge RST_N) begin
    if(!RST_N)begin
        ADDR_PIXEL <= 0;
    end
    else if(state == WAIT) begin
        ADDR_PIXEL <= 0;
    end
    else if(state == Encoding && !AER_BUSY && !spike)begin
       ADDR_PIXEL <= ADDR_PIXEL + 1'b1; 
    end
    else begin
        ADDR_PIXEL <= ADDR_PIXEL;
    end
end


endmodule


module random_gen(
    input wire CLK,
    input wire RST_N,
    input wire gen_random,
    input wire load_data,
    
    output reg [11:0] rand_num
);

always@(posedge CLK , negedge RST_N) begin
    if(!RST_N)begin
        rand_num <= 12'b101010100111;       
    end
    else if(load_data)begin
        rand_num <= 12'b101010100111;//12'b101010100111
    end
    else if(gen_random)begin
        rand_num[0] <= rand_num[11];
        rand_num[1] <= rand_num[11] ^ rand_num[0];
        rand_num[2] <= rand_num[11] ^ rand_num[1];
        rand_num[3] <= rand_num[2];
        rand_num[4] <= rand_num[11] ^ rand_num[3];
        rand_num[5] <= rand_num[4];
        rand_num[6] <= rand_num[5];
        rand_num[7] <= rand_num[11] ^ rand_num[6];
        rand_num[8] <= rand_num[7];
        rand_num[9] <= rand_num[11] ^ rand_num[8];
        rand_num[10] <= rand_num[9];
        rand_num[11] <= rand_num[11] ^ rand_num[10];
    end
end

endmodule
