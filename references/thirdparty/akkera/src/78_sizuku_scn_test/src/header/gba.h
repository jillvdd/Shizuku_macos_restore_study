// gba.h by eloist 

#ifndef	GBA_H
#define GBA_H
#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------------
//
typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned long  u32;
typedef signed   char  s8;
typedef signed   short s16;
typedef signed   long  s32;
typedef signed   long  long  int s64;
typedef unsigned char  byte;
typedef unsigned short hword;
typedef unsigned long  word;

typedef unsigned char  bool;
typedef double f32;

typedef volatile unsigned long  vu32;

//---------------------------------------------------------------------------

#define BIT0	1
#define BIT1	2
#define BIT2	4
#define BIT3	8
#define BIT4	16
#define BIT5	32
#define BIT6	64
#define BIT7	128
#define BIT8	256
#define BIT9	512
#define BIT10	1024
#define BIT11	2048
#define BIT12	4096
#define BIT13	8192
#define BIT14	16384
#define BIT15	32768

//---------------------------------------------------------------------------

#define NULL 0
#define TRUE  (1)
#define FALSE (0)

#define  OAMmem        (u32*)0x7000000
#define  VideoBuffer   (u16*)0x6000000
//#define  OAMdata       (u16*)0x6010000
#define  OAMdata       (u16*)0x6014000	//ビットマップモード時
#define  BGpal         (u16*)0x5000000
#define  OBJpal        (u16*)0x5000200

