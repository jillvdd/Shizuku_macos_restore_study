
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
#include "main.h"


//#include "header\font\BGFont.h"


//Mode3

//DMA1  8ad sound
//DMA3  ƒf[ƒ^“]‘—

//Timer0 8ad sound
//Timer1 none
//TImer2 key input
//Timer3 key wait(srand)

//---------------------------------------------------------------------------
typedef struct {
	u16 sel;
	u16 maxSel;
	u8  strSel[32];
	u8  strFileName[32];
} ST_FILE;

//---------------------------------------------------------------------------
//screnn.c
extern ST_SCREEN_IMG ScreenImg;

//---------------------------------------------------------------------------
ST_FILE File;
u8  State;

//---------------------------------------------------------------------------
EWRAM_CODE int main()
{
	State = STATE_INIT;

	for(;;)
	{
		switch(State)
		{
			case STATE_INIT:   StateInit();   break;
			case STATE_RESET:  StateReset();  break;
			case STATE_INPUT:  StateInput();  break;
			case STATE_SCRIPT: StateScript(); break;
			case STATE_DRAW:  StateDraw();    break;

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
	ST_FONT_SRC half;		//”¼Šp•¶Žš

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
	ST_FILE* p = &File;

	if( GBFSInit() == FALSE )
	{
		ErrorMessage("GBFS Not Found.", NULL);
	}

	p->sel    = 0;
	p->maxSel = SIZUKU_SCN_CNT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateReset()
{
	AdInit();
//	DMAChainInit();

	FontLeafInit();
	ScreenImgInit();
	ScreenFontInit();
	ScreenCursorInit();

	SizukuInit();
	ScriptInit();
	HistoryInit();

	State = STATE_DRAW;
//	State = STATE_SCRIPT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateInput()
{
	ScrInputSelect();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScrInputSelect()
{
	ST_FILE* p = &File;
	u16 key;

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
			continue;
		}

		if(key & KEY_A)
		{
			goto Scr;
		}

		if(key & KEY_LEFT)
		{
			if(p->sel == 0) continue;

			p->sel--;
			goto Draw;
		}
		else if(key & KEY_RIGHT)
		{
			if(p->sel+1 >= p->maxSel) continue;

			p->sel++;
			goto Draw;
		}
	}

Scr:
	ScriptLoadScenario(p->sel, 1);
	State = STATE_SCRIPT;
	return;

Draw:
	State = STATE_DRAW;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScrCalcStrSelect()
{
	_Sprintf((char*)File.strSel, "[%03d/%03d]", File.sel+1, SIZUKU_SCN_CNT);
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateDraw()
{
	ScrCalcStrSelect();
	ScrDrawStrSelect();

	ScreenImgUpdate();

	State = STATE_INPUT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScrDrawStrSelect()
{
	ST_FILE* p = &File;

	Mode3DrawFillBox(0, 0, 200, 11, COLOR_BLACK);
	Mode3DrawFontStr(   0, 0, (u8*)"Select Scr File:", COLOR_WHITE);
	Mode3DrawFontStr(17*7, 0, (u8*)p->strSel, COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateScript()
{
	ScriptExec();

	State = STATE_RESET;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ErrorMessage(char* msg1, char* msg2)
{
	LibMode3SetScreenBuffer((u16*)VideoBuffer);

	if(msg1 != NULL) Mode3DrawFontStr(0, 0, (u8*)msg1, COLOR_WHITE);
	if(msg2 != NULL) Mode3DrawFontStr(0,11, (u8*)msg2, COLOR_WHITE);

	for(;;){}
}
