# 1 "div.c"
! mmixal:= 8H LOC Data_Section
	.text ! mmixal:= 9H LOC 8B
	.p2align 2
	LOC	@+(4-@)&3
	.global main
main	IS	@
	SETL	$0,#6c1
	STT	$0,foo
	SETL	$3,#1
	SET	$1,$0
L:2	IS	@
	SL	$0,$1,2
	ADD	$2,$0,$1
	SET	$1,$2
	ADD	$0,$3,1
	SET	$3,$0
	SL	$0,$0,32
	SR	$0,$0,32
	CMP	$0,$0,10
	PBNZ	$0,L:2
	STT	$2,foo
	POP	1,0

	.comm	foo,4,4 ! mmixal-incompatible COMMON
	.data ! mmixal:= 8H LOC 9B
