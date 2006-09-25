#define set_s7_0(x) IOSPACE[9] = (x)
#define set_s7_1(x) IOSPACE[11] = (x)
#define set_fbaddr0(x) IOSPACE[21] = (x)

register volatile int *IOSPACE asm("$233");

void putch(int ch)
{
        while (IOSPACE[1])
                ;
        IOSPACE[0] = ch;
}

void puthex(unsigned v)
{
        if (v >= 16) puthex(v >> 4);
        putch("0123456789abcdef"[v & 15]);
}

int
main()
{
        IOSPACE = (int*) 0x1000000000000ULL;
        unsigned fbaddr0 = 0;

        for (;;) {
                puthex(fbaddr0);
                putch('\r');
                putch('\n');
                set_fbaddr0(fbaddr0);
                set_s7_0(fbaddr0);
                set_s7_1(fbaddr0 >> 8);
                fbaddr0 += 640 / 8;
        }
}
