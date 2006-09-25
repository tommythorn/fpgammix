#define IOSPACE $250
        .text

/*	LOC	#10000 */

Main:   seth	IOSPACE,1		/* IOSPACE pointer */
        setl	$0,interruptvector
        put	rTT,$0
        setl	$0,#FFFF
	put	rK,$0
	get	$0,rK

        setl	$0,100
        put	rI,$0

loop:   addu	$255,$255,1
        jmp	loop

#if 0
interruptvector:
        setl	$255,0
        put	rQ,$255
        setl	$255,100
        put	rI,$255
        nxor	$255,$255,$255
        resume	1
#else

interruptvector:
        pushj	255,interrupthandler/* To allocate some free variables */
        put	rJ,$255		/* Restore rJ */
        nxor	$255,$0,$0	/* Set up new interrupt mask (enable all) */
        resume	1

/* Must preserve $255 */
interrupthandler:
	get	$0,rQ		/* All pending interrupts */
	subu	$1,$0,1		/* This and the following ... */
        sadd	$2,$1,$0	/* ... calculates the index of the highest priority */
	and	$0,$0,$1	/* Clears just the highest priority one */
	put	rQ,$0

        setl	$0,100
        put	rI,$0

       	addu	$2,$2,'A'
       	stbu	$2,IOSPACE	/* Do something with the index */
       	pop	0,0
#endif