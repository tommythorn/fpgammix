/*
 * This file is part of the fpgammix package
 * Copyright (C) Tommy Thorn 2006
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * MMIX on an FPGA
 *
 * This is a first FPGA implementation of Dr. Knuth's MMIX
 * architecture. The priorities for this implementation is to reach a
 * useful functional subset as quickly as possible.  Performance and
 * logic usage in particular are *NOT* a priority (but will be for a
 * later implementation).
 *
 * Todo:
 * - TRAP [DONE]
 * - interrupts [DONE]
 * - Interval timer exceptions [DONE]
 * - marginal to local register promotion [Partly, needs stack_store()]
 * - Clean up core's memory model
 * - MOR, MXOR
 * - DIV
 * - SAVE, UNSAVE
 * - LDSF, STSF
 * - Rename I_XX -> XX (maybe)
 */

// Warn about undefined nets
// `default_nettype none
// but Icarus does that with -Wimplicit also
module core(input  wire        clock
           ,input  wire        reset
           ,input  wire [63:0] start

           ,input  wire [23:0] core_interrupt

           ,output reg         core_io_access = 0
           ,output reg         core_transfer_request = 0
           ,output wire [31:0] core_address // Physical
           ,output reg         core_wren = 0
           ,output reg  [31:0] core_wrdata
           ,output reg  [ 3:0] core_wrmask
           ,input              core_wait_request
           ,input              core_read_data_valid
           ,input       [31:0] core_read_data

           ,output reg         core_ifetch // Exported for diagnostics reasons only
           );

   parameter V = 0; // V for verbose

