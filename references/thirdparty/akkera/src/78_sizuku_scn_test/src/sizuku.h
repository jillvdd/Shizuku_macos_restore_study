
#ifndef __SIZUKU_H__
#define __SIZUKU_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define SIZUKU_SCN_CNT						197
#define SIZUKU_SND_CNT						24
#define SIZUKU_SYS_FLAG_CNT					14

#define SIZUKU_SCN_STR						"SCN%03d.DAT"
#define SIZUKU_SND_STR						"tr_%03d.8ad"

//---------------------------------------------------------------------------
typedef struct {
	u8  sysFlag[SIZUKU_SYS_FLAG_CNT];		//シナリオ制御用フラグ

} ST_SIZUKU;


//---------------------------------------------------------------------------
EWRAM_CODE void SizukuInit();

EWRAM_CODE u8   SizukuGetSysFlag(u8 no);
EWRAM_CODE void SizukuSetSysFlag(u8 no, u8 val);
EWRAM_CODE void SizukuAddSysFlag(u8 no, u8 val);
EWRAM_CODE u8   SizukuCalcSysFlag(u8 no);

EWRAM_CODE u8   SizukuGetBgmNo(u8 no);


#ifdef __cplusplus
}
#endif
#endif
