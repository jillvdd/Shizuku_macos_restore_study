
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "bios_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"
#include "main.h"
#include "screen.h"

#include "sizuku.h"

//---------------------------------------------------------------------------
ST_SIZUKU      Sizuku;
ST_SIZUKU_FLAG SizukuSRAM;

//---------------------------------------------------------------------------
EWRAM_CODE void SizukuInit()
{
	_Memset((u8*)&Sizuku,     0x00, sizeof(ST_SIZUKU));
	_Memset((u8*)&SizukuSRAM, 0x00, sizeof(ST_SIZUKU_FLAG));
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuInitScenario()
{
	ST_SIZUKU_FLAG* p = &Sizuku.flag;

	//シナリオフラグ初期化
	p->sys[2]  = 0;
	p->sys[3]  = 0;
	p->sys[4]  = 0;
	p->sys[5]  = 0;
	p->sys[6]  = 0;

	p->sys[9]  = 0;
	p->sys[10] = 0;
	p->sys[11] = 0;
	p->sys[12] = 0;
	p->sys[13] = 0;
}
//---------------------------------------------------------------------------
//シナリオフラグの変換
EWRAM_CODE u8 SizukuGetMapSys(u8 no)
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
		TRACEOUT("SizukuGetSysNo Bad Flag No[%02x]", no);
		for(;;){}
	}
}
//---------------------------------------------------------------------------
//BGMパラメータの変換
EWRAM_CODE u8 SizukuGetMapBgm(u8 no)
{
	if(no == 14)
	{
		return 2;
	}
	else if(no < 16)
	{
		return no + 2;
	}

	return no + 1;
}
//---------------------------------------------------------------------------
//背景画像 パラメータ変換
EWRAM_CODE u8 SizukuGetMapBg(u8 no)
{
	switch(no)
	{
	case 4:
		return 2; //教室(夕方)
	case 5:
		return 2; //教室(深夜)
	case 6:
		return 3; //休み時間(夕方)
	case 32:
		return 31; //屋上(夕方)
	case 33:
		return 31; //屋上(夜)
	case 35:
		return 34; //屋上(網)夕方
	case 36:
		return 34; //屋上(網)夜
	case 38:
		return 11; //体育館 (夕方)
	case 41:
		return 15; //中庭 (夕方)
	case 42:
		return 15; //中庭 (昼)
	case 43:
		return 10; //ろうか(夕方)
	case 44:
		return 10; //ろうか(深夜)
	case 45:
		return 30; //職員室(夕方)
	case 46:
		return 30; //職員室(深夜)
	case 47:
		return 22; //階段 (夕方)
	case 48:
		return 22; //階段（深夜)
	case 49:
		return 12; //生徒会廊下(夕方)
	case 50:
		return 12; //生徒会廊下(深夜)
	case 51:
		return 24; //体育館の中(夕方)
	case 52:
		return 24; //体育館の中(夜)
	case 53:
		return 12; //部活廊下(真っ暗)
	case 54:
		return 18; //鉄のとびら閉(夕方)
	case 55:
		return 19; //鉄のとびら開(夕方)
	}

	return no;
}
//---------------------------------------------------------------------------
//テキスト用エフェクトパラメータ変換
EWRAM_CODE u8 SizukuGetMapEffect(u8 no)
{
	no = 0;		//本来はエフェクト処理の番号が入ります
	return no;
}
//---------------------------------------------------------------------------
//ビジュアル用パラメータ変換
EWRAM_CODE u8 SizukuGetMapVis(u8 no)
{
	return no == 21 ? 2 : no;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8 SizukuGetMapChr(u8 pos)
{
	switch (pos)
	{
	default:
	case 'l':		//Left
	case 'L':
		return 0;

	case 'r':		//Right
	case 'R':
		return 1;

	case 'c':		//Center
	case 'C':
	case '0':
		return 2;

	case 'a':		//ALL
	case 'A':
		return 3;
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE u8 SizukuGetSysFlag(u8 no)
{
	return Sizuku.flag.sys[ SizukuGetMapSys(no) ];
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetSysFlag(u8 no, u8 val)
{
	Sizuku.flag.sys[ SizukuGetMapSys(no) ] = val;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuAddSysFlag(u8 no, u8 val)
{
	Sizuku.flag.sys[ SizukuGetMapSys(no) ] += val;
}





//---------------------------------------------------------------------------
EWRAM_CODE bool SizukuIsEndFlag()
{
	return Sizuku.isEnd;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool SizukuIsNextFlag()
{
	return Sizuku.isNext;
}
//---------------------------------------------------------------------------
EWRAM_CODE bool SizukuIsRestartFlag()
{
	return Sizuku.isRestart;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetEndFlag(bool flag)
{
	Sizuku.isEnd = flag;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetNextFlag(bool flag)
{
	Sizuku.isNext = flag;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetRestartFlag(bool flag)
{
	Sizuku.isRestart = flag;
}





//---------------------------------------------------------------------------
EWRAM_CODE ST_SIZUKU_FLAG* SizukuGetFlagPointer()
{
	return &Sizuku.flag;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetFlagBg(u8 type, u8 no)
{
	Sizuku.flag.bgType = type;
	Sizuku.flag.bgNo   = no;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetFlagChr(u8 no, u8 pos)
{
	ST_SIZUKU_FLAG* p = &Sizuku.flag;
	u8 chr = SizukuGetMapChr(pos);

    if(no == 0x99)
    {
		SizukuSetFlagChrClear(pos);
		return;
	}

	p->chrNo[chr] = no;
	p->chr[chr]   = TRUE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetFlagChrClear(u8 pos)
{
	ST_SIZUKU_FLAG* p = &Sizuku.flag;
	u8 no = SizukuGetMapChr(pos);

	if(no == 3)		//3は、ALL
	{
		p->chr[0] = FALSE;
		p->chr[1] = FALSE;
		p->chr[2] = FALSE;

		return;
	}

	p->chr[no] = FALSE;
}





//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoad(u8* name, u16 no, bool isErr)
{
	char buf[64];
	_Sprintf(buf, (char*)name, no);

	u8* p = GBFSGetFilePointer(buf);

	if(p == NULL)
	{
		if(isErr == TRUE)
		{
			ErrorMessage("file not found.", buf);
		}
		else
		{
			TRACEOUT("[file not found: %s]\n", buf);
		}
	}

	return p;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoad2(u8* name, bool isErr)
{
	u8* p = GBFSGetFilePointer((char*)name);

	if(p == NULL)
	{
		if(isErr == TRUE)
		{
			ErrorMessage("file not found.", (char*)name);
		}
		else
		{
			TRACEOUT("[file not found: %s]\n", (char*)name);
		}
	}

	return p;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoadScn(u16 scnNo, u16 blkNo)
{
	u8* p = SizukuLoad(SIZUKU_SCN_STR, scnNo, TRUE);

	Sizuku.flag.scnNo = scnNo;
	Sizuku.flag.blkNo = blkNo;
	return p;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoadSnd(u8 no)
{
	u8* p = SizukuLoad(SIZUKU_SND_STR, SizukuGetMapBgm(no), FALSE);

	Sizuku.flag.bgmNo   = no;
	Sizuku.flag.bgmSize = GBFSGetFileLength();
	return p;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoadBg()
{
	ST_SIZUKU_FLAG* s = &Sizuku.flag;
	u8* p;

	switch(s->bgType)
	{
	case BG_VISUAL:
		p = SizukuLoad(SIZUKU_VIS_STR, SizukuGetMapVis(s->bgNo), TRUE);
		break;

	case BG_HCG:
		p = SizukuLoad(SIZUKU_HVS_STR, s->bgNo, TRUE);
		break;

	case BG_BACK:
		p = SizukuLoad(SIZUKU_BG_STR, SizukuGetMapBg(s->bgNo), TRUE);
		break;

	default:
		TRACEOUT("Err: LoadBg type = %x\n", s->bgType);
		for(;;){}
		break;
	}

	return p;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* SizukuLoadChr(u8 pos)
{
	return SizukuLoad(SIZUKU_CHR_STR, Sizuku.flag.chrNo[pos], TRUE);
}





//---------------------------------------------------------------------------
EWRAM_CODE bool SizukuIsSRAM()
{
	if( SRAMRead8(0) != 'S' ) return FALSE;
	if( SRAMRead8(1) != 'I' ) return FALSE;
	if( SRAMRead8(2) != 'Z' ) return FALSE;

	return TRUE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSetSRAM()
{
	u8* pSrc    = (u8*)&Sizuku.flag;
	u8* pDst    = (u8*)&SizukuSRAM;
	u32 flagCnt = sizeof(ST_SIZUKU_FLAG);
	u32 i;

	for(i=0; i<flagCnt; i++)
	{
		*pDst++ = *pSrc++;
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuLoadSRAM()
{
	u8* pSizuku = (u8*)&Sizuku.flag;
	u32 flagCnt = sizeof(ST_SIZUKU_FLAG);
	u32 readCnt = 3;
	u32 i;

	for(i=0; i<flagCnt; i++)
	{
		*pSizuku++ = SRAMRead8(readCnt++);
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void SizukuSaveSRAM()
{
	u8* pSizuku  = (u8*)&SizukuSRAM;
	u32 flagCnt  = sizeof(ST_SIZUKU_FLAG);
	u32 writeCnt = 0;
	u32 i;

	SRAMWrite8 (writeCnt++, 'S');
	SRAMWrite8 (writeCnt++, 'I');
	SRAMWrite8 (writeCnt++, 'Z');

	for(i=0; i<flagCnt; i++)
	{
		SRAMWrite8(writeCnt++, *pSizuku++);
	}
}
