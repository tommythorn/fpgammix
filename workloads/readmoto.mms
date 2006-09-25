! Boot loader, reading srec

!#define IOSPACE	$253
!#define SUM	$252
!#define ERROR   $251

IOSPACE	GREG
SUM	GREG
ERROR   GREG
InputText   GREG

	.text
	.p2align 2
        .global main

	LOC	#80000000
Main	IS      @
        SETH	IOSPACE,1
        GETA    InputText,SampleInput

Loop    IS      @
        SETL    ERROR,0
        GETA    $1,WelcomeText
        PUSHJ   $0,Puts
        PUSHJ   $0,Getch
        CMP     $0,$0,'S'
        BNZ     $0,Loop

        PUSHJ   $0,Getdigit
! $0 is type
        CMP     $1,$0,1
        BZ      $1,Loop1
        CMP     $1,$0,9
        BNZ     $1,Loop

Loop1   IS      @
        SETL    SUM,0
        PUSHJ   $1,Get2digits
! $1 is count
        PUSHJ   $2,Get4digits
! $2 is address

! Adjust for the already read 2 address bytes and the final checksum
        SUBU    $1,$1,3
! Skip if no data is expected
        BZ      $1,Loop9

! data loop
Loop2   IS      @
        PUSHJ   $3,Get2digits
        BNZ     ERROR,HandleError

        STBU    $3,$2,0
        ADDU    $2,$2,1

        SUBU    $1,$1,1
        BNZ     $1,Loop2

! Check the checksum
Loop9   IS      @
        PUSHJ   $3,Get2digits
        AND     $3,$3,255
        CMP     $3,$3,255
        BNZ     $3,HandleChecksumError

        CMP     $1,$0,1
        BZ      $1,Loop11

        PUSHGO  $0,$2

Loop11  IS      @
        SETL    $1,'.'
        PUSHJ   $0,Putch
        JMP     Loop

HandleChecksumError IS      @
        GETA    $1,ChecksumErrorText
        PUSHJ   $0,Puts
        JMP     Loop

HandleError IS      @
        GETA    $1,ErrorText
        PUSHJ   $0,Puts
        JMP     Loop

        LOC  (@+3)&-4
ChecksumErrorText IS      @
        BYTE    "Checksum Error, skipping",#0D,#0A,#0

        LOC  (@+3)&-4
ErrorText IS      @
        BYTE    "Error, skipping",#0D,#0A,#0

	LOC  (@+3)&-4
WelcomeText IS      @
        BYTE    "$ ",#0

	LOC  (@+3)&-4
SampleInput IS	@
        BYTE    "askldS10D299020000000000000A843002E",#0D,#0A
        BYTE	"S90301807B",#0D,#0A

        LOC  (@+3)&-4
Putch	IS      @
        LDTU	$1,IOSPACE,4
	PBOD	$1,Putch
	STBU	$0,IOSPACE,7
	POP	0,0


! $0 address, $1 ret addr, $3 out param
Puts    IS      @
	GET	$1,rJ
        LDBU    $3,$0,0
        BZ      $3,Puts1
Puts2   IS      @
        PUSHJ   $2,Putch
        ADD     $0,$0,1
        LDBU    $3,$0,0
        BNZ     $3,Puts2
Puts1   IS      @
        PUT     rJ,$1
        POP     0,0


Getch	IS      @
        LDT	$0,IOSPACE,12
	PBN	$0,Getch
	POP	1,0

! Getch   IS      @ ! fake
!         LDBU    $0,InputText,0
!         ADDU    InputText,InputText,1
!         POP     1,0

Getdigit IS      @
        BNZ     ERROR,Fail
	GET     $0,rJ
        PUSHJ   $1,Getch
        CMP     $2,$1,'0'
        BN      $2,Fail
        CMP     $2,$1,'9'+1
        BNN     $2,Getdigit1
	PUT     rJ,$0
        SUB     $0,$1,'0'
        POP     1,0
Getdigit1 IS      @
        CMP     $2,$1,'A'
        BN      $2,Fail
        CMP     $2,$1,'F'+1
        BNN     $2,Fail
	PUT     rJ,$0
        SUBU    $0,$1,'A'-10
        POP     1,0
Fail    IS      @
        SETL    ERROR,1
	PUT     rJ,$0
        POP     0,0

Get2digits IS      @
	GET     $0,rJ
        PUSHJ   $1,Getdigit
        PUSHJ   $2,Getdigit
	PUT     rJ,$0
        16ADDU  $0,$1,$2
        ADDU	SUM,SUM,$0
        POP     1,0

Get4digits IS      @
	GET     $0,rJ
        PUSHJ   $1,Get2digits
        SLU     $1,$1,8
        PUSHJ   $2,Get2digits
	PUT     rJ,$0
        ADDU    $0,$1,$2
        POP     1,0

