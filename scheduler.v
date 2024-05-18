module scheduler #(
    parameter                   N = 1024,
    parameter                   M = 10,
    parameter                   Input_Neuron = 3071
)( 

    // Global inputs ------------------------------------------
    input  wire                 CLK,
    input  wire                 RSTN,
    
    // Inputs from controller ---------------------------------
    input  wire                 CTRL_SCHED_POP_N,
    input  wire [          4:0] CTRL_SCHED_VIRTS,
    input  wire [          11:0] CTRL_SCHED_ADDR,
    input  wire [          6:0] CTRL_SCHED_EVENT_IN,
    
    // Inputs from neurons ------------------------------------
    input  wire [        7:0] CTRL_NEURMEM_ADDR,
    input  wire [          6:0] NEUR_EVENT_OUT,

    input  wire [3:0]           input_timestamp,
    input  wire [3:0]           neuron_timestamp,
    
    input wire [13:0]           input_neuron_addr,
    input wire                  signal_from_arbit,
    // Outputs ------------------------------------------------
    output wire                 SCHED_EMPTY,
    output wire                 SCHED_FULL,
    output wire                 SCHED_BURST_END,
    output wire [         13:0] SCHED_DATA_OUT,

    output wire                 fifo_0_empty,
    output wire                 fifo_1_empty,
    input  wire [3:0]           aim_neuron_stamp,
    output wire                 pre_empty_schedule,
    output wire                 event_fifo_empty_schedule,
    output wire [         13:0] SCHED_DATA_OUT_Next,
    input wire                  one_layer_time_driver
);


    wire                   spike_in;
    wire [            2:0] spk_ref;

    wire                   empty_main,empty_main1;
    wire                   full_main,full_main1;
    wire [           13:0] data_out_main,data_out_main1;

    reg push_req_n;
    reg push_req_n1;

    // Splitting event_out into FIFO push commands

    assign spike_in  = CTRL_SCHED_EVENT_IN[6] | signal_from_arbit;
    assign spk_ref   = CTRL_SCHED_EVENT_IN[6] ? CTRL_SCHED_EVENT_IN[5:3] :3'b0;

    reg [15:0] delay_push_n;

    always@(*) begin
        if(spike_in)begin
            ///LSFR 编码脉冲
            if((spk_ref == 3'd0) && ~signal_from_arbit)begin
                case(input_timestamp)
                    4'd0  : delay_push_n = 16'b1111_1111_1111_1110;
                    4'd1  : delay_push_n = 16'b1111_1111_1111_1101;
                    4'd2  : delay_push_n = 16'b1111_1111_1111_1011;
                    4'd3  : delay_push_n = 16'b1111_1111_1111_0111;
                    4'd4  : delay_push_n = 16'b1111_1111_1110_1111;
                    4'd5  : delay_push_n = 16'b1111_1111_1101_1111;
                    4'd6  : delay_push_n = 16'b1111_1111_1011_1111;
                    4'd7  : delay_push_n = 16'b1111_1111_0111_1111;
                    4'd8  : delay_push_n = 16'b1111_1110_1111_1111;
                    4'd9  : delay_push_n = 16'b1111_1101_1111_1111;
                    4'd10 : delay_push_n = 16'b1111_1011_1111_1111;
                    4'd11 : delay_push_n = 16'b1111_0111_1111_1111;
                    4'd12 : delay_push_n = 16'b1110_1111_1111_1111;
                    4'd13 : delay_push_n = 16'b1101_1111_1111_1111;
                    4'd14 : delay_push_n = 16'b1011_1111_1111_1111;
                    4'd15 : delay_push_n = 16'b0111_1111_1111_1111;
                    default:delay_push_n = 16'b1111_1111_1111_1111;
                endcase 
            end 
            else if ((spk_ref == 3'd0) && signal_from_arbit)begin
                case(aim_neuron_stamp)//此处的aim_neuron_stamp 已经加上了用户给定的突触延迟
                    4'd0  : delay_push_n = 16'b1111_1111_1111_1110;
                    4'd1  : delay_push_n = 16'b1111_1111_1111_1101;
                    4'd2  : delay_push_n = 16'b1111_1111_1111_1011;
                    4'd3  : delay_push_n = 16'b1111_1111_1111_0111;
                    4'd4  : delay_push_n = 16'b1111_1111_1110_1111;
                    4'd5  : delay_push_n = 16'b1111_1111_1101_1111;
                    4'd6  : delay_push_n = 16'b1111_1111_1011_1111;
                    4'd7  : delay_push_n = 16'b1111_1111_0111_1111;
                    4'd8  : delay_push_n = 16'b1111_1110_1111_1111;
                    4'd9  : delay_push_n = 16'b1111_1101_1111_1111;
                    4'd10 : delay_push_n = 16'b1111_1011_1111_1111;
                    4'd11 : delay_push_n = 16'b1111_0111_1111_1111;
                    4'd12 : delay_push_n = 16'b1110_1111_1111_1111;
                    4'd13 : delay_push_n = 16'b1101_1111_1111_1111;
                    4'd14 : delay_push_n = 16'b1011_1111_1111_1111;
                    4'd15 : delay_push_n = 16'b0111_1111_1111_1111;
                    default:delay_push_n = 16'b1111_1111_1111_1111;
                endcase
            end 

            else begin
            delay_push_n = 16'b1111_1111_1111_1111; 
            end
        end 
        else begin
            delay_push_n = 16'b1111_1111_1111_1111; 
        end
    end 

    genvar i;

    wire [15:0] fifo_full;
    wire [15:0] fifo_empty;
    wire [223:0] fifo_dout;
    wire [223:0] next_fifo_dout;
    wire [15:0]  pre_empty;
    wire [15:0]  event_fifo_empty;
    wire [15:0] time_driver_en;
    generate
        for(i=0;i<16;i=i+1)begin
            fifo_top #(
                .width(14),
                .depth(4096),
                .depth_addr(12),
                .Input_Neuron(Input_Neuron)
            ) fifo_group(
                .clk(CLK),
                .rst_n(RSTN),
                .push_req_n(fifo_full[i] | delay_push_n[i]),
                .pop_req_n((neuron_timestamp == i) ? (fifo_empty[i] | CTRL_SCHED_POP_N) : 1),
                .data_in(CTRL_SCHED_EVENT_IN[6] ? {2'b0,CTRL_SCHED_ADDR} : {input_neuron_addr}),
                .empty(fifo_empty[i]),
                .full(fifo_full[i]),
                .data_out(fifo_dout[14*i+13:14*i]),
                .pre_empty(pre_empty[i]),
                .next_data_out(next_fifo_dout[14*i+13:14*i]),
                // .time_driver_en(time_driver_en[i]),
                .event_fifo_empty(event_fifo_empty[i])
            );
        end
    endgenerate

    reg [13:0] SCHED_DATA_OUT_reg;
    reg [13:0] SCHED_DATA_OUT_reg_next;
    reg SCHED_EMPTY_reg;
    reg SCHED_FULL_reg;
    always@(posedge CLK)begin
        case(neuron_timestamp)
            4'd0 : begin SCHED_DATA_OUT_reg <= fifo_dout[13:0]; SCHED_DATA_OUT_reg_next <= next_fifo_dout[13:0];end
            4'd1 : begin SCHED_DATA_OUT_reg <= fifo_dout[27:14];SCHED_DATA_OUT_reg_next <= next_fifo_dout[27:14];end 
            4'd2 : begin SCHED_DATA_OUT_reg <= fifo_dout[41:28];SCHED_DATA_OUT_reg_next <= next_fifo_dout[41:28];end
            4'd3 : begin SCHED_DATA_OUT_reg <= fifo_dout[55:42];SCHED_DATA_OUT_reg_next <= next_fifo_dout[55:42];end
            4'd4 : begin SCHED_DATA_OUT_reg <= fifo_dout[69:56];SCHED_DATA_OUT_reg_next <= next_fifo_dout[69:56];end
            4'd5 : begin SCHED_DATA_OUT_reg <= fifo_dout[83:70];SCHED_DATA_OUT_reg_next <= next_fifo_dout[83:70];end
            4'd6 : begin SCHED_DATA_OUT_reg <= fifo_dout[97:84];SCHED_DATA_OUT_reg_next <= next_fifo_dout[97:84];end
            4'd7 : begin SCHED_DATA_OUT_reg <= fifo_dout[111:98];SCHED_DATA_OUT_reg_next <= next_fifo_dout[111:98];end
            4'd8 : begin SCHED_DATA_OUT_reg <= fifo_dout[125:112];SCHED_DATA_OUT_reg_next <= next_fifo_dout[125:112];end
            4'd9 : begin SCHED_DATA_OUT_reg <= fifo_dout[139:126];SCHED_DATA_OUT_reg_next <= next_fifo_dout[139:126];end
            4'd10 : begin SCHED_DATA_OUT_reg <= fifo_dout[153:140];SCHED_DATA_OUT_reg_next <= next_fifo_dout[153:140];end
            4'd11 : begin SCHED_DATA_OUT_reg <= fifo_dout[167:154];SCHED_DATA_OUT_reg_next <= next_fifo_dout[167:154];end
            4'd12 : begin SCHED_DATA_OUT_reg <= fifo_dout[181:168];SCHED_DATA_OUT_reg_next <= next_fifo_dout[181:168];end
            4'd13 : begin SCHED_DATA_OUT_reg <= fifo_dout[195:182];SCHED_DATA_OUT_reg_next <= next_fifo_dout[195:182];end
            4'd14 : begin SCHED_DATA_OUT_reg <= fifo_dout[209:196];SCHED_DATA_OUT_reg_next <= next_fifo_dout[209:196];end
            4'd15 : begin SCHED_DATA_OUT_reg <= fifo_dout[223:210];SCHED_DATA_OUT_reg_next <= next_fifo_dout[223:210];end
            default:begin SCHED_DATA_OUT_reg <= 0;SCHED_DATA_OUT_reg_next <= 0;end
        endcase
end

    always@(*)begin
        case(neuron_timestamp)
            4'd0 : begin SCHED_EMPTY_reg <= fifo_empty[0];SCHED_FULL_reg <= fifo_full[0]; end
            4'd1 : begin SCHED_EMPTY_reg <= fifo_empty[1];SCHED_FULL_reg <= fifo_full[1]; end 
            4'd2 : begin SCHED_EMPTY_reg <= fifo_empty[2];SCHED_FULL_reg <= fifo_full[2]; end
            4'd3 : begin SCHED_EMPTY_reg <= fifo_empty[3];SCHED_FULL_reg <= fifo_full[3]; end
            4'd4 : begin SCHED_EMPTY_reg <= fifo_empty[4];SCHED_FULL_reg <= fifo_full[4]; end
            4'd5 : begin SCHED_EMPTY_reg <= fifo_empty[5];SCHED_FULL_reg <= fifo_full[5]; end
            4'd6 : begin SCHED_EMPTY_reg <= fifo_empty[6];SCHED_FULL_reg <= fifo_full[6]; end
            4'd7 : begin SCHED_EMPTY_reg <= fifo_empty[7];SCHED_FULL_reg <= fifo_full[7];end
            4'd8 : begin SCHED_EMPTY_reg <= fifo_empty[8];SCHED_FULL_reg <= fifo_full[8];end
            4'd9 : begin SCHED_EMPTY_reg <= fifo_empty[9];SCHED_FULL_reg <= fifo_full[9];end
            4'd10 : begin SCHED_EMPTY_reg <= fifo_empty[10];SCHED_FULL_reg <= fifo_full[10];end
            4'd11 : begin SCHED_EMPTY_reg <= fifo_empty[11];SCHED_FULL_reg <= fifo_full[11];end
            4'd12 : begin SCHED_EMPTY_reg <= fifo_empty[12];SCHED_FULL_reg <= fifo_full[12];end
            4'd13 : begin SCHED_EMPTY_reg <= fifo_empty[13];SCHED_FULL_reg <= fifo_full[13];end
            4'd14 : begin SCHED_EMPTY_reg <= fifo_empty[14];SCHED_FULL_reg <= fifo_full[14];end
            4'd15 : begin SCHED_EMPTY_reg <= fifo_empty[15];SCHED_FULL_reg <= fifo_full[15];end
            default:begin SCHED_EMPTY_reg <= 0;SCHED_FULL_reg <= 0;end
        endcase 
    end

    // Output selection
    // assign SCHED_DATA_OUT                                              = neuron_timestamp[0] ? data_out_main1 : data_out_main; 
    assign SCHED_DATA_OUT       = SCHED_DATA_OUT_reg;
    assign SCHED_DATA_OUT_Next  = SCHED_DATA_OUT_reg_next;
    assign SCHED_EMPTY          = SCHED_EMPTY_reg;
    assign SCHED_FULL           = SCHED_FULL_reg;
    assign SCHED_BURST_END      = 1'b0 ;
    // assign SCHED_EMPTY                                                 = neuron_timestamp[0] ? empty_main1 : empty_main;
    // assign SCHED_FULL                                                  = neuron_timestamp[0] ? full_main1  : full_main;


    assign fifo_0_empty         = SCHED_EMPTY;
    assign fifo_1_empty         = 0;
    // assign pre_empty_schedule   = time_driver_en[neuron_timestamp];
    assign event_fifo_empty_schedule = event_fifo_empty[neuron_timestamp];

    assign pre_empty_schedule = one_layer_time_driver ? pre_empty[neuron_timestamp]:1'b1;



endmodule