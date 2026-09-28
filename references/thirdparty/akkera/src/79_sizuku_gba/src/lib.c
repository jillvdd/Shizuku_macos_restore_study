#include "inc.h"

#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "rand.h"
#include "minix.h"
#include "gbfs.h"
#include "header\mathtable.h"

#include "lib.h"

#define ADR_SRAM     (u8*)0xe000000
#define ADR_ROM_END  (u8*)&__pad_lma + 8

//===========================================================================
/* gba_cart.ld */
extern u8 __pad_lma;		//ROMの終端ポインタ

//===========================================================================
ST_LIB   Lib;
ST_FONT  Font;
ST_KEY   Key;
ST_TIMER Timer;
ST_WAVE  Wave;
ST_SEEK  Seek;
ST_GBFS  GBFS;
ST_FADE  Fade;

//===========================================================================
EWRAM_CODE void LibInit()
{
	ST_LIB* p = &Lib;

	p->screenBuf = VideoBuffer;
}
//===========================================================================
EWRAM_CODE void LibMode3SetScreenBuffer(u16* buf)
{
	Lib.screenBuf = buf;
}
//===========================================================================
EWRAM_CODE void BGSetChrData(u16* chrData, u32 chrSize, u8 chrNo)
{
	u16* BGChr = MEM_BG_CHR(chrNo);
	u32  size  = chrSize >> 1;

	u32 i;
	for(i=0; i<size; i++)
	{
		*BGChr++ = *chrData++;
	}
}
//===========================================================================
EWRAM_CODE void BGSetMapData(u16* mapData, u32 mapSize, u8 mapNo, u16 palNo)
{
	u16* BGMap = MEM_BG_MAP(mapNo);
	u32  size  = mapSize >> 1;

	u32 i;
	for(i=0; i<size; i++)
	{
		*BGMap++ = (*mapData++) | (palNo << 12);
	}
}
//===========================================================================
EWRAM_CODE void BGSetPalData16(u16* palData, u8 palNo)
{
	u16* BGPal = MEM_BG_PAL + (16 * palNo);

	u16 i;
	for(i=0; i<16; i++)
	{
		*BGPal++ = *palData++;
	}
}
//===========================================================================
EWRAM_CODE void BGSetPalData256(u16* palData)
{
	u16* BGPal = MEM_BG_PAL;

	u16 i;
	for(i=0; i<256; i++)
	{
		*BGPal++ = *palData++;
	}
}
//===========================================================================
EWRAM_CODE void BGDrawCls(u8 mapNo, u16 fillChr)
{
	u16 *BGMap = MEM_BG_MAP(mapNo);

	u16 i;
	for(i=0; i<32*32; i++)
	{
		*BGMap++ = fillChr;
	}
}
//===========================================================================
EWRAM_CODE void BGDrawBox(u8 mapNo, u16 sx, u16 sy, u16 cx, u16 cy, u16 fillChr)
{
	u16 *BGMap = MEM_BG_MAP(mapNo) + (sy * 32) + sx;

	u16 x, y;
	for(y=0; y<cy; y++)
	{
		for(x=0; x<cx; x++)
		{
			BGMap[y*32 + x] = fillChr;
		}

		BGMap += 32;
	}
}
//===========================================================================
EWRAM_CODE void BGDrawOrder(u8 mapNo)
{
	u16 x, y;
	u16 chrCnt = 0;

	for(y=0; y<32; y++)
	{
		for(x=0; x<32; x++)
		{
			BGDrawPut(mapNo, x, y, chrCnt++);
		}
	}
}
//===========================================================================
EWRAM_CODE void BGDrawPut(u8 mapNo, u16 x, u16 y, u16 chr)
{
	u16* BGMap = MEM_BG_MAP(mapNo) + x + (y * 32);

	*BGMap = chr;
}
//===========================================================================
EWRAM_CODE void BGDrawStr(u8 mapNo, u16 x, u16 y, u8* str)
{
	u16 chr;
	u16 i=0, dx=0;

	for(;;)
	{
		chr = str[i++];

		if(chr == NULL) return;
		if(chr == CR)   return;
		if(chr == LF)   return;

		if(chr <= 0x7f)
		{
			//1byte char
			BGDrawChr(mapNo, x + dx, y, 0, chr);
		}
		else
		{
			//2byte char

			switch(chr)
			{
				case 0x82: chr = str[i++] - 0x90 + 192; break;
				case 0x83: chr = str[i++] - 0x40 + 304; break;
				default:   chr = str[i++];              break;
			}

			BGDrawChr(mapNo, x + dx, y, 0, chr);
		}
		dx++;
	}
}
//===========================================================================
EWRAM_CODE void BGDrawChr(u8 mapNo, u16 x, u16 y, u8 palNo, u16 chr)
{
	u16* BGMap = MEM_BG_MAP(mapNo) + x + (y * 32);

	*BGMap = chr + (palNo << 12);
}
//===========================================================================
EWRAM_CODE u16 BGGetChr(u8 mapNo, u16 x, u16 y)
{
	u16* BGMap = MEM_BG_MAP(mapNo) + x + (y * 32);

	return *BGMap;
}
//===========================================================================
EWRAM_CODE void Mode3DrawCls(u16 col)
{
	Mode3DrawFillBox(0, 0, SCREEN_CX, SCREEN_CY, col);
}
//===========================================================================
EWRAM_CODE void Mode3DrawFillBox(u16 sx, u16 sy, u16 cx, u16 cy, u16 col)
{
	u16* Screen = Lib.screenBuf + (sy * SCREEN_CX) + sx;

	u16 x, y;
	for(y=0; y<cy; y++)
	{
		for(x=0; x<cx; x++)
		{
			Screen[y*SCREEN_CX + x] = col;
		}
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawBox(u16 sx, u16 sy, u16 cx, u16 cy, u16 col)
{
	Mode3DrawLine(   sx,    sy, sx+cx,    sy, col);
	Mode3DrawLine(   sx,    sy,    sx, sy+cy, col);
	Mode3DrawLine(sx+cx,    sy, sx+cx, sy+cy, col);
	Mode3DrawLine(   sx, sy+cy, sx+cx, sy+cy, col);
}
//===========================================================================
EWRAM_CODE void Mode3DrawPut(u16 x, u16 y, u16 col)
{
	u16* Screen = Lib.screenBuf + x + (y * SCREEN_CX);
	*Screen = col;
}
//===========================================================================
EWRAM_CODE void Mode3DrawLine(u16 x1, u16 y1, u16 x2, u16 y2, u16 col)
{
	s16 dx,dy,sx,sy;
	s16 x, y;
	s16 E;
	s16 i;

	sx = ( x2 > x1 ) ? 1 : -1;
	dx = ( x2 > x1 ) ? x2 - x1 : x1 - x2;
	sy = ( y2 > y1 ) ? 1 : -1;
	dy = ( y2 > y1 ) ? y2 - y1 : y1 - y2;

	x = x1;
	y = y1;

	if(dx >= dy)
	{	//傾きが1以下の場合
		E = -dx;

		for(i=0; i<=dx; i++)
		{
			Mode3DrawPut(x, y, col);
			x += sx;
			E += 2 * dy;
			if(E >= 0)
			{
				y += sy;
				E -= 2 * dx;
			}
		}
	}
	else
	{	//傾きが1より大きい場合
		E = -dy;
		
		for(i=0; i<=dy; i++)
		{
			Mode3DrawPut(x, y, col);
			y += sy;
			E += 2 * dx;
			if(E >= 0)
			{
				x += sx;
				E -= 2 * dy;
			}
		}
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawCircle(u16 sx, u16 sy, u16 rad, u16 col)
{
	u16 x = rad;
	u16 y = 0;
	s16 p = 3 - 2 * rad;

	while(x >= y)
	{
		Mode3DrawPut(sx + x, sy + y, col);
		Mode3DrawPut(sx - x, sy + y, col);
		Mode3DrawPut(sx + x, sy - y, col);
		Mode3DrawPut(sx - x, sy - y, col);
		Mode3DrawPut(sx + y, sy + x, col);
		Mode3DrawPut(sx - y, sy + x, col);
		Mode3DrawPut(sx + y, sy - x, col);
		Mode3DrawPut(sx - y, sy - x, col);

		if (p >= 0)
		{
			x--;
			p -= 4 * x;
		}

		y++;
		p += 4 * y + 2;
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawFillCircle(u16 sx, u16 sy, u16 rad, u16 col)
{
	u16 x = rad;
	u16 y = 0;
	s16 p = 3 - 2 * rad;

	while(x >= y)
	{
		Mode3DrawLine(sx-x, sy+y, sx+x, sy+y, col);
		Mode3DrawLine(sx-x, sy-y, sx+x, sy-y, col);
		Mode3DrawLine(sx-y, sy+x, sx+y, sy+x, col);
		Mode3DrawLine(sx-y, sy-x, sx+y, sy-x, col);

		if(p >= 0)
		{
			x--;
			p -= 4 * x;
		}

		y++;
		p += 4 * y + 2;
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawImage(u16 sx, u16 sy, u16 cx, u16 cy, u16* img)
{
	u16* Screen = Lib.screenBuf + (sy * SCREEN_CX) + sx;

	u16 x, y;
	for(y=0; y<cy; y++)
	{
		for(x=0; x<cx; x++)
		{
			Screen[y*SCREEN_CX + x] = img[y*cx + x];
		}
	}
}
//===========================================================================
EWRAM_CODE void Mode3SetFont(ST_FONT_SRC* s, ST_FONT_SRC* h)
{
	ST_FONT* p = &Font;

	if(s != NULL)
	{
		p->sing.pDat   = s->pDat;
		p->sing.pSheet = s->pSheet;
		p->sing.imgCx  = s->imgCx;
		p->sing.cnt    = s->cnt;
		p->sing.cx     = s->cx;
		p->sing.cy     = s->cy;
	}

	if(h != NULL)
	{
		p->half.pDat   = h->pDat;
		p->half.pSheet = h->pSheet;
		p->half.imgCx  = h->imgCx;
		p->half.cnt    = h->cnt;
		p->half.cx     = h->cx;
		p->half.cy     = h->cy;
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawFontStr(u16 sx, u16 sy, u8* str, u16 col)
{
	ST_FONT* p = &Font;

	u16 chr;
	u16 i=0, x=0, y=0;

	for(;;)
	{
		chr = str[i++];

		if(chr == NULL) return;
		if(chr == CR)   return;
		if(chr == LF)   return;

		//改行処理
		if(sx + x >= SCREEN_CX)
		{
			x  = 0;
			y += p->sing.cy;

			if(sy + y + p->sing.cy >= SCREEN_CY)
			{
				return;
			}
		}

		//全角か半角かのチェックをします
		if( IsSJIS(chr) == TRUE )
		{
			chr = (chr << 8) | str[i++];
			Mode3DrawFontSingChr(sx + x, sy + y, chr, col);
			x += p->sing.cx;
		}
		else
		{
			Mode3DrawFontHalfChr(sx + x, sy + y, chr, col);
			x += p->half.cx;
		}
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawFontSingChr(u16 sx, u16 sy, u16 chr, u16 col)
{
	ST_FONT_SRC* p = &Font.sing;

	//書き込む起点位置を求めます
	u16* pScreen = Lib.screenBuf + (sy * SCREEN_CX) + sx;
	//書き込むフォントデータの位置を求めます
	u8*  pDat    = p->pDat + p->cx * Mode3GetDrawFontIndex(chr, p);

	u16 x, y;
	for(y=0; y<p->cy; y++)
	{
		for(x=0; x<p->cx; x++)
		{
			if(pDat[y*p->imgCx + x] == 0x00)
			{
				continue;
			}

			pScreen[y*SCREEN_CX + x] = col;
		}
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawFontHalfChr(u16 sx, u16 sy, u16 chr, u16 col)
{
	ST_FONT_SRC* p = &Font.half;

	u16* pScreen = Lib.screenBuf + (sy * SCREEN_CX) + sx;
	u8*  pDat    = p->pDat + p->cx * Mode3GetDrawFontIndex(chr, p);

	u16 x, y;
	for(y=0; y<p->cy; y++)
	{
		for(x=0; x<p->cx; x++)
		{
			if(pDat[y*p->imgCx + x] == 0x00)
			{
				continue;
			}

			pScreen[y*SCREEN_CX + x] = col;
		}
	}
}
//===========================================================================
//フォントシートから書き込む文字のインデックスを求めます
EWRAM_CODE u16  Mode3GetDrawFontIndex(u16 chr, ST_FONT_SRC* p)
{
	//1バイト目と2バイト目を交換します
	chr = (chr << 8) | (chr >> 8);

	u16 i;
	for(i=0; i<p->cnt; i++)
	{
		if(chr == p->pSheet[i])
		{
			return i;
		}
	}

	TRACEOUT("[Err] Mode3GetDrawFontIndex: not Found Idx = [%x]\n", chr);
	return 0;
}
//===========================================================================
EWRAM_CODE void Mode3DrawFontBackGround(u16 x, u16 y, u8* str, u16 fontCol, u16 backCol)
{
//	ST_MODE3_FONT* p = &Mode3Font;
//	u8 len = _Length(str);

//	Mode3DrawFillBox(x * p->cx, y * p->cy, p->cx * len, p->cy, backCol);
//	Mode3DrawFontStr(x, y, (u8*)str, fontCol);
}
//===========================================================================
EWRAM_CODE u16 Mode3GetDot(u16 x, u16 y)
{
	u16* Screen = VideoBuffer + (y * SCREEN_CX) + x;
	return *Screen;
}
//===========================================================================
EWRAM_CODE void Mode3DrawBlend(u16 BlendMode, u16 min, u16 max)
{
	REG_BLDMOD = BlendMode | BLEND_TOP_BG2;
	REG_COLEY  = 0;

	Fade.min = min;
	Fade.max = max;
}
//===========================================================================
EWRAM_CODE void Mode3DrawFadeIn(u32 wait)
{
	s16 i;
	for(i=Fade.min; i<=Fade.max; i++)
	{
		WaitForVsync();
		REG_COLEY = i;

		WaitMs(wait);
	}
}
//===========================================================================
EWRAM_CODE void Mode3DrawFadeOut(u32 wait)
{
	s16 i;
	for(i=Fade.max; i>=Fade.min; i--)
	{
		WaitForVsync();
		REG_COLEY = i;

		WaitMs(wait);
	}
}
//===========================================================================
EWRAM_CODE void SpriteInit()
{
	u16 i;
	for(i=0; i<MAX_SPRITE; i++)
	{
		SpriteMove(i, SCREEN_CX, SCREEN_CY);
	}
}
//===========================================================================
EWRAM_CODE void SpriteSetPalData16(u16* palData)
{
	u16* OBJPaleAdr = OBJpal;

	u16 i;
	for(i=0; i<16; i++)
	{
		*OBJPaleAdr++ = *palData++;
	}
}
//===========================================================================
EWRAM_CODE void SpriteSetPalData256(u16* palData)
{
	u16* OBJPaleAdr = OBJpal;

	u16 i;
	for(i=0; i<256; i++)
	{
		*OBJPaleAdr++ = *palData++;
	}
}
//===========================================================================
EWRAM_CODE void SpriteSetData(u16* sprData, u32 sprSize)
{
	u16 *OAMDataAdr = OAMdata;
	u32 size        = sprSize >> 1;

	u32 i;
	for(i=0; i<size; i++)
	{
		*OAMDataAdr++ = *sprData++;
	}
}
//===========================================================================
EWRAM_CODE void SpriteMove(u16 num, s16 x, s16 y)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	if(x<0) x += 512;
	if(y<0) y += 256;

	sp->attribute1 &= 0xfe00;
	sp->attribute0 &= 0xff00;
	sp->attribute1 |= (x & 0x01ff);
	sp->attribute0 |= (y & 0x00ff);
}
//===========================================================================
EWRAM_CODE void SpriteSetChr(u16 num, u16 ch)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute2 &= 0xfc00;
	sp->attribute2 |= ch;
}
//===========================================================================
//	スプライトの形状を設定
//	size   SP_SIZE_8,SP_SIZE_16,SP_SIZE_32,SP_SIZE_64
//	form   SP_SQUARE,SP_TALL,SP_WIDE
//	color  SP_COLOR_16, SP_COLOR_256
EWRAM_CODE void SpriteSetSize(u16 num, u16 size, u16 form, u16 col)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute0 &= 0x1fff;
	sp->attribute1 &= 0x3fff;
	sp->attribute0 |= col  | form | (SCREEN_CY);
	sp->attribute1 |= size | (SCREEN_CX);
}
//===========================================================================
EWRAM_CODE void SpriteSetPalNo(u16 num, u16 palNo)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute2 &= 0x0fff;
	sp->attribute2 |= (palNo << 12);
}
//===========================================================================
EWRAM_CODE void SpriteSetPriority(u16 num, u16 priority)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute2 &= 0xf3ff;
	sp->attribute2 |= priority << 10;
}
//===========================================================================
EWRAM_CODE void SpriteSetVertical(u16 num, u8 flag)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute1 &= 0xEFFF;
	sp->attribute1 |= flag << 12;
}
//===========================================================================
EWRAM_CODE void SpriteSetScale(u16 num, u16 xscale, u16 yscale)
{
	RotData* rot = (RotData*)OAMmem + num;

	rot->pa = _UDiv(256*100, xscale);
	rot->pb = _UDiv(0*100  , xscale);
	rot->pc = _UDiv(0*100  , yscale);
	rot->pd = _UDiv(256*100, yscale);
}
//===========================================================================
// 拡大縮小回転機能を使う設定にする
//	num・・・変更するスプライトを指定
//	no ・・・使用するスプライトRotateパラメータの番号
//	double_flag・・描画領域を２倍使用できるようにするか
//		0なら通常の描画領域、SP_SIZE_DOUBLEなら２倍
EWRAM_CODE void SpriteSetRotateFlag(u16 num, u16 no, u16 doubleFlag)
{
	OAMEntry* sp = (OAMEntry*)OAMmem + num;

	sp->attribute0 |= SP_ROTATION_FLAG;

	sp->attribute1 &= 0xC1FF;
	sp->attribute0 &= 0xFDFF;

	sp->attribute1 |= SP_ROTDATA(no);
	sp->attribute0 |= doubleFlag;
}
//===========================================================================
// 拡大率を%で指定
EWRAM_CODE void SpriteSetRotate(u16 num, u8 angle, u16 scale)
{
	RotData* rot = (RotData*)OAMmem + num;

	s16 CosAngle = (s16)( _Cos(angle) * (128 + scale) );
	s16 SinAngle = (s16)( _Sin(angle) * (128 + scale) );

	rot->pa =  CosAngle;
	rot->pb =  SinAngle;
	rot->pc = -SinAngle;
	rot->pd =  CosAngle;
}
//===========================================================================
  //いまのところはPCM(8bit Wav)だけ演奏させる
EWRAM_CODE void SoundInit()
{
	SOUNDCNT_X  = ENABLE_SOUND_MASTER;
	SOUNDCNT_L  = 0;
	SOUNDCNT_H  = 0;
	SOUNDCNT_H |= (DSOUND_A_TIMER0 | ENABLE_DSOUND_A_RIGHT | ENABLE_DSOUND_A_LEFT | DSOUND_A_FULL_OUTPUT);
	SOUNDCNT_H |= (RESET_DSOUND_A);
}
//===========================================================================
EWRAM_CODE void SoundSetData(s8 *offset, u32 size)
{
	Wave.Offset = offset;
	Wave.size   = size;
}
//===========================================================================
EWRAM_CODE void SoundStart()
{
	REG_TM0CNT   &= ~TM_ENABLE;
	REG_DM1CNT_H &= ~DMA_TRANSFER_ON;

	REG_DM1CNT_H = 0;
	REG_DM1SAD   = (u32)(Wave.size);
	REG_DM1DAD   = (u32)(FIFO_A);
	REG_DM1CNT_H = (DMA_SIZE_32 | DMA_TRANSFER_OFF | DMA_TIMING_FIFO | 
	                DMA_REPEAT_ON | DMA_SAD_INC | DMA_DAD_FIX | DMA_INTR_ON);
	REG_TM0D     = (u16)(-1520);
	REG_TM0CNT   = TM_ENABLE | TM_FREQ_PER_1;

	REG_DM1CNT_H |= DMA_TRANSFER_ON;
}
//===========================================================================
EWRAM_CODE void KeyInit()
{
	Key.now = 0;
	Key.old = 0;

	Timer.wait      = 0;	//入力時のタイマ
	Timer.repeat    = 0;
	Timer.clockTick = 0;
}
//===========================================================================
EWRAM_CODE bool KeyWaitTimer()
{
	if(Timer.clockTick - Timer.wait < TIMER_INTMS)
	{
		return TRUE;
	}

	Timer.wait = Timer.clockTick;
	return FALSE;
}
//===========================================================================
//キーリピード判定（チャタリング防止）
EWRAM_CODE bool KeyRepeat()
{
	ST_KEY*   p = &Key;
	ST_TIMER* t = &Timer;

	p->now = ~(*KEYS) & 0x03ff;

	if(p->now && p->now == p->old)
	{
		if(t->clockTick - t->repeat < KEY_REPEAT_TIME)
		{
			return TRUE;
		}

		return FALSE;
	}

	p->old    = p->now;
	t->repeat = t->clockTick;

	return FALSE;
}
//===========================================================================
EWRAM_CODE u16 KeyGet()
{
	if( KeyWaitTimer() == TRUE )
	{
		return KEY_NONE;
	}
	if( KeyRepeat() == TRUE )
	{
		return KEY_NONE;
	}

	return Key.now;
}
//===========================================================================
EWRAM_CODE u16 KeyGet2()
{
	ST_KEY*   p = &Key;
	ST_TIMER* t = &Timer;

	while( KeyWaitTimer() == TRUE ){}

	p->old    = p->now;
	p->now    = ~(*KEYS) & 0x03ff;
	t->repeat = t->clockTick;

	return Key.now;
}
//===========================================================================
EWRAM_CODE u16 KeyWait(u16 keyWait)
{
	REG_TM3CNT = 0;
	REG_TM3CNT = TM_FREQ_PER_64 | TM_ENABLE;

	for(;;)
	{
		if( KeyGet() & keyWait )
		{
			break;
		}
	}

	_Srand(REG_TM3D);

	REG_TM3CNT = 0;
	REG_TM3D   = 0;

	return Key.now;
}
//===========================================================================
//入力がなくなるまで待ちます
EWRAM_CODE u16 KeyWait2(u16 keyWait)
{
	KeyWait(keyWait);
	while( KeyGet2() != KEY_NONE ){}

	return Key.now;
}
//===========================================================================
EWRAM_CODE void KeyWait3()
{
	while( KeyGet2() != KEY_NONE ){}
}
//===========================================================================
EWRAM_CODE u8 SRAMRead8(u32 offset)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	return (u8)sram[0];
}
//===========================================================================
EWRAM_CODE u16 SRAMRead16(u32 offset)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	return (u16)sram[0] | (u16)sram[1]<<8;
}
//===========================================================================
EWRAM_CODE u32 SRAMRead32(u32 offset)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	return (u32)sram[0] | (u32)sram[1]<<8 | (u32)sram[2]<<16 | (u32)sram[3]<<24;
}
//===========================================================================
EWRAM_CODE void SRAMWrite8(u32 offset, u8 data)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	*sram = (u8)(data & 0xff);
}
//===========================================================================
EWRAM_CODE void SRAMWrite16(u32 offset, u16 data)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	*sram++ = (u8)((data   ) & 0x00ff);
	*sram   = (u8)((data>>8) & 0x00ff);
}
//===========================================================================
EWRAM_CODE void SRAMWrite32(u32 offset, u32 data)
{
	u8* sram = (u8*)ADR_SRAM + offset;
	*sram++ = (u8)((data    ) & 0x000000ff);
	*sram++ = (u8)((data>>8 ) & 0x000000ff);
	*sram++ = (u8)((data>>16) & 0x000000ff);
	*sram   = (u8)((data>>24) & 0x000000ff);
}
//===========================================================================
EWRAM_CODE u8* SRAMGetPointer()
{
	return ADR_SRAM;
}
//===========================================================================
EWRAM_CODE u8 EtfsReadu8(u32 offset)
{
	u8* p = ADR_ROM_END + offset;
	return *p;
}
//===========================================================================
EWRAM_CODE u16 EtfsReadu16(u32 offset)
{
	u16* p = (u16*)ADR_ROM_END + offset;
	return *p;
}
//===========================================================================
EWRAM_CODE u32 EtfsReadu32(u32 offset)
{
	u32* p = (u32*)ADR_ROM_END + offset;
	return *p;
}
//===========================================================================
EWRAM_CODE u8* EtfsGetPointer()
{
	return ADR_ROM_END;
}
//===========================================================================
EWRAM_CODE bool GBFSInit()
{
	ST_GBFS* p = &GBFS;

	p->pStart = (GBFS_FILE*)EtfsGetPointer();
	p->pStart = find_first_gbfs_file(p->pStart);

	if(p->pStart == NULL)
	{
		TRACEOUT("[Err] GBFS Initialize Error.");
		return FALSE;
	}

	return TRUE;
}
//===========================================================================
EWRAM_CODE u16 GBFSGetFileCnt()
{
	return (u16)gbfs_count_objs(GBFS.pStart);
}
//===========================================================================
EWRAM_CODE u8* GBFSGetFilePointer(char* filename)
{
	ST_GBFS* p = &GBFS;

	_Strncpy((u8*)p->name, (u8*)filename, 24);
	p->name[24] = 0;

	return (u8*)gbfs_get_obj(p->pStart, filename, (u32*)&p->len);
}
//===========================================================================
EWRAM_CODE u8* GBFSGetFilePointer2(u32 num)
{
	ST_GBFS* p = &GBFS;
	return (u8*)gbfs_get_nth_obj(p->pStart, (size_t)num, (char*)&p->name, (u32*)&p->len);
}
//===========================================================================
EWRAM_CODE u8* GBFSGetFileName()
{
	return (u8*)&GBFS.name;
}
//===========================================================================
EWRAM_CODE u32 GBFSGetFileLength()
{
	return GBFS.len;
}
//===========================================================================
EWRAM_CODE void SeekSetChr(u8* pOffset, u32 size, u8 chr)
{
	Seek.now   = pOffset;
	Seek.start = pOffset;
	Seek.end   = pOffset + size;
	Seek.chr   = chr;
}
//===========================================================================
EWRAM_CODE u8* SeekNext()
{
	while(Seek.now < Seek.end)
	{
		Seek.now++;

		if(*Seek.now == Seek.chr)
		{
			return Seek.now;
		}
	}

	return NULL;
}
//===========================================================================
EWRAM_CODE u8* SeekPrev()
{
	while(Seek.now > Seek.start)
	{
		Seek.now--;

		if(*Seek.now == Seek.chr)
		{
			return Seek.now;
		}
	}

	return NULL;
}
//===========================================================================
EWRAM_CODE bool SeekHasMore()
{
	u8* now = Seek.now;
	while(now < Seek.end)
	{
		now++;

		if(*now == Seek.chr)
		{
			return TRUE;
		}
	}

	return FALSE;
}
//===========================================================================
//deg 0～255
EWRAM_CODE s16 _Sin(u8 deg)
{
	return Sintbl[(deg) & 0xff];
}
//===========================================================================
//deg 0～255
EWRAM_CODE s16 _Cos(u8 deg)
{
	return Sintbl[((deg)+64) & 0xff];
}
//===========================================================================
EWRAM_CODE u8 _Angle(s16 dx, s16 dy)
{
	//長さの比を求める
	s16 raito;
	if(dx == 0)
	{
		raito = 32767;
	}
	else
	{
		raito = _Div(dy * 256, dx);
		if(raito < 0)
		{
			raito = -raito;
		}
	}

	//64方向分サーチ
	u8 angle;
	for(angle=0; angle<64; angle++)
	{
		if(raito < Atntbl[angle])
		{
			break;
		}
	}

	//方向を調整
	if(dx < 0) angle = 64 - angle +  64;
	if(dy < 0) angle = 64 - angle + 192;

	return (angle & 0xff);
}
//===========================================================================
EWRAM_CODE void DMA0Memcpy32(u32 src, u32 dst, u16 srcMode, u16 dstMode, u16 size)
{
	REG_DM0SAD   = src;
	REG_DM0DAD   = dst;
	REG_DM0CNT_L = size;


	REG_DM0CNT_H = (DMA_SIZE_32 | DMA_TRANSFER_ON | DMA_TIMING_NOW | DMA_REPEAT_OFF |
	                srcMode     | dstMode         | DMA_INTR_OFF);


//	DMAChainAdd(src, dst, size, srcMode | dstMode);

	//DMA転送フラグ停止するまでループ
//	while(REG_IF & IRQ_BIT_DMA3){}
}
//===========================================================================
EWRAM_CODE void WaitForVsync()
{
	while(REG_VCOUNT != 159) {}
	while(REG_VCOUNT == 159) {}
}
//===========================================================================
EWRAM_CODE void WaitMs(u32 wait)
{
	u32 t = Timer.clockTick;

	while(Timer.clockTick - t < wait) {}
}
//===========================================================================
EWRAM_CODE void BiosSetCheckSum()
{
	u32 result;
	asm volatile("swi 0x0d\n" "mov r0, %0\n" : "=r"(result) : : "r1", "r2", "r3" );
	Lib.checkSum = result;
}
//===========================================================================
EWRAM_CODE bool BiosIsEmulator()
{
	//0xBAAE187F GBAで動作中
	//0xBAAE1880 DSのGBAモード
	//それ以外   エミュレータ
	return (Lib.checkSum == 0xBAAE187F || Lib.checkSum == 0xBAAE1880) ? TRUE : FALSE;
}
//===========================================================================
EWRAM_CODE void DebugMessage(char* msg)
{
	_Puts(msg);
	for(;;){}
}
