#include <stdio.h>
#include <stdlib.h>

static int orig_lg(int n)
{
        int j, l;

        if (n <= 0) return -1;

        for (j = n, l = 0; j; j >>= 1) l++;
        return l - 1;
}

#define ARGS(a) a

static int lg ARGS((int n));
static int lg(n)
   int n;
{
        int j;

        if (n <= 0) return -1;

        j = 0;
#if 1
        if (n & 0xFFFF0000) j  = 16, n >>= 16;
        if (n & 0x0000FF00) j +=  8, n >>=  8;
        if (n & 0x000000F0) j +=  4, n >>=  4;
        if (n & 0x0000000C) j +=  2, n >>=  2;
        if (n & 0x00000002) j +=  1;
#else
        if (n >> 16) j  = 16, n >>= 16;
        if (n >>  8) j +=  8, n >>=  8;
        if (n >>  4) j +=  4, n >>=  4;
        if (n >>  2) j +=  2, n >>=  2;
        if (n >>  1) j +=  1;
#endif

        return j;
}

int
main(int argc, char **argv)
{
        int i = 0, k, l, f;
        srandom(1729);

        int sum = 0;


        for (k = 0; k < 300000000; ++k) {
                int n = k - 10 /*random() % 60*/;

#if 0
                sum += l = orig_lg(n);
#else
                sum += f = lg(n);
#endif

#if 0
                if (l != f)
                        printf("Opps, bug at lg(%d) = %d, not %d\n", n, l, f);
#endif
        }

        printf("sum = %d\n", sum);
}
