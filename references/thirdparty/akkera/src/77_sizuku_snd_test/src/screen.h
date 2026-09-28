
#ifndef __SCREEN_H__
#define __SCREEN_H__
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------

//---------------------------------------------------------------------------

typedef struct {
	u16 buf[SCREEN_CX][SCREEN_CY];
} ST_SCREEN_IMG;


//---------------------------------------------------------------------------
EWRAM_CODE void ScreenImgInit();
EWRAM_CODE void ScreenImgCls();
EWRAM_CODE void ScreenImgUpdate();



#ifdef __cplusplus
}
#endif
#endif
