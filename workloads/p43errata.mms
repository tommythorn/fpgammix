        LOC     #250

Main	SETL  $10,6

        SET   $0,$10
	SUBU  $1,$0,1
	XOR   $2,$0,$1
	ANDN  $1,$0,$1
	SADD  $2,$2,0

New     SET   $0,$10
	SUBU  $1,$0,1
	SADD  $2,$1,$0
	ANDN  $1,$0,$1

