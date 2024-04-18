li a2, 3
li a7, 3
nop
nop
nop
nop
nop
add a1, a2, a2
sub a3, a1, a2
nop
nop
nop
nop
nop
sub a5, a3, a7
mv a0, a5
csrw 0x780, a0