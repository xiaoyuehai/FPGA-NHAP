module TholdSet(
	input wire CLK,
	input wire RST_N,
	input wire uart_rx,


	output wire uart_tx,

	output wire Sram_We,
	output wire [1:0] Sram_addr,
	output wire [7:0] Sram_Data
	);
	
	wire [7:0]  uart_r_data;
	wire 		rx_done;
	wire [7:0]  send_data;
	wire 		Send_Go;
	wire 		Tx_done;
	reg   		fifo_read;
	wire [7:0]  fifo_dout;
	wire   		fifo_empty;
	wire 		fifo_full;


	uart_rx_high u_r(
		.sclk(CLK),         //系统输入时钟  
		.s_rst_n(RST_N),         //系统复位信号
		
		.rx(uart_rx),         //Rs232串口接收信号
		
		.rx_data(uart_r_data),         //接收到的数据
		.po_flag(rx_done) 					 //传输完成信号
 
	);

	uart_byte_tx u_t(
	    .Clk(CLK),
	    .Reset_n(RST_N),
	    .Data(8'hFF),
	    .Send_Go(Send_Go),
	    .Baud_set(3'b101),
	    .uart_tx(uart_tx),
	    .Tx_done(Tx_done)
	);

	sfifo #(
    .DW(8),.AW(2),.Depth(3)
    )
	    thold_fifo(
	    .clk(CLK),
	    .rst_n(RST_N),
	    .we(rx_done),
	    .re(fifo_read),
	    .din(uart_r_data),
	    .dout(fifo_dout),
	    .empty(fifo_empty),
	    .full(fifo_full)
    );

	always@(*)begin
		if(!RST_N)begin
			fifo_read <= 0;
		end
		else if(fifo_full)begin
			fifo_read <= 1;
		end
		else if(fifo_empty)begin
			fifo_read <= 0;
		end
		else begin
			fifo_read <= fifo_read;
		end
	end

	reg fifo_read_temp;

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			fifo_read_temp <= 0;
		end
		else begin
			fifo_read_temp <= fifo_read;
		end
	end

	reg [1:0] Thold_Sram_addr;

	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			Thold_Sram_addr <= 0;
		end
		else if(fifo_read_temp)begin
			Thold_Sram_addr <= Thold_Sram_addr + 1;
		end
		else begin
			Thold_Sram_addr <= 0;
		end
	end
	reg fifo_empty_temp;
	always@(posedge CLK or negedge RST_N)begin
		if(!RST_N)begin
			fifo_empty_temp <= 0;
		end
		else begin
			fifo_empty_temp <= fifo_empty;
		end
	end
	assign Send_Go = fifo_empty & !fifo_empty_temp;

	assign Sram_We   = fifo_read_temp;
	assign Sram_addr = Thold_Sram_addr;
	assign Sram_Data = fifo_dout;
endmodule