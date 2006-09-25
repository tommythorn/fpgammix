		.text

/*
A long struggle to get the answer: Yes, my proglet is correct and this
is how it's supposed to behave.

Committing 8000000000005010: 1efffefd(trap) y=6c1 z=13 b=8000000000005024* x=0!g[255] a=8000000000005024!rBB int=F state=1
 setting rWW=8000000000005014, rXX=20000001efffefd
 setting rYY=6c1, rZZ=13

So far so good, entering the trap handler

Committing 8000000000005024: f2ff0006(st)+ y=6000000000000000 z=300000000 b=1 x=1!m[300000000] state=14
Committing 8000000000005024: f2ff0006(pushj) y=8000000000005028 z=800000000000503c x=ff!l[255] a=8000000000005028!rJ rL=0!rL state=1
Committing 800000000000503c: fe00001d(st)+ y=6000000000000008 z=300000008 b=4000000000000008 x=4000000000000008!m[300000008] state=14
Committing 800000000000503c: fe00001d(incrl)+ x=0!l[0] rL=1!rL state=1
Committing 800000000000503c: fe00001d(get) z=20000001efffefd x=20000001efffefd!l[0] state=1
Committing 8000000000005040: 3f010038(st)+ y=6000000000000010 z=300000010 x=0!m[300000010] state=14
Committing 8000000000005040: 3f010038(incrl)+ x=0!l[1] rL=2!rL state=1
Committing 8000000000005040: 3f010038(sh) y=20000001efffefd z=38 x=2!l[1] state=3
Committing 8000000000005044: 31010102(cmp) y=2 z=2 x=0!l[1] state=3
Committing 8000000000005048: 4a010006(br) y=800000000000504c z=8000000000005060 b=0* x=400000003? state=1
Committing 800000000000504c: 3f000018(sh) y=20000001efffefd z=18 x=20000001e!l[0] state=3
Committing 8000000000005050: c90100fc(and) y=20000001e z=fc x=1c!l[1] state=3
Committing 8000000000005054: 3101011c(cmp) y=1c z=1c x=0!l[1] state=3
Committing 8000000000005058: 42010004(br) y=800000000000505c z=8000000000005068 b=0* x=400000000? ->8000000000005068 state=1
Committing 8000000000005068: fe00001e(get) z=6c1 x=6c1!l[0] state=1
Committing 800000000000506c: fe01001f(get) z=13 x=13!l[1] state=1

Here's our fake patch-up

Committing 8000000000005070: 20000001(add) y=6c1 z=13 rA=0 x=6d4!l[0] state=3

... which we store in rX

Committing 8000000000005074: f61f0000(put) z=6d4 x=6d4!rZZ state=1
Committing 8000000000005078: f8000000(ld)+ y=6000000000000010 z=300000010 x=0!l[2] state=13
Committing 8000000000005078: f8000000(ld)+ y=6000000000000008 z=300000008 x=4000000000000008!l[1] state=13
Committing 8000000000005078: f8000000(ld)+ y=6000000000000000 z=300000000 x=1!l[0] state=13
Committing 8000000000005078: f8000000(pop) y=8000000000005028 b=8000000000005028* rL=ff!rL ->8000000000005028 rS=c00000000000000 rO=c00000000000100 state=1
Committing 8000000000005028: f60400ff(put) x=0!rJ state=1
Committing 800000000000502c: e3ff0000(set) x=0!g[255] state=3

... and resume

Committing 8000000000005030: f9020001(resum)
                             b=2000000e0ff0000
                             x=8000000000005024!g[255]
                             a=0!rK ->8000000000005014 state=1

Notice how the instruction executed at #5010 isn't the DIVU above
(#1efffefd) but the fake ORI inserted by the resume instruction.

Committing 8000000000005010: e0ff0000(set) y=6c1 z=6d4 rA=0 x=6d4!g[255] state=3

And we proceed.

Committing 8000000000005014: e7ff1234(addu) y=6d4 z=1234 x=1908!g[255] state=3
        */
                .global	Main
Main:		geta	$255,traphandler
        	put	rT,$255
        	setl	$254,1729
        	setl	$253,19
        	divu	$255,$254,$253
                incl	$255,#1234
        	trap	0,0,0

                swym
                swym

traphandler: 	pushj	255,1F
		put	rJ,$255
        	setl	$255,0
		resume	1

                swym
                swym

1H		get	$0,rXX
        	sru	$1,$0,56
        	cmp	$1,$1,#02
                bnz	$1,2F

                sru	$0,$0,24
                and	$1,$0,#FC
                cmp	$1,$1,#1C
                bz	$1,3F

% Unknown trap
		pop	0,0

% Ordinary trap ("system call") handling
2H		swym
        	pop	0,0


% Div[u][i] emulation
3H		get     $0,rJ
                get	$2,rXX
                get	$3,rYY
        	get	$4,rZZ
                pushj	$1,div_emulation
        	put	rZZ,$1
                put	rJ,$0
        	pop	0,0

div_emulation	add	$0,$1,$2
        	pop	1,0
