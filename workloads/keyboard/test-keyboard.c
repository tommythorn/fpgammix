#include "stdio.h"
#include "fb-io.h"

// Debugging or not
#define D 1

// Missing map entries for special keys, like F1..F12, Cursor up, etc.
char *keyboard_map[256] = {
        [0x76] = "\e",

        // Numeric row
        [0x0E] = "`~",
        [0x16] = "1!",
        [0x1E] = "2@",
        [0x26] = "3#",
        [0x25] = "4$",
        [0x2E] = "5%",
        [0x36] = "6^",
        [0x3D] = "7&",
        [0x3E] = "8*",
        [0x46] = "9(",
        [0x45] = "0)",
        [0x4E] = "-_",
        [0x55] = "=+",
        [0x66] = "\b",

        // Tab row
        [0x0D] = "\t",
        [0x15] = "qQ",
        [0x1D] = "wW",
        [0x24] = "eE",
        [0x2D] = "rR",
        [0x2C] = "tT",
        [0x35] = "yY",
        [0x3C] = "uU",
        [0x43] = "iI",
        [0x44] = "oO",
        [0x4D] = "pP",
        [0x54] = "[{",
        [0x5B] = "]}",
        [0x5D] = "\\|",

        // CapsLock row
        // 0x58 = CapsLock
        [0x1c] = "aA",
        [0x1b] = "sS",
        [0x23] = "dD",
        [0x2b] = "fF",
        [0x34] = "gG",
        [0x33] = "hH",
        [0x3b] = "jJ",
        [0x42] = "kK",
        [0x4b] = "lL",
        [0x4c] = ";:",
        [0x52] = "'\"",
        [0x5a] = "\n",


        // Shift row
        // 0x12 = Shift_L
        [0x1a] = "zZ",
        [0x22] = "xX",
        [0x21] = "cC",
        [0x2a] = "vV",
        [0x32] = "bB",
        [0x31] = "nN",
        [0x3a] = "mM",
        [0x41] = ",<",
        [0x49] = ".>",
        [0x4a] = "/?",
        // 0x59 Shift_R

        // Control row
        // 0x14 = Ctrl_L
        // 0x11 = Alt_L
        [0x29] = " ",
        // 0xE0 0x11 = Alt_R
        // 0xE0 0x14 = Ctrl_R
};

/* Keycode fifo */
#define FIFO_SIZE 256
unsigned char keycode_fifo[FIFO_SIZE];
volatile uint64_t fifo_wp = 0, fifo_rp = 0;

void
interrupthandler(int id)
{
        if (id == 40) {
                unsigned keycode = MMIX_IOSPACE[MMIX_IO_KEYBOARD];
                MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
                keycode_fifo[fifo_wp++] = keycode;
                fifo_wp &= FIFO_SIZE - 1;
                MMIX_IOSPACE[MMIX_IO_S7_0_OUT] = ~fifo_wp;
                MMIX_IOSPACE[MMIX_IO_S7_1_OUT] = ~fifo_rp;
        }
}


static int kbRelease_on  = 0;
static int kbExtended_on = 0;
static int kbCapsLock_on = 0;
static int kbShift_on    = 0;
static int kbCtrl_on     = 0; // XXX Isn't really implemented yet
static int kbAlt_on      = 0; // XXX Isn't implemented yet

unsigned check_keyboard(void)
{
        char *translation, ch = 0;
        if (fifo_rp != fifo_wp) {

                unsigned keycode = keycode_fifo[fifo_rp++];
                fifo_rp &= FIFO_SIZE - 1;

                if(D)mmix_printf("keycode: %8x ", keycode);

                if (keycode >> 8)
                        if(D)mmix_printf("OVERFLOW: %16x ", keycode);

                //fb_puthex(2,keycode);
                //fb_putchar(' ');

                // Ctrl_R: E0 11  E0 F0 11
                // Shift: 12 F0 12
                switch (keycode) {
                case 0xE0: kbExtended_on = 1; break;
                case 0xF0: kbRelease_on  = 1;
//                        fb_puts("RelOn ");
                                              return 0; /* As to not clear extended */
                case 0x58: kbCapsLock_on ^= !kbRelease_on; break;
                case 0x12:
                case 0x59: kbShift_on = !kbRelease_on;
/*
                        fb_puts("Shift ");
                        fb_putchar(" o"[kbShift_on]);
                        fb_putchar(" R"[kbRelease_on]);
                        fb_putchar(' ');
*/
                        break;

                case 0x11: kbCtrl_on = !kbRelease_on; break;
                default:
                        /*
                        fb_putchar('<');
                        fb_puthex(2,keycode);
                        fb_putchar(',');
                        fb_puthex(1,kbRelease_on);
                        fb_putchar(',');
                        fb_puthex(1,kbShift_on);
                        fb_putchar(',');
                        fb_puthex(1,kbExtended_on);
                        fb_putchar('>');
                        */

                        translation = keyboard_map[keycode];

                        if (translation && !kbRelease_on) {
                                //fb_putchar(translation[0]);
                                //fb_putchar(" o"[kbShift_on]);
                                //fb_putchar(' ');

                                ch = translation[0];
                                if ((kbCapsLock_on ^ kbShift_on) && translation[1]) {
                                        ch = translation[1];
                                }
                        }
                        break;
                }

                if (keycode != 0xE0)
                        kbExtended_on = 0;
                if (keycode != 0xF0)
                        kbRelease_on = 0;

        }

        if (ch)
                if(D)mmix_printf("got %d\n", ch);
        return ch;
}

