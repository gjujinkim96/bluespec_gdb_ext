li a1, 1000
li a2, 7
sw a2, 8(a1)
li a2, 0
li a3, 8
li a4, 2
nop
nop
nop
nop
nop
lw a2, 8(a1)
add a2, a3, a4
sub a5, a2, a4
nop
nop
nop
nop
nop
sub a5, a5, a3
mv a0, a5
csrw 0x780, a0