
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "ad_arm.h"
#include "gbfs.h"
#include "lib.h"

#include "screen.h"
#include "script.h"
#include "sizuku.h"
#include "anime.h"
#include "main.h"

//#include "header\font\BGFont.h"


//Mode3

//DMA0 none
//DMA1 8ad sound
//DMA2 none
//DMA3 none

//Timer0 8ad sound
//Timer1 none
//TImer2 key input
//Timer3 key wait(srand)

//---------------------------------------------------------------------------
u8 State;

//---------------------------------------------------------------------------
EWRAM_CODE int main()
{
	State = STATE_INIT;

	for(;;)
	{
		switch(State)
		{
			case STATE_INIT:    StateInit();    break;
			case STATE_RESET:   StateReset();   break;
			case STATE_JINGLE:  StateJingle();  break;
			case STATE_OPENING: StateOpening(); break;
			case STATE_TITLE:   StateTitle();   break;
			case STATE_SCRIPT:  StateScript();  break;

			default:
				DebugMessage("Err: Main State");
				break;
		}
	}


	return 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateInit()
{
	InitWS();
	InitLib();
	InitKey();
	InitIRQ();
	InitFont();
	InitSprite();

	SetMode(MODE_3 | BG2_ENABLE | OBJ_ENABLE | OBJ_MAP_2D);
	InitGBFS();

	State = STATE_RESET;
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitWS()
{
	REG_WSCNT = 0x4317;
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitLib()
{
	LibInit();
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitKey()
{
	KeyInit();
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitIRQ()
{
	REG_INTERUPT = (u32)IRQUserHandler;
	REG_IE       = IRQ_BIT_TIMER2;

	REG_TM2D     = 65536 - 2621;			// (((16*1024*1024) / 64) * 10) / 1000
	REG_TM2CNT   = TM_ENABLE | TM_FREQ_PER_64 | TM_USEIRQ;

	REG_IME      = IRQ_MASTER_ON;
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitFont()
{
	ST_FONT_SRC half;		//半角文字

	half.pDat   = (u8*)&mplus_s10rBitmap;
	half.pSheet = (u16*)&mplus_sfnt_txt;
	half.imgCx  = MPLUS_S10R_IMG_CX;
	half.cnt    = MPLUS_S10R_FONT_CNT;
	half.cx     = MPLUS_S10R_FONT_CX;
	half.cy     = MPLUS_S10R_FONT_CY;

	Mode3SetFont(NULL, &half);
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitSprite()
{
	SpriteInit();

	SpriteSetPalData16((u16*)&sprPal);
	SpriteSetData((u16*)&sprTiles, sprTilesLen);
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitGBFS()
{
	if( GBFSInit() == FALSE )
	{
		ErrorMessage("GBFS Not Found.", NULL);
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateReset()
{
	AdInit();

	FontLeafInit();
	ScreenImgInit();
	ScreenFontInit();
	ScreenCursorInit();

	SizukuInit();
	ScriptInit();
	HistoryInit();
	MenuInit();

	State = STATE_JINGLE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateJingle()
{
	AnimeExecJingle();

	State = ( AnimeIsKey() == TRUE ) ? STATE_TITLE : STATE_OPENING;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateOpening()
{
	AnimeExecOpening();

	State = STATE_TITLE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateTitle()
{
	//オープニングが途中で中断されたか、ゲーム本編から戻ってきたかチェックをします
	if( AnimeIsKey() == TRUE || SizukuIsEndFlag() == TRUE )
	{
		AnimeExecTitle();
	}

	ScreenImgFadeIn(BLEND_MODE_DARK, 0, 4, 20);

	MenuSetListStart();
	MenuProc();

	ScreenImgFadeIn(BLEND_MODE_DARK, 4, 15, 20);

	ScreenImgClear();
	ScreenImgUpdate();

	State = STATE_SCRIPT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateScript()
{
	ScriptExec();

	State = STATE_TITLE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ErrorMessage(char* msg1, char* msg2)
{
	ScreenImgFadeOut(0);
	LibMode3SetScreenBuffer((u16*)VideoBuffer);

	if(msg1 != NULL) Mode3DrawFontStr(0,  0, (u8*)msg1, COLOR_WHITE);
	if(msg2 != NULL) Mode3DrawFontStr(0, 11, (u8*)msg2, COLOR_WHITE);

	for(;;){}
}