char read_keyboard(void)
{
        char ch;

        do {
                ch = check_keyboard();
        } while (ch == 0);

        return ch;
}

/*
  Key numbers: Tck: 30-50us, Tsu: 5-25us, Thld: 5-25us
 */

// <parity> <b7> ... <b0>
void send_keyboard(long sh, unsigned data_with_parity)
{
        unsigned long i = -1;

#define set_data_clk(d,c) ({MMIX_IOSPACE[23] = (0xF & (((c) << 1) | (d)) << sh);})
#define get_data() ((MMIX_IOSPACE[23] >> sh) & 1)
#define get_clk() ((MMIX_IOSPACE[23] >> (sh+1)) & 1)

#define WAIT_UNTIL(cond) \
	({ for (;!(cond);)      \
		if (timeout <= now()){\
			mmix_printf("\nTimed out waiting for " #cond " in line %d ", __LINE__); \
			mmix_printf("(i == %d)", i);                    \
        		return; }})
#define ms * (FREQUENCY / 1000)

        unsigned long parity = 1;
        long timeout;

        /* The device always generates the clock signal */

        /* First, Request-to-Send */

        set_data_clk(1,0);  // Communication Inhibited
        wait_us(100);       // Wait at least 100 us
        set_data_clk(0,0);  // Bring the data line low
        //wait_us(2);
        set_data_clk(0,1);  // Host Request-to-Send (includes start bit)

        timeout = now() + 15 ms;

        // Wait for low clock
        WAIT_UNTIL(get_clk() == 0);

        timeout = now() + 20 ms;

        for (i = 1; i <= 8; ++i) {

                //wait_us(5);
                set_data_clk(data_with_parity & 1, 1);
                parity ^= data_with_parity & 1;
                data_with_parity >>= 1;

                // Wait for clock to go high
                WAIT_UNTIL(get_clk() == 1);
                // Wait for low clock
                WAIT_UNTIL(get_clk() == 0);
        }

        // Parity

        //wait_us(5);
        set_data_clk(parity, 1);

        WAIT_UNTIL(get_clk() == 1);

        set_data_clk(1, 1);  // Release the data line (9)
        // Wait for data low (10)

        WAIT_UNTIL(get_data() == 0);
        // Wait for clock low (11)
        WAIT_UNTIL(get_clk() == 0);

        // Wait for release (12)
        WAIT_UNTIL(get_clk() == 1 && get_data() == 1);

#if 0
        if (0)
        if (((MMIX_IOSPACE[23] >> 1) & 1) != 0) {
                mmix_printf("Keyboard didn't acknowledge!\n", 0);
        } else
                mmix_printf("Done!\n", 0);

        // Clear out cruft from buffer
        // MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
#endif
}

extern void interruptvector(void);

long last;

long read_mouse_scancode(void)
{
        long timeout = now() + 20 ms;

        for (; now() < timeout;)
                  if (fifo_rp != fifo_wp) {
                          unsigned keycode = keycode_fifo[fifo_rp++];
                          fifo_rp &= FIFO_SIZE - 1;
                          last = now();
//                          if (keycode & 0xFF00)
//                                  mmix_printf("Overflow? %4x ", keycode);
                          return keycode;
                  }
        return -1;
}

long x_pos = 16 * 640 / 2;
long y_pos = 16 * 480 / 2;
long buttons = 0;

int check_mouse(void)
{
        long buttons_and_more;
        long x_delta, y_delta;

        buttons_and_more = read_mouse_scancode();
        if (buttons_and_more < 0 || (~buttons_and_more & 8)) {
                if (buttons_and_more != -1)
                        mmix_printf("dropping <%4x> ", buttons_and_more);
                return 0;
        }
        x_delta = read_mouse_scancode();
        if (x_delta < 0) {
                //mmix_printf("timeout2 ", 0);
                return 0;
        }
        y_delta = read_mouse_scancode();
        if (y_delta < 0) {
                //mmix_printf("timeout3 ", 0);
                return 0;
        }

        // buttons_and_more =
        // Yoverflow Xoverflow Ysign Xsign 1 M_B R_B L_B
        if (buttons_and_more & 0x10) x_delta = x_delta - 256;
        if (buttons_and_more & 0x20) y_delta = y_delta - 256;

        x_pos += x_delta;
        if (x_pos < 0) x_pos = 0;
        else if (x_pos >= 16 * 640) x_pos = 16 * 640 - 1;

        y_pos -= y_delta;
        if (y_pos < 0) y_pos = 0;
        else if (y_pos >= 16 * 480) x_pos = 16 * 480 - 1;

        buttons = buttons_and_more & 7;

        return 1;
}

void undraw(uint64_t x, uint64_t y)
{
        static uint32_t * const fb = (uint32_t *) (128 * 1024);

        if (x < 640 && y < 480)
                fb[y * 20 + (x >> 5)] &= ~(0x80000000 >> (x & 31));
}

void draw(uint64_t x, uint64_t y)
{
        static uint32_t * const fb = (uint32_t *) (128 * 1024);

        if (x < 640 && y < 480)
                fb[y * 20 + (x >> 5)] |= 0x80000000 >> (x & 31);
}

void inline xdraw(uint64_t x, uint64_t y)
{
        static uint32_t * const fb = (uint32_t *) (128 * 1024);

        if (x < 640 && y < 480)
                fb[y * 20 + (x >> 5)] ^= 0x80000000 >> (x & 31);
}

void xdraw_vline(uint64_t x, uint64_t y, int64_t len)
{
        static uint32_t * const fb = (uint32_t *) (128 * 1024);
        uint32_t mask;
        uint32_t *p;

        if (640 <= x || 480 <= y || len <= 0)
                return;

        if (480 <= y + len)
                len = 480 - y;

        p = fb + 20 * y + (x >> 5);
        mask = 0x80000000 >> (x & 31);

        switch (len & 3) {
        case 3: *p ^= mask, p += 20;
        case 2: *p ^= mask, p += 20;
        case 1: *p ^= mask, p += 20;
        case 0: ;
        }

        len &= ~3;

        for (; len; len -= 4, p += 80) {
                p[0]  ^= mask;
                p[20] ^= mask;
                p[40] ^= mask;
                p[60] ^= mask;
        }
}

void xdraw_hline(uint64_t x, uint64_t y, int64_t len)
{
        static uint64_t * const fb = (uint64_t *) (128 * 1024);
        uint64_t mask;
        uint64_t *p, *p_end;

        if (640 <= x || 480 <= y || len <= 0)
                return;

        if (640 <= x + len)
                len = 640 - x;
        p = fb + 10 * y + (x >> 6);

        if ((x & ~63) == ((x + len - 1) & ~63)) {
                //  head & tail (special case for speed)
                // | __XXX___  |

                // | __XXXXXX  |
                mask = ~0UL >> (x & 63);

                // | XXXXX___  |
                mask &= (1L << 63) >> ((x + len - 1) & 63);
                *p ^= mask;
        } else {
                //   head        body                     tail
                // | ___XXXXX | XXXXXXX | ... | XXXXXX |  XXXXX___ |


                // | __XXXXXX  |
                *p++ ^= ~0UL >> (x & 63);
                len -= 64 - (x & 63);
                x += 64 - (x & 63);

                // | XXXXXX| ... | XXXXXX|
                p_end = p + (len >> 6);
                for (; p != p_end;)
                        *p++ ^= ~0UL;
                x += 64 * (len >> 6);
                len -= 64 * (len >> 6);

                // | XXXXX___ |
                if (len) {
                        mask = (1L << 63) >> ((x + len - 1) & 63);
                        *p++ ^= mask;
                }
        }
}



int
main()
{
        int64_t n, round;

        fb_clear();

        for (round = 0; round < 16; ++round) {
                for (n = 1; n < 256; ++n) {
                        xdraw_hline(128-round,round+128+n,n);
                }
        }

        mmix_printf("In test keyboard\n", 0);

        //stdout = 1; // Frame buffer from here on

        mmix_printf("Hello! Is this thing on? ", 0);

#if 1
        //wait_ms(2000);
        //mmix_printf("Enabling interrupts ", 0);

        setInterruptVector((long)interruptvector);
        setInterval(800);
        setIntrMask(~0);
        //wait_ms(2000);
#endif

        // Enable keyboard and mouse (0x00)
        // Enable input (0x0F)
        MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
        MMIX_IOSPACE[23] = 0x0F;

        y_pos = 0;
        for (x_pos = 30; x_pos < 600; ++x_pos) {
                draw(x_pos, y_pos);
                y_pos += (x_pos & 10) ? 1 : -1;
        }

#define check_kbd() ({\
  if (fifo_rp != fifo_wp) { \
        unsigned keycode = keycode_fifo[fifo_rp++]; \
        fifo_rp &= FIFO_SIZE - 1;                   \
        mmix_printf("%2x", keycode); }})

        x_pos = 16 * 640 / 2 ; y_pos = 16 * 480 / 2;

        xdraw_hline(0, y_pos / 16, 640);
        xdraw_vline(x_pos / 16, 0, 480);

        for (;;) {
                long sw;
                mmix_printf("\nready> ", 0);
                do {
                        long old_x = x_pos, old_y = y_pos;
                        sw = get_switches();
                        if (check_mouse()) {
                                if (   x_pos / 16 != old_x / 16
                                    || y_pos / 16 != old_y / 16
                                    || buttons) {
                                        // Remove cursor
                                        xdraw_hline(0, old_y / 16, 640);
                                        xdraw_vline(old_x / 16, 0, 480);

                                        if (buttons & 1)
                                                draw(x_pos / 16, y_pos / 16);
                                        else if (buttons & 2)
                                                undraw(x_pos / 16, y_pos / 16);

                                        // Draw cursor
                                        xdraw_hline(0, y_pos / 16, 640);
                                        xdraw_vline(x_pos / 16, 0, 480);
                                }
#if 0
                                mmix_printf("(%d,", x_pos);
                                mmix_printf("%d) ", y_pos);
                                if (buttons & 1) mmix_printf("L", 0);
                                if (buttons & 2) mmix_printf("R", 0);
                                if (buttons & 4) mmix_printf("M", 0);
                                mmix_printf("       \r", 0);
#endif
                        }
                } while (!sw);
                while (get_switches())
                        check_kbd();

                if (sw & 1) {
                        mmix_printf("Sending reset\n", 0);
                        send_keyboard(0, 0xFF);
                        read_mouse_scancode();
                        read_mouse_scancode();

                        send_keyboard(0, 0xFF);
                        read_mouse_scancode();
                        read_mouse_scancode();

                        send_keyboard(0, 0xF3);
                        send_keyboard(0, 200);

                        send_keyboard(0, 0xF3);
                        send_keyboard(0, 100);

                        send_keyboard(0, 0xF3);
                        send_keyboard(0,  50);

                        send_keyboard(0, 0xF2);
                        read_mouse_scancode();

                        send_keyboard(0, 0xF3);
                        send_keyboard(0,  10);

                        send_keyboard(0, 0xE8);
                        send_keyboard(0,   1);

                        send_keyboard(0, 0xE6);

                        send_keyboard(0, 0xF3);
                        send_keyboard(0, 40);

                        send_keyboard(0, 0xF4);
                } else if (sw & 2) {
/*                        mmix_printf("Flashing LEDs\n", 0);
                        for (sw = 200; --sw;) {
                                send_keyboard(0, 0xED);
                                send_keyboard(0, led);

                                led = (led == 4) ? 1 : led << 1;
                                wait_ms(100);
                        }
*/
                        x_pos = 640 / 2;
                        y_pos = 480 / 2;
                        draw(x_pos + 1, y_pos);
                        draw(x_pos - 1, y_pos);
                        draw(x_pos, y_pos + 1);
                        draw(x_pos, y_pos - 1);
                } else if (sw & 4) {
                        fb_clear();
                } else if (sw & 8) {
                        mmix_printf("Mouse on\n", 0);
                        send_keyboard(0, 0xF6);
                }
        }
#if 0
        for (;;) {
                char ch = read_keyboard();
                if (ch == 't') {
                        mmix_printf("Ok, as you wish.  Launching test\n", 0);

                        send_keyboard(0xFF + 0x100); // Reset
                } else if (ch == 's') {
                        send_keyboard(0xED + 0x100);
                        send_keyboard(0x02 + 0x000);
                } else if (ch == 'c') {
                        fb_clear();
                } else if (ch != '\b' || stdout == 0)
                        mmix_putchar(ch);
                else {
                        fb_gotoxy(fb_io_x-1,fb_io_y);
                        mmix_putchar(' ');
                        fb_gotoxy(fb_io_x-1,fb_io_y);
                }
        }
#endif
}
