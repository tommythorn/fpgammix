module main();
   integer file, ch;
   reg clk = 1;


   always #5 clk <= ~clk;

   always @(posedge clk) begin
      $write("%05d Hello ", $time);
      $strobe("Testing");
      
      $display(" foobar ");
      ch = $fgetc(file);
      $display("<%c>", ch);      
      
   end

   
   initial begin
      file = $fopen("fileio-test.v", "r");

      
      #100 $finish;
      
   end
endmodule // main
