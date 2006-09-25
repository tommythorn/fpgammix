// As long as we stay in the first segment, we won't have to deal with the crazy segments.
unsigned char *fb = (unsigned char *) (128 * 1024);
unsigned long cursor_x = 0;
unsigned long cursor_y = 0;
long int point_x, point_y;

void clear(void)
{
        unsigned i;
        for (i = 0; i < 10 * 480; ++i)
                ((long *)fb)[i] = 0;
        cursor_y = cursor_x = point_x = point_y = 0;
}

static inline void point(long int x, long int y)
{
        unsigned char *p = fb + (x >> 3) + y * (640/8);
        *p |= 1 << (~x & 7);
}

static inline void moveto(long int x, long int y)
{
        point_x = x;
        point_y = y;
}

void drawto(long int x, long int y)
{
        long int i, from, to;
        if (x == point_x) {
                if (point_y > y)
                        from = y, to = point_y;
                else
                        from = point_y, to = y;

                for (i = from; i <= to; ++i)
                        point(x, i);
                point_y = y;
        } else if (y == point_y) {
                if (point_x > x)
                        from = x, to = point_x;
                else
                        from = point_x, to = x;

                for (i = from; i <= to; ++i)
                        point(i, y);
                point_x = x;
        }
}

void a(long int), b(long int), c(long int), d(long int);

long int h0 = 8;
long int h, x, y, x0, y0;

void a(long int i)
{
        if (i > 0) {
                d(i-1); x -= h; drawto(x,y);
                a(i-1); y -= h; drawto(x,y);
                a(i-1); x += h; drawto(x,y);
                b(i-1);
        }
}

void b(long int i)
{
        if (i > 0) {
                c(i-1); y += h; drawto(x,y);
                b(i-1); x += h; drawto(x,y);
                b(i-1); y -= h; drawto(x,y);
                a(i-1);
        }
}

void c(long int i)
{
        if (i > 0) {
                b(i-1); x += h; drawto(x,y);
                c(i-1); y += h; drawto(x,y);
                c(i-1); x -= h; drawto(x,y);
                d(i-1);
        }
}

void d(long int i)
{
        if (i > 0) {
                a(i-1); y -= h; drawto(x,y);
                d(i-1); x -= h; drawto(x,y);
                d(i-1); y += h; drawto(x,y);
                c(i-1);
        }
}

#define IOSPACE ((volatile int *) 0x1000000000000ULL)
#define set_fbaddr0(x) IOSPACE[21] = (x)

int dummy;

main()
{
        int d, i;

        set_fbaddr0(fb);

        for (;;)
        for (d = 0; d <= 6; ++d) {
                clear();

                h0 = 8;
                h = h0; x0 = h/2; y0 = x0; h = h/ 2;
                x0 += h/2; y0 += h/2;

                x = x0 + 400; y = y0 + 350; moveto(x,y);
                a(d);

                for (i = 0; i < 1000000; ++i)
                        ++dummy;
        }
}
