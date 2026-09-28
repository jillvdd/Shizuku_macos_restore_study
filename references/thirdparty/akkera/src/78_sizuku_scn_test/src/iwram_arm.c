
#include "inc.h"

#include "gbfs.h"
#include "lib.h"
#include "minix.h"
#include "ad_arm.h"

#include "screen.h"
#include "iwram_arm.h"

//---------------------------------------------------------------------------
#define MAX_DMA_CHAIN			10

//---------------------------------------------------------------------------
typedef struct {
	u32 src;
	u32 dst;
	u16 size;
	u16 mode;
} ST_DMA;


typedef struct {
	u16    cnt;
	ST_DMA buf[MAX_DMA_CHAIN];
} ST_DMA_CHAIN;

//---------------------------------------------------------------------------
//lib.c
extern ST_TIMER Timer;

//---------------------------------------------------------------------------
ST_DMA_CHAIN DMAChain;

//---------------------------------------------------------------------------
IWRAM_CODE void IRQUserHandler()
{
	REG_IME  = IRQ_MASTER_OFF;
	u16 flag = REG_IF;


	if(flag & IRQ_BIT_VBLANK)
	{
		AdBufferSend();
	}
	else if(flag & IRQ_BIT_VCOUNT)
	{
		if( AdIsEndData() == FALSE )
		{
			AdBufferMixer();
		}
		else
		{
			if( AdIsLoop() == TRUE )
			{
				AdReStart();
			}
			else
			{
				AdStop();
			}
		}
	}
	else if(flag & IRQ_BIT_TIMER2)
	{
		Timer.clockTick += TIMER_INTMS;
		ScreenCursorDrawBlink();
	}

	REG_IF  = flag;
	REG_IME = IRQ_MASTER_ON;
}
//---------------------------------------------------------------------------
IWRAM_CODE void DMAChainInit()
{
	DMAChain.cnt = 0;
}
//---------------------------------------------------------------------------
IWRAM_CODE void DMAChainAdd(u32 src, u32 dst, u16 size, u16 mode)
{
	REG_IME = IRQ_MASTER_OFF;

	ST_DMA* p = &DMAChain.buf[DMAChain.cnt];

	p->src  = src;
	p->dst  = dst;
	p->size = size;
	p->mode = mode | DMA_SIZE_32 | DMA_TRANSFER_ON | DMA_TIMING_NOW | DMA_REPEAT_OFF | DMA_INTR_OFF;

	DMAChain.cnt++;
	if(DMAChain.cnt >= MAX_DMA_CHAIN)
	{
		TRACEOUT("Too Many DMAChain\n");
		for(;;){}
	}

	REG_IME = IRQ_MASTER_ON;
}
//---------------------------------------------------------------------------
IWRAM_CODE void DMAChainTransfer()
{
	u16 i;
	for(i=0; i<DMAChain.cnt; i++)
	{
		REG_DM3SAD   = DMAChain.buf[i].src;
		REG_DM3DAD   = DMAChain.buf[i].dst;
		REG_DM3CNT_L = DMAChain.buf[i].size;
		REG_DM3CNT_H = DMAChain.buf[i].mode;

//		while(REG_IF & IRQ_BIT_DMA3){}
	}

	DMAChain.cnt = 0;
}
