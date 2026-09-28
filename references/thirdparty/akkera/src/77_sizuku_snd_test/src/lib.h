// lib.h

#ifndef __LIB_H__
#define __LIB_H__
#ifdef __cplusplus
extern "C" {
#endif

// TODO 2007/05/05 BGDrawはすべて256*256を想定しているので、256*256以外は変更が必要。
//                 Mode3とBGでは文字を表示する際の処理が違うので統一すること。

// TODO 2007/06/27 InitLib関数を作ったが、作らない方向にできないか検討すること。

//===========================================================================
//キー入力のウェイト
#define KEY_REPEAT_TIME			500
#define TIMER_INTMS				10

#define IsSJIS(c) (((c)>=0x81 && (c)<=0x9f) || ((c)>=0xe0 && (c)<=0xef))

//===========================================================================

typedef struct {
	u16* screenBuf;			//スクリーンバッファの位置(MODE3のみ使用)
} ST_LIB;


typedef struct {
	u8*  pDat;				//フォントデータのポインタ
	u16* pSheet; 			//フォントシートのポインタ
	u32  imgCx;				//フォントデータの大きさ
	u16  cnt;				//フォントデータのキャラクタ数
	u32  cx; 				//フォントの横のサイズ
	u32  cy;				//フォントの縦のサイズ
} ST_FONT_SRC;


typedef struct {
	ST_FONT_SRC sing;		//全角文字
	ST_FONT_SRC half;		//半角文字
} ST_FONT;


typedef struct {
	s8* Offset;
	u32 size;
} ST_WAVE;


typedef struct {
	vu32 clockTick;
	vu32 wait;
	vu32 repeat;
} ST_TIMER;


typedef struct {
	u16 now;
	u16 old;
} ST_KEY;


typedef struct {
	u8* now;
	u8* start;
	u8* end;
	u8  chr;
} ST_SEEK;


typedef struct {
	const GBFS_FILE* pStart;
	u8*   name[24];
	u32   len;
} ST_GBFS;


typedef struct {
	u8 chr;
	u8 map;
	u8 col;
} __PACKED ST_BG; //ライブラリ内では使ってない


typedef struct {
	u16 attr0;
	u16 attr1;
	u16 attr2;
	u16 attr3;
} __PACKED ST_OBJ; //ライブラリ内では使ってない


//===========================================================================
//Lib
EWRAM_CODE void LibInit();
EWRAM_CODE void LibMode3SetScreenBuffer(u16* buf);




//===========================================================================
//BG SetData
EWRAM_CODE void BGSetChrData(u16* chrData, u32 chrSize, u8 chrNo);
EWRAM_CODE void BGSetMapData(u16* mapData, u32 mapSize, u8 mapNo, u16 palNo);
EWRAM_CODE void BGSetPalData16(u16* palData, u8 palNo);
EWRAM_CODE void BGSetPalData256(u16* palData);
//BG Draw
EWRAM_CODE void BGDrawCls(u8 mapNo, u16 fillChr);
EWRAM_CODE void BGDrawBox(u8 mapNo, u16 sx, u16 sy, u16 cx, u16 cy, u16 fillChr);
EWRAM_CODE void BGDrawOrder(u8 mapNo);
EWRAM_CODE void BGDrawPut(u8 mapNo, u16 x, u16 y, u16 chr);
//BG Draw Font
EWRAM_CODE void BGDrawStr(u8 mapNo, u16 x, u16 y, u8* str);
EWRAM_CODE void BGDrawChr(u8 mapNo, u16 x, u16 y, u8 palNo, u16 chr);
//BG Etc
EWRAM_CODE u16  BGGetChr(u8 mapNo, u16 x, u16 y);




//===========================================================================
//Mode3 Draw
EWRAM_CODE void Mode3DrawCls(u16 col);
EWRAM_CODE void Mode3DrawFillBox(u16 sx, u16 sy, u16 cx, u16 cy, u16 col);
EWRAM_CODE void Mode3DrawBox(u16 sx, u16 sy, u16 cx, u16 cy, u16 col);
EWRAM_CODE void Mode3DrawPut(u16 x, u16 y, u16 col);
EWRAM_CODE void Mode3DrawLine(u16 x1, u16 y1, u16 x2, u16 y2, u16 col);
EWRAM_CODE void Mode3DrawCircle(u16 sx, u16 sy, u16 rad, u16 col);
EWRAM_CODE void Mode3DrawFillCircle(u16 sx, u16 sy, u16 rad, u16 col);
EWRAM_CODE void Mode3DrawImage(u16 sx, u16 sy, u16 cx, u16 cy, u16* img);
//Mode3 Draw Font
EWRAM_CODE void Mode3SetFont(ST_FONT_SRC* s, ST_FONT_SRC* h);
EWRAM_CODE void Mode3DrawFontStr(u16 sx, u16 sy, u8* str, u16 col);
EWRAM_CODE void Mode3DrawFontSingChr(u16 sx, u16 sy, u16 chr, u16 col);
EWRAM_CODE void Mode3DrawFontHalfChr(u16 sx, u16 sy, u16 chr, u16 col);
EWRAM_CODE u16  Mode3GetDrawFontIndex(u16 chr, ST_FONT_SRC* p);
EWRAM_CODE void Mode3DrawFontBackGround(u16 x, u16 y, u8* str, u16 fontCol, u16 backCol);

//Mode3 Etc
EWRAM_CODE u16 Mode3GetDot(u16 x, u16 y);
//Mode3 Effect
//EWRAM_CODE void Mode3DrawFadeOut();
//EWRAM_CODE void Mode3DrawFadeIn();




//===========================================================================
//Sprite
EWRAM_CODE void SpriteInit();
//Sprite SetData
EWRAM_CODE void SpriteSetPalData16(u16* palData);
EWRAM_CODE void SpriteSetPalData256(u16* palData);
EWRAM_CODE void SpriteSetData(u16* sprData, u32 sprSize);
//Sprite Attribute
EWRAM_CODE void SpriteMove(u16 num, s16 x, s16 y);
EWRAM_CODE void SpriteSetChr(u16 num, u16 ch);
EWRAM_CODE void SpriteSetSize(u16 num, u16 size, u16 form, u16 col);
EWRAM_CODE void SpriteSetPalNo(u16 num, u16 palNo);
EWRAM_CODE void SpriteSetPriority(u16 num, u16 priority);
EWRAM_CODE void SpriteSetVertical(u16 num, u8 flag);
EWRAM_CODE void SpriteSetScale(u16 num, u16 xscale, u16 yscale);
EWRAM_CODE void SpriteSetRotateFlag(u16 num, u16 no, u16 doubleFlag);
EWRAM_CODE void SpriteSetRotate(u16 num, u8 angle, u16 Scale);




//===========================================================================
//Sound
EWRAM_CODE void SoundInit();
EWRAM_CODE void SoundSetData(s8 *offset, u32 size);
EWRAM_CODE void SoundStart();
//EWRAM_CODE void SoundStop();




//===========================================================================
//キー入力
EWRAM_CODE void KeyInit();
EWRAM_CODE bool KeyWaitTimer();
EWRAM_CODE bool KeyRepeat();
EWRAM_CODE u16  KeyGet();
EWRAM_CODE void KeyWait(u16 waitKey);
EWRAM_CODE void KeyWait2(u16 waitKey);




//===========================================================================
//SRAM
EWRAM_CODE u8   SRAMRead8  (u32 offset);
EWRAM_CODE u16  SRAMRead16 (u32 offset);
EWRAM_CODE u32  SRAMRead32 (u32 offset);
EWRAM_CODE void SRAMWrite8 (u32 offset, u8  data);
EWRAM_CODE void SRAMWrite16(u32 offset, u16 data);
EWRAM_CODE void SRAMWrite32(u32 offset, u32 data);
//EWRAM_CODE bool SRAMComp8 (u32 offset, u8  data);
//EWRAM_CODE bool SRAMComp16(u32 offset, u16 data);
//EWRAM_CODE bool SRAMComp32(u32 offset, u32 data);
EWRAM_CODE u8*  SRAMGetPointer();




//===========================================================================
//ExtendTinyFileSystem
EWRAM_CODE u8  EtfsReadu8(u32 offset);
EWRAM_CODE u16 EtfsReadu16(u32 offset);
EWRAM_CODE u32 EtfsReadu32(u32 offset);
EWRAM_CODE u8* EtfsGetPointer();




//===========================================================================
//GBFSFileSystem
EWRAM_CODE bool GBFSInit();
EWRAM_CODE u16  GBFSGetFileCnt();
EWRAM_CODE u8*  GBFSGetFilePointer(char* filename);
EWRAM_CODE u8*  GBFSGetFilePointer2(u32 num);
EWRAM_CODE u8*  GBFSGetFileName();
EWRAM_CODE u32  GBFSGetFileLength();




//===========================================================================
//Seek
EWRAM_CODE void SeekSetChr(u8* pOffset, u32 size, u8 chr);
EWRAM_CODE u8*  SeekNext();
EWRAM_CODE u8*  SeekPrev();
EWRAM_CODE bool SeekHasMore();




//===========================================================================
//Etc
EWRAM_CODE s16 _Sin(u8);
EWRAM_CODE s16 _Cos(u8);
EWRAM_CODE u8  _Angle(s16 dx, s16 dy);

//DMA転送
EWRAM_CODE void DMA3Memcpy32(u32 src, u32 dst, u16 srcMode, u16 dstMode, u16 size);
//ウェイト
EWRAM_CODE void WaitForVsync();
EWRAM_CODE void WaitMs(u32 wait);
//デバック
EWRAM_CODE void DebugMessage(char* msg);


#ifdef __cplusplus
}
#endif
#endif

