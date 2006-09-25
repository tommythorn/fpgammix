#ifndef _FB_IO_H_
#define _FB_IO_H_ 1

extern unsigned long fb_io_x;
extern unsigned long fb_io_y;

void fb_write(char *buf, int);
void fb_cursor_off(void);
void fb_cursor_on(void);
void fb_clear(void);
void fb_gotoxy(unsigned long x, unsigned long y);

#endif
