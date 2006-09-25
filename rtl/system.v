// Warn about undefined nets
// `default_nettype none
// but Icarus does that with -Wimplicit also
module system
           (// Clock and reset
            input  wire        clk25MHz
           ,input  wire        reset

           // Push buttons LEDs 7-segments
           ,input  wire  [3:0] sw           // Pushbutton switches
           ,output reg   [7:0] led          // Debugging LEDs
           ,output reg   [7:0] s7_0         // Debugging 7-segment LEDs
           ,output reg   [7:0] s7_1         // --

           // Debug serial connection
           ,output wire        ttyb_txd     // Debug TxD
           ,input              ttyb_rxd     // Debug RxD

           // Flash-SRAM-Ethernet bus
           ,output wire [22:0] fse_a        // Mainboard common bus address
           ,inout  wire [31:0] fse_d        // Mainboard common bus data
           ,output wire        flash_cs_n   // Flash ROM CS#
           ,output wire        enet_aen     // Ethernet Access Enable
           ,output wire        sram_cs_n    // SRAM CS#
           ,output wire  [3:0] sram_be_n    // SRAM byte enables
           ,output wire        sram_oe_n    // SRAM OE#
           ,output wire        sram_we_n    // SRAM WE#

           // CompactFlash slot
           ,output wire [10:0] cf_a         // CompactFlash address bus
           ,inout  wire [15:0] cf_d         // CompactFlash data bus
           ,input              cf_rdy       // CompactFlash RDY
           ,input              cf_wait_n    // CompactFlash WAIT#
           ,output             cf_ce1_n     // CompactFlash CE1#
           ,output             cf_ce2_n     // CompactFlash CE2#
           ,output             cf_oe_n      // CompactFlash OE#
           ,output             cf_we_n      // CompactFlash WE#
           ,output             cf_reg_n     // CompactFlash REG#
           ,input              cf_cd1_n     // CompactFlash card detect

           // Lancelot VGA interface
           ,output wire  [7:0] vga_r        // VGA red
           ,output wire  [7:0] vga_g        // VGA green
           ,output wire  [7:0] vga_b        // VGA blue
           ,output wire        vga_hs       // VGA horz sync
           ,output wire        vga_vs       // VGA vert sync
           ,output wire        vga_blank_n  // VGA DAC force blank
           ,output wire        vga_sync_n   // VGA sync enable
           ,output wire        vga_sync_t   // VGA sync on R/G/B
           ,output wire        vga_m1       // VGA color space config
           ,output wire        vga_m2       // VGA color space config

           // Lancelot PS/2 keyboard/mouse
           ,output             ps2_sel      // PS/2 port enable
           ,inout              ps2_kclk     // PS/2 keyboard clock
           ,inout              ps2_kdata    // PS/2 keyboard data
           ,inout              ps2_mclk     // PS/2 mouse clock
           ,inout              ps2_mdata    // PS/2 mouse data

           // Lancelot Audio
           ,output wire        audio_l      // 1-bit Sigma-delta converter
           ,output wire        audio_r      // 1-bit Sigma-delta converter
           );


