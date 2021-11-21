.section .rodata
.Lhello_str:
.string "hellohworld!\n"

.type   hello_addr, @object
.size   hello_addr, 4
.align 2
hello_addr:
	.word .Lhello_str

.text
.align 4
.global _start
_start:
	li t0, 13 /* size of our string */
	lui t1, %hi(hello_addr)
	lw t1, %lo(hello_addr)(t1)
	
loop:
	lb a0, 0(t1)
	call uart_write
	addi x7, x7, -1
	addi t1, t1, 1
	bnez x7, loop

1:
	j 1b

uart_write:
	lui     a5,0x82003
1:
	lw      a4,4(a5) # 82003004
	bnez    a4,1b
	sw      a0,0(a5)
	li      a4,1
	sw      a4,16(a5)
	ret
