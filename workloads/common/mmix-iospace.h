#ifndef _MMIX_IOSPACE_H_
#define _MMIX_IOSPACE_H_ 1

// XXX Don't belong here I know.
typedef long            int64_t;
typedef long unsigned  uint64_t;
typedef int             int32_t;
typedef int  unsigned  uint32_t;
typedef short           int16_t;
typedef short unsigned uint16_t;
typedef char            int8_t;
typedef char unsigned  uint8_t;

#define MMIX_IOSPACE ((volatile int *) 0x1000000000000ULL)

#define MMIX_IO_PS2_RAW		       23
#define MMIX_IO_KEYBOARD	       25
#define MMIX_IO_MOUSE		       27

#define MMIX_IO_RS232_OUT		1
#define MMIX_IO_RS232_BUSY_IN		1

#define MMIX_IO_RS232_RDDATA_IN		3

#define MMIX_IO_S7_0_OUT		9
#define MMIX_IO_S7_1_OUT	       11

#define set_mmix_fbaddr0(x) MMIX_IOSPACE[21] = (int) (unsigned long) (x)


void wait(unsigned long ms);
void wait_us(long unsigned us);

static inline long unsigned now(void) {
        long unsigned rC;

        asm volatile("GET %0,rC" : "=r" (rC));

        return rC;
}


static inline long unsigned getEvents(void) {
        long unsigned rC;

        asm volatile("GET %0,rQ" : "=r" (rC));

        return rC;
}

static inline long unsigned getIntrMask(void) {
        long unsigned rC;

        asm volatile("GET %0,rK" : "=r" (rC));

        return rC;
}


static inline void setIntrMask(long unsigned mask) {
        asm volatile("PUT rK,%0" :: "r" (mask));}

static inline void setInterruptVector(long unsigned addr) {
        asm volatile("PUT rTT,%0" :: "r" (addr)); }

static inline void setInterval(long unsigned v) {
        asm volatile("PUT rI,%0" :: "r" (v)); }


#define get_switches() MMIX_IOSPACE[5]
#define SW0 1
#define SW1 2
#define SW2 4
#define SW3 8


#define DAC_both MMIX_IOSPACE[17]

#define FREQUENCY 25000000

#endif
