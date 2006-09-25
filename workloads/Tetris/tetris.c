#include <stdio.h>

//extern void setitimer(int, long *, int), system(char *), sigvec(), srand(int), exit(int);
//extern int atoi(char *), rand(void), getpid(void);

#ifndef __mmix__
long h[4];

int t(void)
{
        h[3] -= h[3] / 3000;

        setitimer(0, h, 0);
}
#endif

int key, d, level;

int v[] = {(int)t, 0, 2};

int w, s, I, K = 0, i = 276, j, k, q[276], Q[276], *n = q, *m, x = 17;

int shape[] = {
         7, -13, -12,  1, // 0        0 -> 7 -> 0
         8, -11, -12, -1, // 1        1 -> 8 -> 1
         9,  -1,   1, 12, // 2        2 -> 9 -> 10 -> 11 -> 2
         3, -13, -12, -1, // 3  Square block!
        12,  -1,  11,  1, // 4        4 -> 12 -> 13 -> 14 -> 4
        15,  -1,  13,  1, // 5        5 -> 15 -> 16 -> 17 -> 5
        18,  -1,   1,  2, // 6        6 -> 18 -> 6
         0, -12,  -1, 11, // 7
         1, -12,   1, 13, // 8
        10, -12,   1, 12, // 9
        11, -12,  -1,  1, // 10
         2, -12,  -1, 12, // 11
        13, -12,  12, 13, // 12
        14, -11,  -1,  1, // 13
         4, -13, -12, 12, // 14
        16,  -11,-12, 12, // 15
        17,  -13,  1, -1, // 16
         5,  -12, 12, 11, // 17
         6,  -12, 12, 24  // 18
};

// Lazy screen refresh
int update(void)
{
        for (i = 11; ++i < 264;)
                if ((k = q[i]) - Q[i]) {
                        Q[i] = k;
                        if (i - ++I || i % 12 < 1) {
                                I = i;
#ifdef __mmix__
                                gotoxy(i % 12 * 2 + 28, i / 12);
#else
                                printf("\033[%d;%dH",
                                       i / 12,
                                       i % 12 * 2 + 28);
#endif
                        }
#ifdef __mmix__
                        mmix_putchar("# "[!k]);
#else
                        printf("\033[%dm  " + (K - k ? 0 : 5), k);
                        K = k;
#endif
                }
        Q[263] = key = getchar();
}

// Test position
int test_brick(long newpos)
{
        long i;

        for (i = 4; --i;)
                if (q[newpos + n[i]])
                        return 0;

        if (q[newpos])
                return 0;

        return 1;
}

// Move
int draw_brick(long color)
{
        long i;
        for (i = 4; --i;)
                q[x + n[i]] = color;
        q[x] = color;
}

int main(long argc, char **argv)
{
        char *a;

        h[3] = 1000000 / (level = argc > 1 ? atoi(argv[1]) : 2);

        a = argc > 2 ? argv[2] : "jkl pq";

        /* Draw the board */
        for (i = 276; i; --i)
                *n++ = i < 25 || i % 12 < 2 ? 7 : 0;

#ifndef __mmix__
        srand(getpid());
        system("stty cbreak -echo stop u");
        sigvec(14, v, 0);
#endif

        t();

#ifdef __mmix__
        stdout = 1;
        fb_clear();
#else
        puts("\033[H\033[J");
#endif

        for (n = shape + rand() % 7 * 4;; draw_brick(7), update(), draw_brick(0)) {
                if (key < 0) {
                        if (test_brick(x + 12))
                                x += 12;
                        else {
                                draw_brick(7);
                                ++w;
                                for (j = 0; j < 252; j = 12 * (j / 12 + 1))
                                        for (; q[++j];)
                                                if (j % 12 == 10) {
                                                    for (; j % 12; q[j--] = 0)
                                                            ;
                                                    update();
                                                    for (; --j; q[j + 12] = q[j])
                                                            ;
                                                    update();
                                                }
                                n = shape + rand() % 7 * 4;
                                test_brick(x = 17) || (key = a[5]);
                        }
                }

                // Move left
                if (key == a[0])
                        test_brick(--x) || ++x;

                // Rotate
                if (key == a[1])
                        n = shape + 4 * *(m = n), test_brick(x) || (n = m);

                // Move Right
                if (key == a[2])
                        test_brick(++x) || --x;

                // Drop
                if (key == a[3])
                        for (; test_brick(x + 12); ++w)
                                x += 12;

                if (key == a[4] || key == a[5]) {
#ifndef __mmix__
                        s = sigblock(8192);
                        printf("\033[H\033[J\033[0m%d\n", w);
                        if (key == a[5])
                                break;
                        for (j = 264; j--; Q[j] = 0);
                        while (getchar() - a[4])
                                ;
                        puts("\033[H\033[J\033[7m");
                        sigsetmask(s);
#else
                        exit(0);
#endif
                }
        }
#ifndef __mmix__
        d = popen("stty -cbreak echo stop \023;cat - HI|sort -rn|head -20>/tmp/$$;mv /tmp/$$ HI;cat HI", "w");
        fprintf(d, "%4d on level %1d by %s\n", w, level, getlogin());
        pclose(d);
#endif
}
