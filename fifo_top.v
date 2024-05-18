module fifo_top #(
	parameter width      = 9,
    parameter depth      = 4,
    parameter depth_addr = 2,
    parameter Input_Neuron = 14'd3071
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push_req_n,
    input  wire              pop_req_n,
    input  wire [width-1: 0] data_in,
    output wire               empty,
    output wire              full,
    output wire [width-1: 0] data_out,
    output wire              pre_empty,
    output wire [width-1: 0] next_data_out,
    output wire              event_fifo_empty
    //
    // output wire              time_driver_en
);


//This File for Creat a 16 FIFOs Group (16 layers network)
    
    genvar i;

    wire [1:0] fifo_full;
    wire [1:0] fifo_empty;
    wire [27:0] fifo_dout;
    wire [27:0] next_fifo_dout;
    wire [1:0]  pre_empty_o;
    assign empty = &fifo_empty;
    assign full  = |fifo_full;
    // push logic 
    reg [1:0] layers_push_en;
    reg [13:0] data_in_reg;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            layers_push_en <= 2'b0;
            data_in_reg <= 14'b0;
        end
        else if(!push_req_n)begin
            layers_push_en[0] <= (data_in >= 14'd0) & (data_in <= Input_Neuron);
            layers_push_en[1] <= (data_in >= Input_Neuron+1);
            data_in_reg <= data_in;

        end
        else begin
            layers_push_en <= 2'b0; 
            data_in_reg <= 14'b0;
        end
    end

    //pop logic
    reg [1:0] layers_pop_en_n;
    reg [13:0] data_out_choose;
    reg [13:0] next_data_out_choose;
    reg [1:0] fifo_empty_reg;
    always@(*)begin
        if(!pop_req_n)begin
            case(fifo_empty)
                2'b00:    layers_pop_en_n <= 2'b10 ;
                2'b10:    layers_pop_en_n <= 2'b10 ;
                2'b01:    layers_pop_en_n <= 2'b01 ;
                default             :    layers_pop_en_n <= 2'b11 ;
            endcase
        end
        else begin
           layers_pop_en_n <= 2'b11; 
        end
    end

    always@(posedge clk)begin
        case(fifo_empty_reg)
            2'b00 : begin data_out_choose <= fifo_dout[13:0]; end
            2'b10 : begin data_out_choose <= fifo_dout[13:0]; end
            2'b01 : begin data_out_choose <= fifo_dout[27:14];end 
            default:begin data_out_choose <= 0;end
        endcase
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            fifo_empty_reg <= 2'b11; 
        end
        else if(!pop_req_n)begin
            fifo_empty_reg <= fifo_empty; 
        end
    end

    assign data_out = data_out_choose;

    always@(posedge clk)begin
        case(fifo_empty)
            2'b00 : begin next_data_out_choose <= next_fifo_dout[13:0]; end
            2'b10 : begin 
                    next_data_out_choose <= next_fifo_dout[13:0]; 
                end
            2'b01 : begin 
                    if(fifo_empty_reg == 2'b00)begin
                        next_data_out_choose <= fifo_dout[27:14];
                    end
                    else begin
                        next_data_out_choose <= next_fifo_dout[27:14];
                    end
                    
                end 
            default:begin next_data_out_choose <= 0;end
        endcase
    end

    assign next_data_out = next_data_out_choose;
    wire fifo_0empty_fifo_1noempty;
    assign fifo_0empty_fifo_1noempty = !pop_req_n & !fifo_empty[0];
    generate
        for(i=0;i<2;i=i+1)begin
            original_fifo #(
                .width(14),
                .depth(4096),
                .depth_addr(12)
            ) fifo_group0(
                .clk(clk),
                .rst_n(rst_n),
                .push_req_n(fifo_full[i] | !layers_push_en[i]),
                .pop_req_n(layers_pop_en_n[i]),
                .fifo_0empty_fifo_1noempty(fifo_0empty_fifo_1noempty && i==1),
                .data_in(data_in_reg),
                .empty(fifo_empty[i]),
                .full(fifo_full[i]),
                .data_out(fifo_dout[14*i+13:14*i]),
                .pre_empty(pre_empty_o[i]),
                .next_data_out(next_fifo_dout[14*i+13:14*i])
            );
        end
    endgenerate

    reg pre_empty_group;
    reg event_fifo_empty_reg;

    always@(*)begin
        if(!rst_n)begin
            pre_empty_group <= 1'b1; 
        end 
        else if(!fifo_empty[0])begin
            pre_empty_group <= pre_empty_o[0];
        end
        else begin
            pre_empty_group <= 1'b1; 
        end
    end

    assign pre_empty = pre_empty_group;

    always@(*)begin
        case(fifo_empty)
        2'b00:          event_fifo_empty_reg <= pre_empty_o[0];
        2'b10:          event_fifo_empty_reg <= pre_empty_o[0];
        2'b01:          event_fifo_empty_reg <= pre_empty_o[1];
        default:        event_fifo_empty_reg <= 1;
        
        endcase
    end
    assign event_fifo_empty = event_fifo_empty_reg;

endmodule

module fifo_top1 #(
	parameter width      = 9,
    parameter depth      = 4,
    parameter depth_addr = 2
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push_req_n,
    input  wire              pop_req_n,
    input  wire [width-1: 0] data_in,
    output wire               empty,
    output wire              full,
    output wire [width-1: 0] data_out,
    output wire              pre_empty,
    output wire [width-1: 0] next_data_out,
    output wire              event_fifo_empty
    //
    // output wire              time_driver_en
);


