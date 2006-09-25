#define IOSPACE ((volatile int *) 0x1000000000000ULL)
#define set_s7_0(x) IOSPACE[9] = (x)
#define set_s7_1(x) IOSPACE[11] = (x)

int timeout_count, read_count;

static int _inbyte(unsigned short timeout) // msec timeout
{
        long int ms;

        for (; timeout; --timeout) {
                // 25Mhz, ~ 25 CPI => 1000 inst/ms
                for (ms = 1000; ms; --ms) {
                        int c = IOSPACE[3];
                        if (c >= 0) {
                                set_s7_0(++read_count);
                                return c;
                        }
                }
        }
                set_s7_1(++timeout_count);
        return -1;
}

static void _outbyte(int c)
{
        while (IOSPACE[1])
                ;
        IOSPACE[0] = c;
}

static void host_memcpy(void *dest, const void *src, int n)
{
        // XXX Very slow implementation
        unsigned char *d = (unsigned char *) dest;
        unsigned char *s = (unsigned char *) src;

        while (n--)
                *d++ = *s++;
}

static void host_memset(void *dest, int c, int n)
{
        // XXX Very slow implementation
        unsigned char *d = (unsigned char *) dest;

        while (n--)
                *d++ = c;
}

#define memset host_memset
#define memcpy host_memcpy
