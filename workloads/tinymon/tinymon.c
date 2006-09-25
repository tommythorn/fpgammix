/*
  I figured it would be easier to write the assembly if I had a
  working model in C first ...

  Take 2: I discovered late that Motorola's SREC is a poor fit as it
  doesn't support 64-bit addresses, so plan B is to simply parse the
  output of objdump -s.  It wasn't a complete waste as much of the C
  and assembly code can be reused.

  For reference, this is what such output might look like:



hwfb.elf:     file format elf64-mmix

Contents of section .init:
 0100 fe000004 f2010003 e3ff00ff 00000000  ................
 0110 e3011934 e6010000 e5010000 e4010000  ...4............
 0120 e3ff03a8 e6ff0000 e5ff0000 e4ff0000  ................
 0130 bf00ff00 e3ff0244 e6ff0000 e5ff0000  .......D........
 0140 e4ff0000 bf01ff00 f6040000 e3ff18f8  ................
 0150 e6ff0000 e5ff0000 e4ff0000 bf01ff00  ................
 0160 f6040000 f4ff0003 f60400ff f8000000  ................
 0170 f6040000 f8000000                    ........        
Contents of section .text:
 0178 60000000 00000000 e3ff0020 f61300ff  `.......... ....
 0188 f5fffffc 8ffeff00 83ff0100 83ff0101  ................
...
 2000000000001000 00000000 00000000 00000000 00000000  ................
 2000000000001010 00000000 00000000 00000000 00000000  ................
Contents of section .MMIX.reg_contents:
 0790 00000000 00002990 20000000 00000000  ......). .......
 07a0 20000000 000007c0 20000000 00000fd0   ....... .......
 07b0 40000000 00000000 00000000 00000000  @...............
 07c0 00000000 00000000 00000000 00000000  ................
 07d0 00000000 00000000 00000000 00000000  ................
 07e0 00000000 00000000 00000000 00000000  ................
 07f0 00000000 00000000                    ........        
 */

#ifndef __MMIX__
#  include <stdint.h>
#  include <stdio.h>
#  include <stdlib.h>
char lookahead;
typedef int INT;
#  define store(v, address) printf("[%08lx] <- %08lx\n", address, v)


#else


typedef long long unsigned uint64_t;
typedef long int INT;

/* Carefully inspect the assembly after each change as this code is very fragile */

register volatile int *IOSPACE   asm("$245");
register INT           lookahead asm("$246");

#define reg(n) register unsigned long g##n asm("$"#n)

/*
reg(32); reg(33); reg(34); reg(35); reg(36); reg(37); reg(38); reg(39);
reg(40); reg(41); reg(42); reg(43); reg(44); reg(45); reg(46); reg(47); reg(48); reg(49);
reg(50); reg(51); reg(52); reg(53); reg(54); reg(55); reg(56); reg(57); reg(58); reg(59);
reg(60); reg(61); reg(62); reg(63); reg(64); reg(65); reg(66); reg(67); reg(68); reg(69);
reg(70); reg(71); reg(72); reg(73); reg(74); reg(75); reg(76); reg(77); reg(78); reg(79);
reg(80); reg(81); reg(82); reg(83); reg(84); reg(85); reg(86); reg(87); reg(88); reg(89);
reg(90); reg(91); reg(92); reg(93); reg(94); reg(95); reg(96); reg(97); reg(98); reg(99);
reg(100); reg(101); reg(102); reg(103); reg(104); reg(105); reg(106); reg(107); reg(108); reg(109);
reg(110); reg(111); reg(112); reg(113); reg(114); reg(115); reg(116); reg(117); reg(118); reg(119);
reg(120); reg(121); reg(122); reg(123); reg(124); reg(125); reg(126); reg(127); reg(128); reg(129);
reg(130); reg(131); reg(132); reg(133); reg(134); reg(135); reg(136); reg(137); reg(138); reg(139);
reg(140); reg(141); reg(142); reg(143); reg(144); reg(145); reg(146); reg(147); reg(148); reg(149);
reg(150); reg(151); reg(152); reg(153); reg(154); reg(155); reg(156); reg(157); reg(158); reg(159);
reg(160); reg(161); reg(162); reg(163); reg(164); reg(165); reg(166); reg(167); reg(168); reg(169);
reg(170); reg(171); reg(172); reg(173); reg(174); reg(175); reg(176); reg(177); reg(178); reg(179);
reg(180); reg(181); reg(182); reg(183); reg(184); reg(185); reg(186); reg(187); reg(188); reg(189);
reg(190); reg(191); reg(192); reg(193); reg(194); reg(195); reg(196); reg(197); reg(198); reg(199);
reg(200); reg(201); reg(202); reg(203); reg(204); reg(205); reg(206); reg(207); reg(208); reg(209);
reg(210); reg(211); reg(212); reg(213); reg(214); reg(215); reg(216); reg(217); reg(218); reg(219);
reg(220); reg(221); reg(222); reg(223); reg(224); */ reg(225); reg(226); reg(227); reg(228);
reg(229);
reg(230);
reg(231);
reg(232);
reg(233);
reg(234);
reg(235);
reg(236);
reg(237);
reg(238);
reg(239);
reg(240);
reg(241);
reg(242);
reg(243);
reg(244);
/*reg(245);*/
#define g245 IOSPACE
/*reg(246);*/
#define g246 lookahead

