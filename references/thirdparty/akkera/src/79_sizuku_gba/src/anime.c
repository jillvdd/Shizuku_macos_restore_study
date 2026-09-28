
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "ad_arm.h"
#include "gbfs.h"
#include "lib.h"
#include "main.h"
#include "screen.h"
#include "script.h"
#include "sizuku.h"

#include "anime.h"

//---------------------------------------------------------------------------
//「ジングル」データ
ROM_DATA ST_ANIME_PAT AnimeDatJingle[] = {
	{ ANIME_SOUND     ,    2 },
	{ ANIME_LIGHT_IN  ,   60 },
	{ ANIME_FILLBOX   ,    0 },
	{ ANIME_IMAGE2    ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_LIGHT_OUT ,   60 },
	{ ANIME_WAIT      ,  500 },
	{ ANIME_WAVE      ,    0 },
	{ ANIME_WAIT      , 2000 },

	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//「ジングル」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgJingle[] = {
	{ "LEAF.img" },
	{ "" },
};



//-------------------------------------------------------
//「涙の雫」データ
ROM_DATA ST_ANIME_PAT AnimeDatSizuku[] = {
	{ ANIME_SET       ,   17 },
	{ ANIME_IMAGE2    ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_WAIT      ,  200 },
	{ ANIME_DEC       ,    0 },
	{ ANIME_IF        ,    1 },

	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//「涙の雫」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgSizuku[] = {
	{ "OP_S00.img" },
	{ "OP_S01.img" },
	{ "OP_S02.img" },
	{ "OP_S03.img" },
	{ "OP_S04.img" },
	{ "OP_S05.img" },
	{ "OP_S06.img" },
	{ "OP_S07.img" },
	{ "OP_S08.img" },
	{ "OP_S09.img" },
	{ "OP_S10.img" },
	{ "OP_S11.img" },
	{ "OP_S12.img" },
	{ "OP_S13.img" },
	{ "OP_S14.img" },
	{ "OP_S15.img" },
	{ "OP_S16.img" },
	{ "" },
};


//-------------------------------------------------------
//「瑞穂」データ
ROM_DATA ST_ANIME_PAT AnimeDatMizuho[] = {
	{ ANIME_DARK_IN   ,    0 },
	{ ANIME_IMAGE     ,  110 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_WAIT      , 1000 },

	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//「瑞穂」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgMizuho[] = {
	{ "OP_V0.img" },
	{ "" },
};


//-------------------------------------------------------
//「沙織」データ
ROM_DATA ST_ANIME_PAT AnimeDatSaori[] = {
	{ ANIME_DARK_IN   ,    0 },
	{ ANIME_IMAGE     ,   30 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_WAIT      , 1000 },

	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//「沙織」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgSaori[] = {
	{ "OP_V1.img" },
	{ "" },
};


//-------------------------------------------------------
//「瑠璃子」データ
ROM_DATA ST_ANIME_PAT AnimeDatRuriko[] = {
	{ ANIME_SET       ,   39 },
	{ ANIME_DARK_IN   ,    0 },
	{ ANIME_IMAGE     ,   70 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_IMAGE     ,   70 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_WAIT      ,  200 },
	{ ANIME_DEC       ,    0 },
	{ ANIME_IF        ,    5 },

	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};

//「瑠璃子」データ
ROM_DATA ST_ANIME_IMG AnimeImgRuriko[] = {
	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L1.img" },
	{ "OP_L2.img" },
	{ "OP_L1.img" },

	{ "OP_L0.img" },
	{ "OP_L3.img" },
	{ "OP_L4.img" },
	{ "OP_L5.img" },

	{ "OP_L6.img" },
	{ "OP_L7.img" },
	{ "OP_L8.img" },
	{ "OP_L7.img" },

	{ "OP_L6.img" },
	{ "OP_L7.img" },
	{ "OP_L8.img" },
	{ "OP_L7.img" },

	{ "OP_L6.img" },
	{ "OP_L7.img" },
	{ "OP_L8.img" },
	{ "OP_L7.img" },
	{ "" },
};
//-------------------------------------------------------
//「タイトル1」データ
ROM_DATA ST_ANIME_PAT AnimeDatTitle1[] = {
	{ ANIME_DARK_IN   ,    0 },
	{ ANIME_IMAGE     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_WAIT      , 2000 },
	{ ANIME_IMAGE3    ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_KEY       ,    0 },
	{ ANIME_END       ,    0 },
};


//「タイトル2」データ
ROM_DATA ST_ANIME_PAT AnimeDatTitle2[] = {
	{ ANIME_DARK_IN   ,    0 },
	{ ANIME_IMAGE     ,    0 },
	{ ANIME_IMAGE3    ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_END       ,    0 },
};


