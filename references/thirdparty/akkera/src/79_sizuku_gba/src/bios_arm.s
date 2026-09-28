	.ARM
	.ALIGN
	.SECTION .iwram,"ax",%progbits

	.GLOBAL		LZ77UnCompWram
	.GLOBAL		LZ77UnCompVram
	.GLOBAL		CpuSet
	.GLOBAL		CpuFastSet
	.GLOBAL		SoftReset

@extern void LZ77UnCompWram(void *Srcp, void *Destp)
LZ77UnCompWram:

	stmfd	sp!,{r0-r12,lr}
0:
	ldrb	r3,[r0],#1
	cmp		r3,#0x20
	beq		0b

	sub		r0,r0,#1

	swi	#0x110000
	ldmfd	sp!,{r0-r12,lr}
	bx lr

	.ALIGN
	.POOL

@extern void LZ77UnCompVram(void *Srcp, void *Destp)
LZ77UnCompVram:

	stmfd	sp!,{r0-r12,lr}
0:
	ldrb	r3,[r0],#1
	cmp		r3,#0x20
	beq		0b

	sub		r0,r0,#1

	swi	#0x120000
	ldmfd	sp!,{r0-r12,lr}
	bx lr

	.ALIGN
	.POOL

@extern void CpuSet(u32 src, u32 dst, u32 flag)
CpuSet:

@	stmfd	sp!,{r0-r12,lr}

	swi	#0x0b0000
@	ldmfd	sp!,{r0-r12,lr}
	bx lr

@extern void CpuFastSet(u32 src, u32 dst, u32 flag)
CpuFastSet:

	stmfd	sp!,{r0-r12,lr}

	swi	#0x0c0000
	ldmfd	sp!,{r0-r12,lr}
	bx lr

SoftReset:

	stmfd	sp!,{r0-r12,lr}

	swi	#0x010000
	ldmfd	sp!,{r0-r12,lr}
	bx lr

	.ALIGN
	.POOL
	.END
