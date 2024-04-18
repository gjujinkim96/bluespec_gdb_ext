li a1, 1000
li a2, 7
sw a2, 8(a1)
li a2, 0
li a4, 2
li a5, 1
nop
nop
nop
nop
nop
lw a2, 8(a1)
add a3, a2, a4
sub a5, a2, a5
nop
nop
nop
nop
nop
li a4, 15
add a5, a3, a5
sub a5, a5, a4
mv a0, a5
csrw 0x780, a0