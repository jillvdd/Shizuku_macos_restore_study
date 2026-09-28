
#include "inc.h"

#include "minix.h"
#include "iwram_arm.h"
#include "div_arm.h"
#include "gbfs.h"
#include "lib.h"
#include "ad_arm.h"

#include "main.h"
#include "screen.h"
#include "sizuku.h"
#include "anime.h"
#include "script.h"

//---------------------------------------------------------------------------
ST_SCRIPT  Script;
ST_HISTORY History;
ST_MENU    Menu;

//---------------------------------------------------------------------------
EWRAM_CODE void ScriptInit()
{
	_Memset((u8*)&Script, 0x00, sizeof(ST_SCRIPT));
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadScenario(u16 scn, u16 blk)
{
	u8* pScn = SizukuLoadScn(scn, blk);
	ScriptLoad(pScn, scn, blk);

	SizukuSetSRAM();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoad(u8* pScn, u16 scnNo, u16 blk)
{
	ST_SCRIPT_HEADER* h = (ST_SCRIPT_HEADER*)pScn;
	ST_SCRIPT*        s = &Script;

	s->pScn        = pScn + h->scnOffset;
	s->pTxt        = pScn + h->txtOffset;
	s->scnNo       = scnNo;
	s->scnSize     = h->scnSize;
	s->txtSize     = h->txtSize;
	s->pScnCurHead = s->pScn + GET_SHORT(s->pScn + (blk+1) * 2);
	s->pScnCur     = s->pScnCurHead;
	s->pTxtCur     = NULL;
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptExec()
{
	ScriptParserScn();
}
//---------------------------------------------------------------------------
//「雫」シナリオパーサ本体
#define c s->pScnCur

EWRAM_CODE void ScriptParserScn()
{
	ST_SCRIPT* s = &Script;

	for(;;)
	{
		if( SizukuIsEndFlag() == TRUE )
		{
			if( SizukuIsRestartFlag() == FALSE )
			{
				return;
			}

			ScriptRestart();
		}

		switch(c[0])
		{
		case 0x00:
			TRACEOUT("[ブロック終了]\n");
			SizukuSetEndFlag(TRUE);
			ScriptMusicStop();
			c++;
			return;

		case 0x01:
			//特殊効果

			switch(c[1])
			{
			case 0x01:
				TRACEOUT("[ぐにゃり→暗]-[メッセージ: %d]\n", c[2]);
				ScriptParserTxt(c[2], TRUE);
				ScreenFontClear();
				c += 3;
				break;

			case 0x02:
				TRACEOUT("[暗→ぐにゃり]-[メッセージ: %d]\n", c[2]);
				ScriptParserTxt(c[2], TRUE);
				ScreenFontClear();
				c += 3;
				break;

			case 0x03:
				TRACEOUT("[涙の雫: %02x]\n", c[2]);
				AnimeExecSizuku();	//本来は２通りの「雫」がありますが手抜きしました（＾＾；
				c += 3;
				break;

			case 0x04:
				TRACEOUT("[ぐにゃり2(異次元)]-[メッセージ:%d]\n", c[2]);
				ScriptParserTxt(c[2], TRUE);
				ScreenFontClear();
				c += 3;
				break;

			default:
				TRACEOUT("異常な0x01コマンドです(%02x,%02x)\n", c[1], c[2]);
				return;
			}
			break;

		case 0x03:
			TRACEOUT("[謎: %02x]\n", c[0]);
			c += 2;
			break;

		case 0x04:
			TRACEOUT("[ジャンプ: SCN%03d.dat Block %d]\n", c[1], c[2]);
			ScriptLoadScenario(c[1], c[2]);
			break;

		case 0x05:
			TRACEOUT("[選択肢: %d][メッセージ: %d]\n", c[2], c[1]);
			c = ScriptSelect(c);
			break;

		case 0x06:
			TRACEOUT("[謎: %02x]\n", c[0]);
			c++;
			break;

		case 0x07:
			TRACEOUT("[前の選択肢に戻るマーク位置]\n");
			//SizukuSetSelPoint(c);
			c++;
			break;

		case 0x0a:
			TRACEOUT("[背景のみロード: MAX_S%02d.img]\n", c[1]);
			ScriptLoadBg(c[1]);
			c += 2;
			break;

		case 0x14:
			TRACEOUT("[画面クリア? %02d]\n", c[1]);
			ScriptClear();
			c += 2;
			break;

		case 0x16:
			TRACEOUT("[Hシーンロード: MAX_H%02d.img]\n", c[1]);
			ScriptLoadBgH(c[1]);
			c += 2;
			break;

		case 0x22:
			TRACEOUT("[キャラクタロード: MAX_C%02x.img %02x]\n", c[1], c[2]);
			ScriptLoadChr(c[1], c[2]);
			ScriptUpdate2();
			c += 3;
			break;

		case 0x24:
			TRACEOUT("[キャラクタロード2?(center?): MAX_C%02x.img]\n", c[1]);
			ScriptLoadChr(c[1], 'c');
			ScriptUpdate2();
			c += 3;
			break;

		case 0x28:
			TRACEOUT("[選択肢の前に存在するデータ]\n");
			c++;
			break;

		case 0x38:
			TRACEOUT("[表\示処理: %02x]\n", c[1]);
			ScriptUpdate();
			c += 2;
			break;

		case 0x3d:
			TRACEOUT("[if文 flg:%02x == 0x%02x pc += %02x]\n", c[1], c[2], c[3]);
			if( SizukuGetSysFlag(c[1]) == c[2] )
			{
				c += c[3];
			}
			c += 4;
			break;

		case 0x3e:
			TRACEOUT("[if文(否定) flg:%02x != 0x%02x pc += %02x]\n", c[1], c[2], c[3]);
			if( SizukuGetSysFlag(c[1]) != c[2] )
			{
				c += c[3];
			}
			c += 4;
			break;

		case 0x47:
			TRACEOUT("[フラグの値設定: %02x = 0x%02x]\n", c[1], c[2]);
			SizukuSetSysFlag(c[1], c[2]);
			c += 3;
			break;

		case 0x48:
			TRACEOUT("[フラグ加算: %02x += 0x%02x\n", c[1], c[2]);
			SizukuAddSysFlag(c[1], c[2]);
			c += 3;
			break;

		case 0x54:
			TRACEOUT("[テキストメッセージ: %d]\n", c[1]);
			ScriptParserTxt(c[1], TRUE);
			ScreenFontClear();
			c += 2;
			break;

		case 0x5a:
			TRACEOUT("[謎: %02x]\n", c[0]);
			c++;
			break;

		case 0x5c:
			TRACEOUT("[謎: %02x %02x]\n", c[0], c[1]);
			c += 2;
			break;

		case 0x61:
			TRACEOUT("[謎: %02x %02x %02x]\n", c[0], c[1], c[2]);
			c += 3;
			break;

		case 0x62:
			TRACEOUT("[謎:%02x(%02x)]\n", c[0], c[1]);
			c += 2;
			break;

		case 0x60:
		case 0x63:
		case 0x64:
		case 0x65:
		case 0x66:
			TRACEOUT("[謎: %02x]\n", c[0]);
			c++;
			break;

		case 0x6e:
			TRACEOUT("[BGM再生: %02x]\n", c[1]);
			ScriptMusicStart(c[1], TRUE);
			c += 2;
			break;

		case 0x6f:
		case 0x73:
			TRACEOUT("[謎: %02x]\n", c[0]);
			break;

		case 0x7e:
			TRACEOUT("[エンディング番号設定: %02x]\n");
			/*
			 0 12 卒業式
			 1 12 瑞穂 BAD
			 2 12 破壊
			 3 12 トースター
			 4 11 佐織 HAPPY
			 5 12 佐織 BAD
			 6 11 瑞穂 HAPPY
			 7 12 瑞穂 BAD
			 8 10 True
			 9 11 瑠璃子 HAPPY
			 a 01 大田さん
			 b 14 異次元
			 c 12 異次元 BAD
			*/

			//瑠璃子 HAPPY を見ているかチェックをします
			if( SizukuGetSysFlag(0x46) == 1)
			{
				SizukuSetSysFlag(0, 3);
			}
			else
			{
				if( SizukuGetSysFlag(0) == 0 )
				{
					SizukuSetSysFlag(0, 2);
				}
				else
				{
					SizukuSetSysFlag(0, 1);
				}
			}
			c += 2;
			break;

		case 0x7c:
			TRACEOUT("[エンディング関係 謎:%02x()]\n", c[0]);
			c++;
			break;

		case 0x7d:
			TRACEOUT("[エンディングBGM設定 & 起動:%02x %d]\n", c[0], c[1]);
			SizukuSetNextFlag(FALSE);

			ScriptMusicStart(c[1], FALSE);
			AnimeExecEnding();
			c += 2;
			break;

		case 0xff:
			TRACEOUT("[本来アクセスし得ない場所にアクセスした %02x]\n", c[0]);
			for(;;){}
			break;

		default:
			TRACEOUT("[ScriptParserScn unknown = %02x][no: %02x]\n", c[0], s->scnNo);
			for(;;){}
			break;

		} // switch(c[0])

	} // for(;;)
}
#undef c
//---------------------------------------------------------------------------
//「雫」テキストパーサ本体
#define c s->pTxtCur

EWRAM_CODE void ScriptParserTxt(u8 no, bool isHistoryAdd)
{
	ST_SCRIPT* s = &Script;
	u8 c1, c2, c3, c4;

	//シナリオデータのロード
	c = s->pTxt + GET_SHORT(s->pTxt + (no+1) * 2);

	if(isHistoryAdd == TRUE)
	{
		HistoryAdd(c);
	}

	for(;;)
	{
		if(SizukuIsEndFlag() == TRUE)
		{
			return;
		}

		if(c[0] & 0x80 || c[0] == 'r')
		{
			c = ScriptDrawCode(c);
			continue;
		}

		switch(c[0])
		{
		case '$':
			TRACEOUT("[メッセージ終了]\n");
			c++;
			return;

#if 0
		case 'r':
			TRACEOUT("[改行]\n");
			c++;
			break;
#endif

		case 'p':
			TRACEOUT("[ページ更新待ち]\n");
			ScriptWaitPage();
			c++;
			break;

		case 'k':
		case 'K':
			TRACEOUT("[キー入力待ち]\n");
			ScriptWaitKey();
			c++;
			break;

		case '0':
			TRACEOUT("[謎: %02x]\n", c[0]);
			c++;
			break;

		case 'C':
			TRACEOUT("[キャラクタ交換: %c, MAX_C%c%c]\n", c[1], c[2], c[3]);
			ScreenFontOut();
			ScriptClearChr(c[1]); 
			ScriptLoadChr(HexToDig2(c[2], c[3]), c[1]);
			ScriptUpdate2();
			ScreenFontIn();
			c += 4;
			break;

		case 'B':
			TRACEOUT("[背景ロード: %c%c, %d, %d]\n", c[1], c[2], Dig(c[3],c[4]), Dig(c[5],c[6]));
			ScreenFontOut();
			ScriptClear();
			ScriptLoadBg(Dig(c[1],c[2]));
			ScriptUpdate();
			ScreenFontIn();
			c += 7;
			break;

		case 'S':
			TRACEOUT("[背景付きキャラ表\示: %c, MAX_C%c%c, MAX_S%c%c, %d, %d]\n", c[1], c[2],c[3],c[4],c[5], Dig(c[6],c[7]), Dig(c[8], c[9]));
			ScreenFontOut();
			ScriptClear();
			ScriptLoadBg(Dig(c[4],c[5]));
			ScriptLoadChr(HexToDig2(c[2], c[3]), c[1]);
			ScriptUpdate();
			ScreenFontIn();
			c += 10;
			break;

		case 'D':
			TRACEOUT("[キャラ全消去後表\示: %c, MAX_C%c%c]\n", c[1], c[2], c[3]);
			ScreenFontOut();
			ScriptClearChr('a');
			ScriptLoadChr(HexToDig2(c[2], c[3]), c[1]);
			ScriptUpdate2();
			ScreenFontIn();
			c += 4;
			break;

		case 'A':
		case 'a':
			TRACEOUT("[キャラ3人表\示: %c, %c%c, %c, %c%c, %c, %c%c]\n", c[1],c[2],c[3],  c[4],c[5],c[6], c[7],c[8],c[9]);
			ScreenFontOut();
			ScriptClearChr('a');
			ScriptLoadChr(HexToDig2(c[2], c[3]), c[1]);
			ScriptLoadChr(HexToDig2(c[5], c[6]), c[4]);
			ScriptLoadChr(HexToDig2(c[8], c[9]), c[7]);
			ScriptUpdate2();
			ScreenFontIn();
			c += 10;
			break;

		case 'Q':
			TRACEOUT("[画面を揺らす: %02x]\n", c[0]);
			c++;
			break;

		case 'E':
			TRACEOUT("[背景ロード(2)?: MAX_S%c%c.img, %d, %d]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
			ScreenFontOut();
			ScriptClear();
			ScriptLoadBg(Dig(c[1],c[2]));
			ScriptUpdate();
			ScreenFontIn();
			c += 7;
			break;

		case 'F':
			TRACEOUT("[フラッシュ: %c]\n", c[0]);
			ScreenFontOut();
			ScreenImgFlash();
			ScreenFontIn();
			c++;
			break;

		case 'V':
			TRACEOUT("[ビジュアル: VIS%c%c, %d, %d]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
			ScreenFontOut();
			ScriptClear();
			ScriptLoadBgV(Dig(c[1], c[2]));
			ScriptUpdate();
			ScreenFontIn();
			c += 7;
			break;

		case 'H':
			TRACEOUT("[Hシーン(HVS%c%c, %d, %d)]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
			ScreenFontOut();
			ScriptClear();
			ScriptLoadBgH(Dig(c[1], c[2]));
			ScriptUpdate();
			ScreenFontIn();
			c += 7;
			break;

		case 'M':
			//BGM 関連
			c1  = c[1];
			c  += 2;

			if(c1 == 'f')
			{
				TRACEOUT("[BGM フェードアウト]\n");
				ScriptMusicFadeOut();
			}
			else if (c1 == 'n')
			{
				c2 = *c++;
				c3 = *c++;
				TRACEOUT("[BGM 再生(next): M_%c%c\n", c2, c3);
				ScriptMusicStart(Dig(c2, c3), TRUE);
			}
			else if (c1 == 'w')
			{
				TRACEOUT("[BGM FADE WAIT]\n");
			}
			else if (c1 >= '0' && c1 <= '2')
			{
				c2 = *c++;
				TRACEOUT("[BGM 再生: M_%c%c]\n", c1, c2);
				ScriptMusicStart(Dig(c1, c2), TRUE);
			}
			else if (c1 == 's')
			{
				TRACEOUT("[BGM 停止]\n");
				ScriptMusicStop();
			}
			else
			{
				TRACEOUT("[cmd:4d][cmd:%x]\n", c1);
			}
			break;

		case 'P':
			//PCM 関連
			c1  = c[1];
			c  += 2;

			if(c1 == 'l')
			{
				c2 = *c++;
				c3 = *c++;
				TRACEOUT("[PCMロード(%c%c)]\n", c2, c3);
			}
			else if (c1 >= '0' && c1 <= '9')
			{
				c2 = *c++;
				c3 = *c++;
				c4 = *c++;
				TRACEOUT("[PCM再生指定(%c%c, %c%c)]\n", c1, c2, c3, c4);
			}
			else if(c1 == 'f')
			{
				TRACEOUT("[PCMフェードアウト?]\n");
			}
			else if(c1 == 'w')
			{
				TRACEOUT("[PCM wait?]\n");
			}
			else if(c1 == 's')
			{
				TRACEOUT("[PCM停止]\n");
			}
			else
			{
				TRACEOUT("[cmd:50][cmd:%x]\n");
			}
			break;

		case 'X':
			TRACEOUT("[表\示オフセット指定: %x]\n", c[1]);
			c += 2;
			break;

		case 's':
			TRACEOUT("[表\示速度指定?: %x]\n", c[1]);
			c += 2;
			break;

		default:
			TRACEOUT("[ScriptParserTxt unknown = %02x][no: %02x]\n", c[0], s->scnNo);
			for(;;){}
			break;

		} // switch(c[0])

	} // for(;;)
}
#undef c
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptWaitPage()
{
	ScreenCursorMoveIn();
	ScriptKey();

	ScreenFontSetNewLine();
	ScreenCursorMoveOut();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptWaitKey()
{
	ScreenCursorMoveIn();
	ScriptKey();

	ScreenCursorMoveOut();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptKey()
{
	u16 key;

Restart:

	//「次の選択肢まで進む」フラグのチェック
	if( SizukuIsNextFlag() == TRUE )
	{
		key = KeyGet2();

		if(key & KEY_B)
		{
			SizukuSetNextFlag(FALSE);
			KeyWait3();

			goto Restart;
		}

		return;
	}

	key = KeyWait(KEY_A | KEY_DOWN | KEY_LEFT | KEY_B | KEY_R);

	if(key & KEY_R)
	{
		return;
	}

	if(key & KEY_LEFT)
	{
		if( HistoryIsEmpty() == FALSE )
		{
			ScreenCursorMoveOut();
			HistoryProc();
			ScreenCursorMoveIn();
		}

		goto Restart;
	}

	if(key & KEY_B)
	{
		MenuSetListSystem();
		ScreenCursorMoveOut();

		MenuProc();
		if( SizukuIsEndFlag() == TRUE )
		{
			return;
		}

		ScreenCursorMoveIn();
		goto Restart;
	}

	//ここまで来るのは、Aボタンか下ボタン
	KeyWait3();
}
//---------------------------------------------------------------------------
EWRAM_CODE u16 ScriptGetDrawCode(u8** c, u16* buf)
{
	u16 i = 0;

	do
	{
		if(**c == 'r')
		{
			//改行は無視します
			*c += 1;
			continue;
		}

		buf[i]  = ((**c & 0x7f) << 8) | (*(*c + 1));

		*c += 2;
		i++;

	} while(**c & 0x80 || **c == 'r');

	return i;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* ScriptDrawCode(u8* p)
{
	u16 buf[200], txt[200];
	u16 len, tmp;
	u8* c = p;

	tmp = ScriptGetDrawCode(&c, buf);
	len = ScreenFontSetHyphenation(buf, txt, tmp);	//禁則文字の処理をします

	if( ScreenFontIsOver(len) == TRUE )
	{
		ScreenFontClear();
		len = ScreenFontSetHyphenation(buf, txt, tmp);

		HistoryAdd(p);
	}

	ScreenFontDrawStr(txt, len);
	return c;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* ScriptSelect(u8* c)
{
	ScreenFontClear();

	ScriptParserTxt(c[1], TRUE);
	ScreenFontSetNewLine();

	//選択肢表示には画面をまたがってはいけないので、行数が3以上の場合は画面を消去します
	if( ScreenFontGetY() >= 3 )
	{
		ScreenFontClear();
	}

	u16 key;
	s16 sel  = -1;
	s16 mSel = c[2];
	u16 x    = ScreenFontGetX();
	u16 y    = ScreenFontGetY();

	ScriptDrawSelect(c, sel);

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
			continue;
		}
		else if(key & KEY_B)
		{
			MenuProc();
			if( SizukuIsEndFlag() == TRUE )
			{
				return NULL;
			}
			continue;
		}
		else if(key & KEY_LEFT)
		{
			HistoryProc();
			continue;
		}
		else if( (key != KEY_DOWN) && sel == -1 )
		{
			//間違えてボタンを押すのを防止します
			continue;
		}

		if(key & KEY_A)
		{
			break;
		}
		else if(key & KEY_UP)
		{
			if(sel == 0) continue;
			sel--;

			ScreenFontSetXY(x, y);
			ScriptDrawSelect(c, sel);
		}
		else if(key & KEY_DOWN)
		{
			if(sel+1 >= mSel) continue;
			sel++;

			ScreenFontSetXY(x, y);
			ScriptDrawSelect(c, sel);
		}
	}

	ScreenFontClear();
	SizukuSetNextFlag(FALSE);
	HistoryAdd( Script.pTxt + GET_SHORT(Script.pTxt + (c[3+sel*2] + 1) * 2) );

	TRACEOUT("選択分岐: %d (+%02x)\n", sel, c[4 + sel*2]);
	return c = c + 3 + c[2]*2 + c[4 + sel*2];
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptDrawSelect(u8* c, s8 sel)
{
	s8 i;
	for(i=0; i<c[2]; i++)
	{
		if(i == sel)
		{
			FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
		}
		else
		{
			FontLeafSetAttr(FONT_LEAF_COLOR_GRAY);
		}

		TRACEOUT("[選択肢: %d][メッセージ: %d][オフセット: %02x]\n", i, c[3+i*2], c[4+i*2]);
		ScriptParserTxt(c[3+i*2], FALSE);
		ScreenFontSetNewLine();
	}

	FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicStart(u8 no, bool isLoop)
{
	u8* pSnd = SizukuLoadSnd(no);

	if(pSnd == NULL)
	{
		return;
	}

	ST_SIZUKU_FLAG* p = SizukuGetFlagPointer();
	AdStart(pSnd, p->bgmSize, isLoop);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicStop()
{
	AdStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicFadeOut()
{
	//TODO MusicFadeOut処理
	ScriptMusicStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadBg(u8 no)
{
	SizukuSetFlagBg(BG_BACK, no);
	SizukuSetFlagChrClear('a');
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadBgH(u8 no)
{
	SizukuSetFlagBg(BG_HCG, no);
	SizukuSetFlagChrClear('a');
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadBgV(u8 no)
{
	SizukuSetFlagBg(BG_VISUAL, no);
	SizukuSetFlagChrClear('a');
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadChr(u8 no, u8 pos)
{
	SizukuSetFlagChr(no, pos);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptUpdate()
{
	//本来は個々のエフェクト処理が入ります

	ScreenImgFadeIn(BLEND_MODE_DARK, 4, 15, 20);

	ScriptUpdateBg();
	ScriptUpdateChr();
	ScreenImgUpdate();

	ScreenImgFadeOut(20);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptUpdate2()
{
	//本来は個々のエフェクト処理が入ります

	ScriptUpdateBg();
	ScriptUpdateChr();

	WaitForVsync();
	ScreenImgUpdate();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptUpdateBg()
{
	ST_SIZUKU_FLAG* p = SizukuGetFlagPointer();

	if((p->bgType == BG_BACK) && (p->bgNo == 0))
	{
		ScreenImgClear();
		return;
	}

	if(p->bgType == BG_VISUAL)
	{
		ScreenImgClear();

		u8* b = SizukuLoadBg();
		ScreenImgLoadChr(b, 2);		//2は中央表示

		return;
	}

	ST_IMG_HEADER* h = (ST_IMG_HEADER*)SizukuLoadBg();
	ScreenImgLoadBg((u8*)(h + 1));
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptUpdateChr()
{
	ST_SIZUKU_FLAG* p = SizukuGetFlagPointer();
	u8* pChr;
	u16 i;

	for(i=0; i<=2; i++)
	{
		if(p->chr[i] == FALSE)
		{
			continue;
		}

		pChr = SizukuLoadChr(i);
		ScreenImgLoadChr(pChr, i);			//0: Left, 1: Right, 2: Center
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptClear()
{
	//TODO 本来は個々のエフェクト処理が入ります

	SizukuSetFlagBg(BG_BACK, 0);
	SizukuSetFlagChrClear('a');
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptClearChr(u8 pos)
{
	SizukuSetFlagChrClear(pos);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptRestart()
{
	//システム初期化
	AdStop();
	ScreenFontClear();
	ScreenImgFadeIn(BLEND_MODE_DARK, 4, 15, 20);
	ScreenImgClear();
	ScreenImgUpdate();
	ScreenImgFadeOut(0);

	//SRAMロード
	SizukuLoadSRAM();

	//システム復帰
	ST_SIZUKU_FLAG* p = SizukuGetFlagPointer();
	ScriptLoadScenario(p->scnNo, p->blkNo);
	ScriptMusicStart(p->bgmNo, TRUE);

	//画面ロード
	ScreenImgFadeIn(BLEND_MODE_DARK, 4, 15, 0);
	ScriptUpdate2();
	ScreenImgFadeOut(20);

	//フラグ初期化
	SizukuSetEndFlag(FALSE);
	SizukuSetNextFlag(FALSE);
	SizukuSetRestartFlag(FALSE);
	HistoryInit();
}






//---------------------------------------------------------------------------
EWRAM_CODE void HistoryInit()
{
	History.cnt = 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE void HistoryAdd(u8* pTxtCur)
{
	ST_HISTORY* p = &History;
	u16 i = p->cnt;

	while(i >= 1)
	{
		p->pTxtCur[i] = p->pTxtCur[i-1];
		i--;
	}
	p->pTxtCur[0] = pTxtCur;


	if(p->cnt+1 < HISTORY_MAX_CNT)
	{
		p->cnt++;
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE bool HistoryIsEmpty()
{
	return History.cnt <= 1 ? TRUE : FALSE;
}
//---------------------------------------------------------------------------
EWRAM_CODE void HistoryProc()
{
	ST_HISTORY* p = &History;

	u16 key;
	u16 x      = ScreenFontGetX();
	u16 y      = ScreenFontGetY();
	u8  selMax = p->cnt;
	u8  sel    = 1;

	ScreenFontClearNoBuf();

	FontLeafSetAttr(FONT_LEAF_COLOR_GRAY);
	HistoryParserTxt(p->pTxtCur[sel]);

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
			continue;
		}

		if(key & KEY_B)
		{
			break;
		}
		else if(key & KEY_LEFT)
		{
			if(sel+1 >= selMax) continue;
			sel++;

			ScreenFontClearNoBuf();
			HistoryParserTxt(p->pTxtCur[sel]);
		}
		else if(key & KEY_RIGHT)
		{
			if(sel == 1) break;
			sel--;

			ScreenFontClearNoBuf();
			HistoryParserTxt(p->pTxtCur[sel]);
		}
	}

	//画面を復帰させます
	FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
	ScreenFontDrawRestore();
	ScreenFontSetXY(x, y);
}
//---------------------------------------------------------------------------
//「雫」テキストパーサ本体(履歴表示用)
EWRAM_CODE void HistoryParserTxt(u8* c)
{
	u8  c1;
	u16 buf[200], txt[200];
	u16 tmp, len;

	for(;;)
	{
		if(c[0] & 0x80 || c[0] == 'r')
		{
			tmp = ScriptGetDrawCode(&c, buf);
			len = ScreenFontSetHyphenation(buf, txt, tmp);

			if( ScreenFontIsOver(len) == TRUE )
			{
				return;
			}

			ScreenFontDrawStrNoBuf(txt, len);
			continue;
		}

		switch(c[0])
		{
			case '$':
				c++;
				return;

			case 'p':
			case 'k':
			case 'K':
			case '0':
			case 'Q':
			case 'F':
				c++;
				break;

			case 'C':
			case 'D':
				c += 4;
				break;

			case 'B':
			case 'E':
			case 'V':
			case 'H':
				c += 7;
				break;

			case 'S':
			case 'A':
			case 'a':
				c += 10;
				break;

			case 'M':
				c1  = c[1];
				c  += 2;

				if(c1 == 'f' || c1 == 'w' || c1 == 's')
				{
					//EMPTY
				}
				else if (c1 == 'n')
				{
					c += 2;
				}
				else if (c1 >= '0' && c1 <= '2')
				{
					c++;
				}
				else
				{
					//EMPTY
				}
				break;

			case 'P': //PCM 関連
				c1  = c[1];
				c  += 2;

				if(c1 == 'l')
				{
					c += 2;
				}
				else if (c1 >= '0' && c1 <= '9')
				{
					c += 3;
				}
				else if(c1 == 'f' || c1 == 'w' || c1 == 's')
				{
					//EMPTY
				}
				else
				{
					//EMPTY
				}
				break;

			case 'X':
			case 's':
				c += 2;
				break;

			default:
				TRACEOUT("[HistoryParserTxt unknown = %02x][no: %02x]\n", c[0]);
				for(;;){}
				break;

		} // switch(c[0])

	} // for(;;)
}





//---------------------------------------------------------------------------
EWRAM_CODE void MenuInit()
{
	_Memset((u8*)&Menu, 0x00, sizeof(ST_MENU));
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSetTitle(u8* pStr)
{
	_Strncpy(Menu.titleStr, pStr, MENU_MAX_STR_LENGTH);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuAddSelect(u8* pStr, void* p)
{
	_Strncpy(Menu.selStr[Menu.cnt], pStr, MENU_MAX_STR_LENGTH);
	Menu.p[Menu.cnt] = p;

	Menu.cnt++;
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSetOption(u8 sx, u8 sy, bool isCancel)
{
	Menu.sx       = sx;
	Menu.sy       = sy;
	Menu.isCancel = isCancel;
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSetListSystem()
{
	MenuInit();
	MenuSetOption(MENU_SYSTEM_SX, MENU_SYSTEM_SY, TRUE);

	MenuSetTitle((u8*)"－　システムメニュー　－");
	MenuAddSelect((u8*)"次の選択肢に進む",     &MenuSystemNextSelect);
	MenuAddSelect((u8*)"１つ前の選択肢に戻る", &MenuSystemPrevSelect);
	MenuAddSelect((u8*)"シナリオ回想",         &MenuSystemReference);
	MenuAddSelect((u8*)"文字を消す",           &MenuSystemFontOut);
	MenuAddSelect((u8*)"セーブ",               &MenuSystemSave);
	MenuAddSelect((u8*)"ロード",               &MenuSystemLoad);
	MenuAddSelect((u8*)"ゲーム終了",           &MenuSystemGameEnd);
	MenuAddSelect((u8*)"デバッグ",             &MenuSystemDebug);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuDrawTitle(u16 x, u16 y)
{
	ScreenFontDrawStrSJISNoBuf(x, y, Menu.titleStr);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuDrawSelect(u16 sx, u16 sy, s8 sel)
{
	u16 y = 0;
	u16 i;

	for(i=0; i<Menu.cnt; i++)
	{
		if(i == sel)
		{
			FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
		}
		else
		{
			FontLeafSetAttr(FONT_LEAF_COLOR_GRAY);
		}

		ScreenFontDrawStrSJISNoBuf(sx , sy + y, Menu.selStr[i]);
		y++;
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuProc()
{
	ST_MENU* p = &Menu;
	u16 x      = ScreenFontGetX();
	u16 y      = ScreenFontGetY();
	s16 sel    = 0;
	u16 key;

	ScreenFontClearNoBuf();

	MenuDrawTitle(p->sx, p->sy);
	MenuDrawSelect(p->sx, p->sy+2, sel);

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
			continue;
		}

		if(key & KEY_A)
		{
			break;
		}
		else if( (key & KEY_B) && (p->isCancel == TRUE) )
		{
			sel = -1;
			break;
		}
		else if(key & KEY_UP)
		{
			if(sel == 0) continue;
			sel--;

			MenuDrawSelect(p->sx, p->sy+2, sel);
		}
		else if(key & KEY_DOWN)
		{
			if(sel+1 >= p->cnt) continue;
			sel++;

			MenuDrawSelect(p->sx, p->sy+2, sel);
		}
	}

	KeyWait3();

	if(sel != -1)
	{
		p->p[sel]();
	}

	//画面を復帰させます
	FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
	ScreenFontDrawRestore();
	ScreenFontSetXY(x, y);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemNextSelect()
{
	SizukuSetNextFlag(TRUE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemPrevSelect()
{
	//TODO
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemReference()
{
	if( HistoryIsEmpty() == FALSE )
	{
		HistoryProc();
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemFontOut()
{
	ScreenFontOut();
	KeyWait(KEY_B);
	ScreenFontIn();
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemSave()
{
	SizukuSaveSRAM();
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemLoad()
{
	if( SizukuIsSRAM() == FALSE )
	{
		return;
	}

	SizukuSetEndFlag(TRUE);
	SizukuSetRestartFlag(TRUE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemGameEnd()
{
	SizukuSetEndFlag(TRUE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuSystemDebug()
{
	
}





//---------------------------------------------------------------------------
EWRAM_CODE void MenuSetListStart()
{
	MenuInit();
	MenuSetOption(MENU_START_SX, MENU_START_SY, FALSE);

	MenuSetTitle((u8*)"");
	MenuAddSelect((u8*)"ゲームを始める", &MenuStartGame);
	MenuAddSelect((u8*)"ロードする",     &MenuStartLoad);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuStartGame()
{
	if( SizukuIsEndFlag() == TRUE )
	{
		SizukuInitScenario();
		HistoryInit();

		SizukuSetEndFlag(FALSE);
		SizukuSetNextFlag(FALSE);
		SizukuSetRestartFlag(FALSE);
	}

	ScriptLoadScenario(0, 1);
}
//---------------------------------------------------------------------------
EWRAM_CODE void MenuStartLoad()
{
	MenuStartGame();

	if( SizukuIsSRAM() == FALSE )
	{
		return;
	}

	SizukuSetEndFlag(TRUE);
	SizukuSetRestartFlag(TRUE);
}
