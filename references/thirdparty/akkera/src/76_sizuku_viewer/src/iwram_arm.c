
#include "inc.h"

#include "gbfs.h"
#include "lib.h"
#include "minix.h"

#include "iwram_arm.h"

//---------------------------------------------------------------------------
//lib.c
extern ST_TIMER Timer;

//---------------------------------------------------------------------------
IWRAM_CODE void IRQUserHandler()
{
	REG_IME  = IRQ_MASTER_OFF;
	u16 flag = REG_IF;

	if(flag & IRQ_BIT_TIMER0)
	{
		Timer.clockTick += TIMER_INTMS;
	}

	REG_IF  = flag;
	REG_IME = IRQ_MASTER_ON;
}
