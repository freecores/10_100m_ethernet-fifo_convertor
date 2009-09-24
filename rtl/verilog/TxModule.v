//This module is used to receive data from the demodulate module and send the data to the Ethernet PHY chip
`define tx_data_buf_len 649		//3*8+156.25*4
`define tx_data_len 656			//make the length of tx_data_buf be conformed to IEEE802.3

`define ff_cnt_wide 11
`define ff_cnt_init 11'd25
`define ff_cnt_step 11'h1

module TxModule(reset, phy_txd, phy_txen, phy_txclk, phy_txer,
				ff_clk, ff_en, ff_data, frameid, empty, start,
				test1, test2, test3, test4);
	input phy_txclk, reset;
	input ff_clk, ff_en, ff_data;	//ff_clk should be 207.83333KHz
	input[23:0] frameid;			//get the frameid information from RxModule
	input empty, start;					//decide whether should give out the "need-data" ethernet package
	output [3:0] phy_txd;			//MII
	output phy_txen, phy_txer;
	
	output test1, test2, test3, test4;
	reg test1;//, test2, test3, test4;
	
	reg[3:0] phy_txd;
	reg phy_txen;
	
	reg[175:0] pre;
	//reg[175:0] pre_buf=176'h0008_5952_264C_5247_FFFF_FFFF_FFFF_D555_5555_5555_5555;
	reg[159:0] pre_buf=159'h0100_0000_0000_FFFF_FFFF_FFFF_D555_5555_5555_5555;
	//already stored MAC preamble, destination address and source address from right to left respectively. 
	
	//reg[223:0] temp_buf=224'h0186_15ac_0000_0000_0000_be86_15ac_88fe_467d_2300_0100_0406_0008_0100;
	//reg[223:0] temp_buf=224'h0000_0000_0000_0000_0000_0000_0000_0000_467d_2300_0100_0a30_0008_0100;
	
	reg[`tx_data_buf_len-1:0] tx_data_buf[0:1];	//two buffer helps to step over different frame seamlessly
	reg pre_toggle, toggle=1'b0;		//helps to decide when to give PC a MAC frame
	reg[`tx_data_len-1:0] tx_data;		//used as FIFO
		
	reg[`ff_cnt_wide-1:0] ff_cnt=0;		
		
	reg[8:0] tx_cnt;
	
	reg Enable_Crc, Initialize_Crc;		//declare the variables for the CRC module
	wire [3:0] Data_Crc;
	wire CrcError;
	wire [31:0] Crc;
	
	// Declare state register
	reg	[2:0]state;

	// Declare states
	parameter s_idle = 3'h0, s_pre = 3'h1, s_add = 3'h2, s_data = 3'h3, s_crc =3'h4;
	
	assign test2 = state[2];
	assign test3 = state[1];
	assign test4 = state[0];
	
	always @ (posedge ff_clk) begin		//receive data from demodulate module every bit one by one
		if(ff_en & start) begin
			if (ff_cnt==0) begin
				tx_data_buf[toggle][`tx_data_buf_len-1:`tx_data_buf_len-25] <= {ff_data, frameid};
				ff_cnt <= `ff_cnt_init; //11'd25
				//tosend <= 1'b0;
			end
			else if (ff_cnt == `tx_data_buf_len-1) begin
				tx_data_buf[toggle] <= {ff_data, tx_data_buf[toggle][`tx_data_buf_len-1:1]};
				//tx_data_buf[toggle] <= {144'h0,temp_buf};
				ff_cnt <= 0;
				toggle <= ~toggle;
				//tosend <= 1'b1;
			end
			else begin
				tx_data_buf[toggle] <= {ff_data, tx_data_buf[toggle][`tx_data_buf_len-1:1]};
				ff_cnt <= ff_cnt + `ff_cnt_step;
			end
		end
		//else if(ff_cnt != 0) begin
		//	tx_data_buf[toggle] <= {(tx_data_buf[toggle][`MAXLEN-1:8]>>(`DATALEN-ff_cnt)),2'b00 ,ff_cnt[8:3]};
			//tx_data_buf[toggle] <= {144'h0,temp_buf};
		//	ff_cnt <= 0;
		//	toggle <= ~toggle;
			//tosend <= 1'b1;
		//end
		//else tosend <=1'b0;
	end
	
	assign phy_txer = 1'b0;

	// Determine the next state
	always @ (negedge phy_txclk) begin	//state machine run to send out the MAC frame
		if (reset)
			state <= s_idle;
		else begin
			case (state)
				s_idle: begin		//wait to be trigged
					test1 <= ~test1;
					if(pre_toggle ^ toggle)	//once be trigged, prepare the data to send
						state <= s_pre;
					else state <= s_idle;
				end
				
				s_pre:			//send the preambles
					if(tx_cnt ==9'h00f)
						state <= s_add;
					else
						state <= s_pre;
						
				s_add: begin		//send the destination address, source address and type
					if(tx_cnt==9'h02b)
						state <= s_data;
					else
						state <= s_add;
				end
				s_data:					//send data to PHY, every time four bits, lower bits go first
					//test2 <= ~test2;
					if (tx_cnt == (`tx_data_len >> 2)+9'h02b)
						state <= s_crc;
					else state <= s_data;
				
				s_crc:
					if (tx_cnt == (`tx_data_len >> 2)+9'h033)
						state <= s_idle;
					else
						state <= s_crc;
				
				default: 
					state <= s_idle;
			endcase
		end
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		pre_toggle <= toggle;
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			tx_cnt <= 9'h000;
		else if(state==s_idle)
			tx_cnt <= 9'h000;
		else
			tx_cnt <= tx_cnt + 9'h01;
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			phy_txd <= 4'h0;
		else 
			case (state)
				s_idle: begin
					tx_data <= {7'h0,tx_data_buf[~toggle]};
					if(empty) pre <= {16'h0008,pre_buf};	//decide whether should ask PC for new packages
					else pre <= {16'h0000, pre_buf};
				end
				s_pre:
					{pre[171:0], phy_txd} <= pre;
				s_add:
					{pre[171:0], phy_txd} <= pre;
				s_data:
					{tx_data[`tx_data_len-5:0],phy_txd} <= tx_data;
				s_crc: begin
					phy_txd[3] <= ~Crc[28];	//Special, the usage of the CRC_Module
					phy_txd[2] <= ~Crc[29];
					phy_txd[1] <= ~Crc[30];
					phy_txd[0] <= ~Crc[31];
				end
				default:
					phy_txd <= 4'h0;
			endcase
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			phy_txen <= 1'b0;
		else if((state==s_pre)||(state==s_add)||(state==s_data)||(state==s_crc))
			phy_txen <= 1'b1;
		else
			phy_txen <= 1'b0;
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			Initialize_Crc <= 1'b0;
		else if(state==s_pre)
			Initialize_Crc <= 1'b1;		//prepare the CRC_Module for the following addresses
		else
			Initialize_Crc <= 1'b0;
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			Enable_Crc <= 1'b0;
		else if((state==s_add)||(state==s_data))
			Enable_Crc <= 1'b1;		//enable the CRC_Module
		else
			Enable_Crc <= 1'b0;
	end

	assign Data_Crc[0] = phy_txd[3];	//input prepare for CRC_Module
	assign Data_Crc[1] = phy_txd[2];
	assign Data_Crc[2] = phy_txd[1];
	assign Data_Crc[3] = phy_txd[0];
	
	// Connecting module Crc
	CRC_Module txcrc (.Clk(phy_txclk), .Reset(reset), .Data(Data_Crc), .Enable(Enable_Crc), .Initialize(Initialize_Crc), 
               .Crc(Crc), .CrcError(CrcError));
              
endmodule
