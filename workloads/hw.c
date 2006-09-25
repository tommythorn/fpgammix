#define IOSPACE ((volatile int *) 0x1000000000000ULL)

void putchar(char ch)
{
        if (ch == '\n')
                putchar('\r');

        while (IOSPACE[1])
                ;
        IOSPACE[0] = ch;
}

void puts(char *s)
{
        while (*s)
                putchar(*s++);
}

int main()
{
        puts("Hello world!\n");
}
