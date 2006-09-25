simulate:
	$(MAKE) -C rtl/Icarus

clean:
	rm -f *.rpt *.pin *.summary *.txt *.done *.qdf *.pof *.smsg

realclean: clean
	rm -f *~ *.qws
