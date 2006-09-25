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

module datamem(input  wire        clock,
	       input  wire [ 7:0] rdaddress,
	       output wire [63:0] q,
	       input  wire [ 7:0] wraddress,
	       input  wire [ 7:0] byteena_a,
	       input  wire        wren,
               input  wire [63:0] data);

   reg [ 7:0] addr_delayed;
   reg [ 7:0] ram0[(1<<8) - 1:0],
              ram1[(1<<8) - 1:0],
              ram2[(1<<8) - 1:0],
              ram3[(1<<8) - 1:0],
              ram4[(1<<8) - 1:0],
              ram5[(1<<8) - 1:0],
              ram6[(1<<8) - 1:0],
              ram7[(1<<8) - 1:0];

   assign q =
   {ram7[addr_delayed],ram6[addr_delayed],ram5[addr_delayed],ram4[addr_delayed],
    ram3[addr_delayed],ram2[addr_delayed],ram1[addr_delayed],ram0[addr_delayed]};


   always @(posedge clock) begin
     addr_delayed <= rdaddress;
     if (wren) begin
       if (byteena_a[7]) ram7[wraddress] <= data[63:56];
       if (byteena_a[6]) ram6[wraddress] <= data[55:48];
       if (byteena_a[5]) ram5[wraddress] <= data[47:40];
       if (byteena_a[4]) ram4[wraddress] <= data[39:32];
       if (byteena_a[3]) ram3[wraddress] <= data[31:24];
       if (byteena_a[2]) ram2[wraddress] <= data[23:16];
       if (byteena_a[1]) ram1[wraddress] <= data[15: 8];
       if (byteena_a[0]) ram0[wraddress] <= data[ 7: 0];
     end
   end       

   reg [8:0] i;
   initial
     for (i = 0; i < 256; i = i + 1) begin
        ram0[i] <= 0;
        ram1[i] <= 0;
        ram2[i] <= 0;
        ram3[i] <= 0;
        ram4[i] <= 0;
        ram5[i] <= 0;
        ram6[i] <= 0;
        ram7[i] <= 0;
     end
endmodule
