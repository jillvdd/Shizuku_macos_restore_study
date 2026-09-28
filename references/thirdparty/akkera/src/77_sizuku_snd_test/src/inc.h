
#ifndef INC_H
#define INC_H
#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------------

#include "header\gba.h"

#include "header\bg.h"
#include "header\blend.h"
#include "header\dma.h"
#include "header\irq.h"
#include "header\sound.h"
#include "header\sprite.h"
#include "header\timer.h"

#include "res\resource.h"

//---------------------------------------------------------------------------
#define FIX_POWER				64

#define INT2FIX(A)				( (A) * FIX_POWER )
#define FIX2INT(A)				( _Div((A), FIX_POWER) )
#define FIX_MUL(A,B)			( _Div(((A) * (B)), FIX_POWER) )
#define FIX_DIV(A,B)			( _Div(((A) * FIX_POWER), (B)) )

#define PI						INT2FIX(3.14)				//3.141592654f

#define MAX(a,b)				(((a) > (b)) ? (a) : (b))
#define MIN(a,b)				(((a) < (b)) ? (a) : (b))

#define COLOR_WHITE				RGB(31,31,31)
#define COLOR_GREEN				RGB( 0,31, 0)
#define COLOR_GRAY				RGB(16,16,16)
#define COLOR_BLACK				RGB( 0, 0, 0)

//---------------------------------------------------------------------------



#ifdef __cplusplus
}
#endif
#endif

