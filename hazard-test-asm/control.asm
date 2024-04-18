li a1, 10
li a2, 5
li a7, 14
bge a1, a2, label1
addi a5, a5, 1
label1:
addi a5, a5, 2
li a2, 20
bge a1, a2, label2
addi a5, a5, 4
label2:
addi a5, a5, 8
sub a5, a5, a7
mv a0, a5
csrw 0x780, a0