`ifdef __ICARUS__
   parameter inputtext  = "input.txt";
   integer   file, ch;
`endif

   parameter       V = 0; // V - verbose, debugging

   wire        rs232in_attention;
   wire [ 7:0] rs232in_data;

   /* Switches */

   wire [ 3:0] sw_filtered, sw_stb;
   filter filter_0(clk25MHz, ~sw[0], sw_filtered[0], sw_stb[0]);
   filter filter_1(clk25MHz, ~sw[1], sw_filtered[1], sw_stb[1]);
   filter filter_2(clk25MHz, ~sw[2], sw_filtered[2], sw_stb[2]);
   filter filter_3(clk25MHz, ~sw[3], sw_filtered[3], sw_stb[3]);

   /* Keyboard */
   /*
    * ps2_Xdata is shifted into ps2_Xshift (under the control of
    * ps2_Xclk). When a full sample is seen it's verified and latched
    * into ps2_Xsample (with minimal overrun control).
    *
    *     (data:1,clk:1) -> shift:11 -> sample:16
    */
   reg  [ 4:0] ps2_control;
   assign      ps2_sel   = ps2_control[4];
   assign      ps2_mclk  = ps2_control[3] ? 1'bz : 1'b0;
   assign      ps2_mdata = ps2_control[2] ? 1'bz : 1'b0;
   assign      ps2_kclk  = ps2_control[1] ? 1'bz : 1'b0;
   assign      ps2_kdata = ps2_control[0] ? 1'bz : 1'b0;

   wire        ps2_kclk_filtered, ps2_kdata_filtered;
   wire        ps2_kclk_stb, ps2_kdata_stb;
   wire        ps2_mclk_filtered, ps2_mdata_filtered;
   wire        ps2_mclk_stb, ps2_mdata_stb;

   reg         ps2_kintr,
               ps2_mintr; // Active for one cycle
   reg  [10:0] ps2_kshift = ~0,
               ps2_mshift = ~0;
   reg  [15:0] ps2_ksample = 0,
               ps2_msample = 0; // Latched data.  Anything in top byte is error

   // XXX Is this overkill for the data?
   filter filter_kc(clk25MHz, ps2_kclk,  ps2_kclk_filtered,  ps2_kclk_stb);
   filter filter_kd(clk25MHz, ps2_kdata, ps2_kdata_filtered, ps2_kdata_stb);
   filter filter_mc(clk25MHz, ps2_mclk,  ps2_mclk_filtered,  ps2_mclk_stb);
   filter filter_md(clk25MHz, ps2_mdata, ps2_mdata_filtered, ps2_mdata_stb);

   /* Audio */
   reg  [15:0] audio_l_pdm = 0, audio_r_pdm = 0;
   pdm #(16) pdm_l(clk25MHz, audio_l_pdm, audio_l);
   pdm #(16) pdm_r(clk25MHz, audio_r_pdm, audio_r);

   /* Framebuffer memory port */
   wire        fb_transfer_request, fb_wait_request;
   wire [31:0] fb_address;
   wire [31:0] fb_read_data;
   wire        fb_read_data_valid;
   wire        fb_wren;
   wire [31:0] fb_wrdata;
   wire [ 3:0] fb_wrmask;

   /* Core memory port & interrupts */
   wire        core_io_access;
   wire        core_transfer_request;
   wire [31:0] core_address;
   wire        core_wren;
   wire [31:0] core_wrdata;
   wire [ 3:0] core_wrmask;
   wire        core_wait_request;
   wire        core_read_data_valid;
   wire [31:0] core_read_data;

   wire        core_ifetch; // Diag only

   /*
    * Interrupts are triggered and latched in rQ whenever one of
    * core_interrupt goes high.  For PS/2 mouse & kbd we trigger when
    * then low start bit has made it to from pos 10 to pos 0.
    * XXX Consider extra buffering of keyboard / mouse to allow for
    * high interrupt latency
    * XXX Add rs232 input data available, rs232 output ready, and VSync
    */
   wire [23:0] core_interrupt = {ps2_mintr,ps2_kintr};

   wire        core_sram_transfer_request;
   wire [31:0] core_sram_address;
   wire        core_sram_wren;
   wire [31:0] core_sram_wrdata;
   wire [ 3:0] core_sram_wrmask;
   wire        core_sram_wait_request;
   wire        core_sram_read_data_valid;
   wire [31:0] core_sram_read_data;

   /* Memory interface */
   wire        mi_transfer_request;
   wire [31:0] mi_address;
   wire        mi_wren;
   wire [31:0] mi_wrdata;
   wire [ 3:0] mi_wrmask;
   wire        mi_wait_request;
   wire        mi_read_data_valid;
   wire [31:0] mi_read_data;

   /*
    * Memory space routing
    * Any address over 2^48 is for memory mapped I/O
    *
    * XXX This multiplexer is completely broken for multiple
    * outstanding requests simultaneously to both sram and IO.
    * (Multiple outstanding requests for either at a time are fine).
    * We depend on the core not issuing such (for now).
    */

   reg         io_read_data_valid = 0;
   reg [31:0]  io_read_data;

   wire        core_firmware_access       = core_address[31];
   wire        core_hit_sram              = ~core_io_access & ~core_firmware_access;
   assign      core_sram_transfer_request = core_transfer_request & core_hit_sram;
   assign      core_sram_address          = core_address;
   assign      core_sram_wren             = core_wren;
   assign      core_sram_wrdata           = core_wrdata;
   assign      core_sram_wrmask           = core_wrmask;

   assign      core_wait_request  /* IO never waits */
                              = core_sram_wait_request & core_sram_transfer_request;
   assign      core_read_data_valid
                              = core_sram_read_data_valid | io_read_data_valid;
   assign      core_read_data = core_sram_read_data_valid
                                ? core_sram_read_data
                                : io_read_data;

   wire [ 7:0] rs232out_data = core_wrdata[7:0];
   wire        rs232out_we   = core_transfer_request &
                               core_io_access &
                               core_wren &
                               core_address[6:3] == 0;
   wire        rs232out_busy;
   reg         rs232in_newdata = 0;

   reg [31:0]  fb_addr0 = 0;

   /* XXX This is Quartus specific.  Must find a way to make this more
      portable to also Xilinx ISE. */
   (* ram_init_file = "../initmem.mif" *)
   reg [31:0]  firmware [255 : 0];

   reg [ 7:0]  tmp;

   // XXX This is not scalable.  Figure out a better way that isn't
   // too expensive.
   always @(posedge clk25MHz) if (reset) begin
      ps2_kshift <= ~0;
      ps2_mshift <= ~0;
      ps2_kintr <= 0;
      ps2_mintr <= 0;
      ps2_ksample <= 0;
      ps2_msample <= 0;
   end else begin
      ps2_kintr <= 0;
      ps2_mintr <= 0;

      /* <start: 0> <b0> <b1> ... <b7> <parity> <stop: 1> */
      if (ps2_kclk_stb & ~ps2_kclk_filtered) // Negedge
        ps2_kshift <= {ps2_kdata_filtered, ps2_kshift[10:1]};
      if (ps2_mclk_stb & ~ps2_mclk_filtered) // Negedge
        ps2_mshift <= {ps2_mdata_filtered, ps2_mshift[10:1]};

      if (~ps2_kshift[0])
         if (^ps2_kshift[9:1] & ps2_kshift[10]) begin
            // Good sample
            ps2_ksample[15:8] <= ps2_ksample[15:8] | ps2_ksample[7:0];
            ps2_ksample[ 7:0] <= ps2_kshift[8:1];
            ps2_kshift  <= ~0;
            ps2_kintr <= 1;
         end else begin
            // Bad sample
            ps2_ksample[15:0] <= ~0;
            ps2_kshift  <= ~0;
         end

      if (~ps2_mshift[0])
         if (^ps2_mshift[9:1] & ps2_mshift[10]) begin
            // Good sample
            ps2_msample[15:8] <= ps2_msample[15:8] | ps2_msample[7:0];
            ps2_msample[ 7:0] <= ps2_mshift[8:1];
            ps2_mshift  <= ~0;
            ps2_mintr <= 1;
         end else begin
            // Bad sample
            ps2_msample[15:0] <= ~0;
            ps2_mshift  <= ~0;
         end

      if (core_ifetch)
         led <= core_address[9:2];

      io_read_data_valid <= 0;
      io_read_data       <= 32'd0;
      if (core_transfer_request) begin
         if (core_io_access) begin
            if (core_wren) begin
               if (core_address[2]) // Only the lower-order tetra
                 case (core_address[6:3])
                   // #00
                   0: /* 0: #1_0000_0000_0000 rs232 output*/
                      if (8'd20 <= core_wrdata[7:0] && core_wrdata[7:0] < 128)
                        $display("%06d *** RS232 out '%c' (#%x)", $time,
                                 core_wrdata[7:0], core_wrdata[7:0]);
                      else
                        $display("%06d *** RS232 out #%x", $time,
                                 core_wrdata[7:0]);
                   // 2 << 3 + 1 << 2 = #1..014
                   2: begin
                      // Leds hijacked to show the 8 least significant IF bits
                      //led <= core_wrdata[7:0]; /* #1_0000_0000_0010 leds */
                      $display("%06d *** LEDs now #%x", $time,
                               core_wrdata[7:0]);
                   end
                   4: begin
                       /* #1_0000_0000_0024 s7_0 (right) */
                      s7_0 <= core_wrdata[7:0];
                      $display("%06d *** s7_0 now #%x", $time,
                               core_wrdata[7:0]);
                   end
                   5: begin
                      /* #1_0000_0000_002C s7_1 (left) */
                      s7_1 <= core_wrdata[7:0];
                      $display("%06d *** s7_1 now #%x", $time,
                               core_wrdata[7:0]);
                   end
                   6: begin
                      /* #1_0000_0000_0030 audio (left) */
                      audio_l_pdm <= core_wrdata[15:0];
                      $display("%06d *** audio left now %d", $time,
                               core_wrdata[15:0]);
                   end
                   7: begin
                      /* #1_0000_0000_0038 audio (right) */
                      audio_r_pdm <= core_wrdata[15:0];
                      $display("%06d *** audio right now %d", $time,
                               core_wrdata[15:0]);
                   end
                   8: begin
                      /* #1_0000_0000_0040 audio (both)  */
                      audio_l_pdm <= core_wrdata[15:0];
                      audio_r_pdm <= core_wrdata[15:0];
                      $display("%06d *** audio now %d", $time,
                               core_wrdata[15:0]);
                   end
                   10: begin
                      fb_addr0 <= core_wrdata;
                      $display("%06d *** frame buffer start address is now #%x",
                               $time, core_wrdata);
                   end
                   11:begin
                      ps2_control <= core_wrdata;
                      ps2_kshift <= ~0;
                      ps2_mshift <= ~0;
                      $display("%06d *** ps2_control is now #%x",
                               $time, core_wrdata);
                   end
                   12:begin
                      ps2_ksample <= core_wrdata;
                      $display("%06d *** keyboard data is now #%x",
                               $time, core_wrdata);
                   end
                   13:begin
                      ps2_msample <= core_wrdata;
                      $display("%06d *** mouse data is now #%x",
                               $time, core_wrdata);
                   end
                 endcase
            end else begin // !core_wren

               /**** Reading ****/

               io_read_data_valid <= 1;
               $display("%06d    read from #%x", $time, core_address);
               if (core_address[2])
                 case (core_address[6:3])
                   0: begin
                      /* 0: #1_0000_0000_0000 rs232out busy */
                     io_read_data[0] <= rs232out_busy;
                     $display("%06d *** Read the busy signal (%d)", $time,
                              rs232out_busy);
                  end
                  1:
                    /* 1: #1_0000_0000_0008 rs232 input
                       (negative tetra if already read) */
                    begin
`ifndef __ICARUS__
                       io_read_data[31] <= ~rs232in_newdata;
                       io_read_data[7:0] <= rs232in_data;
                       $display("%06d *** Read RS232 input (#%x)", $time,
                                {~rs232in_newdata,23'd0,rs232in_data});
`else
                       io_read_data[31] <= 0;
                       tmp = $fgetc(file);
                       io_read_data[7:0] <= tmp;
                       $display("%06d *** Simulated Read RS232 input (#%x / '%c')", $time,
                                {1'd1,23'd0,tmp}, tmp);
`endif
                       rs232in_newdata <= 0;
                    end
                  2: /* #1_0000_0000_0010 sw */
                    io_read_data[3:0] <= sw_filtered;
                 11:begin
                    io_read_data[3:0] <= {ps2_mclk,ps2_mdata,ps2_kclk,ps2_kdata};
                    $display("%06d *** read ps/2 keyboard/mouse raw #%x",
                             $time, {ps2_mclk,ps2_mdata,ps2_kclk,ps2_kdata});
                    end
                 12:begin
                    io_read_data <= ps2_ksample;
                    $display("%06d *** read ps/2 keyboard data #%x",
                             $time, ps2_ksample);
                    end
                 13:begin
                    io_read_data <= ps2_msample;
                    $display("%06d *** read ps/2 mouse data #%x",
                             $time, ps2_mdata);
                    end
                 endcase
            end // !core_wren
         end else if (core_firmware_access) begin // XXX CHANGE THIS!
            if(V)$display("%06d *** Memory access hit firmware at #%x",
                          $time, core_address);
            if (core_wren) begin
               $display("\n**** write to @#%x in firmware dropped ****\n",
                        core_address);
            end else begin
               // XXX Rename these variables now that they don't just cover IO
               io_read_data <= firmware[core_address[9:2]];
               io_read_data_valid <= 1;
               if(V)$display("          returning #%x",
                             firmware[core_address[9:2]]);
            end
         end /* XXX Should catch accesses outside the mapped memory
              (SRAM, IO, firmware) */
      end

      /* This edge catches needs to come last to avoid a race with the
         read above */
      if (rs232in_attention)
        rs232in_newdata <= 1;
   end // always @ (posedge clk25MHz)

   rs232out rs232out_debug
     (.clk25MHz(clk25MHz)
      ,.serial_txd(ttyb_txd)
      ,.data(rs232out_data)
      ,.we(rs232out_we)
      ,.busy(rs232out_busy)
      );

   rs232in rs232in
      (.clk25MHz(clk25MHz)
      ,.reset(reset)
      ,.serial_rxd(ttyb_rxd)
      ,.attention(rs232in_attention)
      ,.data(rs232in_data)
      );

   arbitration arbitration_inst
      (.clock(clk25MHz)

      ,.transfer_request1(fb_transfer_request)
      ,.address1(fb_address)
      ,.wren1(fb_wren)
      ,.wrdata1(fb_wrdata)
      ,.wrmask1(fb_wrmask)
      ,.wait_request1(fb_wait_request)
      ,.read_data_valid1(fb_read_data_valid)
      ,.read_data1(fb_read_data)

      ,.transfer_request2(core_sram_transfer_request)
      ,.address2(core_sram_address)
      ,.wren2(core_sram_wren)
      ,.wrdata2(core_sram_wrdata)
      ,.wrmask2(core_sram_wrmask)
      ,.wait_request2(core_sram_wait_request)
      ,.read_data_valid2(core_sram_read_data_valid)
      ,.read_data2(core_sram_read_data)

      ,.transfer_request(mi_transfer_request)
      ,.address(mi_address)
      ,.wren(mi_wren)
      ,.wrdata(mi_wrdata)
      ,.wrmask(mi_wrmask)
      ,.wait_request(mi_wait_request)
      ,.read_data_valid(mi_read_data_valid)
      ,.read_data(mi_read_data)
      );

   memory_interface mi /* The ID is 1-bit wide so it's readable in the traces! */
      (.clkin(clk25MHz)

      ,.fse_a(fse_a)
      ,.fse_d(fse_d)
      ,.flash_cs_n(flash_cs_n)
      ,.enet_aen(enet_aen)
      ,.sram_cs_n(sram_cs_n)
      ,.sram_be_n(sram_be_n)
      ,.sram_oe_n(sram_oe_n)
      ,.sram_we_n(sram_we_n)

      ,.transfer_request(mi_transfer_request)
      ,.address(mi_address)
      ,.wren(mi_wren)
      ,.wrdata(mi_wrdata)
      ,.wrmask(mi_wrmask)
      ,.wait_request(mi_wait_request)
      ,.read_data_valid(mi_read_data_valid)
      ,.read_data(mi_read_data)
      );

   vga vga(clk25MHz, reset,
           // Lancelot VGA interface
           vga_r, vga_g, vga_b, vga_m1, vga_m2,
           vga_sync_n, vga_sync_t,
           vga_blank_n, vga_hs, vga_vs,

           //'h000F6A00,  // FB at the end of 1 MiB
           fb_addr0,

           // Video memory port
           fb_transfer_request,
           fb_address,
           fb_wren,
           fb_wrdata,
           fb_wrmask,
           fb_wait_request,
           fb_read_data_valid,
           fb_read_data);

   core core_inst
     (.clock(clk25MHz)
     ,.reset(reset)
     ,.start(64'h8000000080000000) // The top bit is for supervisor mode

     ,.core_interrupt(core_interrupt)
     ,.core_io_access(core_io_access)
     ,.core_transfer_request(core_transfer_request)
     ,.core_address(core_address)
     ,.core_wren(core_wren)
     ,.core_wrdata(core_wrdata)
     ,.core_wrmask(core_wrmask)

     ,.core_wait_request(core_wait_request)
     ,.core_read_data_valid(core_read_data_valid)
     ,.core_read_data(core_read_data)

     ,.core_ifetch(core_ifetch)
     );

`ifdef __ICARUS__
   initial begin
      file = $fopen(inputtext, "r");
      $display("Opening of %s resulted in %d", inputtext, file);
      $readmemh("initmem.data", firmware);
   end
`endif

endmodule
