FPGAMMIX_DIR=/home/tommy/fpgammix
MMIX_TOOLS_BIN=/opt/mmix/bin

# XXX -mno-base-addresses should be the default!  -mbase-addresses is
# completely unscalable, running out of globals within 30 uses.

#CFLAGS=-mno-base-addresses -O2 -fomit-frame-pointer
MMIXCC=$(MMIX_TOOLS_BIN)/mmix-gcc
CFLAGS=-O -fomit-frame-pointer -std=gnu99
LDOPTS=
#LDOPTS=-Ttext=80000000
T=1

# Four ways to run %:
# - via the mmix userlevel simuator: %.mmixsim
# - via the mmmix pipeline simuator: %.mmmixsim
# - via the RTL implementation: %.rtlsim
# - uploaded to tinymon on FPGA: %.txt + manual upload (for now)
#
# In future possible pushed via z-modem or even UDP broadcasts

%.mmixsim: %.mmo
	mmix -l -t$(T) $<

%.mmmixsim: %.mmb
	(echo v1;echo @8000000000005000;echo 999999) | mmmix ../common/plain.mmconfig $<

%.rtlsim: %.txt $(FPGAMMIX_DIR)/rtl/Icarus/initmem.data
	cp $< $(FPGAMMIX_DIR)/rtl/Icarus/input.txt
	$(MAKE) -C $(FPGAMMIX_DIR)/rtl/Icarus;

####

%.mmo: %.mms
	mmixal -l $@.lst -o $@ $<

%.mmo: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objcopy -I elf64-mmix -O mmo $< $@

%.mmb: %.mmo
	mmix -D$@ $<

%.txt: %.elf
	$(MMIX_TOOLS_BIN)/mmix-strip $< -o $<.stripped
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $<.stripped|cut -d' ' -f-6 > $@
	$(MMIX_TOOLS_BIN)/mmix-nm $< |grep 'T Main'|(read x y;echo " $$x"G) >> $@

# The default .elf rule only applies to the most trivial of examples
# XXX To improve in future
%.elf: %.o
	$(MMIXCC) $(CFLAGS)  -Ttext=800 -melf $< -o $@
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $@

%.o: %.c Makefile
	$(MMIXCC) $(CFLAGS) -c $< -o $@

%.o: %.s Makefile
	$(MMIXCC) $(CFLAGS) -c $< -o $@

%.o: %.S Makefile
	$(MMIXCC) $(CFLAGS) -c $< -o $@

%.o: %.mmo
	$(MMIX_TOOLS_BIN)/mmix-objcopy -I mmo -O elf64-mmix $< $@

%.data: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $< | grep '^ '|cut -d' ' -f3-6|tr ' ' '\n' | grep -v '^$$' > $@

%.dis: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $<

clean:
	-rm *.elf *.elf.stripped *.o *.txt *.mmo *.mmb *.data *.dis
