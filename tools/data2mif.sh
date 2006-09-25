#!/bin/bash

depth=256

printf "WIDTH=32;\n"
printf "DEPTH=%d;\n" $depth
printf "ADDRESS_RADIX=HEX;\n"
printf "DATA_RADIX=HEX;\n"
printf "CONTENT BEGIN\n"
a=0
while read v
do
	printf "	%02x  :   %08x ;\n" $a 0x$v
        a=$(($a + 1))
done < $1
printf "	[%02x..%x]  :   00000000;\n" $a $((depth - 1))
printf "END;\n"
