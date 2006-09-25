module fpgammix(// Clock and reset
            input  wire        clkin        // K5  PLL1 input clock (50 MHz)
           ,output wire        pld_clkout   // L8  Clock to zero-skew buffer Lancelot board
           ,input  wire        pld_clkfb    // L14 Feedback from pld_clkout to PLL2
           ,input  wire        reset_n      // C4  CPU Reset button

           // Push buttons LEDs 7-segments
           ,input  wire  [3:0] sw           // Pushbutton switches
           ,output wire  [7:0] led          // Debugging LEDs
           ,output wire  [7:0] s7_0         // Debugging 7-segment LEDs
           ,output wire  [7:0] s7_1         // --

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
           ,output             sram_we_n    // SRAM WE#

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

   wire            reset,
                   reset_stb; // Dummy, not used
   wire            clk25MHz, clk100MHz, pll1_locked;

   /* Filter the reset signal and synchronize it. Purists may not like
      the fact that a short async reset will be ignored.  Whatever. */
   filter filter_reset(clk25MHz, ~reset_n | ~pll1_locked, reset, reset_stb);

   pll1 pll1(
        .inclk0(clkin),         // 50 MHz input clock
        .c0(clk100MHz),         // x2/1 = 100 MHz output clock
        .c1(clk25MHz),          // x1/2 =  25 MHz output clock
        .locked(pll1_locked),
        .e0(pld_clkout)         // External only output x1/2 = 25 MHz
        );

   system
         (clk25MHz     // 25 MHz clock
         ,reset        // C4  CPU Reset button

         ,sw           // Pushbutton switches
         ,led          // Debugging LEDs
         ,s7_0         // Debugging 7-segment LEDs
         ,s7_1         // --

         ,ttyb_txd     // Debug TxD
         ,ttyb_rxd     // Debug RxD

         ,fse_a        // Mainboard common bus address
         ,fse_d        // Mainboard common bus data
         ,flash_cs_n   // Flash ROM CS#
         ,enet_aen     // Ethernet Access Enable
         ,sram_cs_n    // SRAM CS#
         ,sram_be_n    // SRAM byte enables
         ,sram_oe_n    // SRAM OE#
         ,sram_we_n    // SRAM WE#

         ,cf_a         // CompactFlash address bus
         ,cf_d         // CompactFlash data bus
         ,cf_rdy       // CompactFlash RDY
         ,cf_wait_n    // CompactFlash WAIT#
         ,cf_ce1_n     // CompactFlash CE1#
         ,cf_ce2_n     // CompactFlash CE2#
         ,cf_oe_n      // CompactFlash OE#
         ,cf_we_n      // CompactFlash WE#
         ,cf_reg_n     // CompactFlash REG#
         ,cf_cd1_n     // CompactFlash card detect

         ,vga_r        // VGA red
         ,vga_g        // VGA green
         ,vga_b        // VGA blue
         ,vga_hs       // VGA horz sync
         ,vga_vs       // VGA vert sync
         ,vga_blank_n  // VGA DAC force blank
         ,vga_sync_n   // VGA sync enable
         ,vga_sync_t   // VGA sync on R/G/B
         ,vga_m1       // VGA color space config
         ,vga_m2       // VGA color space config

         ,ps2_sel      // PS/2 port input/output select
         ,ps2_kclk     // PS/2 keyboard clock
         ,ps2_kdata    // PS/2 keyboard data
         ,ps2_mclk     // PS/2 mouse clock
         ,ps2_mdata    // PS/2 mouse data


         ,audio_l      // 1-bit Sigma-delta converter
         ,audio_r      // 1-bit Sigma-delta converter
         );
endmodule // main
