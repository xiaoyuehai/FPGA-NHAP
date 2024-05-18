`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/07 19:13:24
// Design Name: 
// Module Name: ahb_dma_pixel
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
// `include "define.v"

module AHB_DMA_Pixel(
	haddr,
    hclk,
    hready,
    hrst_b,
    hsel,
    hwdata,
    hwrite,
    intr,
    hresp,
	hrdata,
    SNN_CLK,

    calca_start,//SNN ????????
    bram_we,    //Bram???
    bram_addr,  //bram???
    bram_wdata, //bram???
    one_time_finish,//????????uart_time??

    SoC_Test_Choose,//????????0?uart 1:SoC
    Counter_Clear,   //?????
	result_class,
	Process_ALL_Time_set,
	Big_time,
	Small_time,
	Events_Nums_Read,
	Spiking_Neuron_Model
	);
	
    input        SNN_CLK;
	input [31:0] haddr;
	input   	 hclk;
	output 		 hready;
	input 		 hrst_b;
	input 	     hsel;
	input [31:0] hwdata;
	input        hwrite;
	output[31:0] hrdata;
	output       intr;
    output[1 :0] hresp;

	input        one_time_finish;
	input [3:0]  result_class;

	output       calca_start;
	output       bram_we;
	output [10:0]bram_addr;
	output [31:0]bram_wdata;
    output       SoC_Test_Choose;
    output       Counter_Clear;
	output [31:0] Process_ALL_Time_set;
	input  [31:0] Big_time;
	input  [31:0] Small_time;
	input  [31:0] Events_Nums_Read;
	output [0 :0] Spiking_Neuron_Model;

    wire         SNN_CLK;
	wire [31:0]  haddr;
	wire   	     hclk;
	wire 		 hready;
	wire 		 hrst_b;
	wire 	     hsel;
	wire [31:0]  hwdata;
	wire [31:0]  hrdata;
	wire         hwrite;
	wire 	     intr;
    wire [1 :0]  hresp;

	wire        one_time_finish;
	wire [3:0]  result_class;
	wire 		calca_start;
	wire        bram_we;
	wire [10:0] bram_addr;
	wire [31:0] bram_wdata; 
    reg         SoC_Test_Choose;
    wire        Counter_Clear;
	wire [31:0] Process_ALL_Time_set;
	wire [31:0] Big_time;
	wire [31:0] Small_time;
	wire [31:0] Events_Nums_Read;
	reg  [0 :0] Spiking_Neuron_Model;

	wire h_write_en;
	// reg [31:0] bram_wdata_reg;
	reg [10:0] bram_addr_reg;
	// reg 	   bram_we;
	reg        h_write_en_reg;
    reg        hready_reg;
	wire       bram_addr_clr;
	wire       SoC_Choose_en;
	wire       Counter_Clr_en;
	wire       Set_Spiking_Neuron;
    wire       intr_clr;
	wire       count_time_start_en;
	reg        count_time_start;
	wire       Process_ALL_Time_en;
	reg        Process_ALL_Time_reg;
	reg [31:0] Process_ALL_Time;

    assign intr_clr = (haddr == 32'h4002040C) & hwrite & hsel;
	assign SoC_Choose_en = (haddr == 32'h40020404) & hwrite & hsel;
	assign Counter_Clr_en = (haddr == 32'h40020408) & hwrite & hsel;
	assign bram_addr_clr = (haddr == 32'h40020000) & hwrite & hsel;
	assign h_write_en =  (32'h40020000 <= haddr <= 32'h40020400) & hwrite & hsel;
	assign count_time_start_en = (haddr == 32'h40020418) & hwrite & hsel;
	assign Set_Spiking_Neuron = (haddr == 32'h4002042C) & hwrite & hsel;
	assign Process_ALL_Time_en = (haddr == 32'h4002041C) & hwrite & hsel;

	always @(posedge hclk or negedge hrst_b) begin
		if(!hrst_b)begin
			Process_ALL_Time_reg <= 0;
		end
		else begin
			Process_ALL_Time_reg <= Process_ALL_Time_en;
		end
	end

	always @(posedge hclk or negedge hrst_b) begin
		if(!hrst_b)begin
			Process_ALL_Time <= 32'b0;
		end
		else if(Process_ALL_Time_reg) begin
			Process_ALL_Time <= hwdata;
		end
	end

	always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			Spiking_Neuron_Model <= 0;
		end
		else if(Set_Spiking_Neuron)begin
			Spiking_Neuron_Model <= hwdata[0];
		end
	end

	assign Process_ALL_Time_set = Process_ALL_Time;

	always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			h_write_en_reg <= 0;
			// count_time_start <= 0;
		end	
		else begin
			h_write_en_reg <= h_write_en;
		end
	end

	always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			count_time_start <= 0;
		end	
		else if(count_time_start_en)begin
			count_time_start <= 1;
		end
		else begin
			count_time_start <= count_time_start;
		end
	end

    always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			bram_addr_reg <= 10'b0;
		end
		else if(bram_addr_clr)begin
			bram_addr_reg <= 10'b0;
		end
		else if(h_write_en_reg) begin
			bram_addr_reg <= bram_addr_reg + 1;
		end
		else begin
			bram_addr_reg <= bram_addr_reg;
		end
	end
	

	assign bram_wdata = hwdata;
	assign bram_we    = h_write_en_reg;
	assign bram_addr  = bram_addr_reg;
    wire   start_wire;
	assign start_wire = (bram_addr_reg == 255) &&  bram_we;

	wire finish_clr;
	reg  finish_temp;
	reg  intr_reg;

	assign finish_clr = !hrst_b | intr_reg;

	always@(posedge one_time_finish or posedge finish_clr)begin
		if(finish_clr)begin
			finish_temp <= 0;
		end
		else begin
			finish_temp <= 1;
		end
	end

	always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			intr_reg <= 0;
		end
		else begin
			intr_reg <= finish_temp;
		end
	end
    reg intr_need_clr;
    always@(posedge hclk or negedge hrst_b)begin
        if(!hrst_b)begin
            intr_need_clr <= 0; 
        end 
        else if(intr_clr)begin
            intr_need_clr <= 0;
        end
        else if(intr_reg)begin
            intr_need_clr <= 1; 
        end
        else begin
            intr_need_clr <= intr_need_clr; 
        end
    end

	reg SoC_Choose_en_reg;
	always@(posedge hclk or negedge hrst_b)begin
		if(!hrst_b)begin
			SoC_Choose_en_reg <= 0;
		end
		else begin
			SoC_Choose_en_reg <= SoC_Choose_en;
		end
	end


    always @(posedge hclk or negedge hrst_b) begin
        if(!hrst_b)begin
            SoC_Test_Choose <= 0; 
        end
        else if(SoC_Choose_en_reg)begin
            SoC_Test_Choose <= hwdata[0];
        end
        // else begin
        //     SoC_Test_Choose <= SoC_Test_Choose;
        // end
    end



	assign intr = intr_need_clr;

	// assign SoC_Test_Choose = SoC_Choose_en;
	assign Counter_Clear = Counter_Clr_en;

    assign hready = ~h_write_en_reg;
    assign hresp = 2'b00;

    wire start_clr;
    reg  start_temp;
    reg  start_reg;

    assign start_clr = !hrst_b | start_reg;

    always@(posedge start_wire or posedge start_clr)begin
        if(start_clr)begin
            start_temp <= 0; 
        end 
        else begin
            start_temp <= 1; 
        end
    end

    always @(posedge SNN_CLK or negedge hrst_b) begin
        if(!hrst_b)begin
            start_reg <= 0; 
        end    
        else begin
            start_reg <= start_temp;
        end
    end

    assign calca_start = start_reg;

	reg [31:0] ihrdata;
	reg [31:0] time_count;
	always @(posedge hclk or negedge hrst_b)
	begin
	if(!hrst_b)
		ihrdata[31:0] <= {32{1'b0}};
	else
		if((hwrite == 1'b0) && (hsel == 1'b1))
		case(haddr)
			32'h40020410:ihrdata <= {{28{1'b0}},result_class};
			32'h40020414:ihrdata <= time_count;
			32'h40020420:ihrdata <= Big_time;
			32'h40020424:ihrdata <= Small_time;
			32'h40020428:ihrdata <= Events_Nums_Read;
		
			default:ihrdata <= {32{1'b0}};
		endcase
		else
			ihrdata <= {32{1'b1}};
	end

assign hrdata[31:0] = ihrdata;



always@(posedge hclk or negedge hrst_b)begin
	if(!hrst_b)begin
		time_count <= 0;
	end
	else if(count_time_start)begin
		time_count <= time_count + 1;
	end
	else begin
		time_count <= 0;
	end
end

endmodule
