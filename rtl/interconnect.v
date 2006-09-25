/*              Interconnect support

TODO:
 - Demultiplexing; connecting one master to several targets

   The interesting issue here is arrises  all my targets use
   variable-length pipelined reads, thus multiple outstanding requests
   can result in data arriving back out of order, or even colliding in
   the same cycle.  This can be solved, albeit a bit involved, with
   a FIFO that remembers the order in which data is expected back and
   an overflow FIFO to save data that's not expected yet.

   I'll delay working on this until I start actually having multiple
   outstanding read requests to multiple targets (currently I only
   have either multiple targets [Core -> memory] or multiple requests
   for a single target [Core & framebuffer -> SRAM]).

 - Burst support (may be useful once I start supporting the SDRAM).

Intro
~~~~~

I've rejected WISHBONE as being too low performance.  Altera's Avalon
represents the golden standard for me, but it's _very_ general and
would take much effort to replicate.

For my needs I only need:
- all reads are pipelined
- multi master support
- burst support


Basics
~~~~~~

Master raises transfer_request to initial a transfer.  Slave
asynchronously raises wait_request when it's not ready.  The master is
expected to hold the request and associated parameters stable until
wait goes down.

Example, a master side state machine issuing two requests (no bust)
will look like:

  always @(posedge clock) case (state)
  S1: begin
    ... <parameters> ... <= .... params for 1st req ....
    transfer_request     <= 1;
    state <= S2;
  end

  S2: if (~wait_request) begin
    ... <parameters> ... <= .... params for 1st req ....
    state <= S3;
  end

  S3: if (~wait_request) begin
    transfer_request <= 0;
    ....
  end


Pipelined Reading
~~~~~~~~~~~~~~~~~

Read requests are just like write requests, except that one or more
cycles in the future replies will arrive, in the order issued, raising
data_valid for one cycle for each reply.

Extending the above example, we need a separate state machine
collecting the data as we can't assume anything about how long we will
have to wait in S2.

  always @(posedge clock) begin
    if (data_valid)
      if (waiting_for_1st) begin
        first <= port_read_data;
        waiting_for_1st <= 0;
      end else begin
        second <= port_read_data;
        waiting_for_2nd <= 0;
      end

    case (state)
    S1: begin
      ... <parameters> ... <= .... params for 1st req ....
      transfer_request     <= 1;
      waiting_for_1st      <= 1;
      state <= S2;
    end

    S2: if (~wait_request) begin
      ... <parameters> ... <= .... params for 2nd req ....
      waiting_for_2nd      <= 1;
      state <= S3;
    end

    S3: if (~wait_request) begin
      transfer_request <= 0;
      state <= S4;
    end

    S4: if (~waiting_for_1st & ~waiting_for_2nd) begin
      ... process data
    end
  end


In many cases burst transfers can replace the need for multiple
issues.


Multi Master
~~~~~~~~~~~~

I really like the shared based approach to arbitration that Avalon
has.  Let's see if we can replicate it.

  Constants
    A_SHARES, B_SHARES

  if (transfer_request_a & (shares_left_for_a | ~transfer_request_b))
     go ahead and let A get access
     if (shares_left_for_a == 0)
        shares_left_for_a = A_SHARES
     else
        --shares_left_for_a
  else if (transfer_request_b & (shares_left_for_b | ~transfer_request_a))
     go ahead and let B get access
     if (shares_left_for_b == 0)
        shares_left_for_b = A_SHARES
     else
        --shares_left_for_b
  else // ~transfer_request_a & ~transfer_request_b
     shares_left_for_a = A_SHARES
     shares_left_for_b = A_SHARES
     do nothing else

Puh, not tooo complicated?  Just wait until we throw burst support into the mix.

Also, I failed to show how to support routing the read data back to
theirs masters.  A simple 1-bit FIFO of length A_SHARES + B_SHARES
(??)  should be sufficient.  (Careful about the latency of the FIFO
itself.)  However, the arbitration must know which requests will
result in a reply.  (Should simply all requests result in a reply to
simplify?)


Burst support
~~~~~~~~~~~~~

I haven't found documentation for how Avalon handles this, but it
seems that simply extending the basic strategy with a burst count
should suffice.

Example: lets show the client side for a change (as the master looks
almost exactly the same as for a single request).  This simple client
can only handle one outstanding request at a time, but it does support
bursts.

  wire wait_request = count != 0;

  always @(posedge clock) begin
    pipeline[N:1] <= pipeline[N-1:0];
    pipeline[0] <= 0;
    if (count) begin
      addr <= addr + 1;
      pipeline[0] <= 1;
      count <= count - 1;
    else if (transfer_request) begin
           count <= burst_length;
           addr <= request_addr
    end
  end

(Of course the counting down to -1 and using the sign bit would be
better).


The only extension needed for the arbitration is knowing about the
burst size.
*/

