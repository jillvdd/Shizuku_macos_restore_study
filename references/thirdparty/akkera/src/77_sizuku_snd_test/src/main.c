
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"

#include "screen.h"
#include "ad_arm.h"
#include "main.h"

//#include "header\font\BGFont.h"

//Mode3

//DMA1 音楽のデータ転送
//DMA3 データ転送

//Timer0 音楽
//Timer3 キー入力

//---------------------------------------------------------------------------
typedef struct {
	u16 cnt;
	u16 num;
	u8  strSel[10];
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
			case STATE_DRAW:   StateDraw();   break;
			case STATE_MUSIC:  StateMusic();  break;

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
	REG_IE       = IRQ_BIT_TIMER3 | IRQ_BIT_VBLANK;

	REG_TM3D     = 65536 - 2621;			// (((16*1024*1024) / 64) * 10) / 1000
	REG_TM3CNT   = TM_ENABLE | TM_FREQ_PER_64 | TM_USEIRQ;

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
EWRAM_CODE void InitGBFS()
{
	ST_FILE* p = &File;

	if( GBFSInit() == FALSE )
	{
		ErrorMessage("GBFS Not Found.", NULL);
	}

	u16 cnt = GBFSGetFileCnt();
	if(cnt == 0)
	{
		ErrorMessage("GBFS File 0 Cnt.", NULL);
	}

	p->cnt = cnt;
	p->num = 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateReset()
{
	ScreenImgInit();
	AdInit();

	State = STATE_DRAW;
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
			goto Sel;
		}

		if(key & KEY_LEFT)
		{
			if(p->num == 0) continue;

			p->num--;
			goto Draw;
		}
		else if(key & KEY_RIGHT)
		{
			if(p->num+1 >= p->cnt) continue;

			p->num++;
			goto Draw;
		}
	}

Sel:
	State = STATE_MUSIC;
	return;

Draw:
	State = STATE_DRAW;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScrCalcStrSelect()
{
	_Sprintf((char*)File.strSel, "[%03d/%03d]", File.num+1, File.cnt);
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateDraw()
{
	ScreenImgCls();
	ScrCalcStrSelect();
	ScrDrawStrSelect();

	WaitForVsync();
	ScreenImgUpdate();

	State = STATE_INPUT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScrDrawStrSelect()
{
	ST_FILE* p = &File;

	Mode3DrawFontStr(   0, 0, (u8*)"Select 8ad File:", COLOR_WHITE);
	Mode3DrawFontStr(17*7, 0, (u8*)p->strSel, COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateMusic()
{
	u8* pFile = GBFSGetFilePointer2(File.num);
	u32 len   = GBFSGetFileLength();

	AdStart(pFile, len, TRUE);

	State = STATE_INPUT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ErrorMessage(char* msg1, char* msg2)
{
	if(msg1 != NULL) Mode3DrawFontStr(0, 0, (u8*)msg1, COLOR_WHITE);
	if(msg2 != NULL) Mode3DrawFontStr(0,11, (u8*)msg2, COLOR_WHITE);

	for(;;){}
}
