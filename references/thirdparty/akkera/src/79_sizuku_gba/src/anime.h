
#ifndef __ANIME_H__
#define __ANIME_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
//アニメーション用トークンリスト
enum {
	ANIME_IMAGE = 0x01,
	ANIME_IMAGE2,
	ANIME_IMAGE3,
	ANIME_SOUND,
	ANIME_LIGHT_IN,
	ANIME_LIGHT_OUT,
	ANIME_DARK_IN,
	ANIME_DARK_OUT,
	ANIME_WAVE,
	ANIME_CLEAR,
	ANIME_CLEAR_FONT,
	ANIME_FONT,
	ANIME_UPDATE,
	ANIME_FILLBOX,
	ANIME_WAIT,
	ANIME_KEY,
	ANIME_IF,
	ANIME_DEC,
	ANIME_SET,
	ANIME_END,
};
//---------------------------------------------------------------------------
//パターンデータ
typedef struct {
	u8  type;
	u16 num;
} ST_ANIME_PAT;


//イメージデータ
typedef struct {
	u8 name[12];
} ST_ANIME_IMG;


//テキストデータ
typedef struct {
	u8  txt[34+1];
	u16 y;
} ST_ANIME_TXT;


typedef struct {
	bool isKey;				//アニメーション中にキーが押された場合のフラグ
	bool isAnimeOut;		//アニメーションの中断有無
	bool isEnd;				//アニメーションが中断したかのフラグ
	u16  val;

	ST_ANIME_PAT* pPat;
	ST_ANIME_IMG* pImg;
	ST_ANIME_TXT* pTxt;
} ST_ANIME;


//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecJingle();
EWRAM_CODE void AnimeExecOpening();
EWRAM_CODE void AnimeExecTitle();
EWRAM_CODE void AnimeExecSizuku();
EWRAM_CODE void AnimeExecEnding();

//----
EWRAM_CODE void AnimeInit();
EWRAM_CODE void AnimeSetData(ST_ANIME_PAT* pPat, ST_ANIME_IMG* pImg, ST_ANIME_TXT* pTxt, bool isAnimeOut);
EWRAM_CODE void AnimeExec();
EWRAM_CODE void AnimeExecEnd();

EWRAM_CODE void AnimePatSound(u16 num);
EWRAM_CODE void AnimePatLightIn(u16 num);
EWRAM_CODE void AnimePatLightOut(u16 num);
EWRAM_CODE void AnimePatImage(u16 num, u8* pName);
EWRAM_CODE void AnimePatImage2(u8* pName);
EWRAM_CODE void AnimePatImage3(u8* pName);
EWRAM_CODE void AnimePatFillBox();
EWRAM_CODE void AnimePatUpdate();
EWRAM_CODE void AnimePatWait(u16 num);
EWRAM_CODE void AnimePatWave();
EWRAM_CODE void AnimePatClear();
EWRAM_CODE void AnimePatClearFont();
EWRAM_CODE void AnimePatFont(u8* txt, u16 num);
EWRAM_CODE void AnimePatDarkIn(u16 num);
EWRAM_CODE void AnimePatDarkOut(u16 num);
EWRAM_CODE void AnimePatKey();

EWRAM_CODE u8*  AnimeLoadImage(u8* pName);
EWRAM_CODE bool AnimeIsKey();

#ifdef __cplusplus
}
#endif
#endif
