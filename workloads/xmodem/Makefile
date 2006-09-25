OBJS=main.o xmodem.o crc16.o
#-Wl,--section-start,MMIX.reg_contents=0
#CFLAGS=-mno-base-addresses -O2 -fomit-frame-pointer -Wall
CFLAGS=-O2 -fomit-frame-pointer -Wall
LDFLAGS=-melf -Ttext=800 #-Ttext=80000000
CC=/opt/mmix/bin/mmix-gcc

goal: xmodem.txt xmodem.dis

include ../Makefile

xmodem.elf: $(OBJS)
	/opt/mmix/bin/mmix-ld -Ttext=800 -melf64mmix $^ -o $@

main.o: Makefile xmodem.h
xmodem.o: Makefile xmodem.h crc16.h host.h
crc16.o: Makefile crc16.h

%.dis: %.elf
	/opt/mmix/bin/mmix-objdump -d $<
	/opt/mmix/bin/mmix-objdump -s $<




#	/opt/mmix/bin/mmix-objcopy -O mmo $< /tmp/xx
#	mmotype /tmp/xx
