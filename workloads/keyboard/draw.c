#include "stdio.h"
#include "fb-io.h"


#define RATE 11250
#include "../audio/newgame-sound.c"

unsigned char *next_sample;
unsigned char *stop_sound;



// Debugging or not
#define D 0

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
unsigned char keycode_fifo[FIFO_SIZE], mousecode_fifo[FIFO_SIZE];
volatile uint64_t kfifo_wp = 0, kfifo_rp = 0, mfifo_wp = 0, mfifo_rp = 0;

void
interrupthandler(int id)
{
        if (id == 7) {
                setInterval(FREQUENCY / 11250 - 100);

                if (next_sample != stop_sound) {
                        DAC_both = *next_sample++ << 8;
                }
        } else if (id == 40) {
                unsigned keycode = MMIX_IOSPACE[MMIX_IO_KEYBOARD];
                MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
                keycode_fifo[kfifo_wp++] = keycode;
                kfifo_wp &= FIFO_SIZE - 1;
                MMIX_IOSPACE[MMIX_IO_S7_0_OUT] = ~kfifo_wp;
                MMIX_IOSPACE[MMIX_IO_S7_1_OUT] = ~kfifo_rp;
        } else if (id == 41) {
                unsigned mousecode = MMIX_IOSPACE[MMIX_IO_MOUSE];
                MMIX_IOSPACE[MMIX_IO_MOUSE] = 0;
                mousecode_fifo[mfifo_wp++] = mousecode;
                mfifo_wp &= FIFO_SIZE - 1;
                MMIX_IOSPACE[MMIX_IO_S7_0_OUT] = ~mfifo_wp;
                MMIX_IOSPACE[MMIX_IO_S7_1_OUT] = ~mfifo_rp;
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
        if (kfifo_rp != kfifo_wp) {

                unsigned keycode = keycode_fifo[kfifo_rp++];
                kfifo_rp &= FIFO_SIZE - 1;

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
void send_ps2(unsigned sh, unsigned data_with_parity)
{
        unsigned long i = -1;

#define set_data_clk(d,c) ({MMIX_IOSPACE[MMIX_IO_PS2_RAW] = 0xF & (((c << 1) | (d)) << sh);})
#define get_data() ((MMIX_IOSPACE[MMIX_IO_PS2_RAW] >> sh) & 1)
#define get_clk() ((MMIX_IOSPACE[MMIX_IO_PS2_RAW] >> (sh+1)) & 1)

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
        if (((MMIX_IOSPACE[MMIX_IO_PS2_RAW] >> 1) & 1) != 0) {
                mmix_printf("Keyboard didn't acknowledge!\n", 0);
        } else
                mmix_printf("Done!\n", 0);

        // Clear out cruft from buffer
        // MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
#endif
}

void send_keyboard(unsigned data) {send_ps2(0, data);}
void send_mouse(unsigned data) {send_ps2(2, data);}

extern void interruptvector(void);

long last;

long read_mouse_scancode(long wait)
{
        long timeout = now() + wait;

        for (; now() < timeout;)
                  if (mfifo_rp != mfifo_wp) {
                          unsigned mousecode = mousecode_fifo[mfifo_rp++];
                          mfifo_rp &= FIFO_SIZE - 1;
                          last = now();
                          if (mousecode & 0xFF00)
                                  mmix_printf("Overflow? %4x ", mousecode);
                          return mousecode;
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

        buttons_and_more = read_mouse_scancode(30 ms);
        if (buttons_and_more < 0 || (~buttons_and_more & 8)) {
                if (buttons_and_more != -1)
                        fb_cursor_off(), mmix_printf("dropping <%4x> ", buttons_and_more),
                                fb_cursor_on();
                return 0;
        }
        x_delta = read_mouse_scancode(100 ms);
        if (x_delta < 0) {
                //mmix_printf("timeout2 ", 0);
                return 0;
        }
        y_delta = read_mouse_scancode(100 ms);
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
        else if (y_pos >= 16 * 480) y_pos = 16 * 480 - 1;

        buttons = buttons_and_more & 7;

        return 1;
}

void service_keyboard(void)
{
        char ch = check_keyboard();
        if (ch) {
                fb_cursor_off();
                if (ch == 8 && fb_io_x) {
                        fb_io_x--;
                        mmix_putchar(' ');
                        fb_io_x--;
                } else
                        mmix_putchar(ch);
                fb_cursor_on();
        }
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


void play(unsigned char *sound, unsigned length)
{
        next_sample = sound;
        stop_sound = sound + length;
}

void xdraw_mouse(unsigned long x_pos, unsigned long y_pos)
{
        xdraw_hline(x_pos/16-10, y_pos/16, 20);
        xdraw_vline(x_pos/16, y_pos/16-10, 20);
}


int
main()
{
        int64_t n, round;

        fb_clear();

        play(blob, 0);

        for (round = 0; round < 16; ++round) {
                for (n = 1; n < 256; ++n) {
                        xdraw_hline(128-round,round+128+n,n);
                }
        }

        mmix_printf("In test keyboard\n", 0);

        stdout = 1; // Frame buffer from here on

        mmix_printf("Hello! Is this thing on? ", 0);

#if 1
        //wait_ms(2000);
        //mmix_printf("Enabling interrupts ", 0);

        setInterruptVector((long)interruptvector);
        setInterval(800);
        setIntrMask(~0);
        //wait_ms(2000);
#endif

        play(blob, sizeof(blob));

        // Enable keyboard and mouse (0x00)
        // Enable input (0x0F)
        MMIX_IOSPACE[MMIX_IO_KEYBOARD] = 0;
        MMIX_IOSPACE[MMIX_IO_MOUSE] = 0;
        MMIX_IOSPACE[MMIX_IO_PS2_RAW] = 0x0F;

        y_pos = 0;
        for (x_pos = 30; x_pos < 600; ++x_pos) {
                draw(x_pos, y_pos);
                y_pos += (x_pos & 10) ? 1 : -1;
        }

        x_pos = 16 * 640 / 2 ; y_pos = 16 * 480 / 2;

//        xdraw_hline(0, y_pos / 16, 640);
//        xdraw_vline(x_pos / 16, 0, 480);

        fb_cursor_on();

        for (;;) {
                long sw;

                xdraw_mouse(x_pos, y_pos);

                do {
                        long old_x = x_pos, old_y = y_pos;
                        service_keyboard();
                        sw = get_switches();
                        if (check_mouse()) {
                                if ((buttons & 2) && x_pos == 0 && y_pos == 0)
                                        play(blob, sizeof(blob));

                                if (   x_pos / 16 != old_x / 16
                                    || y_pos / 16 != old_y / 16
                                    || buttons) {
                                        // Remove cursor
                                        xdraw_mouse(old_x, old_y);

                                        if (buttons & 1)
                                                draw(x_pos/16, y_pos/16);
                                        else if (buttons & 2)
                                                undraw(x_pos/16, y_pos/16);

                                        // Draw cursor
                                        xdraw_mouse(x_pos, y_pos);
                                }
                        }
                } while (!sw);

                xdraw_mouse(x_pos, y_pos);

                while (get_switches());

                if (sw & 1) {
                        mmix_printf("Sending reset\n", 0);
                        send_mouse(0xFF);
                        read_mouse_scancode(10 ms);
                        read_mouse_scancode(10 ms);

                        send_mouse(0xFF);
                        read_mouse_scancode(10 ms);
                        read_mouse_scancode(10 ms);

                        send_mouse(0xF3);
                        send_mouse(200);

                        send_mouse(0xF3);
                        send_mouse(100);

                        send_mouse(0xF3);
                        send_mouse( 50);

                        send_mouse(0xF2);
                        read_mouse_scancode(10 ms);

                        send_mouse(0xF3);
                        send_mouse( 10);

                        send_mouse(0xE8);
                        send_mouse(  1);

                        send_mouse(0xE6);

                        send_mouse(0xF3);
                        send_mouse(40);

                        send_mouse(0xF4);
                } else if (sw & 2) {
                        int led = 1;
                        fb_cursor_off();
                        mmix_printf("Flashing LEDs\n", 0);
                        fb_cursor_on();
                        for (sw = 20; --sw;) {
                                cursor_flip();
                                send_keyboard(0xED);
                                send_keyboard(led);

                                led = (led == 4) ? 1 : led << 1;
                                wait_ms(100);
                        }

                        x_pos = 640 / 2;
                        y_pos = 480 / 2;
                        draw(x_pos + 1, y_pos);
                        draw(x_pos - 1, y_pos);
                        draw(x_pos, y_pos + 1);
                        draw(x_pos, y_pos - 1);
                        play(blob, sizeof(blob));
                } else if (sw & 4) {
                        fb_clear();
                        
                } else if (sw & 8) {
                        fb_cursor_off();
                        mmix_printf("Mouse on\n", 0);
                        fb_cursor_on();
                        send_mouse(0xF6);
                }
        }
}
