
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"

#include "sizuku.h"

//---------------------------------------------------------------------------
ST_SIZUKU Sizuku;


//---------------------------------------------------------------------------
EWRAM_CODE void SizukuInit()
{
	_Memset((u8*)&Sizuku, 0x00, sizeof(ST_SIZUKU));
}
//---------------------------------------------------------------------------
//シナリオフラグの変換
EWRAM_CODE u8 SizukuCalcSysFlag(u8 no)
{
	switch (no)
	{
	case 0:			//エンディング状態記録(非初期化対象)
		return 0;

	case 1:			//雑フラグ
		return 1;

	case 0x40:		//瑠璃子と約束
	case 0x41:		//怪しい人影
	case 0x42:		//部活動で変わったこと
	case 0x43:		//体育館で…
	case 0x44:		//瑠璃子屋上「届かなかった」
	case 0x45:		//瑠璃子 TRUE  (非初期化対象)
	case 0x46:		//瑠璃子 HAPPY (非初期化対象)
	case 0x47:		//佐織ルートON
	case 0x48:		//佐織 Hシーン
	case 0x49:		//おそらく未使用
	case 0x4a:		//瑞穂移動場所制御用
	case 0x4b:		//オルゴールぜんまい
		return 2 + no - 0x40;

	default:
		TRACEOUT("SizukuGetSysFlag Bad Flag No[%02x]", no);
		for(;;){}
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE u8 SizukuGetSysFlag(u8 no)
{
	return Sizuku.sysFlag[ SizukuCalcSysFlag(no) ];
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetSysFlag(u8 no, u8 val)
{
	Sizuku.sysFlag[ SizukuCalcSysFlag(no) ] = val;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuAddSysFlag(u8 no, u8 val)
{
	Sizuku.sysFlag[ SizukuCalcSysFlag(no) ] += val;
}
//---------------------------------------------------------------------------
//BGMパラメータの変換
EWRAM_CODE u8 SizukuGetBgmNo(u8 no)
{
	if(no == 14)
	{
		return 2;
	}
	else if(no < 16)
	{
		return no+2;
	}

	return no+1;
}
