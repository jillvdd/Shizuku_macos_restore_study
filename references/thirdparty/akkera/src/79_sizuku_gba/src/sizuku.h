
#ifndef __SIZUKU_H__
#define __SIZUKU_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define SIZUKU_SCN_CNT						197
#define SIZUKU_SND_CNT						24
#define SIZUKU_SYS_FLAG_CNT					14

#define SIZUKU_BG_STR						(u8*)"MAX_S%02d.img"
#define SIZUKU_CHR_STR						(u8*)"MAX_C%02x.img"
#define SIZUKU_HVS_STR						(u8*)"HVS%02d.img"
#define SIZUKU_VIS_STR						(u8*)"VIS%02d.img"
#define SIZUKU_SCN_STR						(u8*)"SCN%03d.DAT"
#define SIZUKU_SND_STR						(u8*)"tr_%03d.8ad"

//---------------------------------------------------------------------------
enum {
	BG_NONE,
	BG_VISUAL,
	BG_HCG,
	BG_BACK,
};

//---------------------------------------------------------------------------
typedef struct {
	u8   sys[SIZUKU_SYS_FLAG_CNT];			//シナリオ制御用フラグ
	u16  scnNo;
	u16  blkNo;
	u8   bgmNo;
	u32  bgmSize;
	u8   bgType;
	u8   bgNo;
	bool chr[3];
	u8   chrNo[3];
} ST_SIZUKU_FLAG;


typedef struct {
	bool isNext;							//次の選択肢まで進むフラグ
	bool isEnd;								//スクリプトを任意に終了させるフラグ
	bool isRestart;							//スクリプト実行中、SRAMロードするフラグ

	ST_SIZUKU_FLAG flag;
} ST_SIZUKU;


typedef struct {
	u16 scnOffset;
	u16 txtOffset;
	u16 scnSize;
	u16 txtSize;
} __PACKED ST_SCRIPT_HEADER;


typedef struct {
	u16 cx;
	u16 cy;
} __PACKED ST_IMG_HEADER;


//---------------------------------------------------------------------------
EWRAM_CODE void SizukuInit();
EWRAM_CODE void SizukuInitScenario();

EWRAM_CODE u8   SizukuGetMapSys(u8 no);
EWRAM_CODE u8   SizukuGetMapBgm(u8 no);
EWRAM_CODE u8   SizukuGetMapBg(u8 no);
EWRAM_CODE u8   SizukuGetMapEffect(u8 no);
EWRAM_CODE u8   SizukuGetMapVis(u8 no);
EWRAM_CODE u8   SizukuGetMapChr(u8 pos);

EWRAM_CODE u8   SizukuGetSysFlag(u8 no);
EWRAM_CODE void SizukuSetSysFlag(u8 no, u8 val);
EWRAM_CODE void SizukuAddSysFlag(u8 no, u8 val);

EWRAM_CODE bool SizukuIsEndFlag();
EWRAM_CODE bool SizukuIsNextFlag();
EWRAM_CODE bool SizukuIsRestartFlag();
EWRAM_CODE void SizukuSetEndFlag(bool flag);
EWRAM_CODE void SizukuSetNextFlag(bool flag);
EWRAM_CODE void SizukuSetRestartFlag(bool flag);


EWRAM_CODE ST_SIZUKU_FLAG* SizukuGetFlagPointer();
EWRAM_CODE void SizukuSetFlagBg(u8 type, u8 no);
EWRAM_CODE void SizukuSetFlagChr(u8 no, u8 pos);
EWRAM_CODE void SizukuSetFlagChrClear(u8 pos);


EWRAM_CODE u8*  SizukuLoad(u8* name, u16 no, bool isErr);
EWRAM_CODE u8*  SizukuLoad2(u8* name, bool isErr);
EWRAM_CODE u8*  SizukuLoadScn(u16 scnNo, u16 blkNo);
EWRAM_CODE u8*  SizukuLoadSnd(u8 no);
EWRAM_CODE u8*  SizukuLoadBg();
EWRAM_CODE u8*  SizukuLoadChr(u8 pos);


EWRAM_CODE bool SizukuIsSRAM();
EWRAM_CODE void SizukuSetSRAM();
EWRAM_CODE void SizukuLoadSRAM();
EWRAM_CODE void SizukuSaveSRAM();


#ifdef __cplusplus
}
#endif
#endif
