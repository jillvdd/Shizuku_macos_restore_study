
#ifndef __SCREEN_H__
#define __SCREEN_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define FONT_LEAF_COLOR_WHITE			0
#define FONT_LEAF_COLOR_GRAY			1

#define SCREEN_FONT_SPRITE_CNT			8
#define SCREEN_FONT_CX					17
#define SCREEN_FONT_CY					10

#define CURSOR_SX						18
#define CURSOR_SY						22
#define CURSOR_SPRITE_NO				(512+127)
#define CURSOR_TILE_NO_CLS				892
#define CURSOR_TILE_NO_PAGE				988
#define CURSOR_TILE_NO_KEY				990
#define CURSOR_BLINK_TIME				100			//カーソルの点滅の間隔
#define CURSOR_ATTR_PAGE				0
#define CURSOR_ATTR_KEY					1

//---------------------------------------------------------------------------
typedef struct {
	u8*  pDat;										//データの位置
	u8*  pAttr[2];									//データの属性(0:白色、1:灰色)
	u32  imgCx;										//データの大きさ
	u32  cx; 										//横のサイズ
	u32  cy;										//縦のサイズ
	u16* tblSJIS;									//SJIS->Leafコード用のテーブル
	u16  tblCnt;
} ST_FONT_LEAF;


typedef struct {
	u16    buf[SCREEN_FONT_CX][SCREEN_FONT_CY] ALIGN(4);
	ST_OBJ in [SCREEN_FONT_SPRITE_CNT] ALIGN(4);
	ST_OBJ out[SCREEN_FONT_SPRITE_CNT] ALIGN(4);
	u16    x;										//フォントの書き込み位置
	u16    y;
	u16    cnt;										//1画面の最大表示数
} ST_SCREEN_FONT;


typedef struct {
	u16 buf[SCREEN_CX][SCREEN_CY] ALIGN(4);
} ST_SCREEN_IMG;


typedef struct {
	u16  x;
	u16  y;											//表示の行数
	u16  sprNo;
	u16  tile;
	u16  attrNo;
	u16  tileAttr[2];								//0:ページアイコン 1:改行アイコン
	bool blinkFlag;									//点滅用のフラグ
} ST_CURSOR;

//---------------------------------------------------------------------------
EWRAM_CODE void FontLeafInit();
EWRAM_CODE void FontLeafDrawChr(u16 sx, u16 sy, u16 code);
EWRAM_CODE void FontLeafDrawChrType1(u16 sx, u16 sy, u16 code);
EWRAM_CODE void FontLeafDrawChrType2(u16 sx, u16 sy, u16 code);
EWRAM_CODE void FontLeafDrawChrType3(u16 sx, u16 sy, u16 code);
EWRAM_CODE void FontLeafDrawChrType4(u16 sx, u16 sy, u16 code);

EWRAM_CODE u16  FontLeafGetLeafCode(u16 code);
EWRAM_CODE u16  FontLeafGetSJISCode(u16 code);
EWRAM_CODE void FontLeafSetAttr(u16 no);

EWRAM_CODE void FontLeafDebugCode(u16 code);


//----
EWRAM_CODE void ScreenFontInit();
EWRAM_CODE void ScreenFontIn();
EWRAM_CODE void ScreenFontOut();
EWRAM_CODE void ScreenFontDrawCls();
EWRAM_CODE void ScreenFontDrawClsOAM();
EWRAM_CODE void ScreenFontDrawClsBuffer();
EWRAM_CODE void ScreenFontDrawChr(u16 x, u16 y, u16 code);
EWRAM_CODE void ScreenFontDrawStr(u16* buf, u16 cnt);
EWRAM_CODE void ScreenFontDrawStrNoBuf(u16* buf, u16 cnt);
EWRAM_CODE void ScreenFontDrawRestore();
EWRAM_CODE bool ScreenFontIsFull();
EWRAM_CODE bool ScreenFontIsCnt(u16 writeCnt);
EWRAM_CODE bool ScreenFontIsHyphenationBefore(u16 code);
EWRAM_CODE bool ScreenFontIsHyphenationAfter(u16 code);
EWRAM_CODE u16  ScreenFontGetX();
EWRAM_CODE u16  ScreenFontGetY();
EWRAM_CODE void ScreenFontSetXY(u16 x, u16 y);
EWRAM_CODE void ScreenFontClearXY();
EWRAM_CODE u16  ScreenFontSetHyphenation(u16* src, u16* dst, u16 len);
EWRAM_CODE void ScreenFontNewLineTxt();


//----
EWRAM_CODE void ScreenImgInit();
EWRAM_CODE void ScreenImgCls();
EWRAM_CODE void ScreenImgUpdate();


//----
EWRAM_CODE void ScreenCursorInit();
EWRAM_CODE void ScreenCursorDrawBlink();
EWRAM_CODE void ScreenCursorMoveIn();
EWRAM_CODE void ScreenCursorMoveOut();
EWRAM_CODE void ScreenCursorAttr(u16 no);



#ifdef __cplusplus
}
#endif
#endif