`include "mmix_opcodes.v"

   /* The main state machine */
   parameter     S_RESET        =  0,

                 S_IFETCH1      = 10,
                 S_IFETCH2      = 11,
                 S_IFETCH3      = 12,

                 S_INTERRUPT    = 19,

                 S_RF0          = 20,
                 S_RF1          = 21,
                 S_RF2          = 22,
                 S_RF3          = 23,
                 S_RF4          = 24,

                 S_EXECUTE1     = 30,
                 S_EXECUTE2     = 31,

                 S_MEM1         = 40,
                 S_MEM2         = 41,
                 S_MEM3         = 42,

                 S_WB1          = 50,
                 S_WB2          = 51,

                 S_EXTMEM1      = 60,
                 S_EXTMEM2      = 61,
                 S_EXTMEM3      = 62,
                 S_EXTMEM4      = 63,

                 S_POP1         = 70,
                 S_POP2         = 71,

                 S_MULTIPLYING	= 75,
                 S_DIVIDING	= 76,
                 S_MOR          = 77,
                 S_MXOR         = 78,

                 S_TRIPPING1    = 80,

                 S_NOT_IMPLEMENTED
                                = 91,
                 S_ILLEGAL_INST
                                = 92,
                 S_PRIVILEGED_INST
                                = 93,
                 S_HALTED       = 94;

   // 57. Bits for arithmetic exceptions (we diverge from Knuth by
   // also define the log2 equivalent XX_EXC) Note, Knuth left
   // shifts them by eight to line up with the enable bits
   parameter	INTERVAL_TIMEOUT_EXC = 7,  /* the timer register, rI, has reached zero */
                X_EXC	=  8,
		Z_EXC	=  9,
		U_EXC	= 10,
		O_EXC	= 11,
		I_EXC	= 12,
		W_EXC	= 13,
		V_EXC	= 14,
		D_EXC	= 15,
                H_EXC	= 16;

   parameter	RESUME_AGAIN	= 0,
		RESUME_CONT	= 1,
		RESUME_SET	= 2;

   parameter	X_BIT		= 1 << X_EXC,
		Z_BIT		= 1 << Z_EXC,
		U_BIT		= 1 << U_EXC,
		O_BIT		= 1 << O_EXC,
		I_BIT		= 1 << I_EXC,
		W_BIT		= 1 << W_EXC,
		V_BIT		= 1 << V_EXC,
		D_BIT		= 1 << D_EXC,
		H_BIT		= 1 << H_EXC;

   parameter	POWER_FAILURE	= 1<<0,		/* try to shut down calmly and quickly */
		PARITY_ERROR	= 1<<1,		/* try to save the file systems */
                NONEXISTENT_MEMORY=1<<2,	/* a memory address can't be used */
                REBOOT_SIGNAL	= 1<<4;		/* it's time to start over */

   /* 65.  Info flags */
   parameter     Z_is_immed_bit  = 'h01,
                 Z_is_source_bit = 'h02,
                 Y_is_immed_bit  = 'h04,
                 Y_is_source_bit = 'h08,
                 X_is_source_bit = 'h10,
                 X_is_dest_bit   = 'h20,
                 rel_addr_bit    = 'h40,
                 push_pop_bit    = 'h80;

   parameter     VERSION         = 1,
                 SUBVERSION      = 0,
                 SUBSUBVERSION   = 1,
                 ABSTIME         = 1152770398;

   reg [31:0]    state = S_RESET;

   /* XXX This is Quartus specific.  Must find a way to make this more
      portable to also Xilinx ISE. */
   (* ram_init_file = "../info_flags.mif" *)
   reg [ 7:0]    info_flags[0:255];

   reg [63:0]    branch_target;

   /* 55. Knuth keeps all the special registers in the global register
      file, but there's already way too much contention for that.  We
      keep them as seperate variables. */
   reg [63:0]    rB, rD, rE, rH, rJ, rM, rR, rBB, rC, rN, rO, rS, rT,
                 rTT, rK, rQ, rU, rV, rL, rA, rF, rP, rW, rX, rY,
                 rZ, rWW, rXX, rYY, rZZ;

   reg [64:0]    rI; // We use the MSB overflow trick to save a bit of logic
   reg [63:0]    rQ_lastread;

   reg [ 7:0]    tmpbyte;
   reg [63:0]    t, aux;
   reg [64:0]    diff;
   reg           sign, z_sign;
   reg [63:0]    z_abs;
   reg [ 7:0]    n;  // Random bit counter
   reg           truth;
   reg [63:0]    rX_;  /* Temporary for RESUME handling only */

   // 61.
   reg  [63:0] w, x, y, z, b, ma, mb;  /* operands */
   reg  [10:0] x_ptr;  /* destination */
   reg  [63:0] loc;    /* location of the current instruction */
   reg  [63:0] inst_ptr;  /* location of the next instruction */
   reg  [31:0] inst;      /* the current instruction */
   reg  [31:0] exc; /* exceptions raised by the current instruction */
   reg  [ 1:0] rop; /* ropcode of a resumed instruction */
   // int round_mode; /* the style of floating point rounding just used */
   reg  [ 1:0] resuming; /* are we resuming an interrupted instruction?
                          * resuming[0] yes/no
                          * resuming[1] trap/trip
                          */
   // bool halted; /* did the program come to a halt? */
   // bool breakpoint; /* should we pause after the current instruction? */
   // bool tracing; /* should we trace the current instruction? */
   // bool stack_tracing; /* should we trace details of the register stack? */
   // bool interacting; /* are we in interactive mode? */
   // bool interact_after_break; /* should we go into interactive mode? */
   // bool tripping; /* are we about to go to a trip handler? */
   // bool good; /* did the last branch instruction guess correctly? */
   // tetra trace_threshold; /* each instruction should be traced this many times */

   // 62.
   reg  [ 7:0] op;
   reg  [ 7:0] xx;
   reg  [ 7:0] yy;
   reg  [ 7:0] zz;

   reg  [63:0] yz;
   reg  [ 7:0] f;
   reg  [63:0] i, j;

   // 75.
   reg  [ 7:0] G, L, O;

   /*
    * 76.
    *
    * I diverge from MMIXWARE and unify the global and local
    * registers, such that the top 256 registers are global. (For
    * simplicity and to eliminate some muxes)
    */
   parameter GLOBAL = 256;
   reg  [ 8:0] regfile_rdaddress_a, regfile_rdaddress_b, regfile_rdaddress_c;
   reg         regfile_rden_a = 0;
   wire [63:0] regfile_rddata_a;
   reg         regfile_rden_b = 0;
   wire [63:0] regfile_rddata_b;
   reg         regfile_rden_c = 0;
   wire [63:0] regfile_rddata_c;

   reg         regfile_wren;
   reg  [ 8:0] regfile_wraddress;
   reg  [63:0] regfile_wrdata;

   reg  [63:0] g255_readonly_cache;       /* This is a read-only copy of g[255] / $255 */

   reg  [10:0] lring_size, /* the number of local registers (a power of 2) */
               lring_mask, /* one less than lring_size */
               S;          /* congruent to rS >> 3 modulo lring_size */

   reg  [63:0] l_xx;   /* local registers[(O + xx) & lring_mask] */
   reg  [63:0] l_yy;   /* local registers[(O + yy) & lring_mask] */
   reg  [63:0] l_zz;   /* local registers[(O + zz) & lring_mask] */
   reg  [63:0] l_q;
   reg  [63:0] g_q;
   reg  [63:0] g_xx, g_yy, g_zz;

   reg         b_sign, b_zero, b_posi, b_pari;
   reg         y_sign, y_zero, y_posi, y_pari;
   reg  [63:0] high_shift;

   reg  [63:0] datamem_addr;
   reg  [63:0] datamem_rddata = 64'h1BADDECAF4BABE;
   reg         datamem_rddata_high = 0, datamem_rddata_low = 0;
   reg  [63:0] datamem_wrdata;
   reg  [ 7:0] datamem_wrbyteena;
   reg         datamem_wren = 0;
   reg         datamem_rden = 0;

   reg         wb, wb_global;
   reg  [10:0] g_a, l_a;

   reg         error = 0;

   reg  [63:0] mul_acc, mul_aux, mul_a;
   reg  [63:0] mul_b;

   regfile regfile_a (
	.clock ( clock ),

	.rden ( regfile_rden_a ),
	.rdaddress ( regfile_rdaddress_a ),
	.q ( regfile_rddata_a ),

	.wren ( regfile_wren ),
	.wraddress ( regfile_wraddress ),
	.data ( regfile_wrdata )
	);

   regfile regfile_b (
	.clock ( clock ),

	.rden ( regfile_rden_b ),
	.rdaddress ( regfile_rdaddress_b ),
	.q ( regfile_rddata_b ),

	.wren ( regfile_wren ),
	.wraddress ( regfile_wraddress ),
	.data ( regfile_wrdata )
	);

   regfile regfile_c (
	.clock ( clock ),

	.rden ( regfile_rden_c ),
	.rdaddress ( regfile_rdaddress_c ),
	.q ( regfile_rddata_c ),

	.wren ( regfile_wren ),
	.wraddress ( regfile_wraddress ),
	.data ( regfile_wrdata )
	);

   reg [63:0]  core_virt_address;

   address_virtualization tlb(clock, core_virt_address, core_address);

   always @(posedge clock) begin
      /* Maintain the global read-only copy of $255 */
      if (regfile_wren && regfile_wraddress == (GLOBAL | 255))
         g255_readonly_cache <= regfile_wrdata;

      rC <= rC + 1;
      rI <= rI - 65'd1;

      // rQ is low-pri:24 program:8 high-pri I/O:24 machine:8
      rQ[63:40] <= rQ[63:40] | core_interrupt;
      if (core_interrupt & ~rQ[63:40])
         $display("%06d peripherals raising exception", $time, core_interrupt);

      if (rI[64]) begin
         $display("%06d Interval timer just ranout, raising exception", $time);
         rQ[INTERVAL_TIMEOUT_EXC] <= 1;
         rI[64] <= 0;
      end

      if (regfile_wren)
        if (regfile_wraddress & GLOBAL)
          $display("%06d g[%1d]=#%x", $time,
                   regfile_wraddress - GLOBAL, regfile_wrdata);
        else
          $display("%06d l[%1d]=#%x", $time,
                   regfile_wraddress, regfile_wrdata);

      if (core_read_data_valid) begin
         if(V)$display("%06d Core got valid data #%1x (%d%d%d)!", $time,
                  core_read_data,
                  datamem_rddata_high, datamem_rddata_low, core_ifetch);
         if (datamem_rddata_high) begin
            if(V)$display("%06d    Core expected it for high tetra", $time);
            datamem_rddata[63:32] <= core_read_data;
            datamem_rddata_high <= 0;
         end else if (datamem_rddata_low) begin
            if(V)$display("%06d    Core expected it for low tetra", $time);
            datamem_rddata[31:0] <= core_read_data;
            datamem_rddata_low <= 0;
         end else if (~core_ifetch)
           $display("%06d    DROPPED DATA #%1x", $time, core_read_data);
      end

      regfile_wren   <= 0;
      regfile_rden_a <= 0;
      regfile_rden_b <= 0;
      regfile_rden_c <= 0;

      case (state)
        S_RESET: begin
           $display("%06d RESET", $time);
           core_io_access <= 0;
           core_transfer_request <= 0;
           core_wren <= 0;
           datamem_rddata_low <= 0;
           datamem_rddata_high <= 0;
           core_ifetch <= 0;

           datamem_wren <= 0;
           datamem_rden <= 0;
           inst_ptr <= start;

           /*
            * XXX The responsibility for most of these should be move
            * to the firmware (to save logic resources and cycle-time). Obviously,
            * rK, rC, rN, rO, and rS are e... rO and rS??? why.  How
            * is the OS going to set the two latter? (SAVE & UNSAVE).
            */

           g255_readonly_cache <= 0;

           // 77.  p(14.) 37.  XXX Hmm, there should be a better way ...
           // 14.
           // rA = must_remain_zero:46 rounding_mode:2  enable_DVWIOUZX:8 events_DVWIOUZX:8
           // 0 - 7
           rB = 64'hBADDECAFDEADBABE;  // bootstrap register (trip) [0]
           rD = 64'hBADDECAFDEADBABE;  // dividend register [1]
           rE = 64'hBADDECAFDEADBABE;  // epsilon register [2]
           rH = 64'hBADDECAFDEADBABE;  // himult register [3]
           rJ = 64'hBADDECAFDEADBABE;  // return-jump register [4]
           rM = 64'hBADDECAFDEADBABE;  // multiplex mask register [5]
           rR = 64'hBADDECAFDEADBABE;  // remainder register [6]
           rBB= 64'hBADDECAFDEADBABE;  // bootstrap register (trap) [7]

           // These can't be PUT
           rC <= 0; // cycle counter [8]
           rN[63:32] = (VERSION << 24) + (SUBVERSION << 16) + (SUBSUBVERSION << 8);
           rN[31: 0] = ABSTIME; // serial number [9]
           // XXX Correctly this when memory settles
           rO = 64'h6_0000; // register stack offset [10]
           rS = 64'h6_0000; // register stack pointer [11]

           // These can't be PUT by the user
           rI <= ~65'd0;  // interval counter [12]
           rT = 64'h8000000850000000;  // trap address register [13]
           rTT= 64'h8000000600000000;  // dynamic trap address register [14]
           rK = 0;  // interrupt mask register [15]
           rQ <= 0; // interrupt request register [16]
           rU = 0;  // usage counter [17]
           rV = 64'h369c2004;  // virtual translation register [18]

           // Finally, these may cause pipeline delays
           // global threshold register
           G = 256 - 32;
           rL = 0;
           rA = {8'd255, 8'd00}; // Enable all traps, none yet, round nearest

           rF = 0;  // failure location register [22]
           rP = 0;  // prediction register [23]
           rW = 0;  // where-interrupted register (trip) [24]
           rX = 0;  // execution register (trip) [25]
           rY = 0;  // Y operand (trip) [26]
           rZ = 0;  // Z operand (trip) [27]
           rWW= 0;  // where-interrupted register (trap) [28]
           rXX= 0;  // execution register (trap) [29]
           rYY= 0;  // Y operand (trap) [30]
           rZZ= 0;  // Z operand (trap) [31]

           lring_size = 256;
           lring_mask = 255;
           L = 0; // XXX I don't think there really is a need for both rL and L
           O = 0; // XXX I don't think there really is a need for both rO and O
           S = 0;
           resuming = 0;
           state <= S_IFETCH1;
        end

        S_IFETCH1: begin
           $display("");
           if (rQ & rK) begin
              $display("%06d INTERRUPT! rQ=#%1x & rK=#%1x -> #%1x", $time,
                       rQ, rK, rQ & rK);
              state <= S_INTERRUPT;
           end else begin
              state <= S_IFETCH2;
              // 63. sort of ...
              if(V)$display("%06d IF1 Issuing a read request to #%1x", $time, inst_ptr);
              // $display("%06d IFETCH2", $time);
              // CONCEPTUALLY {op, xx, yy, zz} <= progmem[inst_ptr[63:2]]
              if (resuming) begin
                 // We shouldn't get here if resuming is true
                 $display("       Bug in resume support!");
                 state <= S_HALTED;
              end
              core_transfer_request <= 1;
              core_ifetch <= 1;
              core_virt_address <= inst_ptr;
              core_io_access <= 0;
              core_wren <= 0;
              loc <= inst_ptr;
              inst_ptr <= inst_ptr + 4;
           end
        end

      /*
       * Interrupts needs to wait for the pipeline to flush.
       * In this current implementation, the only thing pipelined is
       * the register file write back which hasn't committed yet at S_IFETCH1,
       * thus we go to another cycle.
       */
      S_INTERRUPT: begin
         $display("       $255=#%1x inst_ptr=#%1x",
                  g255_readonly_cache, inst_ptr);
         rK = 0;
         rBB = g255_readonly_cache;
         rWW = inst_ptr;
         rXX = {32'h80000000,inst}; // rop code RESUME_AGAIN, that is, retry inst
         rYY = y;
         rZZ = z;
         regfile_wraddress <= GLOBAL | 255;
         regfile_wrdata    <= rJ;
         regfile_wren      <= 1;
         inst_ptr = rTT;
         state <= S_IFETCH1;
      end

      S_IFETCH2: begin
           if(V)$display("IFETCH2");
           if (~core_wait_request)
              core_transfer_request <= 0;

           if (core_read_data_valid | resuming) begin
              core_ifetch <= 0;
              if (!resuming)
                inst = core_read_data;
              {op, xx, yy, zz} = inst;
              f <= info_flags[op];
              regfile_rdaddress_a <= ((xx >= G) ? (GLOBAL | xx) : ((O + xx) & lring_mask));
              regfile_rdaddress_b <= ((yy >= G) ? (GLOBAL | yy) : ((O + yy) & lring_mask));
              regfile_rdaddress_c <= ((zz >= G) ? (GLOBAL | zz) : ((O + zz) & lring_mask));
              regfile_rden_a <= 1;
              regfile_rden_b <= 1;
              regfile_rden_c <= 1;
              $display("%06d IF2 #%1x:#%1x", $time, loc, inst);
              state <= S_RF1;
           end
        end

        S_RF1: state <= S_RF4;

        S_RF4: begin
           //$display("%06d zz l[%1d]=#%1x g[%1d]", $time, zz, l_zz, zz, g_zz);
           /* 60.  The main loop. */
           state <= S_EXECUTE1;

           yz = {48'd0, inst[15:0]};
           x = 0;
           y = 0;
           z = 0;
           b = 0;
           exc = 0;
           // old_L = L;
           //$display("%06d ** yz .. #%1x", $time, yz);

           // 70.  Convert relative address to absolute address
           if (f & rel_addr_bit) begin
             if ((op & 8'hFE) == I_JMP) begin
               yz = {40'd0, inst[23:0]};
               if(V)$display("%06d ** yz .. #%1x [JMP]", $time, yz);
               end
             if (op & 1) begin
               yz = yz - ((op == I_JMPB) ? 64'h1000000 : 64'h10000);
               if(V)$display("%06d ** yz .. #%1x [op & 1]", $time, yz);
               end
             y = inst_ptr; z = loc + (yz << 2);
           end
           if(V)$display("%06d ** yz = #%1x, z = #%1x", $time, yz, z);

           // 71.  Install operand fields.
           if (resuming && rop != RESUME_AGAIN) begin
              $display("%06d ** resuming ...", $time);
              /* 126.  Install special operands when resuming an interrupted operation */
              if (rop == RESUME_SET) begin
                 op = I_ORI;
                 y = resuming[1] ? rZZ : rZ;
                 z = 0;
                 exc = {resuming[1] ? rXX[47:40] : rX[47:40],8'd0};
                 f = X_is_dest_bit;
                 $display("       resume_set op=#%1x y=#%1x exc=#%1x", op, y, exc);
              end else begin /* RESUME_CONT */
                 y = rY;
                 z = rZ;
              end
           end else begin
             if (f & X_is_source_bit) begin
                // 74.  Set b from register X
                b = regfile_rddata_a;
                if(V)$display("%06d ** regfile a -> b = #%1x", $time, b);
             end
             // XXX if (info[op].third_operand) <set b from special register 79>;
             if (f & Z_is_immed_bit) begin
                z = zz; //$display("%06d ** z = zz", $time);
             end else if (f & Z_is_source_bit) begin
               // 72.  Set z from register Z
                z = regfile_rddata_c;
                if(V)$display("%06d ** regfile c -> z = #%1x", $time, z);
             end else if ((op & 8'hF0) == I_SETH) begin
                // 78.  Set z as an immediate wyde
               case (op[1:0])
               0: z = {yz[15:0],48'd0};
               1: z = {16'd0,yz[15:0],32'd0};
               2: z = {32'd0,yz[15:0],16'd0};
               3: z = {48'd0,yz[15:0]};
               endcase
               y = b;
               if(V)$display("%06d ** 78.  z=#%1x y=#%1x", $time, z, y);
             end
             if (f & Y_is_immed_bit) begin y = yy; if(V)$display("%06d ** y = yy", $time); end
             else if (f & Y_is_source_bit) begin
                // 73.  Set y from register Y
                y = regfile_rddata_b;
                if(V)$display("%06d ** regfile b -> y=#%1x", $time, y);
             end
           end

           wb = 0;
           // 60...
           if (f & X_is_dest_bit) begin
              /* 80.  Install register X as the destination, adjusting the
                      register stack if necessary */
              wb = 1;
              wb_global = 0;
              if (xx >= G) begin
                x_ptr = GLOBAL | xx;
              end else begin
                 if (xx >= L) begin
                    //$display("%06d ** 81.  Increasing rL, setting l[%1d] <- 0", $time, O + L);
                    regfile_wraddress <= (O + L) & lring_mask;
                    regfile_wrdata    <= 0;
                    regfile_wren      <= 1;
                    L = L + 1;
                    rL = L;
                    if (((S - O - L) & lring_mask) == 0) begin
                       $display("%06d ** 83.  stack_store() not implemented!", $time);
                       state <= S_NOT_IMPLEMENTED;
                    end
                    state <= S_RF4;
                 end else
                   x_ptr = (O + xx) & lring_mask;
              end
           end
        end

        /* Even though I'm not trying to optimize, making this run at 50 MHz
           makes my life easier, thus this extra stage which hopefully
           enables Quartus to retime some of this */
        S_EXECUTE1: begin
           state <= S_EXECUTE2;
           resuming = 0;

           w = y + z;
           if(V)$display("%06d ** w (#%1x) = y (#%1x) + z (#%1x)", $time, w, y, z);

           // if (loc >= 64'h20000000) goto privileged_inst;
           branch_target <= loc + {{46{op[0]}},yy,zz,2'd0};

           b_sign = b[63];
           b_zero = b == 0;
           b_pari = b[0];
           b_posi = ~b_sign & ~b_zero;

           y_sign = y[63];
           y_zero = y == 0;
           y_pari = y[0];
           y_posi = ~y_sign & ~y_zero;
        end

        S_EXECUTE2: begin
           state <= S_MEM1;
           if(V)$display("%06d EX2 x=#%1x y=#%1x z=#%1x b=#%1x w=#%1x", $time, x, y, z, b, w);

           case (op)
           // 84.
           I_ADD, I_ADDI:       x = w;

           // 85.
           I_SUB, I_SUBI, I_NEG, I_NEGI, I_SUBU, I_SUBUI, I_NEGU, I_NEGUI:
                                x = y - z;
           I_ADDU, I_ADDUI, I_INCH, I_INCMH, I_INCML, I_INCL:
                                x = w;
           I_2ADDU, I_2ADDUI:   x = (y << 1) + z;
           I_4ADDU, I_4ADDUI:   x = (y << 2) + z;
           I_8ADDU, I_8ADDUI:   x = (y << 3) + z;
           I_16ADDU, I_16ADDUI: x = (y << 4) + z;
           I_SETH, I_SETMH, I_SETML, I_SETL, I_GETA, I_GETAB: begin
                                $display("       SETx = #%1x",z);
                                x = z;
           end
           // 86.
           I_OR, I_ORI, I_ORH, I_ORMH, I_ORML, I_ORL:
                                x =  y |  z;
           I_ORN, I_ORNI:       x =  y | ~z;
           I_NOR, I_NORI:       x = ~(y | z); // === ~y & ~z
           I_XOR, I_XORI:       x =  y ^  z;
           I_AND, I_ANDI:       begin
                                x =  y &  z;
                                $display("       AND #%1x,#%1x -> #%1x", y, z, x);
                                end
           I_ANDN, I_ANDNI, I_ANDNH, I_ANDNMH, I_ANDNML, I_ANDNL:
                                x =  y & ~z;
           I_NAND, I_NANDI:     x = ~(y & z); // === ~y | ~z
           I_NXOR, I_NXORI:     x = ~(y ^ z);

           // 87.
           I_SL, I_SLI, I_SLU, I_SLUI:
             if (z >= 64) begin
                x = 0;
                if (|y) begin
                   exc[V_EXC] = 1;
                   $display("%06d ** SL Overflow", $time);
                end
             end else begin
                x = y << z[5:0];

                // XXX OMG.  Spend 2X the cycles here
               /* if (($signed(x) >> z[5:0]) != y) begin
                   exc[V_EXC] = 1;
                   $display("%06d ** SL Overflow", $time);
                end*/
             end
                                // XXX Not 100% sure of these two
           I_SR, I_SRI:         begin
                                   x = $signed(y) >>> (z[63:6] ? 63 : z[5:0]);
                                   $display("       SR #%1x, #%1x -> #%1x",
                                            y, z, x);
                                end
           I_SRU, I_SRUI:       begin
                                   x = z[63:6] ? 0 : (y >> z[5:0]);
                                   $display("       SRU #%1x, #%1x -> #%1x",
                                            y, z, x);
                                end
           I_MUX, I_MUXI:       x = y & rM | z & ~rM;

           I_SADD, I_SADDI:     begin
                                  t = y & ~z;
                                  x = t[0]+t[1]+t[2]+t[3]+t[4]+t[5]+t[6]+t[7]+t[8]+t[9]+t[10]+t[11]+t[12]+t[13]+t[14]+t[15]+t[16]+t[17]+t[18]+t[19]+t[20]+t[21]+t[22]+t[23]+t[24]+t[25]+t[26]+t[27]+t[28]+t[29]+t[30]+t[31]+t[32]+t[33]+t[34]+t[35]+t[36]+t[37]+t[38]+t[39]+t[40]+t[41]+t[42]+t[43]+t[44]+t[45]+t[46]+t[47]+t[48]+t[49]+t[50]+t[51]+t[52]+t[53]+t[54]+t[55]+t[56]+t[57]+t[58]+t[59]+t[60]+t[61]+t[62]+t[63];
                                end

           I_MOR, I_MORI:       begin
                                  n <= 62;
                                  t <= y;
                                  state <= S_MOR;
                                end

           I_MXOR, I_MXORI:     begin
                                  n <= 62;
                                  t <= y;
                                  state <= S_MXOR;
                                end

           I_BDIF, I_BDIFI:     begin
                                  if (y[63:56] > z[63:56]) x[63:56] = y[63:56] - z[63:56];
                                  if (y[55:48] > z[55:48]) x[55:48] = y[55:48] - z[55:48];
                                  if (y[47:40] > z[47:40]) x[47:40] = y[47:40] - z[47:40];
                                  if (y[39:32] > z[39:32]) x[39:32] = y[39:32] - z[39:32];
                                  if (y[31:24] > z[31:24]) x[31:24] = y[31:24] - z[31:24];
                                  if (y[23:16] > z[23:16]) x[23:16] = y[23:16] - z[23:16];
                                  if (y[15: 8] > z[15: 8]) x[15: 8] = y[15: 8] - z[15: 8];
                                  if (y[ 7: 0] > z[ 7: 0]) x[ 7: 0] = y[ 7: 0] - z[ 7: 0];
                                end
           I_WDIF, I_WDIFI:     begin
                                  if (y[63:48] > z[63:48]) x[63:48] = y[63:48] - z[63:48];
                                  if (y[47:32] > z[47:32]) x[47:32] = y[47:32] - z[47:32];
                                  if (y[31:16] > z[31:16]) x[31:16] = y[31:16] - z[31:16];
                                  if (y[15: 0] > z[15: 0]) x[15: 0] = y[15: 0] - z[15: 0];
                                end
           I_TDIF, I_TDIFI:     begin
                                  if (y[63:32] > z[63:32]) x[63:32] = y[63:32] - z[63:32];
                                  if (y[31: 0] > z[31: 0]) x[31: 0] = y[31: 0] - z[31: 0];
                                end
           I_ODIF, I_ODIFI:     if (y > z) x = y - z;

           I_MULU, I_MULUI, I_MUL, I_MULI: begin
              {mul_aux,mul_acc} <= 0;
              if (y > z) begin
                 mul_a <= y; mul_b <= z;
              end else begin
                 mul_a <= z; mul_b <= y;
              end
              state <= S_MULTIPLYING;
           end

           I_DIV, I_DIVI:
              if (y == 64'h8000000000000000 && z == 64'hFFFFFFFFFFFFFFFF) begin
                 exc[V_EXC] = 1;
                 x  <= y;
                 rR <= 0;
              end else if (z == 0) begin
                 exc[D_EXC] = 1;
                 x  <= 0;
                 rR <= y;
              end else begin
                 n     <= 62;
                 t     <= 0;
                 sign  <= (y[63] ^ z[63]);
                 z_sign <= z[63];
                 if (y[63])
                    y = -y;
                 if (z[63])
                    z = -z;
                 z_abs = z;
                 x     <= y;
                 state <= S_DIVIDING;
              end

           I_DIVU, I_DIVUI: begin
              $display("rD = %d, z = %d, rD >= z %d", rD, z, rD >= z);
              if (rD >= z) begin
                 /* Arith 14. check that x < z; otherwise give trivial answer */
                 x     <= rD;
                 rR    <= y;
              end else begin
                 n     <= 62;
                 t     <= rD;
                 sign  <= 0;
                 x     <= y;
                 y_sign <= 0; // Override signs to avoid any fixup afterwards
                 z_sign <= 0;
                 state <= S_DIVIDING;
              end
           end

            // 89.
           /*
            I_FADD, I_FSUB, I_FMUL, I_FDIV, I_FREM, I_FSQRT, I_FINT,
            I_FIX, I_FIXU, I_FLOT, I_FLOTI, I_FLOTU, I_FLOTUI,
            I_SFLOT, I_SFLOTUI: begin
               $display("%06d ** floating point isn't implemented yet", $time); // XXX
               state <= S_NOT_IMPLEMENTED;
            end
            */

            // 90.
            I_CMP, I_CMPI: begin
               /* I use a simpler version than Knuth's
                  Signed comparisons:
                    a > b <=> (a^M) >U (b^M), M = 1 << 63
                */

               if (y == z)
                  x = 0;
               else if ((y ^ 64'h8000000000000000)
                        > (z ^ 64'h8000000000000000))
                  x = 1;
               else
                  x = -1;
               $display("%06d (CMP) %1d, %1d -> #%1x", $time, y, z, x);
            end

            I_CMPU, I_CMPUI: begin
               if (y == z)
                  x = 0;
               else if (y > z)
                  x = 1;
               else
                  x = -1;
               $display("%06d (CMPU) #%1x, #%1x -> #%1x", $time, y, z, x);
            end

           /*
            I_FCMPE, I_FCMP, I_FUN, I_FEQL, I_FEQLE, I_FUNE: begin
               $display("%06d ** floating point isn't implemented yet", $time); // XXX
               state <= S_NOT_IMPLEMENTED;
            end
            */


            // 91. & 92.
            I_CSN, I_CSNI, I_CSZ, I_CSZI, I_CSP, I_CSPI,
            I_CSOD, I_CSODI, I_CSNN, I_CSNNI, I_CSNZ, I_CSNZI,
            I_CSNP, I_CSNPI, I_CSEV, I_CSEVI, I_ZSN, I_ZSNI,
            I_ZSZ, I_ZSZI, I_ZSP, I_ZSPI, I_ZSOD, I_ZSODI,
            I_ZSNN, I_ZSNNI, I_ZSNZ, I_ZSNZI, I_ZSNP, I_ZSNPI,
            I_ZSEV, I_ZSEVI: begin
               case (op[2:1])
               0: truth = y_sign;
               1: truth = y_zero;
               2: truth = y_posi;
               3: truth = y_pari;
               endcase
               if (op[3]) truth = ~truth;
               x = truth ? z : b;
            end

            // 93.
            I_BN, I_BNB, I_PBN, I_PBNB,
            I_BZ, I_BZB, I_PBZ, I_PBZB,
            I_BP, I_BPB, I_PBP, I_PBPB,
            I_BOD, I_BODB, I_PBOD, I_PBODB,
            I_BNN, I_BNNB, I_PBNN, I_PBNNB,
            I_BNZ, I_BNZB, I_PBNZ, I_PBNZB,
            I_BNP, I_BNPB, I_PBNP, I_PBNPB,
            I_BNOD, I_BNODB, I_PBNOD, I_PBNODB: begin
               $display("%06d ** Branch op[2:0] #%1x", $time, op[2:0]);
               case (op[2:1])
               0: truth = b_sign;
               1: truth = b_zero;
               2: truth = b_posi;
               3: truth = b_pari;
               endcase
               if (op[3]) truth = ~truth;
               if (truth) begin
                  $display("%06d ** Branch taken, jumping to #%1x", $time, z);
                  inst_ptr <= z;
               end
            end

            // 94.
            I_LDB, I_LDBI, I_LDBU, I_LDBUI, I_LDW, I_LDWI, I_LDWU, I_LDWUI,
            I_LDT, I_LDTI, I_LDTU, I_LDTUI, I_LDO, I_LDOI, I_LDOU, I_LDOUI,
            I_LDSF, I_LDSFI, I_LDHT, I_LDHTI: begin
               datamem_addr <= w;
               datamem_rden <= 1;
            end

             // 95.
           I_STB, I_STBI, I_STBU, I_STBUI: begin
              if (op[1])
                 $display("%06d ** STBU [#%1x] <- #%1x", $time, w, b[7:0]);
              else
                 $display("%06d ** STB [#%1x] <- #%1x", $time, w, b);
              datamem_addr      <= w;
              datamem_wrdata    <= {b[7:0], b[7:0], b[7:0], b[7:0],
                                    b[7:0], b[7:0], b[7:0], b[7:0]};
              datamem_wrbyteena <= 8'h80 >> w[2:0];
              datamem_wren      <= 1;

              if ({{56{b[7]}},b[7:0]} != b && ~op[1]) begin
                 $display("%06d ** STB Overflow", $time);
                 exc[V_EXC] = 1;
              end
           end

           I_STW, I_STWI, I_STWU, I_STWUI: begin
              if (op[1])
                 $display("%06d ** STWU [#%1x] <- #%1x", $time, w, b[15:0]);
              else
                 $display("%06d ** STW [#%1x] <- #%1x", $time, w, b);
              datamem_addr      <= w;
              datamem_wrdata    <= {b[15:0], b[15:0], b[15:0], b[15:0]};
              datamem_wrbyteena <= 8'hC0 >> (2*w[2:1]);
              datamem_wren      <= 1;

              if ({{48{b[15]}},b[15:0]} != b && ~op[1]) begin
                 $display("%06d ** STW Overflow", $time);
                 exc[V_EXC] = 1;
              end
           end

           I_STT, I_STTI, I_STTU, I_STTUI: begin
              if (op[1])
                 $display("%06d ** STTU [#%1x] <- #%1x", $time, w, b[31:0]);
              else
                 $display("%06d ** STT [#%1x] <- #%1x", $time, w, b);
              datamem_addr      <= w;
              datamem_wrdata    <= {b[31:0], b[31:0]};
              datamem_wrbyteena <= 8'hF0 >> (4*w[2]);
              datamem_wren      <= 1;

              if ({{32{b[31]}},b[31:0]} != b && ~op[1]) begin
                 $display("%06d ** STT Overflow", $time);
                 exc[V_EXC] = 1;
              end
           end

           I_STO, I_STOI, I_STOU, I_STOUI, I_STUNC, I_STUNCI: begin
              if ((op & ~1) == I_STUNC)
                 $display("%06d ** STUNC [#%1x] <- #%1x", $time, w, b);
              else if (op[1])
                 $display("%06d ** STOU [#%1x] <- #%1x", $time, w, b);
              else
                 $display("%06d ** STO [#%1x] <- #%1x", $time, w, b);
              datamem_addr      <= w;
              datamem_wrdata    <= b;
              datamem_wrbyteena <= 8'hFF;
              datamem_wren      <= 1;
           end

           /*
           I_STSF, I_STSFI:  begin
              state <= S_NOT_IMPLEMENTED;
           end
            */

           I_STHT, I_STHTI: begin
              $display("%06d ** STHT [#%1x] <- #%1x", $time, w, b[63:32]);
              datamem_addr      <= w;
              datamem_wrdata    <= {b[63:32], b[63:32]};
              datamem_wrbyteena <= 8'hF0 >> (4*w[0]);
              datamem_wren      <= 1;
           end

           I_STCO, I_STCOI: begin
              $display("%06d ** STCO [#%1x] <- #%1x", $time, w, {56'd0, xx});
              datamem_addr      <= w;
              datamem_wrdata    <= {56'd0, xx};
              datamem_wrbyteena <= 8'hFF;
              datamem_wren      <= 1;
           end

           // 96.
           /*
           I_CSWAP, I_CSWAPI: state <= S_NOT_IMPLEMENTED;
            */

           // 97.
           I_GET: begin
              if (yy || zz >= 32) // XXX Can synthesis compile >= 32 efficiently?
                 state <= S_NOT_IMPLEMENTED;  // XXX Should be a dynamic trap
              else
                 case (zz)
                 REG_B: x = rB;
                 REG_D: x = rD;
                 REG_E: x = rE;
                 REG_H: x = rH;
                 REG_J: x = rJ;
                 REG_M: x = rM;
                 REG_R: x = rR;
                 REG_BB: x = rBB;
                 REG_C: x = rC;
                 REG_N: x = rN;
                 REG_O: x = rO;
                 REG_S: x = rS;
                 REG_I: x = rI[63:0];
                 REG_T: x = rT;
                 REG_TT: x = rTT;
                 REG_K: x = rK;
                 REG_Q: begin x = rQ; rQ_lastread = rQ; end
                 REG_U: x = rU;
                 REG_V: x = rV;
                 REG_G: x = G;
                 REG_L: x = rL;
                 REG_A: x = rA;
                 REG_F: x = rF;
                 REG_P: x = rP;
                 REG_W: x = rW;
                 REG_X: x = rX;
                 REG_Y: x = rY;
                 REG_Z: x = rZ;
                 REG_WW: x = rWW;
                 REG_XX: x = rXX;
                 REG_YY: x = rYY;
                 REG_ZZ: x = rZZ;
                 endcase
           end

           I_PUT, I_PUTI: begin
              $strobe("%06d ** PUT %d, %x", $time, xx, z);
              // XXX INCOMPLETE
              if (yy)
                 state <= S_ILLEGAL_INST;
              else
                 case (xx)
                 // These are "unencumbered" (cf. p 176)
                 REG_B: rB = z;  // bootstrap register (trip) [0]
                 REG_D: rD = z;  // dividend register [1]
                 REG_E: rE = z;  // epsilon register [2]
                 REG_H: rH = z;  // himult register [3]
                 REG_J: rJ = z;  // return-jump register [4]
                 REG_M: rM = z;  // multiplex mask register [5]
                 REG_R: rR = z;  // remainder register [6]
                 REG_BB:rBB= z;  // bootstrap register (trap) [7]

                 // These can't be PUT
                 REG_C: state <= S_ILLEGAL_INST; // rC = z;  // cycle counter [8]
                 REG_N: state <= S_ILLEGAL_INST; // rN = z;  // serial number [9]
                 REG_O: state <= S_ILLEGAL_INST; // rO = z;  // register stack offset [10]
                 REG_S: state <= S_ILLEGAL_INST; // rS = z;  // register stack pointer [11]

                 // These can't be PUT by the user
                 REG_I: rI <= {1'd0,z};  // interval counter [12] (XXX PRIVILEGED)
                 REG_T: rT = z;  // trap address register [13] (XXX PRIVILEGED)
                 REG_TT:rTT= z;  // dynamic trap address register [14] (XXX PRIVILEGED)
                 REG_K: rK = z;  // interrupt mask register [15] (XXX PRIVILEGED)
                 /* interrupt request register [16] (XXX PRIVILEGED)
                    "Interrupt bits in rQ might be lost if they are set
                     between a GET and a PUT. Therefore we don't allow
		     PUT to zero out bits that have become 1 since the
		     most recently committed GET." */
                 REG_Q: rQ <= rQ & ~rQ_lastread | z;
                 REG_U: rU = z;  // usage counter [17] (XXX PRIVILEGED)
                 REG_V: rV = z;  // virtual translation register [18] (XXX PRIVILEGED)

                 // Finally, these may cause pipeline delays
                 // global threshold register
                 REG_G: // 99.
                    if (z > 255 || z < L || z < 32)
                       state <= S_ILLEGAL_INST;
                    else if (z < G) begin
                       // XXX Interestingly using strobe instead of
                       // display causes a crash! (Maybe the G-1 is the cause)
                       $display("%06d ** PUT g[%d] <- 0", $time, G-1);
                       regfile_wraddress <= GLOBAL | (G - 1);
                       regfile_wrdata    <= 0;
                       regfile_wren      <= 1;
                       G <= G - 1;
                       state <= S_EXECUTE2; // Loop
                    end else
                       G = z;

                 // local threshold register [20]
                 REG_L: // 98.
                    if (z < L) begin
                       L = z;
                       rL = z;
                    end

                 // arithmetic status register [21]
                 REG_A: if (z[63:18])
                    state <= S_ILLEGAL_INST;
                 else
                    rA = z;

                 REG_F: rF = z;  // failure location register [22]
                 REG_P: rP = z;  // prediction register [23]
                 REG_W: rW = z;  // where-interrupted register (trip) [24]
                 REG_X: rX = z;  // execution register (trip) [25]
                 REG_Y: rY = z;  // Y operand (trip) [26]
                 REG_Z: rZ = z;  // Z operand (trip) [27]
                 REG_WW:rWW= z;  // where-interrupted register (trap) [28]
                 REG_XX:rXX= z;  // execution register (trap) [29]
                 REG_YY:rYY= z;  // Y operand (trap) [30]
                 REG_ZZ:rZZ= z;  // Z operand (trap) [31]

                 default:
                    state <= S_ILLEGAL_INST;
                 endcase
           end

           // 101.
           I_POP: begin
              $display("%06d (POP)", $time);
              regfile_rdaddress_a <= (O + xx - 1) & lring_mask;
              regfile_rdaddress_b <= (O - 1) & lring_mask;
              regfile_rden_a <= 1;
              regfile_rden_b <= 1;
              state <= S_POP1;
           end

           I_PUSHGO, I_PUSHGOI, I_PUSHJ, I_PUSHJB: begin
              if (op[2])
                 inst_ptr <= w; // PUSHGO
              else
                 inst_ptr <= z; // PUSHJ

              if (xx > G) begin
                 xx = L;
                 L = L + 1;
                 if (((S - O - L) & lring_mask) == 0) begin
                    $display("%06d ** 83.  stack_store() not implemented!", $time);
                    state <= S_NOT_IMPLEMENTED;
                 end
              end
              regfile_wraddress <= (O + xx) & lring_mask;
              regfile_wrdata    <= xx;
              regfile_wren      <= 1;
              //l[(O + xx) & lring_mask] <= xx;
              wb = 0;
              $display("%06d *** PUSHx  l[%1d]=#%1x", $time,
                       (O + xx) & lring_mask, xx);
              x = loc + 4; // XXX Why?
              rJ = loc + 4;
              L = L - (xx + 1);
              O = O + xx + 1;
              rO = rO + ((xx + 1) << 3);
              b = rO; // XXX Why?
              rL = L;
              $display("%06d     rL=%1d, O=%1d, rO=#%1x, rJ=#%1x", $time, rL, O, rO, rJ);
              state <= S_IFETCH1;
           end

           /*
           // 102.
           I_SAVE: state <= S_NOT_IMPLEMENTED; // XXX Lots of work

           // 104.
           I_UNSAVE: state <= S_NOT_IMPLEMENTED; // XXX Lots of work
           */

           // 106.
           I_SYNCID, I_SYNCIDI, I_PREST, I_PRESTI, I_SYNCD,
              I_SYNCDI, I_PREGO, I_PREGOI, I_PRELD, I_PRELDI,
              I_SWYM:
                 state <= S_IFETCH1;

           // 107.
           I_GO, I_GOI: begin
              $display("%06d ** GO to #%1x", $time, w);
              x = inst_ptr; inst_ptr <= w;
           end

           I_JMP, I_JMPB: begin
              inst_ptr <= loc + {{38{op[0]}},xx,yy,zz,2'd0};
           end

           I_SYNC:
              if (xx != 0 || yy != 0 || zz > 7)
                 state <= S_ILLEGAL_INST;
              else
                 state <= S_WB2;

           I_LDVTS, I_LDVTSI:
              state <= S_ILLEGAL_INST; // XXX Really: priviledged

           // 108.
           I_TRIP: begin
              $display("%06d TRIP %d,%d,%d", $time, xx, yy, zz);
              exc[H_EXC] = 1;
           end

           // 108.
           // 124.
           I_RESUME: if (zz[7:1] || xx || yy /* XXX || zz[0] & ~inst_ptr[63] */)
              state <= S_ILLEGAL_INST;       //     ^^^^^ Correct?, but not yet!
           else begin
              $display("%06d RESUME #%1x", $time, zz);
              inst_ptr = zz[0] ? rWW : rW;
              z = inst_ptr;
              rX_ = zz[0] ? rXX : rX;
              if (zz[0]) begin
                 rK = g255_readonly_cache; // Restore interrupt mask
                 regfile_wraddress <= GLOBAL | 255;
                 regfile_wrdata    <= rBB;
                 regfile_wren      <= 1;
                 $display("  b=#%1x x=#%1x", rX_, rBB);
              end
              state <= S_IFETCH1;
              if (~rX_[63]) begin
                 // 125. Prepare to perform a ropcode
                 rop = rX_[57:56];
                 if (rop == 3) begin
                    $display("       Can't handle ropcode 3");
                    state <= S_ILLEGAL_INST;
                 end else begin
                    // if ((1 << b[31:28]) & #8f30) -- 1000_1111_0011_0000

                    if (rop == RESUME_CONT)  // 1
                       case (rX_[31:28])
                       15,11,10,9,8,5,4: begin
                          $display("       Uhhh, not rX_[31:28] was %d", rX_[31:28]);
                          state <= S_ILLEGAL_INST;
                       end
                       endcase

                    if (rop == RESUME_CONT || rop == RESUME_SET) begin // 1 || 2
                       if (rX_[23:16] >= L && rX_[23:16] < G) begin
                          $display("       Wtf, rX_[23:16] = %d", rX_[23:16]);
                          state <= S_ILLEGAL_INST;
                       end
                    end

                    if (rX_[31:24] == I_RESUME) begin
                       $display("       Arrgh, rX_[31:24] = %d", rX_[31:24]);
                       state <= S_ILLEGAL_INST;
                    end

                    resuming = {zz[0], 1'b1};
                    loc <= inst_ptr - 4;
                    inst = rX_[31:0];
                    $display("%06d resuming #%016x:#%08x", $time, inst_ptr - 4, rX_[31:0]);
                    state <= S_IFETCH2;
                 end
              end
           end

/*
             I_FCMP:
             I_FUN:
             I_FEQL:
             I_FADD:
             I_FIX:
             I_FSUB:
             I_FIXU:
             I_FLOT:
             I_FLOTI:
             I_FLOTU:
             I_FLOTUI:
             I_SFLOT:
             I_SFLOTI:
             I_SFLOTU:
             I_SFLOTUI: */

             // 10
/*           I_FMUL:
             I_FCMPE:
             I_FUNE:
             I_FEQLE:
             I_FDIV:
             I_FSQRT:
             I_FREM:
             I_FINT:
 */

           /* I_TRAP: TRAP is handled exactly like an unknown instruction */
           default: begin
              // XXX This is probably not exactly correct...
              if (op == I_TRAP)
                 $display("%06d TRAP %d,%d,%d inst_ptr = #%1x", $time,
                          xx, yy, zz, inst_ptr);
              else
                 $display("%06d Unknown instruction trap %d,%d,%d", $time,
                          xx, yy, zz);
              rWW = inst_ptr;
              rK = 0;
              rBB = g255_readonly_cache;
              /* This depends on f == info_flags[op]!! */
              rXX = {op == I_TRAP || !(f & X_is_dest_bit)
                     ? 32'h80000000  // normal resume from trap
                     : 32'h02000000, // RESUME_SET
                     inst};
              $display("  setting rWW=#%1x, rXX=#%1x", rWW, rXX);
              rYY = y;
              rZZ = z;
              $display("  setting rYY=#%1x, rZZ=#%1x", rYY, rZZ);
              regfile_wraddress <= GLOBAL | 255;
              regfile_wrdata    <= rJ;
              regfile_wren      <= 1;
              inst_ptr = rT;
              state <= S_IFETCH1;
           end
           endcase
        end

      // XXX Yup, don't care nothin' 'bout being fast
      S_MEM1: if (~datamem_wren & ~datamem_rden) begin
         if(V)$display("%06d ME1: No memory op detected, skipping to ME2", $time);
         state <= S_MEM2; // Cheating!
      end else begin
         if(V)$display("%06d *** 1st half of access #%1x & #%1x (W%d,R%d)",
                  $time, datamem_wrdata[63:32], datamem_wrbyteena[7:4],
                  datamem_wren, datamem_rden);

         {datamem_rddata_high,datamem_rddata_low} <= 2'b11;

         // Writing 1st half
         core_transfer_request <= 1;
         core_virt_address <= datamem_addr & ~7;
         core_io_access <= datamem_addr[63:48] == 1;
         if (datamem_rden & datamem_wren) begin
            $display("%06d Wow!", $time);
            error <= 1;
            state <= S_HALTED;
         end
         core_wren   <= datamem_wren;
         core_wrdata <= datamem_wrdata[63:32];
         core_wrmask <= datamem_wrbyteena[7:4];
         state <= S_EXTMEM1;
      end

      // 2nd half
      S_EXTMEM1: if (~core_wait_request) begin
         if(V)$display("%06d *** 2nd half of access #%1x & #%1x", $time,
                  datamem_wrdata[31:0],
                  datamem_wrbyteena[3:0]);

         core_virt_address <= core_virt_address + 4;
         core_wrdata <= datamem_wrdata[31:0];
         core_wrmask <= datamem_wrbyteena[3:0];
         state <= S_EXTMEM2;
      end

      S_EXTMEM2: if (~core_wait_request) begin
         // And we're done XXX Not handling reads very well are we?
         core_transfer_request <= 0;
         state <= S_MEM2;
      end

      S_MEM2: if (datamem_rden & (datamem_rddata_high | datamem_rddata_low)) begin
         if(V)$display("%06d *** Core waiting for read data to arrive", $time);
      end else begin
         if(V)$display("%06d ME2 x = #%1x", $time, x);
         state <= S_MEM3;
         case (op)
         I_ADD, I_ADDI:
            /* Test for overflow which
             "... occurs if and only if y and z have the same sign
             but the sum has a different sign."
             */
            if (~(y[63] ^ z[63]) & (y[63] ^ x[63])) begin
               $display("%06d ** ADD Overflow x[63]=%d y[63]=%d z[63]=%d", $time,
                        x[63], y[63], z[63]);
               exc[V_EXC] = 1;
            end

         I_SUB, I_SUBI, I_NEG, I_NEGI:
            /* Test for overflow which
             "Other cases of signed and unsigned addition and
             subtraction are, of course, similar. Overflow
             occurs in the calculation x = y - z if and only if
             it occurs in the calculation y = x + z."
             */
            if (~(x[63] ^ z[63]) & (x[63] ^ y[63])) begin
               $display("%06d ** SUB Overflow x[63]=%d y[63]=%d z[63]=%d", $time,
                        x[63], y[63], z[63]);
               exc[V_EXC] = 1;
            end

         I_SL, I_SLI:
            if (z > 64 && y)
               // XXX. This is insufficient.  See 87.
               exc[V_EXC] = 1;
            else if (high_shift != {64{y[63]}})
               exc[V_EXC] = 1;

         // 94.
         I_LDB, I_LDBI: begin
            tmpbyte = datamem_rddata >> (8*(7 - datamem_addr[2:0]));
            x = {{56{tmpbyte[7]}},tmpbyte};
            $display("%06d ** LDB [#%1x] -> #%1x", $time, datamem_addr, {{56{tmpbyte[7]}},tmpbyte});
         end

         I_LDBU, I_LDBUI: begin
            tmpbyte = datamem_rddata >> (8*(7 - datamem_addr[2:0]));
            x = {56'd0,tmpbyte};
            $display("%06d ** LDBU [#%1x] -> #%1x", $time, datamem_addr, {56'd0,tmpbyte});
         end

         I_LDW, I_LDWI: begin
            t[15:0] = datamem_rddata >> (16*(3 - datamem_addr[2:1]));
            x = {{48{t[15]}},t[15:0]};
            $display("%06d ** LDW [#%1x] -> #%1x", $time, datamem_addr, {{48{t[15]}},t[15:0]});
         end

         I_LDWU, I_LDWUI: begin
            t[15:0] = datamem_rddata >> (16*(3 - datamem_addr[2:1]));
            x = {48'd0,t[15:0]};
            $display("%06d ** LDWU [#%1x] -> #%1x", $time, datamem_addr, {48'd0,t[15:0]});
         end

         I_LDT, I_LDTI: begin
            $display("%06d *** datamem_rddata = #%1x datamem_addr[2]=%d", $time,
                     datamem_rddata, datamem_addr[2]);
            t[31:0] = datamem_rddata >> (32*(1 - datamem_addr[2]));
            x = {{32{t[31]}},t[31:0]};
            $display("%06d ** LDT [#%1x] -> #%1x", $time, datamem_addr, {{32{t[31]}},t[31:0]});
         end

         I_LDTU, I_LDTUI: begin
            t[31:0] = datamem_rddata >> (32*(1 - datamem_addr[2]));
            x = {32'd0,t[31:0]};
            $display("%06d ** LDTU [#%1x] -> #%1x", $time, datamem_addr, {32'd0,t[31:0]});
         end

         I_LDO, I_LDOI: begin
            x = datamem_rddata;
            $display("%06d ** LDO [#%1x] -> #%1x", $time, datamem_addr, datamem_rddata);
         end

         I_LDOU, I_LDOUI: begin
            x = datamem_rddata;
            $display("%06d ** LDOU [#%1x] -> #%1x", $time, datamem_addr, datamem_rddata);
         end

         I_LDUNC, I_LDUNCI: begin
            x = datamem_rddata;
            $display("%06d ** LDUNC [#%1x] -> #%1x", $time, datamem_addr, datamem_rddata);
         end

         I_LDHT, I_LDHTI: begin
            t[31:0] = datamem_rddata >> (32*(1 - datamem_addr[0]));
            x = {t[31:0],32'd0};
            $display("%06d ** LDHT [#%1x] -> #%1x", $time, datamem_addr, {t[31:0],32'd0});
         end
         endcase
      end // case: S_MEM2

      S_MEM3: state <= S_WB2;

      S_WB2: begin
         state <= S_IFETCH1;
         datamem_rden <= 0;
         datamem_wren <= 0;

         /* XXX Hmm, in which cases do we _not_ commit in presence of exception? */
         /* XXX We should probably make sure all instructions that can
          *     raise an exception pass through here.  What a mess!
          */
         regfile_wraddress <= x_ptr;
         regfile_wrdata    <= x;
         regfile_wren      <= wb;

         // 122. Check for trip interrupt
         if ((exc & (U_BIT + X_BIT)) == U_BIT && !(rA & U_BIT)) exc = exc & ~U_BIT;
         if (exc) begin
            $display("       *** Exception handling %x", exc);
            state <= S_IFETCH1;
            j = exc & (rA | H_BIT); /* find all exceptions that have been enabled */
            if (j) begin
               // 123. Initiate a trip interrupt
               // Priority encoding.  Very expensive!
               rW = inst_ptr;
               if      (j[H_EXC]) begin inst_ptr =   0; exc[H_EXC] = 0; end // Trip
               else if (j[D_EXC]) begin inst_ptr =  16; exc[D_EXC] = 0; end // Integer divide check
               else if (j[V_EXC]) begin inst_ptr =  32; exc[V_EXC] = 0; end // Integer overflow
               else if (j[W_EXC]) begin inst_ptr =  48; exc[W_EXC] = 0; end // float-to-fix overflow
               else if (j[I_EXC]) begin inst_ptr =  64; exc[I_EXC] = 0; end // float invalid op
               else if (j[O_EXC]) begin inst_ptr =  80; exc[O_EXC] = 0; end // float overflow
               else if (j[U_EXC]) begin inst_ptr =  96; exc[U_EXC] = 0; end // float underflow
               else if (j[Z_EXC]) begin inst_ptr = 112; exc[Z_EXC] = 0; end // float div by 0
               else if (j[X_EXC]) begin inst_ptr = 128; exc[X_EXC] = 0; end // float inexact
               /*
                XXX AFAICT, these can never happen??
                else if (j[ 7]) begin inst_ptr = 144; exc[ 7] = 0; end
                else if (j[ 6]) begin inst_ptr = 160; exc[ 6] = 0; end
                else if (j[ 5]) begin inst_ptr = 176; exc[ 5] = 0; end
                else if (j[ 4]) begin inst_ptr = 192; exc[ 4] = 0; end
                else if (j[ 3]) begin inst_ptr = 208; exc[ 3] = 0; end
                else if (j[ 2]) begin inst_ptr = 224; exc[ 2] = 0; end
                else if (j[ 1]) begin inst_ptr = 240; exc[ 1] = 0; end
                else if (j[ 0]) begin inst_ptr = 256; exc[ 0] = 0; end
                */
               rX[63:32] = 32'h80000000;
               rX[31: 0] = inst;
               if ((op & 8'hE0) == I_STB) begin rY = w; rZ = b; end
               else begin rY = y; rZ = z; end
               rB = g255_readonly_cache;
               regfile_wraddress <= GLOBAL | 8'd255;
               regfile_wrdata    <= rJ;
               regfile_wren      <= 1;

               if (op == I_TRIP) begin
                  w = rW;
                  x = rX;
               end
            end
            rA = rA | (exc >> 8);
         end
      end

      S_POP1: state <= S_POP2; // Register file lookup :-(

      S_POP2: begin
         $display("%06d    l[(O + xx - 1) & lring_mask] == l[%1d] = #%x", $time,
                  (O + xx - 1) & lring_mask, regfile_rddata_a);
         $display("%06d    l[(O - 1) & lring_mask] == l[%1d] = #%x", $time,
                  (O - 1) & lring_mask, regfile_rddata_b);
/*
 regfile_rdaddress_a <= (O + xx - 1) & lring_mask;
 regfile_rdaddress_b <= (O - 1) & lring_mask;
*/
         if (xx != 0 && xx <= L) begin
            y = regfile_rddata_a; /* l[(O + xx - 1) & lring_mask] */
            $display("%06d    x=%1d  y=l[%1d]=#%1x", $time,
                     xx, (O + xx - 1) & lring_mask, y);
         end
         if (rS[31:0] == rO[31:0]) begin
            $display("%06d ** 84.  stack_load() not implemented!", $time);
            state <= S_NOT_IMPLEMENTED;
         end
         // k = regfile_rddata_b & 8'hFF; /* l[(O - 1) & lring_mask] */
         $display("%06d    POP k=%1d, O=%1d, S=%1d", $time, regfile_rddata_b[7:0], O, S);
         if (O - S <= regfile_rddata_b[7:0]) begin
            $display("%06d ** 84.  stack_load() not implemented!", $time);
            state <= S_NOT_IMPLEMENTED;
         end
         L = regfile_rddata_b[7:0] + ((xx <= L) ? xx : (L + 1));
         if (L > G) begin
            $display("%06d    L=G %1d", $time, G);
            L = G;
         end
         if (L > regfile_rddata_b[7:0]) begin
            $display("%06d    l[%1d]=#%1x", $time,
                     (O - 1) & lring_mask, y);
            regfile_wraddress <= (O - 1) & lring_mask;
            regfile_wrdata    <= y;
            regfile_wren      <= 1;
         end
         y = rJ;
         inst_ptr = rJ + (yz << 2);
         $display("%06d    rJ = #%1x + (yz << 2) #%1x = #%1x", $time,
                  rJ, (yz << 2), inst_ptr);
         O = O - (regfile_rddata_b[7:0] + 1);
         rO = rO - ((regfile_rddata_b[7:0] + 1) << 3);
         b = rO; // XXX Why?
         rL = L;
         state <= S_WB2;
      end

      S_MULTIPLYING:
         if (mul_b) begin
            $display("%06d ** MUL %d + %d * %d", $time, {mul_aux,mul_acc}, mul_a, mul_b);
/* 1 bit at a time
            if (mul_b[0])
               {mul_aux,mul_acc} <= {mul_aux,mul_acc} + mul_a;
            mul_a <= {mul_a,1'd0};
            mul_b <= mul_b[63:1];
 */
            // 2 bits at a time, worst-case 32-cycles.
            // XXX This can be done cheaper
            {mul_aux,mul_acc} <= {mul_aux,mul_acc} + mul_a * mul_b[1:0];
            mul_a <= {mul_a,2'd0};
            mul_b <= mul_b[63:2];
         end else begin
            if ((op & ~1) == I_MULU)
               rH <= mul_aux;
            else begin
              if (y[63]) mul_aux = mul_aux - z;
              if (z[63]) mul_aux = mul_aux - y;
              // Orig: if (mul_aux[63:32] != mul_aux[31:0] || (mul_aux[63:32] ^ mul_aux[62:0] ^ mul_acc[63])) begin
              if (mul_aux != {64{mul_acc[63]}}) begin
                 $display("%06d ** MUL Overflow", $time);
                 exc[V_EXC] = 1;
              end
            end
            x <= mul_acc;
            state <= S_WB2;
         end

      // Plain Radix-2 restoring division.  SRT would likely be faster
      S_DIVIDING: begin
         $display("%06d ** DIV[U] t=%16x x=%16x", $time, t, x);
         {t,x} = {t,x} << 1;
         diff = t - z; // diff is 65-bit to handle overflow correctly.
         if (~diff[64]) begin
            t = diff;
            x[0] = 1;
         end

         n <= n - 1;
         if (n[6]) begin
            /* Done. Possibly adjust for signed division. */
            case ({y_sign,z_sign})
            2+1: begin
               t = 0 - t;
               if (x[63]) $display("\n***IMPOSSIBLE***\n");
               $display("       2+1: x=%d   t=%d", $signed(x), $signed(t));
            end

            /* 0+0: do nothing */

            2+0: begin
               if (t) begin
                  t = z_abs - t;
                  x = -1 - x;
               end else begin
                  x = 0 - x;
               end
               $display("       2+0: x=%d   t=%d", $signed(x), $signed(t));
            end

            0+1: begin
               if (t) begin
                  t = t - z_abs;
                  x = -1 - x;
               end else begin
                  x = 0 - x;
               end
               $display("       0+1: x=%d   t=%d", $signed(x), $signed(t));
            end
            endcase
            $display("%06d ** DIV[U] t=%16x x=%16x (after sign correction)", $time, t, x);
            rR <= t;
            state <= S_WB2;
         end
      end

      S_MOR: begin
         x = x >> 1;
         x[63] = |(z[7:0] & {t[56],t[48],t[40],t[32],t[24],t[16],t[8],t[0]});
         if (n[2:0] == 3'b111) begin
            t <= y;
            z <= z >> 8;
         end else
            t <= t >> 1;
         n <= n - 1;
         if (n[6])
            state <= S_WB2;
      end

      S_MXOR: begin
         x = x >> 1;
         x[63] = ^(z[7:0] & {t[56],t[48],t[40],t[32],t[24],t[16],t[8],t[0]});
         if (n[2:0] == 3'b111) begin
            t <= y;
            z <= z >> 8;
         end else
            t <= t >> 1;
         n <= n - 1;
         if (n[6])
            state <= S_WB2;
      end

      S_NOT_IMPLEMENTED: begin  // XXX Will disappear eventually
         $display("%06d NOT IMPLEMENTED EXCEPTION", $time); // XXX Do something here
         error <= 3;
         state <= S_HALTED;
      end

      S_ILLEGAL_INST: begin  // XXX Will disappear eventually
         $display("%06d ILLEGAL INSTRUCTION EXCEPTION", $time); // XXX Do something here
         error <= 4;
         state <= S_HALTED;
      end

      S_PRIVILEGED_INST: begin  // XXX Will disappear eventually
         $display("%06d PRIVILEGED EXCEPTION", $time); // XXX Do something here
         error <= 5;
         state <= S_HALTED;
      end

      S_HALTED: begin  // XXX Will disappear eventually
         $display("%06d HALTED", $time);
         // 25 MHz ~ 2^25, blink the error code with roughly 1 Hz.
         // XXX This depends on the surrounding system having
         // something useful here!  My system happens to have a 7 segment display.
         core_transfer_request <= 1;
         core_io_access <= 1;
         core_virt_address <= 32'h24;
         core_wren <= 1;
         core_wrmask <= ~0;
         core_wrdata <= rC[25] ? ~0 : ~error;
         $finish;
      end
      endcase

      /* At the end to overwrite everything else */
      if (reset)
         state <= S_RESET;
   end

   initial $readmemh("info_flags.data", info_flags);
endmodule

// Cheap and dirty segments
// 1 MiB = #10_0000
// #00..00 - #00..3_FFFF -> segment 0 -> SRAM #0_0000 - #3_FFFF
// #20..00 - #20..3_FFFF -> segment 1 -> SRAM #4_0000 - #7_FFFF
// #40..00 - #40..3_FFFF -> segment 2 -> SRAM #8_0000 - #B_FFFF
// #60..00 - #60..3_FFFF -> segment 3 -> SRAM #C_0000 - #F_FFFF
// That is sram_a = {11'd0,core_a[62:61],core_a[18:0]}

module address_virtualization(input  wire        clk
                             ,input  wire [63:0] virt_a
                             ,output wire [31:0] phys_a);
   assign phys_a = virt_a[63] ? virt_a[31:0] :
          {12'd0,virt_a[62:61],virt_a[17:0]};
endmodule