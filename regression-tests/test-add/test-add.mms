% This is almost "hello world" simple

% This depends on working TRAP, SETL, CMP, BZ

	LOC	#100

Main	SETL	$0,17
	ADDU	$0,$0,34
	CMP	$0,$0,51
	BZ	$0,2F

	GETA	$255,Fail
1H	TRAP	0,Fputs,StdOut
	TRAP	0,Halt,0

2H	GETA	$255,Pass
	BZ	$0,1B

Pass	BYTE	"Passed",#a,0
Fail	BYTE	"Failed!",#a,0
