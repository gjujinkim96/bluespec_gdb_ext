li a2, 5
li a4, 3
li a6, 7
nop
nop
nop
nop
nop
add a1, a2, a2
add a3, a2, a4
sub a2, a1, a4
nop
nop
nop
nop
nop
sub a5, a2, a6
mv a0, a5
csrw 0x780, a0