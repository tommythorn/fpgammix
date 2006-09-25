#include "stdio.h"

#define RATE 11250
#include "newgame-sound.c"

unsigned char *next_sample;
unsigned char *stop_sound;

extern void interruptvector(void);

long time_at_last_run = 0;
long delta = 0;


void
interrupthandler(long unsigned interrupt_source)
{
        setInterval(FREQUENCY / 11250 - 100);

        long time = now();

        if (next_sample != stop_sound) {
                DAC_both = *next_sample++ << 6;
        }

        delta = time - time_at_last_run;
        time_at_last_run = time;
}

int
main()
{
        fb_clear();

        mmix_fprintf(1, "Hello?", 0);

        next_sample = stop_sound = blob + sizeof blob;

        /*
         * XXX 8 and even 7 distorts the sound. Why?  AAhh, it's only
         * when on head phones.  Amplified it sounds great
         */
        unsigned scale = 6;
        unsigned sw;

        for (;;) {
                unsigned char *p;
                long unsigned my_sample, time_for_next;

                mmix_printf("Starting sound.  Scale is %d\n", scale);

                time_for_next = now() + (FREQUENCY / RATE);
                for (p = blob; p != blob + sizeof blob; ++p) {
                        MMIX_IOSPACE[11] = (long) p >> 8;
                        my_sample = *p;
                        my_sample = my_sample << scale;
                        time_for_next += (FREQUENCY / RATE);
                        while (now() < time_for_next)
                                ;
                        DAC_both = my_sample;
                }

                while ((sw = get_switches()) == 0);
                if (sw & (SW2|SW3))
                        scale += (sw & SW3) ? 1 : -1;
                else if (sw & SW1)
                        stdout = !stdout;
                else if (sw & SW0)
                        break;
        }

        mmix_printf("Trying interrupts!\n", 0);

        setInterruptVector(interruptvector);
        setIntrMask(1 << 7); // Enable interval

        for (;;) {
                mmix_printf("Starting sound\n", 0);
                next_sample = blob;

                setInterval(FREQUENCY / RATE);

                while ((get_switches() & SW3) == 0)
                        mmix_printf("delta %d\n", delta);
                while ((get_switches() & SW3) != 0);
        }
}
