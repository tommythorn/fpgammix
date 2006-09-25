target: test-emulation.txt

include ../common/Rules.mk

%.mmmixsim: %.mmb
	(echo v1;echo @8000000000005000;echo 999999) | mmmix nodiv.mmconfig $<

interrupts.o test-emulation.o: ../common/fb-io.h

test-emulation.elf: interrupts.o test-emulation.o stdio.o fb-io.o interrupts.o
	$(MMIXCC) $^ -Ttext=1000 -o $@

stdio.o: ../common/stdio.c
	$(MMIXCC) $(CFLAGS) -c $< -o $@

interrupts.o: ../common/interrupts.S
	$(MMIXCC) -DUSER_TRAPHANDLER $(CFLAGS) -c $< -o $@

fb-io.o: ../common/fb-io.c
	$(MMIXCC) $(CFLAGS) -c $< -o $@

test-divu.elf: test-divu.o
	$(MMIX_TOOLS_BIN)/mmix-ld -Ttext=5000 $< -o $@


test-divu2.elf: test-divu2.mmo
	$(MMIX_TOOLS_BIN)/mmix-objcopy -I mmo -O elf64-mmix $< $@
