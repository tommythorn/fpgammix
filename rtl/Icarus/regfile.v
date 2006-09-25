// -----------------------------------------------------------------------
//
//   Copyright 2004 Tommy Thorn - All Rights Reserved
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, Inc., 53 Temple Place Ste 330,
//   Bostom MA 02111-1307, USA; either version 2 of the License, or
//   (at your option) any later version; incorporated herein by reference.
//
// -----------------------------------------------------------------------

`timescale 1ns/10ps

`define D 8 /* A parameter would be more useful */

module regfile(input  wire        clock,

	       input  wire        rden,
	       input  wire [`D:0] rdaddress,
	       output wire [63:0] q /* rddata would have been better */,

	       input  wire        wren,
	       input  wire [`D:0] wraddress,
               input  wire [63:0] data /* wrdata would have been better */);

   parameter          ID = 0;
   parameter          V = 0;

   reg [`D:0] addr_delayed = 0;
   reg [63:0] ram[(2 << `D) - 1: 0];

   /* XXX Accidentally found a bug in Icarus as I had accidentally written
        reg [63:0] ram[(2 << `D) - 1: 0];
      turning
       assign q = ram[addr_delayed];
      into a bit extract rather than a memory lookup.

      turned out that for addr_delayed == ??? it would crash with a
      segmentation error.
    */

   assign q = ram[addr_delayed];

   always @(posedge clock) if (1) begin
      if(V)$display("%05d REGFILE addr_delayed=#%x q=#%x rdaddress=%x rden%x",
                    $time,
                    addr_delayed, q, rdaddress, rden);

     if (rden) begin
        if(V)$display("%05d REGFILE %c read from XXXXX", $time, ID);
       addr_delayed <= rdaddress;
       // $display("regfile %2x -> %x", rdaddress, ram0[rdaddress]);
       // for (i = 0; i < 256; i = i + 1) $display("regfile %2x -> %2x", i, ram0[i]);
     end
     if (wren) begin
       if(V)$display("%05d RF Writing %x -> [%x]", $time, data, wraddress);
       ram[wraddress] <= data;
     end
   end

   reg [`D+1:0] i;
   initial for (i = 0; i < 1 << (`D+1); i = i + 1) ram[i] = 0;
endmodule
