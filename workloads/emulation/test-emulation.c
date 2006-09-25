#include <stdio.h>

long dummy;

void foo(long x)
{
        dummy += 1729 / x;
}

void traphandler()
{
        // What kind of trap, where, how to patch up?
        mmix_printf("Bzz, trapped in ?");
}

void interrupthandler(long id)
{
        /* do nothing */
}

int main()
{
        long i;
        mmix_printf("Hello, this is test emulation.\n");

        for (i = 1; i < 10; ++i)
                foo(i);

        mmix_printf("And that concludes tonights programming.\n");
}