//This File for Creat a 16 FIFOs Group (16 layers network)
    
    genvar i;

    wire [1:0] fifo_full;
    wire [1:0] fifo_empty;
    wire [27:0] fifo_dout;
    wire [27:0] next_fifo_dout;
    wire [1:0]  pre_empty_o;
    assign empty = &fifo_empty;
    assign full  = |fifo_full;
    // push logic 
    reg [1:0] layers_push_en;
    reg [13:0] data_in_reg;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            layers_push_en <= 2'b0;
            data_in_reg <= 14'b0;
        end
        else if(!push_req_n)begin
            layers_push_en[0] <= (data_in >= 14'd0) & (data_in <= 14'd1023);
            layers_push_en[1] <= (data_in >= 14'd1024);
            data_in_reg <= data_in;

        end
        else begin
            layers_push_en <= 2'b0; 
            data_in_reg <= 14'b0;
        end
    end

    //pop logic
    reg [1:0] layers_pop_en_n;
    reg [13:0] data_out_choose;
    reg [13:0] next_data_out_choose;
    always@(*)begin
        if(!pop_req_n)begin
            case(fifo_empty)
                2'b00:    layers_pop_en_n <= 2'b10 ;
                2'b10:    layers_pop_en_n <= 2'b10 ;
                2'b01:    layers_pop_en_n <= 2'b01 ;
                default             :    layers_pop_en_n <= 2'b11 ;
            endcase
        end
        else begin
           layers_pop_en_n <= 2'b11; 
        end
    end

    always@(*)begin
        case(fifo_empty)
            2'b00 : begin data_out_choose <= fifo_dout[13:0]; end
            2'b10 : begin data_out_choose <= fifo_dout[13:0]; end
            2'b01 : begin data_out_choose <= fifo_dout[27:14];end 
            default:begin data_out_choose <= 0;end
        endcase
    end

    assign data_out = data_out_choose;

    always@(*)begin
        case(fifo_empty)
            2'b00 : begin next_data_out_choose <= next_fifo_dout[13:0]; end
            2'b10 : begin next_data_out_choose <= next_fifo_dout[13:0]; end
            2'b01 : begin next_data_out_choose <= next_fifo_dout[27:14];end 
            default:begin next_data_out_choose <= 0;end
        endcase
    end

    assign next_data_out = next_data_out_choose;

    generate
        for(i=0;i<2;i=i+1)begin
            original_fifo #(
                .width(14),
                .depth(1024),
                .depth_addr(10)
            ) fifo_group0(
                .clk(clk),
                .rst_n(rst_n),
                .push_req_n(fifo_full[i] | !layers_push_en[i]),
                .pop_req_n(layers_pop_en_n[i]),
                .data_in(data_in_reg),
                .empty(fifo_empty[i]),
                .full(fifo_full[i]),
                .data_out(fifo_dout[14*i+13:14*i]),
                .pre_empty(pre_empty_o[i]),
                .next_data_out(next_fifo_dout[14*i+13:14*i])
            );
        end
    endgenerate

    reg pre_empty_group;
    reg event_fifo_empty_reg;

    always@(*)begin
        if(!rst_n)begin
            pre_empty_group <= 1'b1; 
        end 
        else if(!fifo_empty[0])begin
            pre_empty_group <= pre_empty_o[0];
        end
        else begin
            pre_empty_group <= 1'b1; 
        end
    end

    assign pre_empty = pre_empty_group;

    always@(*)begin
        case(fifo_empty)
        2'b00:          event_fifo_empty_reg <= pre_empty_o[0];
        2'b10:          event_fifo_empty_reg <= pre_empty_o[0];
        2'b01:          event_fifo_empty_reg <= pre_empty_o[1];
        default:        event_fifo_empty_reg <= 1;
        
        endcase
    end
    assign event_fifo_empty = event_fifo_empty_reg;

endmodule