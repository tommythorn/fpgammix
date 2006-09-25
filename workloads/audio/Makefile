target: test-audio.txt

include ../Makefile

CFLAGS=-Wall -O -fomit-frame-pointer -I../common
test-audio.elf: test-audio.o stdio.o fb-io.o interrupts.o
	$(CC) $^ -Ttext=1000 -o $@

stdio.o: ../common/stdio.c
	$(CC) $(CFLAGS) -c $< -o $@

interrupts.o: ../common/interrupts.S Makefile
	$(CC) -c $< -o $@

fb-io.o: ../common/fb-io.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@