reg(247);
reg(248);
reg(249);
reg(250);
reg(251);
reg(252);
reg(253);
reg(254);
reg(255);

#  define store(v, address) *(unsigned *) address = v

void putch(INT ch)
{
        while (IOSPACE[1])
                ;
        IOSPACE[0] = ch;
}
#endif

static inline void nextchar(void)
{
#ifndef __MMIX__
        lookahead = getchar();
        if (lookahead < 0)
                exit(0);
        putchar(lookahead);
#else
        do {
                lookahead = IOSPACE[3];
        } while (lookahead < 0);
        //putch(lookahead);
#endif
}

static inline INT digit(void)
{
        INT res;

        if ('0' <= lookahead && lookahead <= '9')
                res = lookahead - '0';
        else if ('a' <= lookahead && lookahead <= 'f')
                res = lookahead - 'a' + 10;
        else if ('A' <= lookahead && lookahead <= 'F')
                res = lookahead - 'A' + 10;
        else
                return -1;

        nextchar();
        return res;
}

int
main()
{
 restart:

#ifdef __MMIX__
        IOSPACE = (int*) 0x1000000000000ULL;
#endif

        putch('O');
        putch('k');
        putch('\r');
        putch('\n');

        nextchar();

        for (;;) {
                uint64_t address, v;
                INT i, d;

                if (lookahead != ' ')
                        goto skip;

                for (i = 0; i < 5; ++i) {
                        nextchar();
                        v = digit();
                        if (v < 0)
                                break;

                        for (;;) {
                                d = digit();
                                if (d < 0)
                                        break;
                                v = v * 16 + d;
                        }

                        if (i == 0) {
                                address = v;
                                if (lookahead == 'G') {
                                        putch('G');
                                        putch('o');
                                        putch('\r');
                                        putch('\n');
/*
g32 = ((unsigned long *) 0)[32];
g33 = ((unsigned long *) 0)[33];
g34 = ((unsigned long *) 0)[34];
g35 = ((unsigned long *) 0)[35];
g36 = ((unsigned long *) 0)[36];
g37 = ((unsigned long *) 0)[37];
g38 = ((unsigned long *) 0)[38];
g39 = ((unsigned long *) 0)[39];
g40 = ((unsigned long *) 0)[40];
g41 = ((unsigned long *) 0)[41];
g42 = ((unsigned long *) 0)[42];
g43 = ((unsigned long *) 0)[43];
g44 = ((unsigned long *) 0)[44];
g45 = ((unsigned long *) 0)[45];
g46 = ((unsigned long *) 0)[46];
g47 = ((unsigned long *) 0)[47];
g48 = ((unsigned long *) 0)[48];
g49 = ((unsigned long *) 0)[49];
g50 = ((unsigned long *) 0)[50];
g51 = ((unsigned long *) 0)[51];
g52 = ((unsigned long *) 0)[52];
g53 = ((unsigned long *) 0)[53];
g54 = ((unsigned long *) 0)[54];
g55 = ((unsigned long *) 0)[55];
g56 = ((unsigned long *) 0)[56];
g57 = ((unsigned long *) 0)[57];
g58 = ((unsigned long *) 0)[58];
g59 = ((unsigned long *) 0)[59];
g60 = ((unsigned long *) 0)[60];
g61 = ((unsigned long *) 0)[61];
g62 = ((unsigned long *) 0)[62];
g63 = ((unsigned long *) 0)[63];
g64 = ((unsigned long *) 0)[64];
g65 = ((unsigned long *) 0)[65];
g66 = ((unsigned long *) 0)[66];
g67 = ((unsigned long *) 0)[67];
g68 = ((unsigned long *) 0)[68];
g69 = ((unsigned long *) 0)[69];
g70 = ((unsigned long *) 0)[70];
g71 = ((unsigned long *) 0)[71];
g72 = ((unsigned long *) 0)[72];
g73 = ((unsigned long *) 0)[73];
g74 = ((unsigned long *) 0)[74];
g75 = ((unsigned long *) 0)[75];
g76 = ((unsigned long *) 0)[76];
g77 = ((unsigned long *) 0)[77];
g78 = ((unsigned long *) 0)[78];
g79 = ((unsigned long *) 0)[79];
g80 = ((unsigned long *) 0)[80];
g81 = ((unsigned long *) 0)[81];
g82 = ((unsigned long *) 0)[82];
g83 = ((unsigned long *) 0)[83];
g84 = ((unsigned long *) 0)[84];
g85 = ((unsigned long *) 0)[85];
g86 = ((unsigned long *) 0)[86];
g87 = ((unsigned long *) 0)[87];
g88 = ((unsigned long *) 0)[88];
g89 = ((unsigned long *) 0)[89];
g90 = ((unsigned long *) 0)[90];
g91 = ((unsigned long *) 0)[91];
g92 = ((unsigned long *) 0)[92];
g93 = ((unsigned long *) 0)[93];
g94 = ((unsigned long *) 0)[94];
g95 = ((unsigned long *) 0)[95];
g96 = ((unsigned long *) 0)[96];
g97 = ((unsigned long *) 0)[97];
g98 = ((unsigned long *) 0)[98];
g99 = ((unsigned long *) 0)[99];
g100 = ((unsigned long *) 0)[100];
g101 = ((unsigned long *) 0)[101];
g102 = ((unsigned long *) 0)[102];
g103 = ((unsigned long *) 0)[103];
g104 = ((unsigned long *) 0)[104];
g105 = ((unsigned long *) 0)[105];
g106 = ((unsigned long *) 0)[106];
g107 = ((unsigned long *) 0)[107];
g108 = ((unsigned long *) 0)[108];
g109 = ((unsigned long *) 0)[109];
g110 = ((unsigned long *) 0)[110];
g111 = ((unsigned long *) 0)[111];
g112 = ((unsigned long *) 0)[112];
g113 = ((unsigned long *) 0)[113];
g114 = ((unsigned long *) 0)[114];
g115 = ((unsigned long *) 0)[115];
g116 = ((unsigned long *) 0)[116];
g117 = ((unsigned long *) 0)[117];
g118 = ((unsigned long *) 0)[118];
g119 = ((unsigned long *) 0)[119];
g120 = ((unsigned long *) 0)[120];
g121 = ((unsigned long *) 0)[121];
g122 = ((unsigned long *) 0)[122];
g123 = ((unsigned long *) 0)[123];
g124 = ((unsigned long *) 0)[124];
g125 = ((unsigned long *) 0)[125];
g126 = ((unsigned long *) 0)[126];
g127 = ((unsigned long *) 0)[127];
g128 = ((unsigned long *) 0)[128];
g129 = ((unsigned long *) 0)[129];
g130 = ((unsigned long *) 0)[130];
g131 = ((unsigned long *) 0)[131];
g132 = ((unsigned long *) 0)[132];
g133 = ((unsigned long *) 0)[133];
g134 = ((unsigned long *) 0)[134];
g135 = ((unsigned long *) 0)[135];
g136 = ((unsigned long *) 0)[136];
g137 = ((unsigned long *) 0)[137];
g138 = ((unsigned long *) 0)[138];
g139 = ((unsigned long *) 0)[139];
g140 = ((unsigned long *) 0)[140];
g141 = ((unsigned long *) 0)[141];
g142 = ((unsigned long *) 0)[142];
g143 = ((unsigned long *) 0)[143];
g144 = ((unsigned long *) 0)[144];
g145 = ((unsigned long *) 0)[145];
g146 = ((unsigned long *) 0)[146];
g147 = ((unsigned long *) 0)[147];
g148 = ((unsigned long *) 0)[148];
g149 = ((unsigned long *) 0)[149];
g150 = ((unsigned long *) 0)[150];
g151 = ((unsigned long *) 0)[151];
g152 = ((unsigned long *) 0)[152];
g153 = ((unsigned long *) 0)[153];
g154 = ((unsigned long *) 0)[154];
g155 = ((unsigned long *) 0)[155];
g156 = ((unsigned long *) 0)[156];
g157 = ((unsigned long *) 0)[157];
g158 = ((unsigned long *) 0)[158];
g159 = ((unsigned long *) 0)[159];
g160 = ((unsigned long *) 0)[160];
g161 = ((unsigned long *) 0)[161];
g162 = ((unsigned long *) 0)[162];
g163 = ((unsigned long *) 0)[163];
g164 = ((unsigned long *) 0)[164];
g165 = ((unsigned long *) 0)[165];
g166 = ((unsigned long *) 0)[166];
g167 = ((unsigned long *) 0)[167];
g168 = ((unsigned long *) 0)[168];
g169 = ((unsigned long *) 0)[169];
g170 = ((unsigned long *) 0)[170];
g171 = ((unsigned long *) 0)[171];
g172 = ((unsigned long *) 0)[172];
g173 = ((unsigned long *) 0)[173];
g174 = ((unsigned long *) 0)[174];
g175 = ((unsigned long *) 0)[175];
g176 = ((unsigned long *) 0)[176];
g177 = ((unsigned long *) 0)[177];
g178 = ((unsigned long *) 0)[178];
g179 = ((unsigned long *) 0)[179];
g180 = ((unsigned long *) 0)[180];
g181 = ((unsigned long *) 0)[181];
g182 = ((unsigned long *) 0)[182];
g183 = ((unsigned long *) 0)[183];
g184 = ((unsigned long *) 0)[184];
g185 = ((unsigned long *) 0)[185];
g186 = ((unsigned long *) 0)[186];
g187 = ((unsigned long *) 0)[187];
g188 = ((unsigned long *) 0)[188];
g189 = ((unsigned long *) 0)[189];
g190 = ((unsigned long *) 0)[190];
g191 = ((unsigned long *) 0)[191];
g192 = ((unsigned long *) 0)[192];
g193 = ((unsigned long *) 0)[193];
g194 = ((unsigned long *) 0)[194];
g195 = ((unsigned long *) 0)[195];
g196 = ((unsigned long *) 0)[196];
g197 = ((unsigned long *) 0)[197];
g198 = ((unsigned long *) 0)[198];
g199 = ((unsigned long *) 0)[199];
g200 = ((unsigned long *) 0)[200];
g201 = ((unsigned long *) 0)[201];
g202 = ((unsigned long *) 0)[202];
g203 = ((unsigned long *) 0)[203];
g204 = ((unsigned long *) 0)[204];
g205 = ((unsigned long *) 0)[205];
g206 = ((unsigned long *) 0)[206];
g207 = ((unsigned long *) 0)[207];
g208 = ((unsigned long *) 0)[208];
g209 = ((unsigned long *) 0)[209];
g210 = ((unsigned long *) 0)[210];
g211 = ((unsigned long *) 0)[211];
g212 = ((unsigned long *) 0)[212];
g213 = ((unsigned long *) 0)[213];
g214 = ((unsigned long *) 0)[214];
g215 = ((unsigned long *) 0)[215];
g216 = ((unsigned long *) 0)[216];
g217 = ((unsigned long *) 0)[217];
g218 = ((unsigned long *) 0)[218];
g219 = ((unsigned long *) 0)[219];
g220 = ((unsigned long *) 0)[220];
g221 = ((unsigned long *) 0)[221];
g222 = ((unsigned long *) 0)[222];
g223 = ((unsigned long *) 0)[223];
g224 = ((unsigned long *) 0)[224];
*/
g225 = ((unsigned long *) 0)[225];
g226 = ((unsigned long *) 0)[226];
g227 = ((unsigned long *) 0)[227];
g228 = ((unsigned long *) 0)[228];
g229 = ((unsigned long *) 0)[229];
g230 = ((unsigned long *) 0)[230];
g231 = ((unsigned long *) 0)[231];
g232 = ((unsigned long *) 0)[232];
g233 = ((unsigned long *) 0)[233];
g234 = ((unsigned long *) 0)[234];
g235 = ((unsigned long *) 0)[235];
g236 = ((unsigned long *) 0)[236];
g237 = ((unsigned long *) 0)[237];
g238 = ((unsigned long *) 0)[238];
g239 = ((unsigned long *) 0)[239];
g240 = ((unsigned long *) 0)[240];
g241 = ((unsigned long *) 0)[241];
g242 = ((unsigned long *) 0)[242];
g243 = ((unsigned long *) 0)[243];
g244 = ((unsigned long *) 0)[244];
g245 = ((unsigned long *) 0)[245];
g246 = ((unsigned long *) 0)[246];
g247 = ((unsigned long *) 0)[247];
g248 = ((unsigned long *) 0)[248];
g249 = ((unsigned long *) 0)[249];
g250 = ((unsigned long *) 0)[250];
g251 = ((unsigned long *) 0)[251];
g252 = ((unsigned long *) 0)[252];
g253 = ((unsigned long *) 0)[253];
g254 = ((unsigned long *) 0)[254];
g255 = ((unsigned long *) 0)[255];
                                        (* (void (*)()) address)();
        IOSPACE = (int*) 0x1000000000000ULL;
                                        putch('\r');
                                        putch('\n');
                                        goto restart;
                                }
                        } else {
                                store(v, address);
                                address += 4;
                                putch('!');
                        }

                        if (lookahead != ' ')
                                break;
                }

        skip:
                while (lookahead != '\n')
                        nextchar();
                nextchar();
        }

        return 0;
}
