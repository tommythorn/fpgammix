target: ../../rtl/initmem.mif ../../rtl/Icarus/initmem.data

include ../Makefile

tinymon.elf: start.o tinymon.o
	/opt/mmix/bin/mmix-ld -Ttext=80000000 -m elf64mmix $^ -o $@

tinymon.o: tinymon.c Makefile
	$(CC) $(CFLAGS) -mno-base-addresses  -c $< -o $@

../../rtl/initmem.mif: tinymon.mif
	cp $< $@

../../rtl/Icarus/initmem.data: tinymon.data
	cp $< $@

