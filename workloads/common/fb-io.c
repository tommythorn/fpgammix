#include "mmix-iospace.h"
#include "fb-io.h"
#include "font-fixed-6x13.h"

#define W (640 / 8)

// As long as we stay in the first segment, we won't have to deal with the crazy segments.
static unsigned char *fb = (unsigned char *) (128 * 1024);
unsigned long fb_io_x = 0;
unsigned long fb_io_y = 0;
static unsigned long cursor_is_on = 0;

/*static*/ void cursor_flip(void) {
        unsigned char *d = fb + (6*fb_io_x) / 8 + 13 * W * fb_io_y;
        unsigned sh      = (fb_io_x * 6) & 7;
        unsigned mask    = ~ (((1 << 6) - 1) >> sh);
        unsigned k;

        for (k = 0; k < 13; d += W, ++k) *d ^= 0xFC >> sh;

        if (sh > 2) {
                d = fb + (6*fb_io_x) / 8 + 13 * W * fb_io_y + 1;
                sh = 8 - sh;
                mask = ~ (((1 << 6) - 1) << sh);

                for (k = 0; k < 13; d += W, ++k) *d ^= 0xFC << sh;
        }
        cursor_is_on ^= 1;
}

void fb_cursor_off(void) { if (cursor_is_on) cursor_flip(); }
void fb_cursor_on(void) { if (!cursor_is_on) cursor_flip(); }

/*
 * Ways to speed this up:
 *
 * 0. Use tetra access to the frame buffer to reduce how often we need to
 *    handle to overlapping case.  (Octa access are twice as expensive as tetra
 *    thus unlikely a win).
 *
 * 1. Move the begining of the framebuffer rather than copying it.  If
 *    used with a mask such that the framebuffer loops around, we'd never have to
 *    copy, otherwise we'd have to copy whenever we loop around.
 *
 * 2. Enhance the SRAM controller with smarts [such at some top address
 *    bits pick mode].  Modes we need here are read-modify-write modes,
 *    like
 *       *dest_addr = (*dest_addr & mask_register) | ((wrdata << shift) >> 32)
 *
 *     (It's not hard to imagine a lot of useful *d = COMBINE(*d, *s) operations)
 *
 *    However, shifters in the SRAM controller are expensive and the
 *    whole approach increasingly looses relevance as the number of
 *    bits pr pixel goes up.  (The core actually could play tricks at
 *    the byte level by exploring the byte enables, hmm).
 */

void fb_write(char *buf, int n)
{
        long unsigned i;
        // Internal versions for speed, can't trust GCC for this
        long unsigned x = fb_io_x;
        long unsigned y = fb_io_y;

        for (; n; ++buf, --n) {
                long unsigned ch = *(unsigned char *)buf;

                if (ch != '\n') {
                        unsigned char *d = fb + (6*x) / 8 + 13 * W * y;
                        unsigned char *s = font_fixed_6x13 + 16*ch;
                        unsigned sh = (x * 6) & 7;
                        unsigned mask = ~ ((((1 << 6) - 1) << 2) >> sh);
                        unsigned char *s_stop = s + 13;

                        for (; s != s_stop; d += W, ++s) {
                                *d = (*s >> sh) | (*d & mask);
                                // *d = *s;
                                // printf("%x\n", p[i]);
                        }
                        if (sh > 2) {
                                d = fb + (6*x) / 8 + 13 * W * y + 1;
                                s = font_fixed_6x13 + 16*(unsigned char)ch;
                                sh = 8 - sh;
                                mask = ~ ((((1 << 6) - 1) << 2) << sh);

                                for (; s != s_stop; d += W, ++s) {
                                        *d = (*s << sh) | (*d & mask);
                                        // *d = *s;
                                        // printf("%x\n", p[i]);
                                }
                        }
                        ++x;
                }

                if (x == (640/6) || ch == '\n') {
                        x = 0;
                        ++y;
                        if (y == (480/13)) {
                                // Scroll up
                                --y;
                                for (i = 0; i < (640 / 64) * 13*(480/13 - 1); ++i)
                                        ((long *)fb)[i] = ((long *)fb)[i + 13 * (640 / 64)];
                                for (; i < (640 / 64) * 480; ++i)
                                        ((long *)fb)[i] = 0;
                        }
                }
        }

        // Copy back
        fb_io_x = x;
        fb_io_y = y;
}

void fb_clear(void) {
        unsigned long *p = (unsigned long *)fb;
        unsigned long *end = p + 4800;

        set_mmix_fbaddr0(fb);

        fb_io_x = fb_io_y = cursor_is_on = 0;

        for (; p != end; p += 10)
                p[9] = p[8] = p[7] = p[6] = p[5] = p[4] = p[3] = p[2] = p[1] = p[0] = 0;
}

void fb_gotoxy(unsigned long _x, unsigned long _y)
{
        fb_io_x = _x, fb_io_y = _y;
}
