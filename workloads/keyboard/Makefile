target: draw.txt

include ../Makefile

CFLAGS=-Wall -O -fomit-frame-pointer -I../common

interrupts.o test-keyboard.o: ../common/fb-io.h

test-keyboard.elf: interrupts.o test-keyboard.o stdio.o fb-io.o interrupts.o
	$(CC) $^ -Ttext=1000 -o $@

draw.elf: interrupts.o draw.o stdio.o fb-io.o interrupts.o
	$(CC) $^ -Ttext=1000 -o $@

stdio.o: ../common/stdio.c
	$(CC) $(CFLAGS) -c $< -o $@

interrupts.o: ../common/interrupts.S
	$(CC) $(CFLAGS) -c $< -o $@

fb-io.o: ../common/fb-io.c
	$(CC) $(CFLAGS) -c $< -o $@