#define REG_INTERUPT   *(volatile u32*)0x3007FFC
#define REG_DISPCNT    *(volatile u32*)0x4000000
#define REG_DISPCNT_L  *(volatile u16*)0x4000000
#define REG_DISPCNT_H  *(volatile u16*)0x4000002
#define REG_DISPSTAT   *(volatile u16*)0x4000004
#define REG_VCOUNT     *(volatile u16*)0x4000006
#define REG_BG0CNT     *(volatile u16*)0x4000008
#define REG_BG1CNT     *(volatile u16*)0x400000A
#define REG_BG2CNT     *(volatile u16*)0x400000C
#define REG_BG3CNT     *(volatile u16*)0x400000E
#define REG_BG0HOFS    *(volatile u16*)0x4000010
#define REG_BG0VOFS    *(volatile u16*)0x4000012
#define REG_BG1HOFS    *(volatile u16*)0x4000014
#define REG_BG1VOFS    *(volatile u16*)0x4000016
#define REG_BG2HOFS    *(volatile u16*)0x4000018
#define REG_BG2VOFS    *(volatile u16*)0x400001A
#define REG_BG3HOFS    *(volatile u16*)0x400001C
#define REG_BG3VOFS    *(volatile u16*)0x400001E
#define REG_BG2PA      *(volatile u16*)0x4000020
#define REG_BG2PB      *(volatile u16*)0x4000022
#define REG_BG2PC      *(volatile u16*)0x4000024
#define REG_BG2PD      *(volatile u16*)0x4000026
#define REG_BG2X       *(volatile u32*)0x4000028
#define REG_BG2X_L     *(volatile u16*)0x4000028
#define REG_BG2X_H     *(volatile u16*)0x400002A
#define REG_BG2Y       *(volatile u32*)0x400002C
#define REG_BG2Y_L     *(volatile u16*)0x400002C
#define REG_BG2Y_H     *(volatile u16*)0x400002E
#define REG_BG3PA      *(volatile u16*)0x4000030
#define REG_BG3PB      *(volatile u16*)0x4000032
#define REG_BG3PC      *(volatile u16*)0x4000034
#define REG_BG3PD      *(volatile u16*)0x4000036
#define REG_BG3X       *(volatile u32*)0x4000038
#define REG_BG3X_L     *(volatile u16*)0x4000038
#define REG_BG3X_H     *(volatile u16*)0x400003A
#define REG_BG3Y       *(volatile u32*)0x400003C
#define REG_BG3Y_L     *(volatile u16*)0x400003C
#define REG_BG3Y_H     *(volatile u16*)0x400003E
#define REG_WIN0H      *(volatile u16*)0x4000040
#define REG_WIN1H      *(volatile u16*)0x4000042
#define REG_WIN0V      *(volatile u16*)0x4000044
#define REG_WIN1V      *(volatile u16*)0x4000046
#define REG_WININ      *(volatile u16*)0x4000048
#define REG_WINOUT     *(volatile u16*)0x400004A
#define REG_MOSAIC     *(volatile u32*)0x400004C
#define REG_MOSAIC_L   *(volatile u32*)0x400004C
#define REG_MOSAIC_H   *(volatile u32*)0x400004E
#define REG_BLDMOD     *(volatile u16*)0x4000050
#define REG_COLEV      *(volatile u16*)0x4000052
#define REG_COLEY      *(volatile u16*)0x4000054
#define REG_SG10_L     *(volatile u16*)0x4000060
#define REG_SG10_H     *(volatile u16*)0x4000062
#define REG_SG11       *(volatile u16*)0x4000064
#define REG_SG20       *(volatile u16*)0x4000068
#define REG_SG21       *(volatile u16*)0x400006C
#define REG_SG30_L     *(volatile u16*)0x4000070
#define REG_SG30_H     *(volatile u16*)0x4000072
#define REG_SG31       *(volatile u16*)0x4000074
#define REG_SG40       *(volatile u16*)0x4000078
#define REG_SG41       *(volatile u16*)0x400007C
#define REG_SGCNT0_L   *(volatile u16*)0x4000080
#define REG_SGCNT0_H   *(volatile u16*)0x4000082
#define REG_SGCNT1     *(volatile u16*)0x4000084
#define REG_SGBIAS     *(volatile u16*)0x4000088
#define REG_SGWR0      *(volatile u32*)0x4000090
#define REG_SGWR0_L    *(volatile u16*)0x4000090
#define REG_SGWR0_H    *(volatile u16*)0x4000092
#define REG_SGWR1      *(volatile u32*)0x4000094
#define REG_SGWR1_L    *(volatile u16*)0x4000094
#define REG_SGWR1_H    *(volatile u16*)0x4000096
#define REG_SGWR2      *(volatile u32*)0x4000098
#define REG_SGWR2_L    *(volatile u16*)0x4000098
#define REG_SGWR2_H    *(volatile u16*)0x400009A
#define REG_SGWR3      *(volatile u32*)0x400009C
#define REG_SGWR3_L    *(volatile u16*)0x400009C
#define REG_SGWR3_H    *(volatile u16*)0x400009E
#define REG_SGFIFOA    *(volatile u32*)0x40000A0
#define REG_SGFIFOA_L  *(volatile u16*)0x40000A0
#define REG_SGFIFOA_H  *(volatile u16*)0x40000A2
#define REG_SGFIFOB    *(volatile u32*)0x40000A4
#define REG_SGFIFOB_L  *(volatile u16*)0x40000A4
#define REG_SGFIFOB_H  *(volatile u16*)0x40000A6
#define REG_DM0SAD     *(volatile u32*)0x40000B0
#define REG_DM0SAD_L   *(volatile u16*)0x40000B0
#define REG_DM0SAD_H   *(volatile u16*)0x40000B2
#define REG_DM0DAD     *(volatile u32*)0x40000B4
#define REG_DM0DAD_L   *(volatile u16*)0x40000B4
#define REG_DM0DAD_H   *(volatile u16*)0x40000B6
#define REG_DM0CNT     *(volatile u32*)0x40000B8
#define REG_DM0CNT_L   *(volatile u16*)0x40000B8
#define REG_DM0CNT_H   *(volatile u16*)0x40000BA
#define REG_DM1SAD     *(volatile u32*)0x40000BC
#define REG_DM1SAD_L   *(volatile u16*)0x40000BC
#define REG_DM1SAD_H   *(volatile u16*)0x40000BE
#define REG_DM1DAD     *(volatile u32*)0x40000C0
#define REG_DM1DAD_L   *(volatile u16*)0x40000C0
#define REG_DM1DAD_H   *(volatile u16*)0x40000C2
#define REG_DM1CNT     *(volatile u32*)0x40000C4
#define REG_DM1CNT_L   *(volatile u16*)0x40000C4
#define REG_DM1CNT_H   *(volatile u16*)0x40000C6
#define REG_DM2SAD     *(volatile u32*)0x40000C8
#define REG_DM2SAD_L   *(volatile u16*)0x40000C8
#define REG_DM2SAD_H   *(volatile u16*)0x40000CA
#define REG_DM2DAD     *(volatile u32*)0x40000CC
#define REG_DM2DAD_L   *(volatile u16*)0x40000CC
#define REG_DM2DAD_H   *(volatile u16*)0x40000CE
#define REG_DM2CNT     *(volatile u32*)0x40000D0
#define REG_DM2CNT_L   *(volatile u16*)0x40000D0
#define REG_DM2CNT_H   *(volatile u16*)0x40000D2
#define REG_DM3SAD     *(volatile u32*)0x40000D4
#define REG_DM3SAD_L   *(volatile u16*)0x40000D4
#define REG_DM3SAD_H   *(volatile u16*)0x40000D6
#define REG_DM3DAD     *(volatile u32*)0x40000D8
#define REG_DM3DAD_L   *(volatile u16*)0x40000D8
#define REG_DM3DAD_H   *(volatile u16*)0x40000DA
#define REG_DM3CNT     *(volatile u32*)0x40000DC
#define REG_DM3CNT_L   *(volatile u16*)0x40000DC
#define REG_DM3CNT_H   *(volatile u16*)0x40000DE
#define REG_TM0D       *(volatile u16*)0x4000100
#define REG_TM0CNT     *(volatile u16*)0x4000102
#define REG_TM1D       *(volatile u16*)0x4000104
#define REG_TM1CNT     *(volatile u16*)0x4000106
#define REG_TM2D       *(volatile u16*)0x4000108
#define REG_TM2CNT     *(volatile u16*)0x400010A
#define REG_TM3D       *(volatile u16*)0x400010C
#define REG_TM3CNT     *(volatile u16*)0x400010E
#define REG_SCD0       *(volatile u16*)0x4000120
#define REG_SCD1       *(volatile u16*)0x4000122
#define REG_SCD2       *(volatile u16*)0x4000124
#define REG_SCD3       *(volatile u16*)0x4000126
#define REG_SCCNT      *(volatile u32*)0x4000128
#define REG_SCCNT_L    *(volatile u16*)0x4000128
#define REG_SCCNT_H    *(volatile u16*)0x400012A
#define REG_P1         *(volatile u16*)0x4000130
#define REG_P1CNT      *(volatile u16*)0x4000132
#define REG_R          *(volatile u16*)0x4000134
#define REG_HS_CTRL    *(volatile u16*)0x4000140
#define REG_JOYRE      *(volatile u32*)0x4000150
#define REG_JOYRE_L    *(volatile u16*)0x4000150
#define REG_JOYRE_H    *(volatile u16*)0x4000152
#define REG_JOYTR      *(volatile u32*)0x4000154
#define REG_JOYTR_L    *(volatile u16*)0x4000154
#define REG_JOYTR_H    *(volatile u16*)0x4000156
#define REG_JSTAT      *(volatile u32*)0x4000158
#define REG_JSTAT_L    *(volatile u16*)0x4000158
#define REG_JSTAT_H    *(volatile u16*)0x400015A
#define REG_IE         *(volatile u16*)0x4000200
#define REG_IF         *(volatile u16*)0x4000202
#define REG_WSCNT      *(volatile u16*)0x4000204
#define REG_IME        *(volatile u16*)0x4000208
#define REG_PAUSE      *(volatile u16*)0x4000300

