fpgammix
========

Partial implementation of Knuth's MMIX processor (FPGA softcore)

This is a quick and dirty hack, but complete enough to run various
graphics demos.

The motivation behind this was to evaluate MMIX as a softcore.  My
preliminary conclusion is that it's not ideal and my effort is better
directed at other targets, such as RISC-V.  I made simple pipelined
32-bit RISC-V softcore [YARVI](https://github.com/tommythorn/yari).

The implementation is left here for posterity, but there are bits and
pieces that may be useful.

## The problem with MMIX

The current implementation is a classic sequenced implementation, that
is, we iterate a state machine through the states like fetch
instruction, read register arguments, calculate load address,
writeback result, etc.  That is probably the easiest possible way to
implement any processor and usually results in reasonably good cycle
time (frequency), but it means taking multiple cycles per instructions
which is pretty far from peak performance.

The first step in improving performance is overlapping these stages,
that is, pipelining.  This requires speculation as we won't know the
full effect of an instruction until it completes (say, a conditional
branch).  Recovering from mispeculation requires restarting the
pipeline (some limited issues can also be handled by stalling part of
the pipeline).  In MMIX there is a lot of implicit state that makes
this speculation less fruitful.

MMIX is also pretty heavyweight.  For instance, the registers are
fetched from a window into a large register file.  This requires an
adder in the decode stage (and some conditional logic for globals).
Also, the larger register file is slower to access than a smaller one
(like in a typical RISC).  The worse problem is that the windowing
semantics is rather involved; writing to a register outside the
current window, grows the window, clearing all the new registers.  The
naive implementation of this (which I use) is a multi-cycle operation
(unacceptable for performance).  Any more performant option
necessarily would migrate some of the burden to the register fetch
(eg. using a bitmap of cleared registers and overwriting read results
with zero).  This doesn't even discuss the semantics involved with
register file over- and underflow.

The register fetch is an important issue, but there are many other
issues like these.  The cheer size of the MMIX definition translates
into a longer implemementation time (annyoing, but fine) and far
worse, a larger design.  If programs compiled to MMIX were
substaintally more efficient then this might be an acceptable
trade-off, but I haven't found that to be the case.

Finally, all the problems complicating a pipelined design, becomes
even bigger issues for a superscalar or out-of-order execution
implementation.

A related and possibly even more serious issue: the ISA appears a
challenging code generation target -- GCC has now dropped support
for MMIX, but the version that did support it reveal a surprising
amount of overhead that isn't apparent in hand-written examples.

## Conclusion
At the end of the day, the value of a processor comes from the
software it executes.  Once we have that, we care about
performance, which ends up being a question of efficiency;
how efficiently we can turn power, area, design-time, etc into
faster execution.  This exercise concluded that the MMIX ISA
includes a lot of complexity that doesn't contribute significantly
to the performance of common programs.
