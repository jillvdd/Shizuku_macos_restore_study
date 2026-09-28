
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"

#include "screen.h"

//---------------------------------------------------------------------------
//lib.c
extern ST_TIMER Timer;

//---------------------------------------------------------------------------
ST_SCREEN_IMG  ScreenImg  EWRAM_DATA;
u32 dummy ALIGN(4);

//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgInit()
{
	dummy = 0;
	ScreenImgCls();
	LibMode3SetScreenBuffer((u16*)ScreenImg.buf);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgCls()
{
	DMA3Memcpy32((u32)&dummy, (u32)ScreenImg.buf, DMA_SAD_FIX, DMA_DAD_INC, 240*160 / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgUpdate()
{
	DMA3Memcpy32((u32)&ScreenImg.buf, (u32)VideoBuffer, DMA_SAD_INC, DMA_DAD_INC, 240*160 / 4);
}
