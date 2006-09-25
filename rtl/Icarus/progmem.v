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

module progmem(input  wire        clock,
	       input  wire        rden,
	       input  wire [6:0]  rdaddress,
	       input  wire [6:0]  wraddress,
	       input  wire        wren,
	       input  wire [31:0] data,
	       output wire [31:0] q);

   reg [ 6:0] addr_delayed;
   reg [31:0] ram[(1<<7) - 1:0];

   assign q = ram[addr_delayed];

   always @(posedge clock)
     if (rden)
       addr_delayed <= rdaddress;


   initial
     $readmemh("initmem.data", ram);
endmodule