//「タイトル1」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgTitle[] = {
	{ "TITLE0.img" },
	{ "TITLE.img"  },
};


//-------------------------------------------------------
//「画面消去」データ
ROM_DATA ST_ANIME_PAT AnimeDatCls[] = {
	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//-------------------------------------------------------
//「エンディング」データ
ROM_DATA ST_ANIME_PAT AnimeDatEnding[] = {
	{ ANIME_SET       ,   14 },
	{ ANIME_DARK_IN   ,    0 },

	{ ANIME_IMAGE     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,   60 },
	{ ANIME_FONT      ,    0 },
	{ ANIME_WAIT      , 2000 },
	{ ANIME_CLEAR_FONT,    0 },
	{ ANIME_DARK_IN   ,   60 },
	{ ANIME_DEC       ,    0 },
	{ ANIME_IF        ,    2 },

	{ ANIME_CLEAR_FONT,    0 },
	{ ANIME_CLEAR     ,    0 },
	{ ANIME_UPDATE    ,    0 },
	{ ANIME_DARK_OUT  ,    0 },
	{ ANIME_END       ,    0 },
};


//「エンディング」イメージ
ROM_DATA ST_ANIME_IMG AnimeImgEnding[] = {
	{ "MAX_S02.img" },
	{ "MAX_S10.img" },
	{ "MAX_S11.img" },
	{ "MAX_S12.img" },
	{ "MAX_S13.img" },
	{ "MAX_S15.img" },
	{ "MAX_S20.img" },
	{ "MAX_S22.img" },
	{ "MAX_S24.img" },
	{ "MAX_S26.img" },
	{ "MAX_S27.img" },
	{ "MAX_S31.img" },
	{ "MAX_S34.img" },
	{ "MAX_S02.img" },
	{ "" },
};


//「エンディング」テキスト
ROM_DATA ST_ANIME_TXT AnimeTxtEnding[] = {
	{ "プログラム"                  ,  3 },
	{ "ＨＡＪＩＭＥ　ＮＩＮＯＭＡＥ",  5 },
	{ ""                            ,  0 },

	{ "キャラクター原案"            ,  3 },
	{ "高彦　龍哉"                  ,  5 },
	{ ""                            ,  0 },

	{ "原画"                        ,  3 },
	{ "水無月　徹"                  ,  5 },
	{ ""                            ,  0 },

	{ "脚本"                        ,  3 },
	{ "高橋　龍也"                  ,  5 },
	{ ""                            ,  0 },

	{ "ビジュアルグラフィックス"    ,  2 },
	{ "鳥野　正信"                  ,  4 },
	{ "ＨＡＭＭＥＲ"                ,  5 },
	{ "親父油"                      ,  6 },
	{ "生波夢"                      ,  7 },
	{ "ＤＯＺＡ"                    ,  8 },
	{ ""                            ,  0 },

	{ "キャラクターグラフィックス"  ,  3 },
	{ "ＨＡＭＭＥＲ"                ,  5 },
	{ "鳥野　正信"                  ,  6 },
	{ ""                            ,  0 },

	{ "背景グラフィックス"          ,  3 },
	{ "鳥野　正信"                  ,  5 },
	{ "親父油"                      ,  6 },
	{ "生波夢"                      ,  7 },
	{ ""                            ,  0 },

	{ "オリジナルフォント"          ,  3 },
	{ "ＨＡＭＭＥＲ"                ,  5 },
	{ "爆裂煙々黒頭巾"              ,  6 },
	{ "水無月　徹"                  ,  7 },
	{ ""                            ,  0 },

	{ "シーン構\成"                 ,  3 },
	{ "ＯＲＩＢＡＳＳ"              ,  5 },
	{ "葉月　優一"                  ,  6 },
	{ "水無月　徹"                  ,  7 },
	{ "初号機"                      ,  8 },
	{ ""                            ,  0 },

	{ "音楽"                        ,  3 },
	{ "折戸　伸治"                  ,  5 },
	{ "下川　直哉"                  ,  6 },
	{ "石川　真也"                  ,  7 },
	{ ""                            ,  0 },

	{ "ＴＥＳＴ　ＰＬＡＹ"          ,  3 },
	{ "ＡＬＬ　ＬＥＡＦ　ＳＴＡＦＦ",  5 },
	{ ""                            ,  0 },

	{ "ＳＰＥＣＩＡＬ　ＴＨＡＮＸ"  ,  3 },
	{ "ＫＥＮ　ＫＥＮ"              ,  5 },
	{ ""                            ,  0 },

	{ "ＡＮＤ　ＹＯＵ"              ,  4 },
	{ ""                            ,  0 },

	{ "企画・開発"                  ,  3 },
	{ "１９９６　ＬＥＡＦ"          ,  5 },
	{ ""                            ,  0 },
};




//---------------------------------------------------------------------------
//lib.c
extern ST_TIMER Timer;

//---------------------------------------------------------------------------
ST_ANIME Anime;


//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecJingle()
{
	AnimeInit();
	AnimeSetData(AnimeDatJingle, AnimeImgJingle, NULL, FALSE);
	AnimeExec();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecOpening()
{
	AnimePatSound(16);
	AnimeInit();

	//雫
	AnimeSetData(AnimeDatSizuku, AnimeImgSizuku, NULL, TRUE);
	AnimeExec();

	//瑞穂
	AnimeSetData(AnimeDatMizuho, AnimeImgMizuho, NULL, TRUE);
	AnimeExec();

	//雫
	AnimeSetData(AnimeDatSizuku, AnimeImgSizuku, NULL, TRUE);
	AnimeExec();

	//沙織
	AnimeSetData(AnimeDatSaori, AnimeImgSaori, NULL, TRUE);
	AnimeExec();

	//雫
	AnimeSetData(AnimeDatSizuku, AnimeImgSizuku, NULL, TRUE);
	AnimeExec();

	//瑠璃子
	AnimeSetData(AnimeDatRuriko, AnimeImgRuriko, NULL, TRUE);
	AnimeExec();

	//タイトル1
	AnimeSetData(AnimeDatTitle1, AnimeImgTitle, NULL, TRUE);
	AnimeExec();

	//途中でオープニングが中断されたかチェックをします
	if( AnimeIsKey() == TRUE )
	{
		AnimeSetData(AnimeDatCls, NULL, NULL, FALSE);
		AnimeExec();
	}

	AdStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecTitle()
{
	//タイトル2
	AnimeInit();
	AnimeSetData(AnimeDatTitle2, AnimeImgTitle, NULL, FALSE);
	AnimeExec();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecSizuku()
{
	//雫（単体）
	AnimeInit();
	AnimeSetData(AnimeDatSizuku, AnimeImgSizuku, NULL, FALSE);
	AnimeExec();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecEnding()
{
	//エンディング
	AnimeInit();
	AnimeSetData(AnimeDatEnding, AnimeImgEnding, AnimeTxtEnding, FALSE);
	AnimeExec();

	AdStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeInit()
{
	_Memset((u8*)&Anime, 0x00, sizeof(ST_ANIME));
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeSetData(ST_ANIME_PAT* pPat, ST_ANIME_IMG* pImg, ST_ANIME_TXT* pTxt, bool isAnimeOut)
{
	Anime.pPat       = pPat;
	Anime.pImg       = pImg;
	Anime.pTxt       = pTxt;
	Anime.isAnimeOut = isAnimeOut;
	Anime.isEnd      = FALSE;
	Anime.val        = 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExec()
{
	ST_ANIME*     a = &Anime;
	ST_ANIME_PAT* p = &Anime.pPat[0];
	ST_ANIME_IMG* m = &Anime.pImg[0];
	ST_ANIME_TXT* t = &Anime.pTxt[0];

	u16 patCnt = 0 - 1;
	u16 imgCnt = 0;
	u16 txtCnt = 0;

	if(a->isKey == TRUE && a->isAnimeOut == TRUE)
	{
		return;
	}

	for(;;)
	{
		patCnt++;

		if((a->isKey == TRUE && a->isAnimeOut == TRUE) || a->isEnd == TRUE)
		{
			AnimeExecEnd();
			return;
		}

		switch(p[patCnt].type)
		{
		case ANIME_IMAGE:
			AnimePatImage(p[patCnt].num, m[imgCnt].name);
			imgCnt++;
			break;

		case ANIME_IMAGE2:
			AnimePatImage2(m[imgCnt].name);
			imgCnt++;
			break;

		case ANIME_IMAGE3:
			AnimePatImage3(m[imgCnt].name);
			imgCnt++;
			break;

		case ANIME_SOUND:
			AnimePatSound(p[patCnt].num);
			break;

		case ANIME_LIGHT_IN:
			AnimePatLightIn(p[patCnt].num);
			break;

		case ANIME_LIGHT_OUT:
			AnimePatLightOut(p[patCnt].num);
			break;

		case ANIME_DARK_IN:
			AnimePatDarkIn(p[patCnt].num);
			break;

		case ANIME_DARK_OUT:  
			AnimePatDarkOut(p[patCnt].num);
			break;

		case ANIME_WAVE:
			AnimePatWave();
			break;

		case ANIME_CLEAR:
			AnimePatClear();
			break;

		case ANIME_CLEAR_FONT:
			AnimePatClearFont();
			break;

		case ANIME_FONT:
			do
			{
				AnimePatFont(t[txtCnt].txt, t[txtCnt].y);

			} while(t[txtCnt++].txt[0] != '\0');

			break;

		case ANIME_UPDATE:
			AnimePatUpdate();
			break;

		case ANIME_FILLBOX:
			AnimePatFillBox();
			break;

		case ANIME_WAIT:
			AnimePatWait(p[patCnt].num);
			break;

		case ANIME_KEY:
			AnimePatKey();
			break;

		case ANIME_IF:
			if(a->val != 0)
			{
				patCnt = p[patCnt].num - 1;		//-1は、この命令の処理で発生するインクリメント分
			}
			break;

		case ANIME_DEC:
			a->val--;
			break;

		case ANIME_SET:
			a->val = p[patCnt].num;
			break;

		case ANIME_END:
			a->isEnd = TRUE;
			break;

		default:
			TRACEOUT("Err: AnimeExec = %2x\n", p->type);
			for(;;){}
			break;
		}

	} // for(;;)
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatSound(u16 num)
{
	if(num == 0)
	{
		AdStop();
		return;
	}

	u8* pSnd = SizukuLoad(SIZUKU_SND_STR, num, FALSE);
	if(pSnd == NULL)
	{
		return;
	}

	AdStart(pSnd, GBFSGetFileLength(), FALSE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatLightIn(u16 num)
{
	Mode3DrawBlend(BLEND_MODE_LIGHT, 0, 15);
	Mode3DrawFadeIn(num);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatLightOut(u16 num)
{
	Mode3DrawFadeOut(num);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatImage(u16 num, u8* pName)
{
	ST_IMG_HEADER* h = (ST_IMG_HEADER*)AnimeLoadImage(pName);

	Mode3DrawImage(num, SCREEN_CY - h->cy, h->cx, h->cy, (u16*)(h+1));
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatImage2(u8* pName)
{
	ST_IMG_HEADER* h = (ST_IMG_HEADER*)AnimeLoadImage(pName);
	u16 sx = (SCREEN_CX / 2) - (h->cx / 2);
	u16 sy = (SCREEN_CY / 2) - (h->cy / 2);

	Mode3DrawImage(sx, sy, h->cx, h->cy, (u16*)(h+1));
}
//---------------------------------------------------------------------------
//タイトルの「雫」表示専用(決め打ちしてます)
EWRAM_CODE void AnimePatImage3(u8* pName)
{
	ST_IMG_HEADER* h = (ST_IMG_HEADER*)AnimeLoadImage(pName);

	Mode3DrawImage(84, 13, h->cx, h->cy, (u16*)(h+1));
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatFillBox()
{
	//今のところ白色のみ対応
	Mode3DrawFillBox(0, 0, SCREEN_CX, SCREEN_CY, COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatUpdate()
{
	ScreenImgUpdate();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatWait(u16 num)
{
	u32 t = Timer.clockTick;
	u16 key;

	while(Timer.clockTick - t < num)
	{
		key = KeyGet2();

		if(key != KEY_NONE)
		{
			Anime.isKey = TRUE;

			if(Anime.isAnimeOut == TRUE)
			{
				return;
			}
		}
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatWave()
{
	u16 i, j, k;
	u16 key;

	for(i=0; i<SCREEN_CX; i++)
	{
		j = (SCREEN_CX - 1) - i;
		k = (SCREEN_CY - 1) - 32;

		Mode3DrawFillBox(i, 0, 1, 32, COLOR_BLACK);
		Mode3DrawFillBox(j, k, 1, 32, COLOR_BLACK);
		ScreenImgUpdate();

		key = KeyGet();

		if(key != KEY_NONE)
		{
			Anime.isKey = TRUE;

			if(Anime.isAnimeOut == TRUE)
			{
				return;
			}
		}
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatClear()
{
	ScreenImgClear();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatClearFont()
{
	ScreenFontClear();
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatFont(u8* txt, u16 num)
{
	u16 len = _Strlen(txt) / 2;
	u16 x   = (SCREEN_FONT_CX / 2)  - (len / 2) - 1;

	ScreenFontDrawStrSJISNoBuf(x, num, txt);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatDarkIn(u16 num)
{
	Mode3DrawBlend(BLEND_MODE_DARK, 0, 15);
	Mode3DrawFadeIn(num);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatDarkOut(u16 num)
{
	Mode3DrawFadeOut(num);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimePatKey()
{
	KeyWait2(KEY_A);
}
//---------------------------------------------------------------------------
EWRAM_CODE void AnimeExecEnd()
{
	
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* AnimeLoadImage(u8* pName)
{
	return SizukuLoad2(pName, TRUE);
}
//---------------------------------------------------------------------------
EWRAM_CODE bool AnimeIsKey()
{
	return Anime.isKey;
}
