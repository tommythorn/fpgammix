TARGET=mmix

QUIET=@
MAKE_OPT=--quiet --no-print-directory

TESTS=test-add

usage:
	@echo "Usage: make test-all TARGET={mmix,mmmix,fpgammix-sim,fpgammix-hw}"

test-all: $(TESTS:%=%.run)

%.run: %
	$(QUIET)$(MAKE) $(MAKE_OPT) -C $< run TARGET=$(TARGET)