module arbitration
            (input         clock

            // Master port 1
            ,input         transfer_request1
            ,input  [31:0] address1
            ,input         wren1
            ,input  [31:0] wrdata1
            ,input  [ 3:0] wrmask1
            ,output        wait_request1
            ,output        read_data_valid1
            ,output [31:0] read_data1

            // Master port 2
            ,input         transfer_request2
            ,input  [31:0] address2
            ,input         wren2
            ,input  [31:0] wrdata2
            ,input  [ 3:0] wrmask2
            ,output        wait_request2
            ,output        read_data_valid2
            ,output [31:0] read_data2

            // Target port
            ,output        transfer_request
            ,output [31:0] address
            ,output        wren
            ,output [31:0] wrdata
            ,output [ 3:0] wrmask
            ,input         wait_request
            ,input         read_data_valid
            ,input  [31:0] read_data
            );

// My preference, but the others could be provided also as alternative
// arbitration modules.
`define SHARE_BASED 1
`define AVG_RATIO_MODEL 1

   /*
    * Data routing fifo.  Size must cover all potential outstanding
    * transactions.
    */
   parameter   FIFO_SIZE_LG2 = 4;
   parameter   debug = 0;

   reg         data_for_1[(1 << FIFO_SIZE_LG2) - 1:0];
   reg [FIFO_SIZE_LG2-1:0] rp = 0;
   reg [FIFO_SIZE_LG2-1:0] wp = 0;

   wire [FIFO_SIZE_LG2-1:0] wp_next = wp + 1;
   wire [FIFO_SIZE_LG2-1:0] rp_next = rp + 1;

   assign      transfer_request = transfer_request1 | transfer_request2;
   assign      read_data1       = read_data;
   assign      read_data2       = read_data;
   assign      read_data_valid1 = read_data_valid & data_for_1[rp];
   assign      read_data_valid2 = read_data_valid & ~data_for_1[rp];

   wire        en1              = transfer_request1 & ~wait_request1;
   wire        en2              = transfer_request2 & ~wait_request2;
   assign      address          = en1 ? address1 : address2;
   assign      wren             = en1 ? wren1    : wren2;
   assign      wrdata           = en1 ? wrdata1  : wrdata2;
   assign      wrmask           = en1 ? wrmask1  : wrmask2;

   always @(posedge clock) begin
      if ((en1 | en2) & ~wren) begin
         data_for_1[wp] <= en1;
         wp <= wp_next;
         if (wp_next == rp)
           if(debug)$display("%05d ARB: FIFO OVERFLOW! wp: %d rp: %d", $time, wp_next, rp);
         else
           if(debug)$display("%05d ARB: FIFO remembered a read req wp: %d rp: %d", $time, wp_next, rp);
      end

      if (read_data_valid) begin
         rp <= rp_next;
         if (rp == wp)
           if(debug)$display("%05d ARB: FIFO UNDERFLOW! wp: %d rp: %d", $time, wp, rp_next);
         else
           if(debug)$display("%05d ARB: FIFO routed read data wp: %d rp: %d", $time, wp_next, rp);
      end
   end

`ifdef UNFAIR
   /*
    * Quick and unfair arbitration.  Master 1 can quite easily starve
    * out master 2
    */
   assign      wait_request2 = wait_request | transfer_request1;
   assign      wait_request1 = wait_request;
`endif

