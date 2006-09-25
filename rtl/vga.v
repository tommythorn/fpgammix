/*
 * TODO: for starters, this could be done in much much less logic with
 * judicious use of the counter underflow trick, eg. instead of
 *
 *  c <= (c == K-1) ? 0 : c + 1;
 *
 * allocate one more bit to c and use
 *
 *  c <= (c[MSB] ? K - 2 : c - 1);
 *
 * TODO: simplify, notably the whole FIFO mess!
 *
 * TODO: support 800x600.  In fact, make all important parameters
 * (except frequency?) settable at run-time.  Adjustable pixel width
 * may be too expensive though.
 *
 * TODO: use bursting (once supported)
 *
 */

/*
   VGA 640x480 core
   Tommy Thorn

   This module assumes a 25Mhz clock and implements VESA VGA output
   in the 640 x 480 resolution, based on the XFree86 modeline

       "640x480" 25.175  640 664 760 800  480 491 493 525

   640 x 480 = 307200 pixels
   At 1 bit pr pixel = 38400/0x9600 bytes, or 9600/0x2580 tetras

*/

`timescale 1ns/10ps

`define ONE_BPP 1

module vga(// Clock
           input  wire        clk25MHz        // PLL input clock
          ,input  wire        reset

           // Lancelot VGA interface
          ,output wire  [7:0] vga_r
          ,output wire  [7:0] vga_g
          ,output wire  [7:0] vga_b
          ,output wire        vga_m1
          ,output wire        vga_m2
          ,output wire        vga_sync_n
          ,output wire        vga_sync_t
          ,output wire        vga_blank_n
          ,output reg         vga_hs = 0
          ,output reg         vga_vs = 0

          ,input  wire [31:0] fb_address0   // Top of FB

          // Framebuffer master port
          ,output reg         fb_transfer_request = 0
          ,output reg  [31:0] fb_address
          ,output wire        fb_wren    // Don't laugh, it may happen in future
          ,output wire [31:0] fb_wrdata
          ,output wire [ 3:0] fb_wrmask
          ,input  wire        fb_wait_request
          ,input  wire        fb_read_data_valid
          ,input  wire [31:0] fb_read_data
          );

   parameter      debug = 0;

   parameter      M1 = 640;
   parameter      M2 = 664;
   parameter      M3 = 760;
   parameter      M4 = 800;

   parameter      M5 = 480;
   parameter      M6 = 491;
   parameter      M7 = 493;
   parameter      M8 = 525;

   parameter      BPP   = 24;
   parameter      FBWL2 = 5;
   parameter      FBW   = 1 << FBWL2;

   parameter      BUFL2 = 6; // must be at least 1

   // VGA interface
   assign         vga_sync_t  = 0;         // No sync-on-RGB
   assign         vga_sync_n  = 1;
   assign         vga_m1      = 0;         // Color space configuration: GBR
   assign         vga_m2      = 0;

   assign         fb_wren     = 0;
   assign         fb_wrdata   = 0;
   assign         fb_wrmask   = 0;

   /*
    * The blanking facility didn't work right for me and it seems I
    * don't really need it.
    */
   assign         vga_blank_n = 1;
   wire           hsync_neg   = 1;         // Negative hsync
   wire           vsync_neg   = 1;         // Positive vsync

   wire [9:0]     x_blank = M1;        // 640
   wire [9:0]     x_sync  = M2;        // 664
   wire [9:0]     x_back  = M3;        // 760
   wire [9:0]     x_max   = M4;        // 800

   wire [9:0]     y_blank = M5;        // 480
   wire [9:0]     y_sync  = M6;        // 491
   wire [9:0]     y_back  = M7;        // 493
`ifdef SIMULATE_MAIN
   wire [9:0]     y_max   = M8;        // 525
`else
   wire [9:0]     y_max   = M8;        // 525