//---------------------------------------------------------------------------
//REG_DISPCNT defines

#define SetMode(mode) REG_DISPCNT = (mode)
#define MODE_0 0x0
#define MODE_1 0x1
#define MODE_2 0x2
#define MODE_3 0x3
#define MODE_4 0x4
#define MODE_5 0x5

#define BACKBUFFER 0x10
#define H_BLANK_OAM 0x20 

#define OBJ_MAP_2D 0x0
#define OBJ_MAP_1D 0x40

#define FORCE_BLANK 0x80

#define BG0_ENABLE 0x100
#define BG1_ENABLE 0x200 
#define BG2_ENABLE 0x400
#define BG3_ENABLE 0x800
#define OBJ_ENABLE 0x1000 

#define WIN1_ENABLE 0x2000 
#define WIN2_ENABLE 0x4000
#define WINOBJ_ENABLE 0x8000

//---------------------------------------------------------------------------
//Key Define

#define KEYS (volatile u32*)0x04000130
#define KEY_NONE	0x0000
#define KEY_DEC		0x030f
#define KEY_A 		1
#define KEY_B 		2
#define KEY_SELECT	4
#define KEY_START 	8
#define KEY_RIGHT 	16
#define KEY_LEFT 	32
#define KEY_UP 		64
#define KEY_DOWN 	128
#define KEY_MOVE	(16 | 32 | 64 | 128)
#define KEY_R		256
#define KEY_L 		512
#define KEY_LR		(256 | 512)

