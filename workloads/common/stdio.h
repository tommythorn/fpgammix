#ifndef _STDIO_H_
#define _STDIO_H_ 1

#include "mmix-iospace.h"
#include "fb-io.h"

extern int stdout;

int mmix_fprintf(int fd, char *format, long arg1, ...);
int mmix_printf(char *format, long arg1, ...);
void write(int, char *, int);
static inline void mmix_putchar(char ch) { write(stdout, &ch, 1); }
void wait_ms(unsigned long ms);
void wait_us(long unsigned us);

#endif
