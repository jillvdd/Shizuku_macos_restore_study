
#ifndef __SCRIPT_H__
#define __SCRIPT_H__

#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------------
#define GET_SHORT(p)						(((p)[1]<<8)|(p)[0])
#define GET_LONG(p)							((p)[3]<<24|(p)[2]<<16|(p)[1]<<8|(p)[0])
#define Dig(c1,c2)							(c1 - '0') * 10 + (c2 - '0')

#define HISTORY_CNT							10

//---------------------------------------------------------------------------
typedef struct {
	u16 scnOffset;
	u16 txtOffset;
	u16 scnSize;
	u16 txtSize;
} __PACKED ST_SCRIPT_HEADER;


typedef struct {
	u8* pScnCurHead;
	u8* pScnCur;
	u8* pTxtCur;
	u8* pScn;
	u8* pTxt;
	u16 scnNo;
	u16 scnSize;
	u16 txtSize;
} ST_SCRIPT;


typedef struct {
	u8  cnt;
	u8* pTxtCur[HISTORY_CNT];
} ST_HISTORY;

//---------------------------------------------------------------------------

EWRAM_CODE void ScriptInit();
EWRAM_CODE void ScriptExec();
EWRAM_CODE void ScriptLoad(u8* pScn, u16 scnNo, u16 blk);
EWRAM_CODE void ScriptParserScn();
EWRAM_CODE void ScriptParserTxt(u8 no, bool isHistoryAdd);
EWRAM_CODE void ScriptKey();


EWRAM_CODE void ScriptLoadScenario(u16 scn, u16 blk);
EWRAM_CODE u8*  ScriptDrawCode(u8* c);
EWRAM_CODE void ScriptDrawSelect(u8* c, s8 sel);
EWRAM_CODE u8*  ScriptWaitSelect(u8* c);
EWRAM_CODE void ScriptWaitPage();
EWRAM_CODE void ScriptWaitKey();
EWRAM_CODE void ScriptMusicStart(u8 no, bool isLoop);
EWRAM_CODE void ScriptMusicStop();
EWRAM_CODE void ScriptMusicFadeOut();


EWRAM_CODE void ScriptDebugScn(u16 no);
EWRAM_CODE void ScriptDebugTxt(u8 no);

//----

EWRAM_CODE void HistoryInit();
EWRAM_CODE void HistoryAdd(u8* pTxtCur);
EWRAM_CODE bool HistoryIsEmpty();
EWRAM_CODE void HistoryReferebce();
EWRAM_CODE void HistoryParserTxt(u8* c);


#ifdef __cplusplus
}
#endif
#endif

