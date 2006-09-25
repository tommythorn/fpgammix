module pdm(clk, level, O);

   parameter N = 16;  /* The resolution in bits */


   input     wire         clk;
   input     wire [N-1:0] level;
   output    wire          O;

   /*
    * A completely ridiculous side project.  Pulse Density Modulation
    * for controlling led intensity.  The theory is pretty simple:
    * given a desired target level 0 <= T <= 1, control the output O
    * in {1,0}, such that O on on average is T.  Do this by
    * integrating the error T - O over time and switching O such that
    * the sum of (T - O) is finite.
    *
    * S = 0, O = 0
    * forever
    *   S = S + (T - O)
    *   if (S >= 0)
    *      O = 1
    *   else
    *      O = 0
    *
    * Check: T=0, O is never turned on; T=1, O is always on; T=0.5, O toggles
    *
    * In fixed point arithmetic this becomes even simpler (assume N-bit arith)
    * S = Sf * 2^N = Sf << N.  As |S| <= 1, N+2 bits is sufficient
    *
    * S = 0, O = 0
    * forever
    *   D = T + (~O + 1) << N === T + (O << N) + (O << (N+1))
    *   S = S + D
    *   O = 1 & ~(S >> (N+1))
    */

   reg [N+1:0] sigma = 0;
   assign O = ~sigma[N+1];
   always @(posedge clk) sigma <= sigma + {O,O,level};
endmodule // pdm