//---------------------------------------------------------------------------
//2005/09/25 追加
//for WSCNT
#define CST_SRAM_4WAIT		0x0000
#define CST_SRAM_3WAIT		0x0001
#define CST_SRAM_2WAIT		0x0002
#define CST_SRAM_8WAIT		0x0003
#define CST_ROM0_1ST_4WAIT	0x0000
#define CST_ROM0_1ST_3WAIT	0x0004
#define CST_ROM0_1ST_2WAIT	0x0008
#define CST_ROM0_1ST_8WAIT	0x000c
#define CST_ROM0_2ND_2WAIT	0x0000
#define CST_ROM0_2ND_1WAIT	0x0010
#define CST_ROM1_1ST_4WAIT	0x0000
#define CST_ROM1_1ST_3WAIT	0x0020
#define CST_ROM1_1ST_2WAIT	0x0040
#define CST_ROM1_1ST_8WAIT	0x0060
#define CST_ROM1_2ND_4WAIT	0x0000
#define CST_ROM1_2ND_1WAIT	0x0080
#define CST_ROM2_1ST_4WAIT	0x0000
#define CST_ROM2_1ST_3WAIT	0x0100
#define CST_ROM2_1ST_2WAIT	0x0200
#define CST_ROM2_1ST_8WAIT	0x0300
#define CST_ROM2_2ND_8WAIT	0x0000
#define CST_ROM2_2ND_1WAIT	0x0400

#define CST_PHI_OUT_NONE	0x0000 // terminal output clock fixed Lo
#define CST_PHI_OUT_4MCK	0x0800 // 4MHz
#define CST_PHI_OUT_8MCK	0x1000 // 8MHz
#define CST_PHI_OUT_16MCK	0x1800 // 16MHz
#define CST_PREFETCH_ENABLE	0x4000 // Enable prefetch buffer
#define CST_AGB				0x0000 // AGB Game Pak
#define CST_CGB				0x8000 // CGB Game Pak

//---------------------------------------------------------------------------
//オリジナルで追加

#define RGB(r,g,b)	(((b)<<10)+((g)<<5)+(r))

#define SCREEN_CX		240
#define SCREEN_CY		160

#define BG_CX					8
#define BG_CY					8
#define BG_SCREEN_CX			30
#define BG_SCREEN_CY			20
#define BG_WORLD_SCREEN_CX		32
#define BG_WORLD_SCREEN_CY		32
#define BG_WORLD_SCREEN_WCX		256
#define BG_WORLD_SCREEN_WCY		256

#define BG_CHR_BYTE_SIZE		32
#define BG_MAP_BYTE_SIZE		8192
#define BG_MAP_MAX_CNT			1024

#define CR						0x0d
#define LF						0x0a


#ifndef DEBUG
#	define IWRAM_CODE				__attribute__((section(".iwram"), long_call))
#	define EWRAM_CODE				__attribute__((section(".ewram"), long_call))
#	define IWRAM_DATA				__attribute__((section(".iwram")))
#	define EWRAM_DATA				__attribute__((section(".sbss")))
#   define ROM_DATA					__attribute__((section(".roda")))
#else
#	define IWRAM_CODE				__attribute__((section(".iwram"), long_call))
#	define EWRAM_CODE 
#	define IWRAM_DATA				__attribute__((section(".iwram")))
#	define EWRAM_DATA				__attribute__((section(".sbss")))
#   define ROM_DATA					__attribute__((section(".roda")))
#endif

#define ALIGN(m)					__attribute__((aligned (m)))
#define __PACKED					__attribute__ ((__packed__))

#ifdef __cplusplus
}
#endif
#endif

