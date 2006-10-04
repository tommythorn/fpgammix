FPGAMMIX_DIR=/home/tommy/fpgammix
MMIX_TOOLS_BIN=/opt/mmix/bin

# XXX -mno-base-addresses should be the default!  -mbase-addresses is
# completely unscalable, running out of globals within 30 uses.

all: readmoto.mmo hwfb.elf #myfib-verbose.sim

#CFLAGS=-mno-base-addresses -O2 -fomit-frame-pointer
CC=$(MMIX_TOOLS_BIN)/mmix-gcc
CFLAGS=-O -fomit-frame-pointer -std=gnu99
LDOPTS=
#LDOPTS=-Ttext=80000000
T=1

%.run-fpgammix-sim: %.txt # $(FPGAMMIX_DIR)/rtl/Icarus/initmem.data
	$(MAKE) -C $(FPGAMMIX_DIR)/workloads/tinymon
	cp $< $(FPGAMMIX_DIR)/rtl/Icarus/input.txt
	$(MAKE) -C $(FPGAMMIX_DIR)/rtl/Icarus;

%.mmo: %.elf
	mmix-objcopy -I elf64-mmix -O mmo $< $@

overflow3.elf: overflow3.o
	$(MMIX_TOOLS_BIN)/mmix-ld -Ttext=0 -melf64mmix $< -o $@
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $@



%.mmosim: %.mmo
	mmix -l -t$(T) $<

%.elfsim: %.elf
	mmix -t$(T) $<

%.mmo: %.mms
	mmixal -l $@.lst -o $@ $<

#%.o: %.mmo
#	$(MMIX_TOOLS_BIN)/mmix-objcopy -I mmo -O elf64-mmix $< $@

%.o: %.c Makefile
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s Makefile
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.S Makefile
	$(CC) $(CFLAGS) -c $< -o $@

%.elf.lite: %.o Makefile
	$(MMIX_TOOLS_BIN)/mmix-ld -Ttext=800 -melf64mmix $< -o $@
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $@

%.elf: %.o
	$(CC) $(CFLAGS)  -Ttext=800 -melf $< -o $@
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $@

# Sigh, SREC doesn't cover 64-bit addresses.
%.data.lite: %.elf.lite
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $< | grep '^ '|cut -d' ' -f3-6|tr ' ' '\n' | grep -v '^$$' > $@

%.data: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $< | grep '^ '|cut -d' ' -f3-6|tr ' ' '\n' | grep -v '^$$' > $@

%.mif: %.data
	$(FPGAMMIX_DIR)/tools/data2mif.sh $< > $@

%.txt.lite: %.elf.lite
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $<|cut -d' ' -f-6 > $@
	$(MMIX_TOOLS_BIN)/mmix-nm $< |grep 'T main'|(read x y;echo " $$x"G) >> $@

# $(MMIX_TOOLS_BIN)/mmix-strip $<

%.txt: %.elf
	$(MMIX_TOOLS_BIN)/mmix-strip $< -o $<.stripped
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $<.stripped|cut -d' ' -f-6 > $@
	$(MMIX_TOOLS_BIN)/mmix-nm $< |grep 'T Main'|(read x y;echo " $$x"G) >> $@


%.dis: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $<

%.emu: %.txt
	cp $< $(FPGAMMIX_DIR)/rtl/Icarus/input.txt
	cd $(FPGAMMIX_DIR)/rtl/Icarus; make

clean:
	-rm *.elf *.elf.stripped *.o *.txt
