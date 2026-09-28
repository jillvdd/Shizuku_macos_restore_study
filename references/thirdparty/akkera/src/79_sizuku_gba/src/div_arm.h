
#ifndef	DIV_ARM_H
#define	DIV_ARM_H
#ifdef __cplusplus
extern "C" {
#endif

#include "header\gba.h"

//Equivalent to '(u32)(n % d)' in C
IWRAM_CODE u32 _UMod(u32 numerator, u32 denominator);


//Equivalent to '(u32)(n / d)' in C
IWRAM_CODE u32 _UDiv(u32 numerator, u32 denominator);


//Equivalent to '(s32)(n / d)' in C
IWRAM_CODE s32 _Div(s32 numerator, s32 denominator);



#ifdef __cplusplus
}
#endif
#endif

