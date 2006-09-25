`timescale 1ns/10ps

module icarus_toplevel();
   reg         clk25MHz = 1;

   wire [22:0] fse_a;        // Mainboard common bus address
   wire [31:0] fse_d;        // Mainboard common bus data
   wire        flash_cs_n;   // Flash ROM CS#
   wire        enet_aen;     // Ethernet Access Enable
   wire        sram_cs_n;    // SRAM CS#
   wire [3:0]  sram_be_n;    // SRAM byte enables
   wire        sram_oe_n;    // SRAM OE#
   wire        sram_we_n;    // SRAM WE#

   always #5 clk25MHz <= ~clk25MHz;

   idt71v416s10 u35(fse_d[15: 0], fse_a[19:2], sram_we_n, sram_oe_n, sram_cs_n,
                    sram_be_n[0], sram_be_n[1]); // Yep, strange order...
   idt71v416s10 u36(fse_d[31:16], fse_a[19:2], sram_we_n, sram_oe_n, sram_cs_n,
                    sram_be_n[2], sram_be_n[3]);

   system tommix_system_inst
                ( .clk25MHz(clk25MHz)
          ,.reset(0)
          ,.fse_a(fse_a)            // Mainboard common bus address
          ,.fse_d(fse_d)            // Mainboard common bus data
          ,.flash_cs_n(flash_cs_n)  // Flash ROM CS#
          ,.enet_aen(enet_aen)      // Ethernet Access Enable
          ,.sram_cs_n(sram_cs_n)    // SRAM CS#
          ,.sram_be_n(sram_be_n)    // SRAM byte enables
          ,.sram_oe_n(sram_oe_n)    // SRAM OE#
          ,.sram_we_n(sram_we_n)    // SRAM WE#
          );



   reg [31:0]  i, v;
   reg [31:0]  preload[0:262143];
   initial begin
      $readmemh("initialsram.data", preload);
      for (i = 0; i <= 262143; i = i + 1) begin
         v = preload[i];
         u36.mem2[i] = v[31:24];
         u36.mem1[i] = v[23:16];
         u35.mem2[i] = v[15: 8];
         u35.mem1[i] = v[ 7: 0];
      end
   end
endmodule // main
