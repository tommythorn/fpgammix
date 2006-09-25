/*
 * TODO: optimize for multiple writes in sequence
 */

module memory_interface
  (clkin,
   fse_a, fse_d,
   flash_cs_n, enet_aen,
   sram_cs_n, sram_be_n, sram_oe_n, sram_we_n,

   transfer_request,
   address,
   wren,
   wrdata,
   wrmask,
   wait_request,
   read_data_valid,
   read_data);

   parameter debug = 0;

   input  wire        clkin;

   // Flash-SRAM-Ethernet bus
   output reg  [22:0] fse_a;        // Mainboard common bus address
   inout  wire [31:0] fse_d;        // Mainboard common bus data
   output wire        flash_cs_n;   // Flash ROM CS#
   output wire        enet_aen;     // Ethernet Access Enable
   output wire        sram_cs_n;    // SRAM CS#
   output reg   [3:0] sram_be_n;    // SRAM byte enables
   output wire        sram_oe_n;    // SRAM OE#
   output wire        sram_we_n;    // SRAM WE#

   // Interface
   input  wire        transfer_request;
   input  wire [31:0] address;
   input  wire        wren;
   input  wire [31:0] wrdata;
   input  wire [ 3:0] wrmask;

   output wire        wait_request;
   output wire        read_data_valid;
//   output reg  [31:0] read_data;
   output wire [31:0] read_data;  // XXX a bit reckless!

   parameter N            = 4;                   // 0  1  2  3  4  5
   parameter MAX_CYCLES   = (1 << (N - 1)) - 1;  // X  0  1  3  7 15

   /*
    * @ 200MHz/5ns the address must be asserted for two cycles but
    * apparently that isn't enough...
    */
   parameter READ_CYCLES  = 0; // 25MHz
   parameter LATENCY      = 1; // data is ready LATENCY cycles from accepted request

   /* How many cycles to assert the data and address
    * *while* writing, that is, not counting setup and teardown
    */
   parameter WRITE_CYCLES = 1; // 25MHz

   parameter IDLE                  = 0;
   parameter READ                  = 1;
   parameter WRITE_PREPARE         = 2;
   parameter WRITE_DO              = 3;
   parameter DELAY_WRITE           = 4;

   // Encode {cs_n,oe_n,we_n} as a command
   parameter SRAM_CMD_READ     = 3'b001;  // 'h1
   parameter SRAM_CMD_WRITE    = 3'b010;  // 'h2
   parameter SRAM_CMD_PRE_WRITE= 3'b011;  // 'h3
   parameter SRAM_CMD_NOP      = 3'b111;  // 'h7

   reg  [31:0] state = IDLE;
   reg  [31:0] fse_d_out;
   reg  [ N:0] countdown;
   reg  [ 2:0] sram_cmd;
   reg  [LATENCY:0] read_data_pipeline;
   /* XXX really should be LATENCY-1 but then the read_data_pipeline assignment
    * below fails for LATENCY == 1  It doesn't really affect anything
    */

   assign          flash_cs_n                       = 1'b1;  // Disable flash ROM
   assign          enet_aen                         = 1'b1;  // Disable Ethernet
   assign          {sram_cs_n,sram_oe_n,sram_we_n}  = sram_cmd;
   assign          fse_d                            = sram_oe_n ? fse_d_out : 32'hZZZZZZZZ;

   assign          wait_request = state != IDLE;
   assign          read_data_valid = read_data_pipeline[LATENCY-1];
   assign          read_data = fse_d;

   integer         i;
   always @(posedge clkin) begin
      //read_data             <= fse_d;
      //if(debug)$display("%06d MI: fse_d %x", $time, fse_d);
      countdown             <= countdown - 1;
      read_data_pipeline    <= {read_data_pipeline[LATENCY-1:0], 1'b0};

      if (read_data_valid)
        if(debug)$display("%06d MI: read data %x", $time, read_data);

      case (state)
      IDLE: begin
         sram_cmd <= SRAM_CMD_READ;

         if (transfer_request)
            if (~wren) begin
               if(debug)$display("%06d MI: got a read command for address %x", $time, address);
               fse_a <= address; // XXX Notice, only 20-bit are valid for SRAM (18 if aligned)
               sram_be_n <= 0;
               if (READ_CYCLES) begin
                  countdown <= READ_CYCLES - 2; // These underflow downcounters always use T - 2
                  state     <= READ;
               end else begin
                  // I _can_ run @100+ MHz with a ~ 25 ns latency (strange)
                  read_data_pipeline[0] <= 1;
               end
            end else begin
               if(debug)$display("%06d MI: got a write command for address %x <- %x mask %x", $time, address, wrdata, wrmask);
               fse_a <= address; // Notice, only 18-bit are valid for SRAM
               fse_d_out <= wrdata;
               sram_be_n <= ~wrmask;
               if (|read_data_pipeline) begin
                 /* If there is an outstanding read command we have to wait
                  for it to finish */
                 state <= DELAY_WRITE;
               end else begin
                  sram_cmd  <= SRAM_CMD_PRE_WRITE;
                  state     <= WRITE_PREPARE;
            end
         end
      end // case: IDLE

      READ: if (countdown[N]) begin
         read_data_pipeline[0] <= 1;
         state                 <= IDLE;
      end

      DELAY_WRITE: if (~|read_data_pipeline) begin
         sram_cmd  <= SRAM_CMD_PRE_WRITE;
         state     <= WRITE_PREPARE;
      end

      WRITE_PREPARE: begin
         sram_cmd  <= SRAM_CMD_WRITE;
         countdown <= WRITE_CYCLES - 2;// These underflow downcounters always use T - 2
         state     <= WRITE_DO;
      end

      WRITE_DO: if (countdown[N]) begin
         if(debug)$display("%06d MI: done writing", $time);
         sram_cmd <= SRAM_CMD_PRE_WRITE;
         state    <= IDLE;
      end
      endcase
   end
endmodule
