target: test-interval.txt

include ../Makefile

test-interval.o: test-interval.S Makefile
	$(CC) $(CFLAGS) -mno-base-addresses -c $< -o $@

test-interval.elf: test-interval.o
	/opt/mmix/bin/mmix-ld -Ttext=0x5000 -melf64mmix $< -o $@
	/opt/mmix/bin/mmix-objdump -d $@

