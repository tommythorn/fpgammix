#include "host.h"
#include "xmodem.h"

unsigned char buf[9999];

static outs(char *s)
{
        while (*s) _outbyte(*s++);
}

int main()
{
        for (;;) {
                outs("Start!\r\n");
                set_s7_0(0x5);
                set_s7_1(0x5);

                int res = xmodemReceive(buf, sizeof buf);

                if (res < 0)
                        outs("Failed!\r\n");
                else
                        outs("Success!\r\n");
        }
}
