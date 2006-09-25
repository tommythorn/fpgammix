# 1 "data.c"
! mmixal:= 8H LOC Data_Section
	.text ! mmixal:= 9H LOC 8B
	.p2align 2
	LOC @+(4-@)&3
	.global foo

foo:    get	$1,rJ

	addu	$3,$0,1
	pushj	$2,bar

	put	rJ,$1
	addu	$0,$2,$2
	pop	1,0

	.global initialized
	.data ! mmixal:= 8H LOC 9B
	.p2align 3
	LOC @+(8-@)&7
initialized	IS @
	OCTA	27
	.comm	uninitialized,8,8 ! mmixal-incompatible COMMON
