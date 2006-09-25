#include "stdio.h"
#include "fb-io.h"

int stdout = 0;

static long
_putint_helper(char **dst, unsigned *size, unsigned long d, unsigned long radix)
{
        unsigned long k;
        unsigned long radix10 = radix * 10;

        if (d >= radix10)
                d = _putint_helper(dst, size, d, radix10);

        for (k = 0; k < 10 && d >= radix; ++k)
                d -= radix;

        if (*size < 1)
                return -1;

        **dst = '0' + k;
        (*dst)++;
        (*size)--;

        return d;
}

int _putint(char **dst, unsigned *size, long d)
{
        if (*size <= 1)
                return -1;

        if (d < 0)
                *(*dst)++ = '-', (*size)--, d = -d;

        return _putint_helper(dst, size, d, 1);
}

int _puthex(char **dst, unsigned *size, int d, unsigned long v)
{
        if (d > 1 || v >> 4)
                if (_puthex(dst, size, d - 1, v >> 4) == -1)
                        return -1;

        *(*dst)++ = "0123456789abcdef"[v & 15];
        (*size)--;

        return 0;
}

int my_vsnprintf(char *str, unsigned size, char *format, long *args)
{
        // XXX varargs anyone?
        char *orig_str = str;
        char *s;

        --size; // Reserve space for a terminating zero

        for (; *format; ++format)
                if (size == 0)
                        goto finish;
                else if (*format != '%') {
                        *str++ = *format;
                        --size;
                } else {
                        long unsigned fieldsize = 0;
                        long unsigned leading_zero = 0;

                        ++format;
                        if (*format == '0')
                                ++format, leading_zero = 1;

                        while ('0' <= *format && *format <= '9')
                                fieldsize = fieldsize * 10 + *format++ - '0';

                        switch (*format) {
                        case 'd':
                                if (args == 0)
                                        goto finish;
                                _putint(&str, &size, *args);
                                args = 0;
                                break;
                        case 'x':
                                if (args == 0)
                                        goto finish;
                                if (fieldsize == 0)
                                        fieldsize = 8;
                                _puthex(&str, &size, fieldsize, *args);
                                args = 0;
                                break;
                        case 's':
                                if (args == 0)
                                        goto finish;
                                for (s = (char *) *args; *s && size; ++s, ++str, --size)
                                        *str = *s;
                                break;
                        default:
                                ;
                        }
                }
 finish:
        *str = 0;
        return str - orig_str;
}

static void serial_out(int ch)
{
        // XXX Replace this with an interrupt driven version

        if (ch == '\n')
                serial_out('\r');

        while (MMIX_IOSPACE[1])
                ;
        MMIX_IOSPACE[0] = ch;
}

void write(int fd, char *buf, int n)
{
        if (fd == 0)
                for (; n; --n, ++buf)
                        serial_out(*buf);
        else if (fd == 1)
                fb_write(buf, n);
}

int mmix_fprintf(int fd, char *format, long arg1, ...)
{
        char buf[9999];  /// XXX use a dynamic buffer
        int len = my_vsnprintf(buf, sizeof buf, format, &arg1); // XXX varargs anyone?
        write(fd, buf, len);
        return len;
}

int mmix_printf(char *format, long arg1, ...)
{
        char buf[9999];  /// XXX use a dynamic buffer
        int len = my_vsnprintf(buf, sizeof buf, format, &arg1); // XXX varargs anyone?
        write(stdout, buf, len);
        return len;
}



void wait_ms(long unsigned ms) {
        long unsigned start = now();
        long cycles = 25000 * ms;

        while (now() - start < cycles)
                ;
}

void wait_us(long unsigned us) {
        long unsigned start = now();
        long cycles = 25 * us;

        while (now() - start < cycles)
                ;
}
