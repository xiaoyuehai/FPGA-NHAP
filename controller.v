/**
  ******************************************************************************
  * File Name          : controller.v
  * Author             : Chen Yuehai
  * Version            : 2.0.1
  * date               : 2021/7/9
  * Description        : ?????????
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
`include "define.v"
module controller #(
    parameter N = 1024,
    parameter M = 10,

    parameter SYNAPSE_DATA_WIDTH = 64,    //????????
    parameter TIME_MUL = 16,              //???????????
    parameter MUL_ADDR_NUMS = 64,         //????
    parameter MUL_NEUR_ADDR_WIDTH = 6,    //??????
    parameter INPUT_SYN_NUMS_WIDTH = 11,  //?????????
    parameter NEUR_STATE_WIDTH = 36,      //??????????
    parameter event_out_WIDTH = 7,
    parameter SYN_WEIGHT_WIDTH = 4,       //??????
    parameter MEMPOTENTIAL_WIDTH = 9,     //????????
    parameter REC_WIDTH = 3,              //??????????????
    parameter MEM_THRESHOLD_WIDTH = 9,    //??????????
    parameter FIXED_WIDTH = 12,           //??????
    parameter SYNAPSE_WIDTH = 16,         //?????????
    parameter TIME_STAMP_WIDTH = 3,       //?????
    parameter REAL_INPUT_NEUR_WIDTH = 10,
    parameter REAL_HANG_WIDTH = 6,
    parameter TREF_NEED_CTRL_CNT = 69,
    `ifdef USE_LIF
        parameter Neuron_Mode = 2'b01
    `else 
        parameter Neuron_Mode = 2'b10
    `endif
)(    
     //DDR3 Channel
    input   wire                            Run_Mode,
    output  reg                      [31:0] RD_ADRS,
    input   wire                            RD_DONE,
    output  reg                      [31:0] RD_LEN,
    output  reg                             RD_START,
    // Global inputs ------------------------------------------
    input  wire                             global_leak_time,
    input  wire                             CLK,
    input  wire                             RST,
    
    // Inputs from AER ----------------------------------------
    input  wire [15:0]                      AERIN_ADDR,//21?
    input  wire                             AERIN_REQ,
    output reg                              AERIN_ACK,
    
    // Inputs from scheduler ----------------------------------
    input  wire                             SCHED_EMPTY,
    input  wire                             SCHED_FULL,
    input  wire                             SCHED_BURST_END,
    input  wire[INPUT_SYN_NUMS_WIDTH-1:0]   SCHED_DATA_OUT,
    
    // Input from AER output ----------------------------------
    input  wire                             AEROUT_CTRL_BUSY,
    input wire                              Tref_Event_Out,
    output wire                             Receive_Tref,
    // Outputs to synaptic core -------------------------------
    output reg                              CTRL_PIPELINE_CHOOSE,
    output reg    [MUL_NEUR_ADDR_WIDTH-1:0] ADDR_1,//10 bit
    output reg    [MUL_NEUR_ADDR_WIDTH-1:0] ADDR_2,//10 bit

    output reg    [31:0]                    SYNAPSE_ADDR_1,
    output reg    [31:0]                    SYNAPSE_ADDR_2,

    output reg                              CTRL_ADDR1_READ,

    output reg                              CTRL_SYNAPSE_ADDR_1_WE,
    output reg                              CTRL_SYNAPSE_ADDR_2_WE,
    output reg                              CTRL_PIPLINE_START,
    output reg                              CTRL_SYNAPSE_PIPLINE_START,
    output reg                              CTRL_ADDR_1_WE,
    output reg                              CTRL_ADDR_2_WE,
    output reg    [TIME_MUL-1:0]            CTRL_PRE_EN,

    output reg   [9:0]                      CTRL_NEURMEM_ADDR,
    output reg                              CTRL_SYNARRAY_CS,
    output reg                              CTRL_NEURMEM_CS,
    output reg                              CTRL_NEUR_DISABLE,
    
    // Outputs to neurons -------------------------------------
    output reg                              CTRL_NEUR_EVENT, 
    output reg                              CTRL_NEUR_TREF,
    
    // Outputs to scheduler -----------------------------------
    output reg                              CTRL_SCHED_POP_N,
    output reg    [INPUT_SYN_NUMS_WIDTH-1:0]CTRL_SCHED_ADDR,
    output reg    [  6:0]                   CTRL_SCHED_EVENT_IN,
    
    // Output to AER output -----------------------------------
    output wire                             CTRL_AEROUT_POP_NEUR,
    output wire   [3:0]                     CTRL_STATE,
    output wire   [3:0]                     CTRL_NEXT_STATE,
    output wire   [TIME_STAMP_WIDTH-1:0]    Input_timestamp,
    output wire   [TIME_STAMP_WIDTH-1:0]    neurontimestamp,
    input  wire   [TIME_STAMP_WIDTH-1:0]    neuron_stamp_from_stamp,
    input  wire                             tx_req,
    input  wire                             udp_clk,
    output reg    [7:0]                     tx_data,
    input  wire                             RST_N,
    output wire                             AER_IN_BUSY_out,
    output reg                              global_to_zero,
    output wire [31:0]                      Big_time,
    output wire [31:0]                      Small_time,
    input  wire                             Tref_Event_generate,
    output wire [31:0]                      Events_Nums_Read,
    ///////////////////////////////////////////////////////////
    input  wire                             event_fifo_empty,
    input  wire[INPUT_SYN_NUMS_WIDTH-1:0]   SCHED_DATA_OUT_Next,
    output wire                             FIFO_Read_Choose_out,
    output wire                             FIFO_Write_Choose_out,
    input  wire                             Spiking_Neuron_Model
);
    // reg [1:0] Neuron_Mode;

    // always@(posedge CLK)begin
    //     if(!RST_N)begin
    //         Neuron_Mode <= 2'b01;
    //     end  
    //     else begin
    //         Neuron_Mode <= !Spiking_Neuron_Model ? 2'b01 : 2'b10; 
    //     end
    // end
	// FSM states 
	localparam WAIT             = 4'd0; 
	localparam TREF             = 4'd1;
	localparam POP_NEUR         = 4'd2;
    localparam POP_NEUR_temp    = 4'd3;
    localparam POP_temp_my      = 4'd4;
    localparam DDR3_PRE         = 4'd5;
    localparam DDR3_READ        = 4'd6;
    localparam Add_Temp         = 4'd7;
    localparam Add_Temp2        = 4'd8;
    localparam Add_Temp3        = 4'd9;

	//----------------------------------------------------------------------------------
	//	REGS & WIRES
	//----------------------------------------------------------------------------------
    
    reg          AERIN_REQ_sync_int, AERIN_REQ_sync;
    reg          Receive_Tref_Reg;
    wire         synapse_event, tref_event, bist_event, virt_event, neuron_event;
    wire         AERIN_REQ_negedge;
    reg  [ 31:0] ctrl_cnt;
    reg  [  4:0] neur_cnt;

    reg  [  3:0] state, nextstate;
    
	//----------------------------------------------------------------------------------
	//	EVENT TYPE DECODING
	//----------------------------------------------------------------------------------
    assign CTRL_STATE = state;
    assign CTRL_NEXT_STATE = nextstate;

    assign tref_event     = Tref_Event_Out;//&AERIN_ADDR[6:0];
    assign neuron_event   = !tref_event;
    wire CP_IN_Check_Empty;

    assign Receive_Tref = Receive_Tref_Reg;
	//----------------------------------------------------------------------------------
	//	SYNC BARRIERS FROM AER AND FROM SPI
	//----------------------------------------------------------------------------------
    assign Input_timestamp = AERIN_ADDR[15:12];
    assign neurontimestamp = neuron_stamp_from_stamp;


    wire read_src_dst_ena;
    wire [19:0] src_dst_data_wire;
    wire [19:0] src_dst_data_for_read_cnt;
    reg [6:0] next_read_cnt;

    reg  [19:0] src_dst_data;
    reg [9 :0] src_addr;
    reg [6 :0] ctrl_cnt_need;

    // assign read_src_dst_ena = (nextstate == POP_NEUR_temp & state == POP_temp_my);

    // neuron_src_dst your_instance_name (
    //     .clka(CLK),    // input wire clka
    //     .ena(~SCHED_EMPTY),      // input wire ena
    //     .addra(SCHED_DATA_OUT),  // input wire [13 : 0] addra
    //     .douta(src_dst_data_wire),  // output wire [19 : 0] douta
    //     .clkb(CLK),    // input wire clkb
    //     .enb(!event_fifo_empty),      // input wire enb
    //     .addrb(SCHED_DATA_OUT_Next),  // input wire [13 : 0] addrb
    //     .doutb(src_dst_data_for_read_cnt)  // output wire [19 : 0] doutb
    // );

    neuron_src_dst neuron_src_dst_0 (
        .clka(CLK),    // input wire clka
        .ena(1),      // input wire ena
        .addra(SCHED_DATA_OUT),  // input wire [13 : 0] addra
        .douta(src_dst_data_wire)  // output wire [19 : 0] douta
    );

    neuron_src_dst neuron_src_dst_1 (
        .clka(CLK),    // input wire clka
        .ena(1),      // input wire ena
        .addra(SCHED_DATA_OUT_Next),  // input wire [13 : 0] addra
        .douta(src_dst_data_for_read_cnt)  // output wire [19 : 0] douta
    );

    // assign next_read_cnt = src_dst_data_for_read_cnt[6:0];

    always@(posedge CLK or posedge RST)begin
        if(RST)begin
            src_addr <= 0;
            ctrl_cnt_need <= 0;
            next_read_cnt <= 0;
        end 
        else begin
            src_addr <= src_dst_data_wire[16:7];
            ctrl_cnt_need <= src_dst_data_wire[6:0];
            next_read_cnt <= src_dst_data_for_read_cnt[6:0];
        end
    end

    // assign ctrl_cnt_need = src_dst_data_wire[6:0];//can use again 7

    // assign src_addr = src_dst_data_wire[16:7];// src_addr can use again just for tingsua 10

    always @(posedge CLK, posedge RST) begin
		if(RST) begin
			AERIN_REQ_sync_int           <= 1'b0;
			AERIN_REQ_sync	             <= 1'b0;
		end
		else begin
			AERIN_REQ_sync_int           <= AERIN_REQ;
			AERIN_REQ_sync	             <= AERIN_REQ_sync_int;

		end
	end
    assign AERIN_REQ_negedge = AERIN_REQ_sync & ~AERIN_REQ_sync_int;
    reg in_waiting;
    reg AER_IN_BUSY;
    assign AER_IN_BUSY_out = AER_IN_BUSY;

    always @(posedge CLK or posedge RST) begin
        if(RST)begin
            CTRL_SCHED_EVENT_IN <= 0;
            CTRL_SCHED_ADDR     <= 0;
            in_waiting          <= 0;
            AERIN_ACK           <= 0;
            AER_IN_BUSY         <= 0;
        end
        else if(AERIN_REQ_negedge)begin
            CTRL_SCHED_EVENT_IN <= 0;
            CTRL_SCHED_ADDR     <= 0;
            in_waiting          <= 0;
            AERIN_ACK           <= 0;
            AER_IN_BUSY         <= 0;
        end
        else if(AERIN_REQ_sync & ~in_waiting) begin
            CTRL_SCHED_EVENT_IN <= 7'h40;
            CTRL_SCHED_ADDR     <= {AERIN_ADDR[11:0]};
            in_waiting          <= 1;
            AERIN_ACK           <= 1;
            AER_IN_BUSY         <= 1;
        end
        else if(in_waiting)begin
            CTRL_SCHED_EVENT_IN <= 7'h00;
            CTRL_SCHED_ADDR     <= CTRL_SCHED_ADDR;
            in_waiting          <= in_waiting;
            AERIN_ACK           <= AERIN_ACK;
            AER_IN_BUSY         <= 0;
        end
        else begin
            CTRL_SCHED_EVENT_IN <= 0;
            CTRL_SCHED_ADDR     <= CTRL_SCHED_ADDR;
            in_waiting          <= in_waiting;
            AERIN_ACK           <= AERIN_ACK;
            AER_IN_BUSY         <= 0;
        end
    end
    
    
	//----------------------------------------------------------------------------------
	//	CONTROL FSM
	//----------------------------------------------------------------------------------
    
    // State register
	always @(posedge CLK, posedge RST)
	begin
		if   (RST) state <= WAIT;
		else       state <= nextstate;
	end
    reg Leak_flag;
    always @(posedge CLK or posedge RST) begin
        if(RST)begin
           Leak_flag <= 0; 
        end
        else if(global_leak_time)begin
            Leak_flag <= 1;
        end
        else if(global_leak_time == 0)begin
           Leak_flag <= 0; 
        end
        else begin
           Leak_flag <= Leak_flag; 
        end
    end

	// Next state logic
    wire CP_IN_WAIT;
    wire CP_IN_DDR_PRE;
    wire CP_IN_DDR_READ;
    wire CP_IN_DDR_READ_Finish;
    

    reg FIFO_Write_Choose,FIFO_Read_Choose;//Write for 0;Read from 0

    always@(posedge CLK or posedge RST)begin
        if(RST)begin
            FIFO_Write_Choose <= 1'b1;  
        end 
        else if(RD_START)begin
            FIFO_Write_Choose <= ~FIFO_Write_Choose; 
        end
        else begin
            FIFO_Write_Choose <= FIFO_Write_Choose;
        end
    end

    always@(posedge CLK or posedge RST)begin
        if(RST)begin
            FIFO_Read_Choose <= 1'b0; 
        end 
        else if(state == POP_NEUR & nextstate == WAIT)begin
            FIFO_Read_Choose <= ~FIFO_Read_Choose; 
        end
        else begin
            FIFO_Read_Choose <= FIFO_Read_Choose;
        end 
    end

    assign FIFO_Write_Choose_out = FIFO_Write_Choose;
    assign FIFO_Read_Choose_out = FIFO_Read_Choose;

    CP_Controler_FSM CP_Controler_FSM0( 
	.CLK(CLK),
	.RST_N(!RST),
	.Main_FSM_state(state),
	.event_fifo_empty(event_fifo_empty),
	.RD_Done(CP_IN_DDR_READ?RD_DONE:1'b0),

	.CP_IN_WAIT(CP_IN_WAIT),
	.CP_IN_DDR_PRE(CP_IN_DDR_PRE),
	.CP_IN_DDR_READ(CP_IN_DDR_READ),
	.CP_IN_DDR_READ_Finish(CP_IN_DDR_READ_Finish),
    .CP_IN_Check_Empty(CP_IN_Check_Empty)

	);

    always @(posedge CLK or posedge RST) begin
        if(RST)begin
            CTRL_SCHED_POP_N <= 1;
        end
        else if(state == WAIT && nextstate == POP_temp_my)begin
            CTRL_SCHED_POP_N <= 0;
        end
        else begin
            CTRL_SCHED_POP_N <= 1;
        end 
    end
	always @(*)
		case(state)
			WAIT 		:	if      (AEROUT_CTRL_BUSY)                                                                      nextstate = WAIT;
                            else if(global_leak_time & !Leak_flag)                                                          nextstate = TREF;
                            else if(tref_event)begin                                                                        nextstate = TREF; Receive_Tref_Reg = 1;end

                            else
                                if (((!global_leak_time & Run_Mode) | !Run_Mode) & SCHED_FULL)
                                                                                                                            nextstate = POP_temp_my;
                                else if (((!global_leak_time & Run_Mode) | !Run_Mode) & ~SCHED_EMPTY)
                                                                                                                            nextstate = POP_temp_my;
                                else                                                                                        nextstate = WAIT;
			TREF    	:   if      (ctrl_cnt == TREF_NEED_CTRL_CNT+1 && Neuron_Mode == `LIF_Pre_Dict)begin
                                Receive_Tref_Reg = 0;
                                nextstate = WAIT;
                                if(Leak_flag)
                                    global_to_zero = 1;
                                else
                                    global_to_zero = 0; 
                            end
                            else if(ctrl_cnt == TREF_NEED_CTRL_CNT+3 && (Neuron_Mode == `Izh))begin
                                Receive_Tref_Reg = 0;
                                nextstate = WAIT;
                                if(Leak_flag)
                                    global_to_zero = 1;
                                else
                                    global_to_zero = 0; 
                            end
							else begin nextstate = TREF;Receive_Tref_Reg = 0; end

            POP_temp_my :                                                                                                   nextstate = Add_Temp;
            Add_Temp : nextstate = Add_Temp2;
            Add_Temp2: nextstate = Add_Temp3;
            Add_Temp3: nextstate = POP_NEUR_temp;
            POP_NEUR_temp : begin
                if(CP_IN_WAIT)begin
                    nextstate = DDR3_PRE;
                end
                else if(CP_IN_DDR_READ_Finish)begin
                    nextstate = POP_NEUR;
                end
                else begin
                    nextstate = POP_NEUR_temp; 
                end
            end                                                                  
            DDR3_PRE:                                                                                                       nextstate = DDR3_READ;
            DDR3_READ:begin
                if(RD_DONE)begin
                    nextstate = POP_NEUR; 
                end
                else begin
                    nextstate = DDR3_READ; 
                end
            end
			POP_NEUR    :   if      (ctrl_cnt == ctrl_cnt_need+1)                                                             nextstate = WAIT;
							else					                                                                        nextstate = POP_NEUR;                
			
			default		:							                                                                        nextstate = WAIT;
		endcase 

    reg [31:0] Events_Nums;
    always@(posedge CLK or negedge RST_N)begin
        if(!RST_N)begin
            Events_Nums <= 0;
        end 
        else if(Tref_Event_generate ||(state == POP_temp_my))begin
            Events_Nums <= Events_Nums + 1; 
        end
        else begin
            Events_Nums <= Events_Nums; 
        end
    end
    assign Events_Nums_Read = Events_Nums;
    always @(posedge CLK or posedge RST) begin
        if(RST)begin
            RD_START <= 0;
            RD_LEN   <= 0;
            RD_ADRS  <= 32'h80000000;
        end 
        else if(state == DDR3_PRE)begin
           RD_START <= 1;
           RD_LEN   <= ctrl_cnt_need - 2;
           RD_ADRS  <= {7'b1000000,SCHED_DATA_OUT,11'b000_0000_0000};
        end
        else if(CP_IN_DDR_PRE)begin
           RD_START <= 1;
           RD_LEN   <= next_read_cnt - 2;
           RD_ADRS  <= {7'b1000000,SCHED_DATA_OUT_Next,11'b000_0000_0000};  
        end
        else begin
           RD_START <= 0;
           RD_LEN   <= RD_LEN;
           RD_ADRS  <= RD_ADRS;
        end
    end

	always @(posedge CLK, posedge RST)
		if      (RST)               begin ctrl_cnt <= 32'd0;end
        else if (state == WAIT || state == POP_NEUR_temp || state == DDR3_READ || state == POP_temp_my)     begin ctrl_cnt <= 32'd0; end
		else if (!AEROUT_CTRL_BUSY) begin ctrl_cnt <= ctrl_cnt + 32'd1; end
        else                        begin ctrl_cnt <= ctrl_cnt;end

    always@(negedge CLK,posedge RST)begin
       if       (RST)               begin CTRL_NEUR_DISABLE<= 1'b0; end
       else if  (state == WAIT)     begin CTRL_NEUR_DISABLE<= 1'b0; end
       else if  (!AEROUT_CTRL_BUSY) begin if(ctrl_cnt[0] == 1'b1) CTRL_NEUR_DISABLE <= 1'b0; else CTRL_NEUR_DISABLE <= 1'b1; end
       else                         begin CTRL_NEUR_DISABLE <= CTRL_NEUR_DISABLE; end
    end

    reg  [31:0]  All_Test_time_Use/* synthesis syn_keep=1 */;
    reg  [31:0]  counter_1s/* synthesis syn_keep=1 */;
    // /* synthesis syn_keep=1 */
    always @(posedge CLK or negedge RST_N) begin
        if(!RST_N)begin
           All_Test_time_Use <= 0; 
           counter_1s <= 0;
        end
        else if(state != WAIT)begin
            if(All_Test_time_Use == 99999999)begin
                All_Test_time_Use <= 0;
                counter_1s <= counter_1s + 1;
            end
            else begin
               All_Test_time_Use <= All_Test_time_Use + 1; 
               counter_1s <= counter_1s;
            end
            
        end
        else begin
            All_Test_time_Use <= All_Test_time_Use;
            counter_1s <= counter_1s;
        end
    end

    assign Big_time = counter_1s;
    assign Small_time = All_Test_time_Use;

    reg [2:0] index;
    always @(posedge udp_clk or negedge RST_N) begin
        if(!RST_N)begin
            index <= 0; 
            tx_data <= 0;   
        end
        else if(tx_req)begin
            case(index)
                0:tx_data <= counter_1s[31:24];
                1:tx_data <= counter_1s[23:16];
                2:tx_data <= counter_1s[15: 8];
                3:tx_data <= counter_1s[7 : 0];
                4:tx_data <= All_Test_time_Use[31:24];
                5:tx_data <= All_Test_time_Use[23:16];
                6:tx_data <= All_Test_time_Use[15: 8];
                7:tx_data <= All_Test_time_Use[7 : 0];
            endcase
            if(index == 7)begin
                index <= 0; 
            end
            else begin
                index <= index + 1;
            end
        end
        else begin
            index <= index; 
            tx_data <= 8'h21;
        end
        
    end


    always@(posedge CLK , posedge RST)begin
       if(RST)                                                          begin ADDR_1 <= 0;end
       else if(state == WAIT)                                           begin ADDR_1 <= 0;end
       else if(state == TREF)begin
           ADDR_1 <= ADDR_1 + 1'b1;
       end
       else if(state == DDR3_PRE | (state != nextstate && nextstate == POP_NEUR))begin
           ADDR_1 <= src_dst_data_wire[16:7];//10bit <= 2bit + 8bit
       end
       else if(state == POP_NEUR)                                         begin 
           ADDR_1 <= ADDR_1 + 1'b1;
        end
       else                                                             begin ADDR_1 <= ADDR_1;end
    end

    always@(posedge CLK , posedge RST)begin
       if(RST)                                                          begin ADDR_2 <= 0; end
       else if(state == WAIT)                                           begin ADDR_2 <= 0;end
       else if(state == TREF)begin
           if(Neuron_Mode == `LIF_Pre_Dict)begin
                case(ctrl_cnt)
                    0,1,2,3    :ADDR_2 <= 0;
                    default  :ADDR_2 <= ADDR_2 + 1;
                endcase
           end
           else if(Neuron_Mode == `Izh)begin
                case(ctrl_cnt)
                    0,1,2,3,4,5    :ADDR_2 <= 0;
                    default    :ADDR_2 <= ADDR_2 + 1;
                endcase
           end
           
       end
       else if(state == POP_NEUR)begin
           case(ctrl_cnt)
                0,1,2,3    :ADDR_2 <= {src_addr};
                default:ADDR_2 <= ADDR_2 + 1;
           endcase
       end
       else begin
          ADDR_2 <= ADDR_2; 
       end
    end

    always@(posedge CLK , posedge RST)begin
       if(RST)                                                                  begin CTRL_ADDR_2_WE <= 1'b0; end
       else if(state == WAIT)                                                   begin CTRL_ADDR_2_WE <= 1'b0; end
       else if(state == TREF)begin
           if(Neuron_Mode == `LIF_Pre_Dict)begin
                case(ctrl_cnt)
                    0,1,2     : CTRL_ADDR_2_WE <= 0;
                    3       : CTRL_ADDR_2_WE <= 1;
                    TREF_NEED_CTRL_CNT+1     : CTRL_ADDR_2_WE <= 0;
                    default : CTRL_ADDR_2_WE <= CTRL_ADDR_2_WE;
                endcase
           end
           else if(Neuron_Mode == `Izh)begin
                case(ctrl_cnt)
                    0,1,2,3,4 : CTRL_ADDR_2_WE <= 0;
                    5       : CTRL_ADDR_2_WE <= 1;
                    TREF_NEED_CTRL_CNT+3     : CTRL_ADDR_2_WE <= 0;
                    default : CTRL_ADDR_2_WE <= CTRL_ADDR_2_WE;
                endcase
           end
       end
       else if(state == POP_NEUR)begin
           if(ctrl_cnt == 0 || ctrl_cnt == 1 || ctrl_cnt == 2)begin
               CTRL_ADDR_2_WE <= 0;
           end 
           else if(ctrl_cnt == 3)begin
               CTRL_ADDR_2_WE <= 1;
           end
           else if(ctrl_cnt >= ctrl_cnt_need+1)begin
               CTRL_ADDR_2_WE <= 0;
           end
           else begin
               CTRL_ADDR_2_WE <= CTRL_ADDR_2_WE;  
           end
       end  
       else begin
          CTRL_ADDR_2_WE <= 0; 
       end
    end

    always@(posedge CLK , posedge RST)begin
       if(RST)                                                          begin SYNAPSE_ADDR_1 <= 0;end
       else if(state == POP_NEUR_temp)                                  begin SYNAPSE_ADDR_1 <= {SCHED_DATA_OUT[REAL_INPUT_NEUR_WIDTH-1:0],6'b0};end
       else if(state == POP_NEUR && ctrl_cnt >= ctrl_cnt_need-2)        begin SYNAPSE_ADDR_1 <= 0;  end
       else if(state == POP_NEUR)                                       begin SYNAPSE_ADDR_1 <= SYNAPSE_ADDR_1 + 1'b1; end
       else                                                             begin SYNAPSE_ADDR_1 <= 0;end
    end



    always@(posedge CLK,posedge RST)begin
        if(RST)                                                          begin CTRL_PIPLINE_START <= 1'b0;end
        else if(state == WAIT)                                           begin CTRL_PIPLINE_START <= 1'b0;end
        else if(state == TREF) begin 
            if(Neuron_Mode == `LIF_Pre_Dict)begin
                case(ctrl_cnt)
                        3:  CTRL_PIPLINE_START <= 1;
                        TREF_NEED_CTRL_CNT: CTRL_PIPLINE_START <= 0;
                        default:CTRL_PIPLINE_START <= CTRL_PIPLINE_START;
                endcase
            end
            else if(Neuron_Mode == `Izh)begin
                case(ctrl_cnt)
                        5:  CTRL_PIPLINE_START <= 1;
                        TREF_NEED_CTRL_CNT+2: CTRL_PIPLINE_START <= 0;
                        default:CTRL_PIPLINE_START <= CTRL_PIPLINE_START;
                endcase
            end

        end

        else if(state == POP_NEUR)   begin 
           case(ctrl_cnt)
                2: CTRL_PIPLINE_START <= 1;
                ctrl_cnt_need :CTRL_PIPLINE_START <= 0;
                default:CTRL_PIPLINE_START <= CTRL_PIPLINE_START;
           endcase 
        end     
        else begin 
           CTRL_PIPLINE_START <= 1'b0; 
        end 
    end

    // assign CTRL_NEURMEM_ADDR = ADDR_2;
    
    always@(posedge CLK , posedge RST)begin
       if(RST)                                                          begin CTRL_NEURMEM_ADDR <= 0; end
       else if(state == WAIT)                                           begin CTRL_NEURMEM_ADDR <= 0;end
       else if(state == TREF)begin
            if(Neuron_Mode == `LIF_Pre_Dict)begin
                case(ctrl_cnt)
                        0,1,2    :CTRL_NEURMEM_ADDR <= 0;
                        default  :begin
                            if(CTRL_NEURMEM_ADDR == 63)begin
                                    CTRL_NEURMEM_ADDR <= 0;
                            end
                            else if(CTRL_NEURMEM_ADDR == 127)begin
                                    CTRL_NEURMEM_ADDR <= 0;
                            end
                            else begin
                                    CTRL_NEURMEM_ADDR <=  CTRL_NEURMEM_ADDR + 1;
                            end
                        end
                endcase
            end
            else if(Neuron_Mode == `Izh)begin
                case(ctrl_cnt)
                        0,1,2,3,4,5    :CTRL_NEURMEM_ADDR <= 0;
                        default  :begin
                            if(CTRL_NEURMEM_ADDR == 63)begin
                                    CTRL_NEURMEM_ADDR <= 0;
                            end
                            else if(CTRL_NEURMEM_ADDR == 127)begin
                                    CTRL_NEURMEM_ADDR <= 0;
                            end
                            else begin
                                    CTRL_NEURMEM_ADDR <=  CTRL_NEURMEM_ADDR + 1;
                            end
                        end
                endcase
            end
       end
       else if(state == POP_NEUR)begin
           case(ctrl_cnt)
                0,1,2    :CTRL_NEURMEM_ADDR <= 0;
                default:CTRL_NEURMEM_ADDR <= CTRL_NEURMEM_ADDR + 1;
           endcase
       end
       else begin
          CTRL_NEURMEM_ADDR <= CTRL_NEURMEM_ADDR; 
       end
    end


    // Output logic      
    always @(*) begin
        if (state == TREF) begin//ctrl_cnt <- clk ????
            CTRL_PRE_EN         = 8'b0;
            // CTRL_SCHED_POP_N    = 1'b1;

            if(ctrl_cnt >= TREF_NEED_CTRL_CNT-2)begin
                CTRL_ADDR1_READ     = 1'b0;
            end
            else CTRL_ADDR1_READ     = 1'b1;

            CTRL_NEUR_EVENT     = 1'b1;
            CTRL_NEUR_TREF      = 1'b1;
            CTRL_NEURMEM_CS     = 1'b1;
            if (ctrl_cnt[0] == 1'd0) begin
                CTRL_PIPELINE_CHOOSE = 1'b1;
                CTRL_ADDR_1_WE = 1'b0;
            end else begin
                CTRL_PIPELINE_CHOOSE = 1'b0;
                CTRL_ADDR_1_WE = 1'b1;
            end
        
        end 
       
        else if (state == POP_NEUR) begin  
            if(ctrl_cnt >= ctrl_cnt_need - 2)begin
                CTRL_ADDR1_READ   = 1'b0;
            end
            else CTRL_ADDR1_READ  = 1'b1;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SYNARRAY_CS    = 1'b1;
            // CTRL_SCHED_POP_N    = ~(ctrl_cnt == ctrl_cnt_need+1) ;//~&ctrl_cnt[5:0];
            CTRL_NEUR_EVENT     = 1'b1;
            CTRL_NEURMEM_CS     = 1'b1;
            if (ctrl_cnt[0] == 1'b0) begin
                CTRL_PIPELINE_CHOOSE = 1'b1;
                
            end else begin 
                CTRL_PIPELINE_CHOOSE = 1'b0;

            end 
        
        end else begin
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_NEURMEM_CS     = 1'b0;
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_PRE_EN         = 8'b0;
            // CTRL_SCHED_POP_N    = 1'b1;
            CTRL_PIPELINE_CHOOSE = 1'b0;
        end
    end

    
endmodule