`endif

   reg [9:0]      x = M4-5;  // Diverging from FPGA here to hit issues earlier.
   reg [9:0]      y = M8-4;  // Diverging from FPGA here to hit issues earlier.
   reg [9:0]      frame_ctr = 0;

   /* PIXEL */
   reg [31:0]     pixels32 = 0;

   reg [23:0]     vga_pixel = 0;
   assign         vga_r = vga_pixel[23:16];
   assign         vga_g = vga_pixel[15: 8];
   assign         vga_b = vga_pixel[ 7: 0];

   /* FIFO */
   reg  [     31:0] pixel_buffer[0:(1 << BUFL2) - 1]; // Initialised at the end.
   reg  [     31:0] pixel_buffer_addr = 0;
   reg  [BUFL2-1:0] pixel_buffer_rp = 0, pixel_buffer_wp = 0;
   wire [BUFL2-1:0] pixel_buffer_rp_plus1 = pixel_buffer_rp + 1;
   wire [BUFL2-1:0] pixel_buffer_wp_plus1 = pixel_buffer_wp + 1;
   wire [BUFL2-1:0] pixel_buffer_wp_plus2 = pixel_buffer_wp + 2;
   wire [BUFL2-1:0] pixel_buffer_wp_plus3 = pixel_buffer_wp + 3;
   reg  [BUFL2-1:0] free = (1 << BUFL2) - 1;

   parameter FRAMEBUFFER_WORDS = 640 * 480 / 32; // 9,600
   parameter LEFT_TO_REQUEST_MSB = 14; // 32,768 = 2 * 16,384 > 2 * 9,600
   reg [LEFT_TO_REQUEST_MSB:0] left_to_request = FRAMEBUFFER_WORDS - 2;

   /*
    FIFO workings.  Each clock cycle these events can occur (simultaneously):

    1. If the last pixel in a word was displayed, one datum was
       consumed, advancing the pixel_buffer_rp (no check for empty fifo).
    2. If a read is ready, one datum can be produced advancing the
       pixel_buffer_wp
    3. If the fifo isn't full, a read will be scheduled

    Because of the latencies involved, the controller will generally
    issue a burst of three reads before the first data tickles in,
    thus we keep a buffer of three free slots in the fifo.
    */

   always @(posedge clk25MHz) begin
      if (reset)
        fb_transfer_request <= 0;

      vga_hs     <= (x_sync <= x && x < x_back) ^ vsync_neg;
      vga_vs     <= (y_sync <= y && y < y_back) ^ hsync_neg;

      // $display("%05d VGA: rp %d wp %d free %d",
      //          $time, pixel_buffer_rp, pixel_buffer_wp, free);

      if (fb_read_data_valid) begin
         if (debug)$display("%05d VGA: FIFO got %x at pos %d", $time, fb_read_data, pixel_buffer_wp);
         pixel_buffer[pixel_buffer_wp] <= fb_read_data;
         pixel_buffer_wp               <= pixel_buffer_wp_plus1;
      end

      if (fb_transfer_request & fb_wait_request)
        if(debug)$display("%05d VGA: MEMORY BUSY", $time);

      if (~fb_transfer_request | ~fb_wait_request) begin
         /*
          * Only issue more requests if it won't overflow the FIFO.
          */

         if (free != 0 && ~left_to_request[LEFT_TO_REQUEST_MSB]) begin
            if (debug)
              $display("%05d VGA: SCHEDULE READ from %x (fifo %d free, %d left to fetch)",
                       $time, pixel_buffer_addr, free, left_to_request + 1);

            left_to_request     <= left_to_request - 1;
            fb_address          <= pixel_buffer_addr;
            fb_transfer_request <= 1;
            pixel_buffer_addr   <= pixel_buffer_addr + 4;
            free                <= free - 1;
         end else begin
            // $display("%5d VGA: Ok, FIFO FULL, stop reading", $time);
            fb_transfer_request <= 0;
         end
      end

      /* Get the pixel */
      if (x < x_blank && y < y_blank ||
          x == x_max-1 && y == y_max-1) // GROSS HACK
        begin
           /*
            * Grab one bit from the tiny pixel buffer and expand it to
            * 24 for black or white.
            */
/*           vga_pixel <= pixels32[31] ? 24'h008000 :
                        (x ==   0)   ? 24'h0000FF :
                        (y ==   0)   ? 24'h00FF00 :
                        (x == 639)   ? 24'hFF0000 :
                        (y == 479)   ? 24'h00FFFF :
                        24'h000000 ; // {24{pixels32[31]}};*/

           vga_pixel <= pixels32[31] ? 24'h008000 : 24'h000000;

           if (debug && x == 0 && y == 0)
              $display("%5d VGA: first word display: %x", $time, pixels32);

           if (x[4:0] == 31) begin
              /*
               * We just consumed the last pixel in the tiny pixel
               * buffer, so refill it from the pixel_buffer FIFO.
               *
               * Notice there's no underflow check as this can't
               * happen (underflow would be catastrophic and point to
               * either lack of memory bandwidth or too small a FIFO).
               */
              pixels32 <= pixel_buffer[pixel_buffer_rp];
              pixel_buffer_rp <= pixel_buffer_rp_plus1;
              if (debug)
                $display("%05d VGA: just read in %x", $time, pixel_buffer[pixel_buffer_rp]);

              if (fb_transfer_request & ~fb_wait_request & free != 0) begin
                 /* We issued another read, so free remains unchanged. */
                 if (debug)
                   $display("%05d VGA: Simultaneous consuming and requesting!", $time);
                 free <= free;
              end else begin
                 free <= free+1;
              end
           end else begin
              pixels32 <= {pixels32[30:0],1'h1};
           end
        end else begin
           vga_pixel <= 24'h0;

           if (y == y_max-2 && x == 0) begin
              if (debug) $display("%05d VGA: restart fetching", $time);

              /*
               * We just displayed last visible pixel in this frame.
               * Resynchronize, clear the fifo, and start fetching from fb_address0.
               */
              // frame_ctr       <= frame_ctr + 1;

              fb_address          <= 0; // XXX Not needed?
              fb_transfer_request <= 0; // XXX Not needed?
              pixel_buffer_addr   <= fb_address0;
              pixel_buffer_wp     <= 0;
              pixel_buffer_rp     <= 0;
              free                <= ~0;
              left_to_request     <= FRAMEBUFFER_WORDS - 2;
           end
        end

      /* Advance the (x,y) pointer. */
      if (x == x_max-1)
        y <= (y == y_max-1) ? 0 : y+1;
      x <= (x == x_max-1) ? 0 : x+1;
   end

   reg [31:0] i;
   initial for (i = 0; i < (1 << BUFL2) - 1; i = i + 1) pixel_buffer[i] = 0;
endmodule

`ifdef SIMULATE_VGA
module tester();
   reg         clk25MHz, rst;

   // Lancelot VGA interface
   wire  [7:0] vga_r;
   wire  [7:0] vga_g;
   wire  [7:0] vga_b;
   wire        vga_m1;
   wire        vga_m2;
   wire        vga_sync_n;
   wire        vga_sync_t;
   wire        vga_blank_n;
   wire        vga_hs;
   wire        vga_vs;

   reg  [31:0] fb_address0;   // Top of FB

   // Memory port
   wire `REQ   fb_req;
   wire `RES   fb_res;

   reg  holdit;

   reg [31:0] addr;

   assign fb_busy = holdit & (fb_rden | fb_req`W);
   assign fb_res`RD   = addr;

   always @(posedge clk25MHz) addr <= fb_req`A;

   vga vga(clk25MHz, rst, vga_r, vga_g, vga_b,
           vga_m1, vga_m2, vga_sync_n, vga_sync_t, vga_blank_n, vga_hs, vga_vs,
           'h9000_0000,
           fb_req, fb_res);

   always #20 clk25MHz = ~clk25MHz;
   initial begin
      #0 clk25MHz = 0; rst = 1; holdit = 0;
      #40 rst = 0;

      $monitor(clk25MHz, rst, vga_r,vga_g,vga_b);
      #4000 holdit = 1; $display("%05d VGA: HOLDIT", $time);
      #110000 holdit = 0; $display("%05d VGA: ~HOLDIT", $time);
   end
endmodule
`endif //  `ifdef SIMULATE_VGA
