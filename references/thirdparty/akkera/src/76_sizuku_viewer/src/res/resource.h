/* resource.h */

#ifndef __RESOURCE_H__
#define __RESOURCE_H__


#include "spr.h"
#include "mplus_j10r.h"
#include "mplus_s10r.h"

extern const u8 mplus_sfnt_txt;
extern const u8 mplus_jfnt_txt;


#define MPLUS_J10R_FONT_CNT			6963
#define MPLUS_J10R_FONT_CX			10
#define MPLUS_J10R_FONT_CY			11
#define MPLUS_J10R_IMG_CX			69632		//69630ではないので注意。(gitで2ドット余分に生成される)
#define MPLUS_J10R_IMG_CY			11


#define MPLUS_S10R_FONT_CNT			192
#define MPLUS_S10R_FONT_CX			7
#define MPLUS_S10R_FONT_CY			11
#define MPLUS_S10R_IMG_CX			1344
#define MPLUS_S10R_IMG_CY			11


#endif
