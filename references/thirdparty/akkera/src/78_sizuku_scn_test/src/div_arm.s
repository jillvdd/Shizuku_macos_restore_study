@「isildur's Gameboy Advance coding and ARM assembly page」のソースを拝借しています
@
@http://www.geocities.com/v_d_d/gba/math.html
@2007/04/17


@ Division routines by Dooby
@ 
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

	.ARM
	.ALIGN 2
	.SECTION .iwram,"ax",%progbits

	.GLOBAL		_UMod
	.GLOBAL		_UDiv
	.GLOBAL		_Div

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ u32 UMod(u32 numerator, u32 denominator)
@ Equivalent to 'n % d' in C
@ a1 = top
@ a2 = bottom
@ a3 = temp
@
_UMod:
	mov	a3, a2		@ Put divisor in temp.
	cmp	a3, a1, lsr #1	@ Is it > top/2?
umod_x2:
	movls	a3, a3, lsl #1	@ No, so double it.
	cmp	a3, a1, lsr #1	@ Is it > top/2?
	bls	umod_x2		@ No - loop.
umod_sub:
	cmp	a1, a3		@ Can we subtract temp?
	subcs	a1, a1, a3	@ Yes - so do.
	mov	a3, a3, lsr #1	@ Halve temp.
	cmp	a3, a2		@ Have we gone past the divisor?
	bhs	umod_sub	@ No - loop.
	
	bx	lr		@ Return remainder in a1.

	.ALIGN
	.POOL

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ u32 UDiv(u32 numerator, u32 denominator)
@ Equivalent to '(int)(n / d)' in C
@ a1 = top
@ a2 = bottom
@ a3 = temp
@ a4 = div
_UDiv:
	mov	a3, a2			@ Put divisor in temp.
	cmp	a3, a1, lsr #1		@ Is it > top/2?
udiv_x2:
	movls	a3, a3, lsl #1		@ No, so double it.
	cmp	a3, a1, lsr #1		@ Is it > top/2?
	bls	udiv_x2			@ No - loop.
	mov	a4, #0			@ Initialise quotient.
udiv_sub:
	cmp	a1, a3			@ Can we subtract temp?
	subcs	a1, a1, a3		@ Yes - so do.
	adc	a4, a4, a4		@ Double div and add new bit.
	mov	a3, a3, lsr #1		@ Halve temp.
	cmp	a3, a2			@ Have we gone past the divisor?
	bhs	udiv_sub		@ No - loop.
	mov	a1, a4			@ Return remainder in a1.

	bx	lr			@ And exit.

	.ALIGN
	.POOL

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@
@ s32 Div(s32 numerator, s32 denominator)
@ Equivalent to '(int)(n / d)' in C
@ a1 = top
@ a2 = bottom
@ a3 = temp
@ a4 = div
_Div:
@ This was added as a hacky after thought.
	cmp	a2, #0		@ Uh oh, division by zero.
	beq	div_zero
	mov	ip, #1		@ Set sign +ve.
	cmp	a1, #0		@ Is top -ve?
	rsblt	ip, ip, #0	@ Flip sign if top -ve.
	rsblt	a1, a1, #0	@ Flip top if -ve.
	movs	a3, a2		@ Put divisor in temp.
	rsbmi	ip, ip, #0	@ Flip sign if divisor -ve.
	rsbmi	a2, a2, #0	@ Flip bottom if -ve.
	rsbmi	a3, a3, #0	@ Flip bottom if -ve.
	cmp	a3, a1, lsr #1	@ Is it > top/2?
div_x2:
	movls	a3, a3, lsl #1	@ No, so double it.
	cmp	a3, a1, lsr #1	@ Is it > top/2?
	bls	div_x2		@ No - loop.
	mov	a4, #0		@ Initialise quotient.
div_sub:
	cmp	a1, a3		@ Can we subtract temp?
	subcs	a1, a1, a3	@ Yes - so do.
	adc	a4, a4, a4	@ Double div and add new bit.
	mov	a3, a3, lsr #1	@ Halve temp.
	cmp	a3, a2		@ Have we gone past the divisor?
	bhs	div_sub		@ No - loop.
	mov	a1, a4		@ Return remainder in a1.
	cmp	ip, #0		@ Was sign -ve?
	rsblt	a1, a1, #0	@ Negate result if so.
	
	bx	lr		@ And exit.
div_zero:
	cmp	a1, #0
	mvn	a1, #0x80000000	@ Infinity
	rsblt	a1, a1, #0	@ or -infinity.
	bx	lr

	.ALIGN
	.POOL
	.END
