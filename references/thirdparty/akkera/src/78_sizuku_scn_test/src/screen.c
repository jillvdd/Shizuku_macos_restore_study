
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
ST_FONT_LEAF   FontLeaf;
ST_SCREEN_IMG  ScreenImg  EWRAM_DATA;
ST_SCREEN_FONT ScreenFont;
ST_CURSOR      Cursor;

u32 dummy ALIGN(4);
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafInit()
{
	ST_FONT_LEAF* p = &FontLeaf;

	p->pAttr[0] = (u8*)&k12x10wBitmap;
	p->pAttr[1] = (u8*)&k12x10gBitmap;

	p->pDat     = p->pAttr[0];
	p->imgCx    = K12X10_IMG_CX;
	p->cx       = K12X10_FONT_CX;
	p->cy       = K12X10_FONT_CY;
	p->tblSJIS  = (u16*)&sjis2leaf_txt;
	p->tblCnt   = SJIS_TO_LEAF_CODE_CNT;
}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafDrawChr(u16 sx, u16 sy, u16 code)
{
	u8 flag = 0x00;

	if(sx & 0x01) flag |= 0x01;
	if(sy & 0x01) flag |= 0x10;

	//x, y座標の偶数、奇数によって書き込み方法を変更します
	switch(flag)
	{
	case 0x00: FontLeafDrawChrType1(sx, sy, code); break;
	case 0x01: FontLeafDrawChrType2(sx, sy, code); break;
	case 0x10: FontLeafDrawChrType3(sx, sy, code); break;
	case 0x11: FontLeafDrawChrType4(sx, sy, code); break;
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafDrawChrType1(u16 sx, u16 sy, u16 code)
{
	ST_FONT_LEAF* p = &FontLeaf;

	u16* pScr1 = OAMdata + (sy * 768) + (sx * 24);
	u16* pScr2 = pScr1 + 16;
	u16* pScr3 = pScr1 + 512;
	u16* pScr4 = pScr1 + 512 + 16;
	u16* pDat  = (u16*)p->pDat + code * 3;

	u16 i;
	for(i=0; i<8; i++)
	{
		*pScr1++ = *(pDat + 0);
		*pScr1++ = *(pDat + 1);
		*pScr2++ = *(pDat + 2);
		pScr2++;

		pDat += (p->imgCx / 4);
	}

	for(i=0; i<2; i++)
	{
		*pScr3++ = *(pDat + 0);
		*pScr3++ = *(pDat + 1);
		*pScr4++ = *(pDat + 2);
		pScr4++;

		pDat += (p->imgCx / 4);
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafDrawChrType2(u16 sx, u16 sy, u16 code)
{
	ST_FONT_LEAF* p = &FontLeaf;

	u16* pScr1 = OAMdata + (16+1) + (sy * 768) + ((sx-1) * 24);
	u16* pScr2 = pScr1 + 16 - 1;
	u16* pScr3 = pScr1 + 512;
	u16* pScr4 = pScr2 + 512;
	u16* pDat  = (u16*)p->pDat + code * 3;

	u16 i;
	for(i=0; i<8; i++)
	{
		*pScr1++ = *(pDat + 0);
		pScr1++;

		*pScr2++ = *(pDat + 1);
		*pScr2++ = *(pDat + 2);

		pDat += (p->imgCx / 4);
	}

	for(i=0; i<2; i++)
	{
		*pScr3++ = *(pDat + 0);
		pScr3++;

		*pScr4++ = *(pDat + 1);
		*pScr4++ = *(pDat + 2);

		pDat += (p->imgCx / 4);
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafDrawChrType3(u16 sx, u16 sy, u16 code)
{
	ST_FONT_LEAF* p = &FontLeaf;

	u16* pScr1 = OAMdata + (512 + 8) + ((sy-1) * 768) + (sx * 24);
	u16* pScr2 = pScr1 + 16;
	u16* pScr3 = pScr1 + 512 - 8;
	u16* pScr4 = pScr2 + 512 - 8;
	u16* pDat  = (u16*)p->pDat + code * 3;

	u16 i;
	for(i=0; i<4; i++)
	{
		*pScr1++ = *(pDat + 0);
		*pScr1++ = *(pDat + 1);
		*pScr2++ = *(pDat + 2);
		pScr2++;

		pDat += (p->imgCx / 4);
	}

	for(i=0; i<6; i++)
	{
		*pScr3++ = *(pDat + 0);
		*pScr3++ = *(pDat + 1);
		*pScr4++ = *(pDat + 2);
		pScr4++;

		pDat += (p->imgCx / 4);
	}

}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafDrawChrType4(u16 sx, u16 sy, u16 code)
{
	ST_FONT_LEAF* p = &FontLeaf;

	u16* pScr1 = OAMdata + (528 + 8 + 1) + ((sy-1) * 768) + ((sx-1) * 24);
	u16* pScr2 = pScr1 +  16 - 1;
	u16* pScr3 = pScr1 + 512 - 8;
	u16* pScr4 = pScr3 +  16 - 1;
	u16* pDat  = (u16*)p->pDat + code * 3;

	u16 i;
	for(i=0; i<4; i++)
	{
		*pScr1++ = *(pDat + 0);
		pScr1++;

		*pScr2++ = *(pDat + 1);
		*pScr2++ = *(pDat + 2);

		pDat += (p->imgCx / 4);
	}

	for(i=0; i<6; i++)
	{
		*pScr3++ = *(pDat + 0);
		pScr3++;

		*pScr4++ = *(pDat + 1);
		*pScr4++ = *(pDat + 2);

		pDat += (p->imgCx / 4);
	}
}
//---------------------------------------------------------------------------
//SJIS -> Leaf
EWRAM_CODE u16 FontLeafGetLeafCode(u16 code)
{
	ST_FONT_LEAF* p = &FontLeaf;
	u16 i;

	for(i=0; i<p->tblCnt; i++)
	{
		if(code == p->tblSJIS[i])
		{
			return i;
		}
	}

	TRACEOUT("Err: FontLeafConvetSJIS\n");
	return 0;
}
//---------------------------------------------------------------------------
//Leaf -> SJIS
EWRAM_CODE u16 FontLeafGetSJISCode(u16 code)
{
	return FontLeaf.tblSJIS[code];
}
//---------------------------------------------------------------------------
//Debug
EWRAM_CODE void FontLeafDebugCode(u16 code)
{
	u16 sjis = FontLeafGetSJISCode(code);
	char buf[3];

	buf[0] = (sjis & 0x00ff);
	buf[1] = (sjis & 0xff00) >> 8;
	buf[2] = '\0';

	TRACEOUT("%s", buf);
}
//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafSetAttr(u16 no)
{
	FontLeaf.pDat = FontLeaf.pAttr[no];
}





//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontInit()
{
	static const u16 x[8] = {  18,  18,  82,  82, 146, 146, 210, 210 };
	static const u16 y[8] = {  22,  86,  22,  86,  22,  86,  22,  86 };
	static const u16 s[8] = { 512, 768, 520, 776, 528, 784, 536, 792 };
	static const u16 t[8] = { SP_SQUARE, SP_SQUARE, SP_SQUARE, SP_SQUARE, SP_SQUARE, SP_SQUARE, SP_TALL, SP_TALL };

	ST_SCREEN_FONT* p = &ScreenFont;

	u16 i;
	for(i=0; i<SCREEN_FONT_SPRITE_CNT; i++)
	{
		p->in[i].attr0 = SP_COLOR_16 | (t[i]) | (y[i]);
		p->in[i].attr1 = SP_SIZE_64  | (x[i]);
		p->in[i].attr2 = s[i];
		p->in[i].attr3 = 0x0000;

		p->out[i].attr0 = SP_COLOR_16 | SP_SQUARE | (SCREEN_CY);
		p->out[i].attr1 = SP_SIZE_16  | (SCREEN_CX);
		p->out[i].attr2 = s[i];
		p->out[i].attr3 = 0x0000;
	}

	p->cnt = SCREEN_FONT_CX * SCREEN_FONT_CY;

	ScreenFontDrawCls();
	ScreenFontIn();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontIn()
{
	DMA0Memcpy32((u32)&ScreenFont.in, (u32)OAMmem + 512 * 8, DMA_SAD_INC, DMA_DAD_INC, 8*8 / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontOut()
{
	DMA0Memcpy32((u32)&ScreenFont.out, (u32)OAMmem + 512 * 8, DMA_SAD_INC, DMA_DAD_INC, 8*8 / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawCls()
{
	ScreenFontDrawClsOAM();
	ScreenFontDrawClsBuffer();
	ScreenFontClearXY();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawClsOAM()
{
	DMA0Memcpy32((u32)&dummy, (u32)OAMdata, DMA_SAD_FIX, DMA_DAD_INC, 15168 / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawClsBuffer()
{
	DMA0Memcpy32((u32)&dummy, (u32)ScreenFont.buf, DMA_SAD_FIX, DMA_DAD_INC, (SCREEN_FONT_CX * SCREEN_FONT_CY * 2) / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawChr(u16 x, u16 y, u16 code)
{
	FontLeafDrawChr(x, y, code);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawStr(u16* buf, u16 cnt)
{
	ST_SCREEN_FONT* p = &ScreenFont;

	u16 i;
	for(i=0; i<cnt; i++)
	{
		if(p->x >= SCREEN_FONT_CX && i<cnt)
		{
			ScreenFontNewLineTxt();
		}

		ScreenFontDrawChr(p->x, p->y, buf[i]);
		p->buf[p->x][p->y] = buf[i];
		p->x++;

		FontLeafDebugCode(buf[i]);
	}
}
//---------------------------------------------------------------------------
//ScreenFontDrawStr関数との相違は、Bufferに書き込んでいないところだけです
EWRAM_CODE void ScreenFontDrawStrNoBuf(u16* buf, u16 cnt)
{
	ST_SCREEN_FONT* p = &ScreenFont;

	u16 i;
	for(i=0; i<cnt; i++)
	{
		if(p->x >= SCREEN_FONT_CX && i<cnt)
		{
			ScreenFontNewLineTxt();
		}

		ScreenFontDrawChr(p->x, p->y, buf[i]);
		p->x++;
	}
}
//---------------------------------------------------------------------------
//禁則文字の処理(かなり適当な処理をしています)
EWRAM_CODE u16 ScreenFontSetHyphenation(u16* src, u16* dst, u16 len)
{
	u16 x = ScreenFont.x;
	u16 i = 0;
	u16 j = 0;
	u16 code;

	//前処理
	if(x == (SCREEN_FONT_CX-1))
	{
		dst[i++] = 0x0000;		//0x0000 = LeafCode "　"
		x = 0;
	}
	else if(x >= SCREEN_FONT_CX)
	{
		x = 0;
	}

	if(src[j+0] == 0x0000)
	{
		dst[i++] = 0x0000;
		j++;
		x++;
	}

	while(j < len)
	{
#if 0
		//空白が連続で２～３文字続いていた場合は詰めます
		if( (j+1 < len) && (src[j+0] == 0x0000) )
		{
			if(src[j+1] == 0x0000)
			{
				j += 2;
			}
			if( (j < len) && src[j+0] == 0x0000)
			{
				j += 1;
			}

			continue;
		}
#endif

		code = src[j++];

		if(code == 0x0000)
		{
			continue;
		}
		else if( (x == 0) && (ScreenFontIsHyphenationBefore(code) == TRUE) )
		{
			//行頭
			dst[i+0] = dst[i-1];
			dst[i+1] = code;
			dst[i-1] = 0x0000;

			//移動した文字が、さらに禁則文字かチェックをします
			if( ScreenFontIsHyphenationBefore(dst[i+0]) == FALSE )
			{
				i += 2;
				x  = 2;
			}
			else
			{
				dst[i+2] = dst[i+1];
				dst[i+1] = dst[i+0];
				dst[i+0] = dst[i-2];
				dst[i-2] = 0x0000;

				i += 3;
				x  = 3;
			}
		}
		else if( (x >= (SCREEN_FONT_CX-1)) && (ScreenFontIsHyphenationAfter(code) == TRUE) )
		{
			//行末
			dst[i+1] = dst[i-1];
			dst[i+2] = code;
			dst[i+0] = 0x0000;
			dst[i-1] = 0x0000;

			i += 3;
			x  = 3;
		}
		else
		{
			dst[i] = code;
			i++;
			x++;

			if(x >= SCREEN_FONT_CX)
			{
				x = 0;
			}
		}
	}

	return i;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool ScreenFontIsHyphenationBefore(u16 code)
{
	switch(code)
	{
		case 0x0030:	//ゃ
		case 0x0031:	//ゅ
		case 0x0032:	//ょ
		case 0x0033:	//っ
		case 0x0057:	//。
		case 0x0058:	//、
		case 0x0059:	//・
		case 0x005a:	//…
		case 0x005c:	//』
		case 0x005e:	//」
		case 0x0060:	//）
		case 0x0061:	//？
		case 0x0062:	//！
		case 0x0063:	//!?
		case 0x0064:	//－
		case 0x0065:	//ー
		case 0x0097:	//ャ
		case 0x0098:	//ュ
		case 0x0099:	//ョ
		case 0x009a:	//ッ
		case 0x04e9:	//ヶ
		case 0x04ea:	//ぁ
		case 0x04eb:	//ぃ
		case 0x04ec:	//ぅ
		case 0x04ed:	//ぇ
		case 0x04ee:	//ぉ
		case 0x04ef:	//ァ
		case 0x04f0:	//ィ
		case 0x04f1:	//ゥ
		case 0x04f2:	//ェ
		case 0x04f3:	//ォ
		case 0x0683:	//．
		case 0x06ff:	//～
			return TRUE;
	}

	return FALSE;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool ScreenFontIsHyphenationAfter(u16 code)
{
	switch(code)
	{
		case 0x005b:	//『
		case 0x005d:	//「
		case 0x005f:	//（
			return TRUE;
	}

	return FALSE;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool ScreenFontIsFull()
{
	return ScreenFont.y >= SCREEN_FONT_CY ? TRUE : FALSE;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool ScreenFontIsCnt(u16 writeCnt)
{
	return ((ScreenFont.x + ScreenFont.y * SCREEN_FONT_CX) + writeCnt) >= ScreenFont.cnt ? TRUE : FALSE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontNewLineTxt()
{
	ScreenFont.x  = 0;
	ScreenFont.y += 1;

	//yが超えた分のチェックは、次回の文字表示時の前処理で行います
}
//---------------------------------------------------------------------------
EWRAM_CODE u16 ScreenFontGetX()
{
	return ScreenFont.x;
}
//---------------------------------------------------------------------------
EWRAM_CODE u16 ScreenFontGetY()
{
	return ScreenFont.y;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontSetXY(u16 x, u16 y)
{
	ScreenFont.x = x;
	ScreenFont.y = y;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontClearXY()
{
	ScreenFont.x = 0;
	ScreenFont.y = 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenFontDrawRestore()
{
	ST_SCREEN_FONT* p = &ScreenFont;
	u16 x, y;

	for(y=0; y<SCREEN_FONT_CY; y++)
	{
		for(x=0; x<SCREEN_FONT_CX; x++)
		{
			ScreenFontDrawChr(x, y, p->buf[x][y]);
		}
	}
}






//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgInit()
{
	dummy = 0;
	ScreenImgCls();
	LibMode3SetScreenBuffer((u16*)&ScreenImg.buf);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgCls()
{
	DMA0Memcpy32((u32)&dummy, (u32)ScreenImg.buf, DMA_SAD_FIX, DMA_DAD_INC, (240*160*2) / 4);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgUpdate()
{
	DMA0Memcpy32((u32)&ScreenImg.buf, (u32)VideoBuffer, DMA_SAD_INC, DMA_DAD_INC, (240*160*2) / 4);
}





//---------------------------------------------------------------------------
EWRAM_CODE void ScreenCursorInit()
{
	ST_CURSOR* p = &Cursor;

	p->x           = SCREEN_CX;
	p->y           = SCREEN_CY;
	p->sprNo       = CURSOR_SPRITE_NO;
	p->tile        = CURSOR_TILE_NO_PAGE;
	p->tileAttr[0] = CURSOR_TILE_NO_PAGE;
	p->tileAttr[1] = CURSOR_TILE_NO_KEY;
	p->attrNo      = 0;
	p->blinkFlag   = FALSE;

	SpriteSetSize(p->sprNo, SP_SIZE_16, SP_SQUARE, SP_COLOR_16);
}
//---------------------------------------------------------------------------
//IRQUserHandler関数（iwram_arm.c）から呼ばれます
EWRAM_CODE void ScreenCursorDrawBlink()
{
	ST_CURSOR* p = &Cursor;

	if( _UMod(Timer.clockTick ,CURSOR_BLINK_TIME) != 0 )
	{
		return;
	}

	if(p->blinkFlag == TRUE)
	{
		p->tile = p->tileAttr[ p->attrNo ];
	}
	else
	{
		p->tile = CURSOR_TILE_NO_CLS;
	}
	p->blinkFlag ^= TRUE;

	SpriteSetChr(p->sprNo, p->tile);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenCursorMoveIn()
{
	ST_SCREEN_FONT* p = &ScreenFont;
	ST_FONT_LEAF*   f = &FontLeaf;
	ST_CURSOR*      c = &Cursor;

	c->x = CURSOR_SX + p->x * (f->cx);
	c->y = CURSOR_SY + p->y * (f->cy + 2);		//+2は余白分

	SpriteMove(c->sprNo, c->x, c->y);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenCursorMoveOut()
{
	SpriteMove(Cursor.sprNo, SCREEN_CX, SCREEN_CY);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScreenCursorAttr(u16 no)
{
	Cursor.attrNo = no;
}
