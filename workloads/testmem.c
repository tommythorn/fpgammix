register volatile int * IOSPACE    asm("$233");

void putch(long int ch)
{
        if (ch == '\n')
                putch('\r');
        while (IOSPACE[1])
                ;
        IOSPACE[0] = ch;
}

void puthex(long unsigned d, long unsigned v)
{
        if (!d)
                return;
        puthex(d - 1, v >> 4);
        putch("0123456789abcdef"[v & 15]);
}

void my_puts(char *s)
{
        while (*s)
                putch(*s++);
}

register unsigned long g242 asm("$242");
register unsigned long g246 asm("$246");
register unsigned long g254 asm("$254");

void write(unsigned long seg, unsigned long offset, unsigned v)
{
        seg <<= 60;
        seg += offset;
        *(unsigned *)seg = v;
}

void check(unsigned long seg, unsigned long offset, unsigned v)
{
        seg <<= 60;
        seg += offset;
        if (*(unsigned *)seg != v) {
                my_puts("#");
                puthex(16,seg);
                my_puts(": ");
                puthex(8,*(unsigned *)seg);
                my_puts(" Bad! Expected ");
                puthex(8, v);
                putch('\n');
        }
}

int
main()
{
        // $254 = #60..00
        /*
g241: 0000000000001a98 _global_impure_ptr = #1a98 (12)
g242: 2000000000000000 !!
g243: 2000000000001088 _impure_ptr
g244: 20000000000017a8 __malloc_av_
g245: 2000000000001fb8 __malloc_trim_threshold
g246: 4000000000000000 _Sbrk_high !!
g247: 0
g248: 0
g249: 0
g250: 0
g251: 0
g252: 0
g253: 0
g254: 6000000000000000 !!
g255: 0000000000000180 Main
        */
        int i;
        IOSPACE = (int*) 0x1000000000000ULL;
        unsigned long x;
        unsigned long y;
        unsigned char *fb;
        unsigned long k = 128;
        k <<= 10;

        g242 = 0x2000000000000000ULL;
        g246 = 0x4000000000000000ULL;
        g254 = 0x6000000000000000ULL;

        //fb = (unsigned char *) (256 * 1024);

        putch('\n');
        my_puts("Hello?\n");
        my_puts("MMIX is **ALIVE**!!\n");

        write(2, 900, 1729);
        write(4, 900, 1789);
        write(6, 900, 666);

        check(2, 900, 1729);
        check(4, 900, 1789);
        check(6, 900, 666);


        for (x = 9000; x < 256 * 1024; x += 8)
                write(1, x, 999 + (x << 2) + x);

        for (x = 9000; x < 256 * 1024; x += 8)
                check(1, x, 999 + (x << 2) + x);

        my_puts("Ok\n");
}
