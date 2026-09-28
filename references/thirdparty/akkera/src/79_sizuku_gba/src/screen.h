
#ifndef __SCREEN_H__
#define __SCREEN_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define FONT_LEAF_COLOR_WHITE			0
#define FONT_LEAF_COLOR_GRAY			1

#define SCREEN_FONT_SPRITE_CNT			8
#define SCREEN_FONT_CX					18
#define SCREEN_FONT_CY					10

#define CURSOR_SX						18
#define CURSOR_SY						22
#define CURSOR_SPRITE_NO				(512+127)
#define CURSOR_TILE_NO_CLS				892
#define CURSOR_TILE_NO_PAGE				988
#define CURSOR_TILE_NO_KEY				990
#define CURSOR_BLINK_TIME				100					//カーソルの点滅の間隔
#define CURSOR_ATTR_PAGE				0
#define CURSOR_ATTR_KEY					1

//---------------------------------------------------------------------------
typedef struct {
	u32  cx; 												//横のサイズ
	u32  cy;												//縦のサイズ
	u32  imgCx;												//データの横のサイズ
	u8*  pDat;												//データの位置
	u8*  pAttr[2];											//データの属性位置
	u8   attrNo;											//データの属性番号(0:白色、1:灰色)
	u16* pTblSJIS;											//SJIS->Leafコード用のテーブル
	u16  tblCnt;											//SJIS->Leafコード用のテーブルカウント
} ST_FONT_LEAF;


typedef struct {
	u16 code  [SCREEN_FONT_CX][SCREEN_FONT_CY] ALIGN(4);	//文字コード
	u8  attrNo[SCREEN_FONT_CX][SCREEN_FONT_CY] ALIGN(4);	//文字の属性(0:白色、1:灰色)
} ST_SCREEN_FONT_BUF;


typedef struct {
	u16    x;												//フォントの書き込み位置
	u16    y;
	ST_OBJ in [SCREEN_FONT_SPRITE_CNT] ALIGN(4);			//スプライトフォントの表示用
	ST_OBJ out[SCREEN_FONT_SPRITE_CNT] ALIGN(4);			//スプライトフォントの退避用

	ST_SCREEN_FONT_BUF buf;									//1画面分の表示文字
} ST_SCREEN_FONT;


typedef struct {
	u16 buf[SCREEN_CX][SCREEN_CY] ALIGN(4);					//VideoBufferの内部用
} ST_SCREEN_IMG;


typedef struct {
	u16 x;
	u16 y;
	u16 sprNo;
	u16 tileNo;
	u16 attrNo;												//0:ページアイコン 1:改行アイコン
	u16 attr[2];
	u8  blinkFlag;											//点滅用のフラグ
} ST_CURSOR;

//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafInit();

EWRAM_CODE void FontLeafDrawChr(u16 x, u16 y, u16 code);
EWRAM_CODE void FontLeafDrawChrType1(u16 x, u16 y, u16 code);
EWRAM_CODE void FontLeafDrawChrType2(u16 x, u16 y, u16 code);
EWRAM_CODE void FontLeafDrawChrType3(u16 x, u16 y, u16 code);
EWRAM_CODE void FontLeafDrawChrType4(u16 x, u16 y, u16 code);

EWRAM_CODE u16  FontLeafGetLeafCode(u16 code);
EWRAM_CODE u16  FontLeafGetSJISCode(u16 code);
EWRAM_CODE void FontLeafSetAttr(u16 no);
EWRAM_CODE u8   FontLeafGetAttrNo();
EWRAM_CODE void FontLeafDebugCode(u16 code);


//----
EWRAM_CODE void ScreenFontInit();
EWRAM_CODE void ScreenFontIn();
EWRAM_CODE void ScreenFontOut();

EWRAM_CODE void ScreenFontClear();
EWRAM_CODE void ScreenFontClearNoBuf();
EWRAM_CODE void ScreenFontClearOAM();
EWRAM_CODE void ScreenFontClearBuf();
EWRAM_CODE void ScreenFontClearXY();

EWRAM_CODE void ScreenFontDrawChr(u16 x, u16 y, u16 code);
EWRAM_CODE void ScreenFontDrawStr(u16* buf, u16 cnt);
EWRAM_CODE void ScreenFontDrawStrNoBuf(u16* buf, u16 cnt);
EWRAM_CODE void ScreenFontDrawStrSJISNoBuf(u16 sx, u16 sy, u8* p);
EWRAM_CODE void ScreenFontDrawRestore();

EWRAM_CODE bool ScreenFontIsFull();
EWRAM_CODE bool ScreenFontIsOver(u16 writeCnt);
EWRAM_CODE bool ScreenFontIsHyphenationBefore(u16 code);
EWRAM_CODE bool ScreenFontIsHyphenationAfter(u16 code);

EWRAM_CODE u16  ScreenFontGetX();
EWRAM_CODE u16  ScreenFontGetY();
EWRAM_CODE void ScreenFontSetXY(u16 x, u16 y);
EWRAM_CODE void ScreenFontSetChrBuf(u16 x, u16 y, u16 code, u8 attrNo);
EWRAM_CODE u16  ScreenFontSetHyphenation(u16* src, u16* dst, u16 len);
EWRAM_CODE void ScreenFontSetNewLine();


//----
EWRAM_CODE void ScreenImgInit();
EWRAM_CODE void ScreenImgClear();
EWRAM_CODE void ScreenImgUpdate();
EWRAM_CODE void ScreenImgLoadBg(u8* pBg);
EWRAM_CODE void ScreenImgLoadChr(u8* pChr, u8 pos);
EWRAM_CODE void ScreenImgFlash();
EWRAM_CODE void ScreenImgFadeIn(u16 mode, u16 min, u16 max, u16 wait);
EWRAM_CODE void ScreenImgFadeOut(u16 wait);


//----
EWRAM_CODE void ScreenCursorInit();
EWRAM_CODE void ScreenCursorDrawBlink();
EWRAM_CODE void ScreenCursorMoveIn();
EWRAM_CODE void ScreenCursorMoveOut();
EWRAM_CODE void ScreenCursorSetAttr(u16 no);


#ifdef __cplusplus
}
#endif
#endif
