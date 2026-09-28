
#ifndef	BLEND_H
#define BLEND_H
#ifdef __cplusplus
extern "C" {
#endif

// REG_BLDMOD

#define BLEND_TOP_BG0	(1<<0) //"first target"
#define BLEND_TOP_BG1	(1<<1)
#define BLEND_TOP_BG2	(1<<2)
#define BLEND_TOP_BG3	(1<<3)
#define BLEND_TOP_OBJ	(1<<4)
#define BLEND_TOP_BD	(1<<5)
#define BLEND_LOW_BG0	(1<<8) //2nd target
#define BLEND_LOW_BG1	(1<<9)
#define BLEND_LOW_BG2	(1<<10)
#define BLEND_LOW_BG3	(1<<11)
#define BLEND_LOW_OBJ	(1<<12)
#define BLEND_LOW_BD	(1<<13)


// ブレンドモード
#define BLEND_MODE_OFF	(0<<6)
#define BLEND_MODE_ALPHA	(1<<6)
#define BLEND_MODE_LIGHT	(2<<6)
#define BLEND_MODE_DARK	(3<<6)


// REG_COLEV

// ブレンドレベル
#define BLEND_LOW(n)	((n)<<0)
#define BLEND_HIGH(n)	((n)<<8)
#define BLEND_LEVEL(n)	(BLEND_LOW(n) | BLEND_HIGH(n))
#define BLEND_BALANCE(n)	(BLEND_LOW(n) | BLEND_HIGH(16-n))

// REG_COLEY

#define BLEND_DEPTH(n)	((n)<<0)


#ifdef __cplusplus
}
#endif
#endif
