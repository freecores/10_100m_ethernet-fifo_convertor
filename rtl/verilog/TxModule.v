//author :gurenliang
//Email: gurenliang@gmail.com
//note: if there are some errors, you are welcome to contact me. It would be the best appreciation to me.



//Next step, add ff_data control to show the IP is busy

//version 0.3, declared a new variable data_av, and use it to start sending frame.
//version 0.3, delete the usage of pre_buf, and rename the pre to preaddlt
//version 0.3, add the option of frameID mode, by include common.v and judge the macro-varible frameIDfromRx
//This module is used to receive data from the demodulate module and send the data to the Ethernet PHY chip
`include "common.v"

`define tx_data_buf_len	(`frameidlen+`uframelen*`num_uframe+66)	
											//132=8.25*`num_uframe is the space between the uframes
											//66=8.25*`num_uframe is the space between the uframes
`define tx_data_madeup	6					//add to tx_data_buf_len to make 132 is dividible by 8
											//add to tx_data_buf_len to make  66 is dividible by 8

`define tx_data_len		(`tx_data_buf_len+`tx_data_madeup)	
											//make the length of tx_data_buf be conformed to IEEE802.3
`define ff_cnt_init 	(1+`frameidlen)

module TxModule(reset, phy_txd, phy_txen, phy_txclk, phy_txer,
				ff_clk, ff_en, ff_data,

				`ifdef frameIDfromRx
					frameid, 
				`endif
				
				start,
				test1, test2, test3, test4);
	//make sure 2^ff_sink_cnt_len is larger than or equal to tx_data_buf_len
	parameter ff_sink_cnt_len =	(`tx_data_buf_len <=    2) ? 1 :
								(`tx_data_buf_len <=    4) ? 2 :
								(`tx_data_buf_len <=    8) ? 3 :
								(`tx_data_buf_len <=   16) ? 4 :
								(`tx_data_buf_len <=   32) ? 5 :
								(`tx_data_buf_len <=   64) ? 6 :
								(`tx_data_buf_len <=  128) ? 7 :
								(`tx_data_buf_len <=  256) ? 8 :
								(`tx_data_buf_len <=  512) ? 9 :
								(`tx_data_buf_len <= 1024) ? 10:
								(`tx_data_buf_len <= 2048) ? 11:
								(`tx_data_buf_len <= 4096) ? 12:
								(`tx_data_buf_len <= 8192) ? 13: 14;
	//make sure 2^tx_cnt_len is larger than [(`tx_data_len >> 2) + 51]
	parameter tx_cnt_len =	(((`tx_data_len >> 2) + 51) <=    2) ? 1 :
							(((`tx_data_len >> 2) + 51) <=    4) ? 2 :
							(((`tx_data_len >> 2) + 51) <=    8) ? 3 :
							(((`tx_data_len >> 2) + 51) <=   16) ? 4 :
							(((`tx_data_len >> 2) + 51) <=   32) ? 5 :
							(((`tx_data_len >> 2) + 51) <=   64) ? 6 :
							(((`tx_data_len >> 2) + 51) <=  128) ? 7 :
							(((`tx_data_len >> 2) + 51) <=  256) ? 8 :
							(((`tx_data_len >> 2) + 51) <=  512) ? 9 :
							(((`tx_data_len >> 2) + 51) <= 1024) ? 10:
							(((`tx_data_len >> 2) + 51) <= 2048) ? 11:
							(((`tx_data_len >> 2) + 51) <= 4096) ? 12:
							(((`tx_data_len >> 2) + 51) <= 8192) ? 13: 14;		
				
				
	input phy_txclk, reset;
	input ff_clk, ff_en, ff_data;	//ff_clk should be 207.83333KHz
	
	`ifdef frameIDfromRx
		input[`frameidlen-1:0] frameid;			//get the frameid information from RxModule
	`endif
	
	input  start;					//decide whether should give out the "need-data" ethernet package
	output [3:0] phy_txd;			//MII
	output phy_txen, phy_txer;
	
	output test1, test2, test3, test4;
	reg test1;//, test2, test3, test4;
	
	`ifdef frameIDcount
		reg[`frameidlen-1:0] frameid=0;
	`endif
	
	reg[3:0] phy_txd;
	reg phy_txen;
	
	reg[175:0] preaddlt;
	//reg[175:0] pre_buf=176'h0008_5952_264C_5247_FFFF_FFFF_FFFF_D555_5555_5555_5555;
	
	reg[`tx_data_buf_len-1:0] tx_data_buf[0:1];	//two buffer helps to step over different frame seamlessly
	reg pre_toggle1,pre_toggle2, toggle=1'b0;		//helps to decide when to give PC a MAC frame
	reg[`tx_data_len-1:0] tx_data;		//used as FIFO
		
	reg[ff_sink_cnt_len-1:0] ff_cnt=0;		
		
	reg[tx_cnt_len-1:0] tx_cnt;
	wire data_av;
	
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
				tx_data_buf[toggle][`tx_data_buf_len-1:`tx_data_buf_len-`frameidlen-1] <= {ff_data, frameid};
				ff_cnt <= `ff_cnt_init;	//`frameidlen+1
				//tosend <= 1'b0;
			end
			else if (ff_cnt == `tx_data_buf_len-1) begin
				tx_data_buf[toggle] <= {ff_data, tx_data_buf[toggle][`tx_data_buf_len-1:1]};
				//tx_data_buf[toggle] <= {144'h0,temp_buf};
				ff_cnt <= 0;
				toggle <= ~toggle;
				//every time a frame being sent, frameID increases one
				`ifdef frameIDcount
					frameid <= frameid + 1;
				`endif
			end
			else begin
				tx_data_buf[toggle] <= {ff_data, tx_data_buf[toggle][`tx_data_buf_len-1:1]};
				ff_cnt <= ff_cnt + 1;
			end
		end
	end
	
	assign phy_txer = 1'b0;
	assign data_av = pre_toggle1^pre_toggle2;
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		pre_toggle1 <= toggle;
		pre_toggle2 <= pre_toggle1;
	end

	// Determine the next state
	always @ (negedge phy_txclk) begin	//state machine run to send out the MAC frame
		if (reset)
			state <= s_idle;
		else begin
			case (state)
				s_idle: begin		//wait to be trigged
					test1 <= ~test1;
					if(data_av) begin	//once be trigged, prepare the data to send
						state <= s_pre;
					end
					else state <= s_idle;
				end
				
				s_pre:			//send the preambles
					if(tx_cnt == 15)
						state <= s_add;
					else
						state <= s_pre;
						
				s_add: begin		//send the destination address, source address and type
					if(tx_cnt== 43)
						state <= s_data;
					else
						state <= s_add;
				end
				s_data:					//send data to PHY, every time four bits, lower bits go first
					//test2 <= ~test2;
					if (tx_cnt == (`tx_data_len >> 2) + 43)
						state <= s_crc;
					else state <= s_data;
				
				s_crc:
					if (tx_cnt == (`tx_data_len >> 2) + 51)
						state <= s_idle;
					else state <= s_crc;
				
				default: 
					state <= s_idle;
			endcase
		end
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			tx_cnt <= 0;
		else if(state==s_idle)
			tx_cnt <= 0;
		else
			tx_cnt <= tx_cnt + 1;
	end
	
	always @ (negedge phy_txclk) begin 	//state machine run to send out the MAC frame
		if (reset)
			phy_txd <= 4'h0;
		else 
			case (state)
				s_idle: begin
					tx_data <= {{`tx_data_madeup{1'b0}}, tx_data_buf[~toggle]};
					//already stored MAC preamble, dest address and source address from right to left. 
					//decide whether should ask PC for new frame
					/*if(empty) preaddlt <= {16'h0008, `MAC_ADD, `PC_MAC_ADD, `Preamble};	
					else*/
					preaddlt <= {16'h0000, `MAC_ADD, `PC_MAC_ADD, `Preamble};
				end
				s_pre:
					{preaddlt[171:0], phy_txd} <= preaddlt;
				s_add:
					{preaddlt[171:0], phy_txd} <= preaddlt;
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
