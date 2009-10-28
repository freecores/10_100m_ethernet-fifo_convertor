//author :gurenliang 
//Email: gurenliang@gmail.com
//note: if there are some errors, you are welcome to contact me. It would be the best appreciation to me.

//Next step, reduce the resource consumed

//version 0.5, defined many parameter to configure the IP core, making it easier to use.
//vertion 0.4, add the function for TxModule to get start in a configurable ff_clk time after 
//				RxModule receiving the first frame. To modify the delay time just to 
//				change the value of the macro-variable delay_cnt_config.
//version 0.3, changed the changes made by version 0.2 back
//version 0.2, set empty when ff_data_buf_index's less significant bits is 3'b111 or 3'b000

`include "common.v"

`define ff_source_cnt_len	8	//(2^ff_source_cnt_len) must be larger than uframelen
`define nibble_cnt_len	10	//(2^nibble_cnt_len) must be larger than eth_buf_len/4
`define delay_cnt_len	4	//(2^delay_cnt_len) must be larger than the number of clocks you want TxModule to wait at the beginning
`define delay_cnt_config	4'h9	//the initiation value for the delay_cnt
`define ff_data_buf_index_len	5	//(2^ff_data_buf_index_len) must be larger than or equal to num_uframe*2
`define toggle_lsbs	4'h0		//the length of zeros is ff_data_buf_index_len-1

//8 bytes preamble, 12 bytes source address and destination address, 2 bytes length/type, 3bytes frameID
`define eth_buf_len (8*(8+6+6+2)+`frameidlen+`uframelen*`num_uframe+8*4)	//the last 4 bytes CRC

`define frameid_offset	176								//index of frameid in eth_buf
`define data_offset		(`frameid_offset+`frameidlen)	//index of beginning of data in eth_buf

module RxModule(phy_rxd, phy_rxen, phy_rxclk, phy_rxer,
				ff_clk, ff_data, ff_en, 
				
				`ifdef frameIDfromRx
					frameid, 
				`endif
				
				start);
	input phy_rxen, phy_rxclk, phy_rxer;	//MII interface
	input [3:0] phy_rxd;
	
	input ff_clk;			//270.8333KHz
	output ff_data, ff_en;
	
	`ifdef frameIDfromRx
		output[`frameidlen-1:0] frameid;
	`endif
	
	output start;			//to tell TxModule that buf in RxModule needs data
	reg ff_data;
	reg ff_en;
	
	reg[`uframelen-1:0] ff_data_buf[0:`num_uframe*2-1];	//declare 
	reg[`uframelen-1:0] ff_d;
	reg[`ff_source_cnt_len-1:0] ff_cnt;
	reg[`eth_buf_len-1:0] eth_buf;
	
	reg[`nibble_cnt_len-1:0] nibble_cnt=0;
	
	`ifdef frameIDfromRx
		reg[`frameidlen-1:0] frameidt[0:1];
	`endif
	
	reg start=1'b0;
	reg start_intra=1'b0;
	reg[`delay_cnt_len-1:0] delay_cnt;
	
	reg[`ff_data_buf_index_len-1:0] ff_data_buf_index;
	wire[`ff_data_buf_index_len-1:0] toggle;
	reg ff_state;
	reg[3:0] gap_cnt = 4'h0;
	
	parameter transfer = 1'b0, gap = 1'b1;
	
	always@(posedge phy_rxclk)begin			//receive data from Ethernet including the preamble, SFD and CRC
		if(phy_rxen & ~phy_rxer) begin		//data is valid and no error
			eth_buf <= {phy_rxd, eth_buf[`eth_buf_len-1:4]};
			nibble_cnt <= nibble_cnt + 1;
		end
		else if ((nibble_cnt == (`eth_buf_len>>2) ) & (eth_buf[111:64] == `MAC_ADD)) begin
		//one frame has been transfered over, the destinate address is right and then been put into the buffer
			
			`ifdef frameIDfromRx
				frameidt[~ff_data_buf_index[`ff_data_buf_index_len-1]] <= eth_buf[`data_offset-1:`frameid_offset];
			`endif
			
			`ifdef num_cover_4
				ff_data_buf[toggle     ] <= eth_buf[`data_offset+ 1*`uframelen-1: `data_offset+ 0*`uframelen];
				ff_data_buf[toggle +  1] <= eth_buf[`data_offset+ 2*`uframelen-1: `data_offset+ 1*`uframelen];
				ff_data_buf[toggle +  2] <= eth_buf[`data_offset+ 3*`uframelen-1: `data_offset+ 2*`uframelen];
				ff_data_buf[toggle +  3] <= eth_buf[`data_offset+ 4*`uframelen-1: `data_offset+ 3*`uframelen];
			`ifdef num_cover_8	
				ff_data_buf[toggle +  4] <= eth_buf[`data_offset+ 5*`uframelen-1: `data_offset+ 4*`uframelen];
				ff_data_buf[toggle +  5] <= eth_buf[`data_offset+ 6*`uframelen-1: `data_offset+ 5*`uframelen];
				ff_data_buf[toggle +  6] <= eth_buf[`data_offset+ 7*`uframelen-1: `data_offset+ 6*`uframelen];
				ff_data_buf[toggle +  7] <= eth_buf[`data_offset+ 8*`uframelen-1: `data_offset+ 7*`uframelen];
			`ifdef num_cover_16
				ff_data_buf[toggle +  8] <= eth_buf[`data_offset+ 9*`uframelen-1: `data_offset+ 8*`uframelen];
				ff_data_buf[toggle +  9] <= eth_buf[`data_offset+10*`uframelen-1: `data_offset+ 9*`uframelen];
				ff_data_buf[toggle + 10] <= eth_buf[`data_offset+11*`uframelen-1: `data_offset+10*`uframelen];
				ff_data_buf[toggle + 11] <= eth_buf[`data_offset+12*`uframelen-1: `data_offset+11*`uframelen];
				ff_data_buf[toggle + 12] <= eth_buf[`data_offset+13*`uframelen-1: `data_offset+12*`uframelen];
				ff_data_buf[toggle + 13] <= eth_buf[`data_offset+14*`uframelen-1: `data_offset+13*`uframelen];
				ff_data_buf[toggle + 14] <= eth_buf[`data_offset+15*`uframelen-1: `data_offset+14*`uframelen];
				ff_data_buf[toggle + 15] <= eth_buf[`data_offset+16*`uframelen-1: `data_offset+15*`uframelen];
			`endif
			`endif
			`endif
			
			start_intra <= 1'b1;
			nibble_cnt <= 0;
		end
		else
			nibble_cnt <= 0;
	end
	
	//assign empty = ((ff_data_buf_index[2:0]==3'b011)|(ff_data_buf_index[2:0]==3'b100));
	//every four 148bit, generate an empty signal to the TxModule
	assign toggle = {~ff_data_buf_index[`ff_data_buf_index_len-1],`toggle_lsbs};	//indicate which half buffer is available
	
	`ifdef frameIDfromRx
		assign frameid = frameidt[ff_data_buf_index[`ff_data_buf_index_len-1]];//
	`endif
	
	always@(negedge ff_clk)				//flow the data out of the buffer
		if(start_intra==1'b0) begin			//wait the first frame to come
			ff_state <= transfer;
			ff_cnt <= 0;
			ff_data_buf_index <= -1;	// to fill every bit in ff_data_buf_index with 1s
			ff_en <= 1'b0;
			
			delay_cnt <= `delay_cnt_config;
		end
		else
			case(ff_state)
				transfer: begin
					delay_cnt <= delay_cnt - 1;
					if(delay_cnt == 0) start <=1'b1;
					
					if(ff_cnt==0) begin		//load new 148 bits
						{ff_d[`uframelen-2:0],ff_data} <= ff_data_buf[ff_data_buf_index + 1];
						ff_data_buf_index <= ff_data_buf_index + 1;
						ff_cnt <= ff_cnt + 1;
						ff_en <= 1'b1;
					end
					else if(ff_cnt == `uframelen) begin	//every 148 bit need a gap
						ff_en <= 1'b0;
						ff_cnt <= 0;
						ff_state <= gap;
						ff_data <= 1'b0;
					end
					else begin
						{ff_d[`uframelen-2:0],ff_data} <= ff_d;
						ff_cnt <= ff_cnt + 1;
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
	