MMIX_TOOLS_BIN=/opt/mmix/bin

%.mmo: %.mms
	mmixal -l $@.lst -o $@ $<

%.mmb: %.mmo
	mmix -D$@ $<

%.run-mmix: %.mmo
	@-echo `basename $< .mmo` '-->' `mmix $<`

%.run-mmix-verbose: %.mmo
	mmix -t9999 $<

%.run-mmmix: %.mmb
	@-echo `basename $< .mmb` '-->' \
	`(echo 999999;echo q) | mmmix ../include/plain.mmconfig $< |tail +2|head -1`

%.run-fpgammix-sim: %.data
	cp $< ../../rtl/Icarus/initmem.data
	$(MAKE) -C $(FPGAMMIX_DIR)/rtl/Icarus;

%.run-fpgammix-hw: %.txt
	@echo "Alas, fpgaMMIX isn't supported yet on real hardware."
	@sz $<

%.run-clean:
	-rm *.mmo *.lst *.mmb

%.data: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -s $< | grep '^ '|cut -d' ' -f3-6|tr ' ' '\n' | grep -v '^$$' > $@

%.dis: %.elf
	$(MMIX_TOOLS_BIN)/mmix-objdump -d $<

%.elf: %.mmo
	$(MMIX_TOOLS_BIN)/mmix-objcopy -O elf64-mmix -I mmo $< $@
