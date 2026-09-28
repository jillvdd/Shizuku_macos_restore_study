
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"

#include "main.h"

//#include "header\font\BGFont.h"


//Mode3
//---------------------------------------------------------------------------

typedef struct {
	u16 buf[SCREEN_CX][SCREEN_CY] ALIGN(4);
	u16 cnt;								//‰æ‘œ‚ÌŒÂ”
	u32 num;								//Œ»Ý“Ç‚Ýž‚ñ‚Å‚¢‚é”Ô†
} ST_VIEW;

//---------------------------------------------------------------------------
ST_VIEW View EWRAM_DATA;

u8  State;

//---------------------------------------------------------------------------
EWRAM_CODE int main()
{
	State = STATE_INIT;

	for(;;)
	{
		switch(State)
		{
			case STATE_INIT:  StateInit();  break;
			case STATE_RESET: StateReset(); break;
			case STATE_DRAW:  StateDraw();  break;
			case STATE_INPUT: StateInput(); break;

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
	InitKey();
	InitIRQ();
	InitFont();
	InitSprite();
	InitLib();

	SetMode(MODE_3 | BG2_ENABLE | OBJ_ENABLE | OBJ_MAP_2D);

	State = STATE_RESET;
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitWS()
{
	REG_WSCNT = 0x4317;
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
	REG_IE       = IRQ_BIT_TIMER0;

	REG_TM0D     = 65536 - 2621;			// (((16*1024*1024) / 64) * 10) / 1000
	REG_TM0CNT   = TM_ENABLE | TM_FREQ_PER_64 | TM_USEIRQ;

	REG_IME      = IRQ_MASTER_ON;
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitFont()
{

	ST_FONT_SRC sing;		//‘SŠp•¶Žš
	ST_FONT_SRC half;		//”¼Šp•¶Žš

	sing.pDat   = (u8*)&mplus_j10rBitmap;
	sing.pSheet = (u16*)&mplus_jfnt_txt;
	sing.imgCx  = MPLUS_J10R_IMG_CX;
	sing.cnt    = MPLUS_J10R_FONT_CNT;
	sing.cx     = MPLUS_J10R_FONT_CX;
	sing.cy     = MPLUS_J10R_FONT_CY;

	half.pDat   = (u8*)&mplus_s10rBitmap;
	half.pSheet = (u16*)&mplus_sfnt_txt;
	half.imgCx  = MPLUS_S10R_IMG_CX;
	half.cnt    = MPLUS_S10R_FONT_CNT;
	half.cx     = MPLUS_S10R_FONT_CX;
	half.cy     = MPLUS_S10R_FONT_CY;

	Mode3SetFont(&sing, &half);
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitSprite()
{
	SpriteInit();

	SpriteSetPalData16((u16*)&sprPal);
	SpriteSetData((u16*)&sprTiles, sprTilesLen);
}
//---------------------------------------------------------------------------
EWRAM_CODE void InitLib()
{
	LibInit();
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateReset()
{
	ViewInit();

	State = STATE_DRAW;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewInit()
{
	ST_VIEW* p = &View;

	if( GBFSInit() == FALSE )
	{
		ErrorMessage("GBFS file not found.", NULL);
	}

	u16 cnt = GBFSGetFileCnt();
	if(cnt == 0)
	{
		ErrorMessage("GBFS file 0 Cnt.", NULL);
	}

//	TRACEOUT("GBFS cnt: %d\n", cnt);
	p->num = 0;
	p->cnt = cnt;

	LibMode3SetScreenBuffer((u16*)&p->buf);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewBufDrawImg()
{
	u8* pImg = GBFSGetFilePointer2(View.num);

	LZ77UnCompWram(pImg, View.buf);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewBufDrawName()
{
	u8* pName = GBFSGetFileName();

	Mode3DrawFillBox(0, 149, 240, 11, RGB(0,0,0));
	Mode3DrawFontStr(7*10, 149, pName, COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewBufDrawNum()
{
	static const u8 strNum[10] = { '[', '0', '0', '0', '/', '0', '0', '0', ']', 0x00 };
	u8 str[10];
	u8 strLeft[10];
	u8 strRight[10];

	_Strncpy(str, (u8*)strNum, 12);
	_I_compute(View.num+1, 10, (char*)strLeft,  3);
	_I_compute(View.cnt,   10, (char*)strRight, 3);

	str[1] = strLeft[0];
	str[2] = strLeft[1];
	str[3] = strLeft[2];

	str[5] = strRight[0];
	str[6] = strRight[1];
	str[7] = strRight[2];

	Mode3DrawFontStr(0, 149, str, COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewVRAMDrawBuf()
{
	REG_DM3SAD = (u32)&View.buf;
	REG_DM3DAD = (u32)VideoBuffer;
	REG_DM3CNT = (240 * 160 / 2)
	             | ( (DMA_SIZE_32 | DMA_TRANSFER_ON | DMA_TIMING_NOW | DMA_REPEAT_OFF |
	                  DMA_SAD_INC | DMA_DAD_INC     | DMA_INTR_OFF) << 16 );
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateDraw()
{
	ViewBufDrawImg();
	ViewBufDrawName();
	ViewBufDrawNum();

	//VCOUNT‚ª‰æ–ÊŠO‚É‚È‚Á‚½‚çVRAM‚Ö‘‚«ž‚Ý‚Ü‚·
	WaitForVsync();
	ViewVRAMDrawBuf();

	State = STATE_INPUT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void StateInput()
{
	ViewInput();

	State = STATE_DRAW;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ViewInput()
{
	ST_VIEW* p = &View;
	u16 key;

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
			continue;
		}
		else if(key & KEY_LEFT)
		{
			if(p->num == 0) continue;

			p->num--;
			return;
		}
		else if(key & KEY_RIGHT)
		{
			if(p->num+1 >= p->cnt) continue;

			p->num++;
			return;
		}
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void ErrorMessage(char* msg1, char* msg2)
{
	if(msg1 != NULL) Mode3DrawFontStr(0, 0, (u8*)msg1, COLOR_WHITE);
	if(msg2 != NULL) Mode3DrawFontStr(0,11, (u8*)msg2, COLOR_WHITE);

	for(;;){}
}
