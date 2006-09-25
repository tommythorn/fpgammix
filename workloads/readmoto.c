/*
  I figured it would be easier to write the assembly if I had a
  working model in C first ...

 */

#include <stdio.h>
#include <stdlib.h>

// S11329300FFFFFFFFFFF0F0F0F0F0F0FFFFFFFFF33

unsigned sum;

void fatal(void)
{
        printf("FAILURE\n");
        exit(1);
}

unsigned getdigit()
{
        unsigned c = getchar();

        if ('0' <= c && c <= '9')
                return c - '0';
        else if ('a' <= c && c <= 'f')
                return c - 'a' + 10;
        else if ('A' <= c && c <= 'F')
                return c - 'A' + 10;
        else
                fatal();
}

unsigned get2digits()
{
        unsigned n = getdigit();
        n = n*16 + getdigit();
        sum = 255 & (sum + n);
        return n;
}

unsigned get4digits()
{
        unsigned n = get2digits();
        return n*256 + get2digits();
}


int
main()
{
        char buf[999];

        for (;;) {
                unsigned type, count, address, i, data, xsum;
                while (getchar() != 'S');
                type = getdigit();
                if (type != 1 && type != 9)
                        continue;
                sum = 0;
                count = get2digits();
                address = get4digits();
                printf("type %d count %d starting %x\n", type, count, address);
                for (i = 2; i < count - 1; ++i, ++address) {
                        data = get2digits();
                        printf("%04x:%02x\n", address, data);
                }
                xsum = get2digits();
                if (sum != 255)
                        printf("Mismatch %02x =? %02x\n", sum, xsum);
        }
}
