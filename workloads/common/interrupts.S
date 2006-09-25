        .text

/* Handler for TRIP		#0 */
	pushj	255,triphandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception D	#10 integer Divide check */
	pushj	255,excdhandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception V	#20 integer oVerflow */
	pushj	255,excvhandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception W	#30 float-to-fix overfloW */
	pushj	255,excwhandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception I	#40 Invalid operation */
	pushj	255,excihandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception O	#50 floating Overflow */
	pushj	255,excohandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception U	#60 floating Underflow */
	pushj	255,excuhandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception Z	#70 floating division by Zero */
	pushj	255,exczhandler
	put	rJ,$255
	get	$255,rB
	resume
/* Handler for exception X	#80 floating ineXact */
	pushj	255,excxhandler
	put	rJ,$255
	get	$255,rB
	resume

/*	LOC	#10000 */

	.p2align 2
	.global interruptvector

interruptvector:
        pushj	255,1F/* To allocate some free variables */
        put	rJ,$255		/* Restore rJ */
        nxor	$255,$0,$0	/* Set up new interrupt mask (enable all) */
        resume	1

/* Must preserve $255 */
1H	get	$0,rQ		/* Get all pending interrupts */
	subu	$1,$0,1
	and	$2,$0,$1	/* Clears just the highest priority one */
	put	rQ,$2

/* Calculate the index of the highest priority and pass it to the interrupt handler */
        sadd	$0,$1,$0
        jmp	interrupthandler

triphandler	get	$250,rA
                get	$251,rX
                get	$252,rY
                get	$253,rZ
                addu	$250,$251,$252
		pop	0,0
excdhandler	get	$250,rA
		pop	0,0
excvhandler	get	$250,rA
		pop	0,0
excwhandler	get	$250,rA
		pop	0,0
excihandler	get	$250,rA
		pop	0,0
excohandler	get	$250,rA
		pop	0,0
excuhandler	get	$250,rA
		pop	0,0
exczhandler	get	$250,rA
		pop	0,0
excxhandler	get	$250,rA
		pop	0,0

trapvector	pushj	255,traphandler
		put	rJ,$255
		get	$255,rBB
		resume	1


#ifndef USER_TRAPHANDLER
traphandler	pop	0,0
#endif
