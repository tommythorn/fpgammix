* Fibonacci subroutines (exercise 1.4.1--13)

    LOC   #100
Main SET   $1,7
     PUSHJ $0,Fib
     TRAP  0,0,0

Fib CMP   $1,$0,2
    PBN   $1,1F
    GET   $1,rJ
    SUB   $3,$0,1
    PUSHJ $2,Fib   $2=F_{n-1}
    SUB   $4,$0,2
    PUSHJ $3,Fib   $3=F_{n-2}
    ADDU  $0,$2,$3
    PUT   rJ,$1
1H  POP   1,0