`ifdef ROUND_ROBIN
   /*
    * Very simple round robin
    */
   reg         current_master = 0;
   assign      wait_request1 = wait_request | transfer_request2 & current_master;
   assign      wait_request2 = wait_request | transfer_request1 & ~current_master;

   always @(posedge clock)
      if (transfer_request1 & transfer_request2 & ~wait_request)
        current_master <= ~current_master;
`endif

`ifdef SHARE_BASED
   /*
    * Share based
    */
   parameter SHARES_1 =  5; // > 0
   parameter SHARES_2 = 10; // > 0
   parameter LIKE_AVALON = 1;

   parameter OVERFLOW_BIT = 6;

   reg         current_master = 0;
   reg [OVERFLOW_BIT:0] countdown = SHARES_1 - 2;
   assign      wait_request1 = wait_request | transfer_request2 & current_master;
   assign      wait_request2 = wait_request | transfer_request1 & ~current_master;

   reg [31:0]  count1 = 1, count2 = 1;

   always @(posedge clock) begin
      if (transfer_request1 | transfer_request2)
        if(debug)
          $display("%05d ARB: Req %d/%d  Arbit %d/%d  W:%d %d (shares left %d, cummulative ratio %f)",
                 $time,
                 transfer_request1, transfer_request2,
                 transfer_request1 & ~wait_request1,
                 transfer_request2 & ~wait_request2,
                 wren1, wren2,
                 countdown + 2,
                 1.0 * count1 / count2);

      /* statistics */
      count1 <= count1 + (transfer_request1 & ~wait_request1);
      count2 <= count2 + (transfer_request2 & ~wait_request2);

`ifdef AVG_RATIO_MODEL
      /* The arbitration is only relevant when two masters try to
       * initiate at the same time.  We swap priorities when the
       * current master runs out of shares.
       *
       * Notice, unlike Avalon, a master does not forfeit its shares if
       * it temporarily skips a request.  IMO this leads to better QOS
       * for a master that initiates on a less frequent rate.
       *
       * In this model, the arbitration tries to approximate a
       * SHARES_1 : SHARE_2 ratio for Master 1 and Master 2
       * transactions (as much as the available requests will allow it).
       */

      if (~wait_request) begin
         if (transfer_request1 | transfer_request2) begin
            countdown <= countdown - 1;
            if (countdown[OVERFLOW_BIT]) begin
               current_master <= ~current_master;
               countdown <= (current_master ? SHARES_1 - 2 : SHARES_2 - 2);
            end
         end
      end
`endif //  `ifdef AVG_RATIO_MODEL

`ifdef WORST_CASE_LATENCY_MODEL
      /*
       * This version tries to be more like Avalon.
       *
       * In this model SHARE_1 essentially defines the worst case time
       * that Master 2 can wait, likewise for SHARE_2.
       */
      if (~wait_request) begin
         if (transfer_request1 & transfer_request2) begin
            countdown <= countdown - 1;
            if (countdown[OVERFLOW_BIT]) begin
               if(debug)$display("Swap priority to master %d", 2 - current_master);
               current_master <= ~current_master;
               countdown <= (current_master ? SHARES_1 - 2 : SHARES_2 - 2);
            end
         end else if (transfer_request1 & current_master) begin
            if(debug)$display("Master 2 forfeits its remaining %d shares", countdown + 2);
            current_master <= 0;
            countdown <= SHARES_1 - 3;
         end else if (transfer_request2 & ~current_master) begin
            if(debug)$display("Master 1 forfeits its remaining %d shares", countdown + 2);
            current_master <= 1;
            countdown <= SHARES_2 - 3;
         end
      end
`endif //  `ifdef WORST_CASE_LATENCY_MODEL
   end
`endif //  `ifdef SHARE_BASED
endmodule


