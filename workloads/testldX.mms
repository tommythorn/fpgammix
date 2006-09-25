% Rudimentary test of LDXX instructions
	LOC	Data_Segment
Tmp	OCTA	0

a	GREG
n	GREG
x	GREG

	LOC	#100
Main	SETH	n,#FEDC
	INCMH	n,#BA98
	INCML	n,#7654
	INCL	n,#3210

	SETH	a,Tmp>>48
	STO	n,a,0
	LDB	x,a,0
	LDB	x,a,2
	LDB	x,a,5
	LDBU	x,a,0
	LDBU	x,a,2
	LDBU	x,a,5
	LDW	x,a,0
	LDW	x,a,2
	LDW	x,a,5
	LDWU	x,a,0
	LDWU	x,a,2
	LDWU	x,a,5
	LDT	x,a,0
	LDT	x,a,2
	LDT	x,a,5
	LDTU	x,a,0
	LDTU	x,a,2
	LDTU	x,a,5
	LDHT	x,a,0
	LDHT	x,a,2
	LDHT	x,a,9
	TRAP	0,Halt,0
