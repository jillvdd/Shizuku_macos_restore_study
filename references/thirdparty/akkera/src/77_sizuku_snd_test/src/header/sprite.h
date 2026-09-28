
#ifndef	SPRITE_H
#define SPRITE_H
#ifdef __cplusplus
extern "C" {
#endif

#define MAX_SPRITE		128


//Atribute0 stuff
#define SP_ROTATION_FLAG 	0x100
#define SP_SIZE_DOUBLE		0x200
#define SP_MODE_NORMAL     	0x0
#define SP_MODE_TRANSPERANT	0x400
#define SP_MODE_WINDOWED	0x800
#define SP_MOSAIC		0x1000
#define SP_COLOR_16		0x0000
#define SP_COLOR_256	0x2000
#define SP_SQUARE		0x0
#define SP_WIDE			0x4000
#define SP_TALL			0x8000

//Atribute1 stuff
#define SP_ROTDATA(n)		((n) << 9)
#define SP_HORIZONTAL_FLIP	0x1000
#define SP_VERTICAL_FLIP	0x2000
#define SP_SIZE_8			0x0
#define SP_SIZE_16			0x4000
#define SP_SIZE_32			0x8000
#define SP_SIZE_64			0xC000

//atribute2 stuff

#define SP_PRIORITY(n)		((n) << 10)
#define SP_PALETTE(n)		((n) << 12)


/////structs/////

typedef struct tagOAMEntry
{
	u16 attribute0;
	u16 attribute1;
	u16 attribute2;
	u16 attribute3;
}OAMEntry,*pOAMEntry;

typedef struct tagRotData
{
		
	u16 filler1[3];
	u16 pa;

	u16 filler2[3];
	u16 pb;	
		
	u16 filler3[3];
	u16 pc;	

	u16 filler4[3];
	u16 pd;
}RotData,*pRotData;


#ifdef __cplusplus
}
#endif
#endif