`ifdef TESTING
module master
            (input         clock
            ,output        transfer_request
            ,input         wait_request
            ,input  [31:0] read_data
            ,input         read_data_valid
             );

   parameter ID = 0;
   parameter WAIT_STATES = 0;

   reg  [31:0] state = 0;
   reg         got1  = 0;
   reg  [31:0] no1, no2;

   reg         transfer_request = 0;

   always @(posedge clock) begin
      case (state)
        0:begin
           if(0)$display("%05d Master%1d state 0", $time, ID);
           transfer_request <= 1;
           state <= 1;
        end

        1:if (~wait_request) begin
             state <= 2;
             if(0)$display("%05d Master%1d scored", $time, ID);
          end

        2:if (~wait_request) begin
             if(0)$display("%05d Master%1d scored again", $time, ID);
             if (WAIT_STATES == 0)
               state <= 1;
             else begin
                transfer_request <= 0;
                state <= (WAIT_STATES <= 1) ? 0 : 3;
             end
          end

        3: state <= (WAIT_STATES <= 2) ? 0 : 4;

        4: state <= 0;
      endcase

      if (read_data_valid) begin
         got1 <= ~got1;
         if (got1) begin
            no2 <= read_data;
            if(0)$display("%05d                     Master%1d got data for no2: %x", $time, ID, read_data);
         end else begin
            no1 <= read_data;
            if(0)$display("%05d                     Master%1d got data for no1: %x", $time, ID, read_data);
         end
      end
   end

endmodule

/*
 * Trivial target that returns serial numbers.  To make it interesting
 * it takes two cycles (thus one wait state) to accept a request and
 * delivers the reply five cycles later.
 */
module target
            (input         clock
            ,input         transfer_request
            ,output        wait_request
            ,output [31:0] read_data
            ,output        read_data_valid
            );

   parameter NOWAIT = 1;
   parameter LATENCY = 5; // >= 0

   reg        got_request;
   reg [32:0] read_data_pipeline [4:0];
   reg [31:0] serial_no  = 0;

   assign     wait_request = transfer_request & ~got_request;
   assign     {read_data_valid,read_data} = read_data_pipeline[LATENCY-1];

   always @(posedge clock) begin
      serial_no <= serial_no + 1;
      read_data_pipeline[0] <= 33'd0;
      read_data_pipeline[1] <= read_data_pipeline[0];
      read_data_pipeline[2] <= read_data_pipeline[1];
      read_data_pipeline[3] <= read_data_pipeline[2];
      read_data_pipeline[4] <= read_data_pipeline[3];

      got_request <= NOWAIT | transfer_request & ~got_request;

      if (got_request & transfer_request) begin
        read_data_pipeline[0] <= {1'd1, serial_no};
         if(0)$display("%05d Target got a request", $time);
      end
   end
endmodule

/* Multi master */
module main();
   reg         clock = 1;
   always # 5  clock = ~clock;

   wire        transfer_request, wait_request, read_data_valid;
   wire [31:0] read_data;
   wire        transfer_request1, wait_request1, read_data_valid1;
   wire [31:0] read_data1;
   wire        transfer_request2, wait_request2, read_data_valid2;
   wire [31:0] read_data2;

   arbitation arbitation_inst
     (clock
     ,transfer_request
     ,wait_request
     ,read_data
     ,read_data_valid

     ,transfer_request1
     ,wait_request1
     ,read_data1
     ,read_data_valid1

     ,transfer_request2
     ,wait_request2
     ,read_data2
     ,read_data_valid2
     );

   target target_inst
     (clock
     ,transfer_request
     ,wait_request
     ,read_data
     ,read_data_valid
     );

   master #(1, 0) master1
     (clock
     ,transfer_request1
     ,wait_request1
     ,read_data1
     ,read_data_valid1
     );

   master #(2, 2) master2
     (clock
     ,transfer_request2
     ,wait_request2
     ,read_data2
     ,read_data_valid2
     );

   initial #400000 $finish;
endmodule

`ifdef MAIN_SIMPLE
module main_simple();
   reg         clock = 1;
   always # 5  clock = ~clock;

   wire        transfer_request, wait_request, read_data_valid;
   wire [31:0] read_data;

   target target_inst
     (clock
     ,transfer_request
     ,wait_request
     ,read_data
     ,read_data_valid
     );

   master #(1) master_inst
     (clock
     ,transfer_request
     ,wait_request
     ,read_data
     ,read_data_valid
     );
endmodule
`endif

`endif