target: test-stdio.txt

include ../Makefile

CFLAGS=-Wall -O -fomit-frame-pointer
test-stdio.elf: test-stdio.o stdio.o fb-io.o
	$(CC) $^ -Ttext=1000 -o $@

test-stdio.o: test-stdio.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@

interrupts.o: ../common/interrupts.S Makefile
	$(CC) -c $< -o $@

fb-io.o: ../common/fb-io.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@

stdio.o: ../common/stdio.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@
