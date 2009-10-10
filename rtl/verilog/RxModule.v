//author :gurenliang 
//Email: gurenliang@gmail.com
//note: if there are some errors, you are welcome to contact me. It would be the best appreciation to me.

////Next task: make the feedback to PC showing need data.

//vertion 0.4, add the function for TxModule to get start in a configurable ff_clk time after 
//				RxModule receiving the first frame. To modify the delay time just to 
//				change the value of the macro-variable delay_cnt_config.
//version 0.3, changed the changes made by version 0.2 back
//version 0.2, set empty when ff_data_buf_index's less significant bits is 3'b111 or 3'b000

`include "common.v"

`define eth_buf_len 1416			//1416=8*(8+6+6+2+3+148+4)
`define nibble_cnt_step 9'h001

`define delay_cnt_config 4'h0
`define delay_cnt_step 4'h1

module RxModule(phy_rxd, phy_rxen, phy_rxclk, phy_rxer,
				ff_clk, ff_data, ff_en, 
				
				`ifdef frameIDfromRx
					frameid, 
				`endif
				
				empty, start);
	input phy_rxen, phy_rxclk, phy_rxer;	//MII interface
	input [3:0] phy_rxd;
	
	input ff_clk;			//270.8333KHz
	output ff_data, ff_en;
	
	`ifdef frameIDfromRx
		output[23:0] frameid;
	`endif
	
	output empty, start;			//to tell TxModule that buf in RxModule needs data
	reg ff_data;
	reg ff_en;
	
	reg[147:0] ff_data_buf[0:15];	//
	reg[147:0] ff_d;
	wire[3:0] toggle;
	reg[7:0] ff_cnt = 8'h00;
	reg[`eth_buf_len-1:0] eth_buf;
	
	reg[8:0] nibble_cnt=9'h00;
	
	`ifdef frameIDfromRx
		reg[23:0] frameidt[0:1];
	`endif
	
	reg start=1'b0;
	reg start_intra=1'b0;
	reg[3:0] delay_cnt;
	
	reg[3:0] ff_data_buf_index = 4'h0;
	reg ff_state;
	reg[3:0] gap_cnt = 4'h0;
	
	parameter transfer = 1'b0, gap = 1'b1;
	
	always@(posedge phy_rxclk)begin			//receive data from Ethernet including the preamble, SFD and CRC
		if(phy_rxen & ~phy_rxer) begin		//data is valid and no error
			eth_buf <= {phy_rxd, eth_buf[`eth_buf_len-1:4]};
			nibble_cnt <= nibble_cnt + `nibble_cnt_step;
		end
		else if ((nibble_cnt == 9'd354 ) & ((eth_buf[111:64] ^ `MAC_ADD)==48'h0)) begin
		//one frame has been transfered over, the destinate address is right and then been put into the buffer
			
			`ifdef frameIDfromRx
				frameidt[toggle[3]] <= eth_buf[199:176];
			`endif
			
			ff_data_buf[toggle     ] <= eth_buf[347:200];
			ff_data_buf[toggle+4'h1] <= eth_buf[495:348];
			ff_data_buf[toggle+4'h2] <= eth_buf[643:496];
			ff_data_buf[toggle+4'h3] <= eth_buf[791:644];
			ff_data_buf[toggle+4'h4] <= eth_buf[939:792];
			ff_data_buf[toggle+4'h5] <= eth_buf[1087:940];
			ff_data_buf[toggle+4'h6] <= eth_buf[1235:1088];
			ff_data_buf[toggle+4'h7] <= eth_buf[1383:1236];
			start_intra <= 1'b1;
			nibble_cnt <= 9'h000;
		end
		else
			nibble_cnt <= 9'h000;
	end
	
	assign empty = ((ff_data_buf_index[2:0]==3'b011)|(ff_data_buf_index[2:0]==3'b100));
	//every four 148bit, generate an empty signal to the TxModule
	assign toggle = {~ff_data_buf_index[3],3'h0};	//indicate which half buffer is available
	
	`ifdef frameIDfromRx
		assign frameid = frameidt[ff_data_buf_index[3]];//
	`endif
	
	always@(negedge ff_clk)				//flow the data out of the buffer
		if(start_intra==1'b0) begin			//wait the first frame to come
			ff_state <= transfer;
			ff_cnt <= 8'h00;
			ff_data_buf_index <= 4'hf;
			ff_en <= 1'b0;
			
			delay_cnt <= `delay_cnt_config;
		end
		else
			case(ff_state)
				transfer: begin
					delay_cnt <= delay_cnt - `delay_cnt_step;
					if(delay_cnt == 0) start <=1'b1;
					
					if(ff_cnt==8'h00) begin		//load new 148 bits
						{ff_d[146:0],ff_data} <= ff_data_buf[ff_data_buf_index+4'h1];
						ff_data_buf_index <= ff_data_buf_index + 4'h1;
						ff_cnt <= ff_cnt + 8'h01;
						ff_en <= 1'b1;
					end
					else if(ff_cnt == 8'd148) begin	//every 148 bit need a gap
						ff_en <= 1'b0;
						ff_cnt <= 8'h0;
						ff_state <= gap;
						ff_data <= 1'b0;
					end
					else begin
						{ff_d[146:0],ff_data} <= ff_d;
						ff_cnt <= ff_cnt + 8'h01;
					end
				end
				gap: begin		//the 8.25 bit gap is implement by (3*8+9)/4
					gap_cnt <= gap_cnt + 4'h1;
					if(((ff_data_buf_index[1:0]==2'b11)&(gap_cnt == 4'h7)) 
						| ((ff_data_buf_index[1:0]!=2'b11)&(gap_cnt == 4'h6)))begin
						gap_cnt <= 4'h0;
						ff_state <= transfer;
					end
				end
			endcase
endmodule
	