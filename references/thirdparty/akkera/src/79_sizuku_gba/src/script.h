
#ifndef __SCRIPT_H__
#define __SCRIPT_H__

#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------------
#define GET_SHORT(p)						(((p)[1]<< 8) | ((p)[0]))
#define GET_LONG(p)							(((p)[3]<<24) | ((p)[2]<<16) | ((p)[1]<<8) | ((p)[0]))

#define _Tolower(ch)						((ch >= 'A' && ch <= 'Z') ? ch - 'A' + 'a' : ch)
#define HexToDig(c)							((_Tolower(c) >= 'a') ? (_Tolower(c) - 'a' + 10) : (c - '0'))
#define HexToDig2(c, c2)					((HexToDig(c) * 16) + HexToDig(c2))
#define Dig(c1,c2)							(c1 - '0') * 10 + (c2 - '0')

#define HISTORY_MAX_CNT						20

#define MENU_MAX_CNT						8
#define MENU_MAX_STR_LENGTH					30
#define MENU_SYSTEM_SX						3		//システム表示の開始位置
#define MENU_SYSTEM_SY						0
#define MENU_START_SX						5		//タイトル表示の開始位置
#define MENU_START_SY						4

//---------------------------------------------------------------------------
typedef struct {
	u8* pScnCurHead;
	u8* pScnCur;									//スクリプトのシナリオ位置
	u8* pTxtCur;									//スクリプトのテキスト位置
	u8* pScn;
	u8* pTxt;
	u16 scnNo;
	u16 scnSize;
	u16 txtSize;
} ST_SCRIPT;


typedef struct {
	u8  cnt;
	u8* pTxtCur[HISTORY_MAX_CNT];
} ST_HISTORY;


typedef struct {
	u8   cnt;
	u8   sx;
	u8   sy;
	bool isCancel;									//メニューのキャンセルの有無

	u8   titleStr[MENU_MAX_STR_LENGTH];
	u8   selStr[MENU_MAX_CNT][MENU_MAX_STR_LENGTH];
	void (*p[MENU_MAX_CNT])();
} ST_MENU;

//---------------------------------------------------------------------------
EWRAM_CODE void ScriptInit();
EWRAM_CODE void ScriptExec();
EWRAM_CODE void ScriptLoad(u8* pScn, u16 scnNo, u16 blk);
EWRAM_CODE void ScriptParserScn();
EWRAM_CODE void ScriptParserTxt(u8 no, bool isHistoryAdd);
EWRAM_CODE void ScriptKey();
EWRAM_CODE u8*  ScriptSelect(u8* c);
EWRAM_CODE void ScriptRestart();


EWRAM_CODE void ScriptLoadBg(u8 no);
EWRAM_CODE void ScriptLoadBgH(u8 no);
EWRAM_CODE void ScriptLoadBgV(u8 no);
EWRAM_CODE void ScriptLoadChr(u8 no, u8 pos);
EWRAM_CODE void ScriptLoadScenario(u16 scn, u16 blk);

EWRAM_CODE u8*  ScriptDrawCode(u8* c);
EWRAM_CODE void ScriptDrawSelect(u8* c, s8 sel);
EWRAM_CODE u16  ScriptGetDrawCode(u8** c, u16* buf);

EWRAM_CODE void ScriptWaitPage();
EWRAM_CODE void ScriptWaitKey();

EWRAM_CODE void ScriptMusicStart(u8 no, bool isLoop);
EWRAM_CODE void ScriptMusicStop();
EWRAM_CODE void ScriptMusicFadeOut();

EWRAM_CODE void ScriptUpdate();
EWRAM_CODE void ScriptUpdate2();
EWRAM_CODE void ScriptUpdateBg();
EWRAM_CODE void ScriptUpdateChr();

EWRAM_CODE void ScriptClear();
EWRAM_CODE void ScriptClearChr(u8 pos);


//----
EWRAM_CODE void HistoryInit();
EWRAM_CODE void HistoryAdd(u8* pTxtCur);
EWRAM_CODE bool HistoryIsEmpty();
EWRAM_CODE void HistoryProc();
EWRAM_CODE void HistoryParserTxt(u8* c);


//----
EWRAM_CODE void MenuInit();
EWRAM_CODE void MenuSetOption(u8 sx, u8 sy, bool isCancel);
EWRAM_CODE void MenuSetTitle(u8* pStr);
EWRAM_CODE void MenuAddSelect(u8* pStr, void* p);
EWRAM_CODE void MenuProc();

EWRAM_CODE void MenuDrawTitle(u16 x, u16 y);
EWRAM_CODE void MenuDrawSelect(u16 sx, u16 sy, s8 sel);

EWRAM_CODE void MenuSetListSystem();
EWRAM_CODE void MenuSystemNextSelect();
EWRAM_CODE void MenuSystemPrevSelect();
EWRAM_CODE void MenuSystemReference();
EWRAM_CODE void MenuSystemFontOut();
EWRAM_CODE void MenuSystemSave();
EWRAM_CODE void MenuSystemLoad();
EWRAM_CODE void MenuSystemGameEnd();
EWRAM_CODE void MenuSystemDebug();

EWRAM_CODE void MenuSetListStart();
EWRAM_CODE void MenuStartGame();
EWRAM_CODE void MenuStartLoad();
EWRAM_CODE void MenuStartEnd();


#ifdef __cplusplus
}
#endif
#endif

