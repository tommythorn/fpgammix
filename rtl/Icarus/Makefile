TOOLSDIR=../../tools

SRC= icarus_toplevel.v ../core.v ../memory_interface.v ../system.v \
     ../filter.v ../pdm.v                                          \
     ../rs232out.v ../rs232in.v ../vga.v ../interconnect.v         \
     regfile.v idt71v416s10.v

run: fpgammix
	./fpgammix

fpgammix: initmem.data $(SRC) ../mmix_opcodes.v
	/opt/iverilog-0.8.2/bin/iverilog -Wimplicit -I.. $(SRC) -o fpgammix
#	iverilog -B/home/tommy/.lib/ivl -I.. $(SRC) -o fpgammix

mifs: ../initmem.mif ../info_flags.mif

../initmem.mif: initmem.data
	$(TOOLSDIR)/data2mif $< > $@

../info_flags.mif: info_flags.data
	$(TOOLSDIR)/data2mif -w8 -l256 $< > $@

clean:
	-rm *.mmo *.lst

realclean: clean
	-rm fpgammix
