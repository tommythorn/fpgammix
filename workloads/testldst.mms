* Testing STO and LDO

Main LOC   #??
     SETH  $253,Data_Segment>>48
     SETL  $1, 1
     SETL  $2, 2
     SETL  $3, 3
     STO   $1, $253, 0
     STO   $2, $253, 8
     STO   $3, $253, 16

     LDO   $3, $253, 0
     LDO   $1, $253, 8
     LDO   $2, $253, 16

