module tri_state(d_in, d_out, out_en, ioport);
	input d_out, out_en;			//init_clk should be 10KHz
	output d_in;
	inout ioport;
	
	assign ioport = (out_en) ?  d_out:1'bz;
	assign d_in = ioport;
endmodule
