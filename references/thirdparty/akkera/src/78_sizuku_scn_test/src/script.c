
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
#include "script.h"

//---------------------------------------------------------------------------
ST_SCRIPT  Script;
ST_HISTORY History;

//---------------------------------------------------------------------------
EWRAM_CODE void ScriptInit()
{
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoadScenario(u16 scn, u16 blk)
{
	char buf[64];
	_Sprintf(buf, SIZUKU_SCN_STR, scn);

	u8* pScn = GBFSGetFilePointer(buf);

	if(pScn == NULL)
	{
		ErrorMessage("scn not found.", NULL);
	}
//	TRACEOUT("pScn = %x\n", pScn);

	ScriptLoad(pScn, scn, blk);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptLoad(u8* pScn, u16 scnNo, u16 blk)
{
	ST_SCRIPT_HEADER* h = (ST_SCRIPT_HEADER*)pScn;
	ST_SCRIPT*        s = &Script;

	s->pScn    = pScn + h->scnOffset;
	s->pTxt    = pScn + h->txtOffset;
	s->scnNo   = scnNo;
	s->scnSize = h->scnSize;
	s->txtSize = h->txtSize;

	s->pScnCurHead = s->pScn + GET_SHORT(s->pScn + (blk+1) * 2);
	s->pScnCur     = s->pScnCurHead;
	s->pTxtCur     = NULL;

//	TRACEOUT("s->pScnCur = %x\n", s->pScnCur);
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
//		ScriptDebugScn(s->scnNo);

		switch(c[0])
		{
		case 0x00:
			TRACEOUT("[ブロック終了]\n");
			c++;
			return;

		case 0x01:				//特殊効果
			switch(c[1])
			{
				case 0x01:
					TRACEOUT("[ぐにゃり→暗]-[メッセージ: %d]\n", c[2]);
					ScriptParserTxt(c[2], TRUE);
					ScreenFontDrawCls();
					c += 3;
					break;

				case 0x02:
					TRACEOUT("[暗→ぐにゃり]-[メッセージ: %d]\n", c[2]);
					ScriptParserTxt(c[2], TRUE);
					ScreenFontDrawCls();
					c += 3;
					break;

				case 0x03:
					TRACEOUT("[涙の雫: %02x]\n", c[2]);
					c += 3;
					break;

				case 0x04:
					TRACEOUT("[ぐにゃり2(異次元)]-[メッセージ:%d]\n", c[2]);
					ScriptParserTxt(c[2], TRUE);
					ScreenFontDrawCls();
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
			c = ScriptWaitSelect(c);
			break;

		case 0x06:
			TRACEOUT("[謎: %02x]\n", c[0]);
			c++;
			break;

		case 0x07:
			TRACEOUT("[前の選択肢に戻るマーク位置]\n");
			c++;
			break;

		case 0x0a:
			TRACEOUT("[背景ロード: MAX_S%02d.img]\n", c[1]);
			c += 2;
			break;

		case 0x14:
			TRACEOUT("[画面クリア? %02d]\n", c[1]);
			c += 2;
			break;

		case 0x16:
			TRACEOUT("[Hシーンロード: MAX_H%02d.img]\n", c[1]);
			c += 2;
			break;

		case 0x22:
			TRACEOUT("[キャラクタロード: MAX_C%02x.LFG %02x]\n", c[1], c[2]);
			c += 3;
			break;

		case 0x24:
			TRACEOUT("[キャラクタロード2?(center?): MAX_C%02x.LFG]\n", c[1]);
			c += 3;
			break;

		case 0x28:
			TRACEOUT("[選択肢の前に存在するデータ]\n");
			c++;
			break;

		case 0x38:
			TRACEOUT("[表\示処理: %02x]\n", c[1]);
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
			ScreenFontDrawCls();
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
			ScriptMusicStart(SizukuGetBgmNo(c[1]), TRUE);
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
//			ScriptMusicStartLoop(SizukuGetBgmNo(c[1]), FALSE);
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
	u8  c1, c2, c3, c4;

	//シナリオデータのロード
	c = s->pTxt + GET_SHORT(s->pTxt + (no+1) * 2);
//	ScriptDebugTxt(no);

	//履歴に登録するかチェックをします
	if(isHistoryAdd == TRUE)
	{
		HistoryAdd(c);
	}


	for(;;)
	{
		if(c[0] & 0x80 || c[0] == 'r')
		{
			c = ScriptDrawCode(c);
			continue;
		}

//		TRACEOUT("ScriptParserTxt = %c\n", c[0]);

		switch(c[0])
		{
			case '$':
				TRACEOUT("[メッセージ終了]\n");
				c++;
				return;
#if 0
			//※　前処理に移動しました。

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
				c += 4;
				break;

			case 'B':
				TRACEOUT("[背景ロード: %c%c, %d, %d]\n", c[1], c[2], Dig(c[3],c[4]), Dig(c[5],c[6]));
				c += 7;
				break;

			case 'S':
				TRACEOUT("[背景付きキャラ表\示: %c, MAX_C%c%c, MAX_S%c%c, %d, %d]\n", c[1], c[2],c[3],c[4],c[5], Dig(c[6],c[7]), Dig(c[8], c[9]));
				c += 10;
				break;

			case 'D':
				TRACEOUT("[キャラ全消去後表\示: %c, MAX_C%c%c]\n", c[1], c[2], c[3]);
				c += 4;
				break;

			case 'A':
			case 'a':
				TRACEOUT("[キャラ3人表\示: %c, %c%c, %c, %c%c, %c, %c%c]\n", c[1],c[2],c[3],  c[4],c[5],c[6], c[7],c[8],c[9]);
				c += 10;
				break;

			case 'Q':
				TRACEOUT("[画面を揺らす: %02x]\n", c[0]);
				c++;
				break;

			case 'E':
				TRACEOUT("[背景ロード(2)?: MAX_S%c%c.LFG, %d, %d]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
				c += 7;
				break;

			case 'F':
				TRACEOUT("[フラッシュ: %c]\n", c[0]);
				c++;
				break;

			case 'V':
				TRACEOUT("[ビジュアル: VIS%c%c, %d, %d]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
				c += 7;
				break;

			case 'H':
				TRACEOUT("[Hシーン(HVS%c%c, %d, %d)]\n", c[1], c[2], Dig(c[3], c[4]), Dig(c[5], c[6]));
				c += 7;
				break;

			case 'M': //BGM 関連
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
					ScriptMusicStart(SizukuGetBgmNo(Dig(c2, c3)), TRUE);
				}
				else if (c1 == 'w')
				{
					TRACEOUT("[BGM FADE WAIT]\n");
				}
				else if (c1 >= '0' && c1 <= '2')
				{
					c2 = *c++;
					TRACEOUT("[BGM 再生: M_%c%c]\n", c1, c2);
					ScriptMusicStart(SizukuGetBgmNo(Dig(c1, c2)), TRUE);
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

			case 'P': //PCM 関連
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
					TRACEOUT("[PCM再生指定(%c%c, %c%c)\n]", c1, c2, c3, c4);

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

	ScreenFontNewLineTxt();
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
Restart:

	KeyWait(KEY_A | KEY_DOWN | KEY_LEFT | KEY_R);
	u16 now = KeyGetNow();

	if(now & KEY_R)
	{
		return;
	}
	else if(now & KEY_LEFT)
	{
		if( HistoryIsEmpty() == FALSE )
		{
			HistoryReferebce();
		}

		goto Restart;
	}

	while( KeyGet2() != KEY_NONE )
	{
		//EMPTY
	}
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* ScriptDrawCode(u8* p)
{
	u16 buf[200], txt[200];
	u16 i = 0, len;
	u8* c = p;

	do
	{
		if(c[0] == 'r')
		{
			//改行は無視します
			c++;
			continue;
		}

		buf[i++] = ((c[0] & 0x7f) << 8) + c[1];
		c += 2;

	} while(c[0] & 0x80 || c[0] == 'r');

	//禁則文字の処理をします
	len = ScreenFontSetHyphenation(buf, txt, i);

	//1画面以内に書き込めるかチェックをします
	if( ScreenFontIsCnt(len) == TRUE )
	{
		ScreenFontDrawCls();
		len = ScreenFontSetHyphenation(buf, txt, i);

		HistoryAdd(p);
	}

	ScreenFontDrawStr(txt, len);
	return c;
}
//---------------------------------------------------------------------------
EWRAM_CODE u8* ScriptWaitSelect(u8* c)
{
	ScreenFontDrawCls();

	ScriptParserTxt(c[1], TRUE);
	ScreenFontNewLineTxt();

	//行数が3文字以上の場合は、画面を消去します
	if( ScreenFontGetY() >= 3 )
	{
		ScreenFontDrawCls();
	}

	u16 key;
	s16 sel = -1;
	u16 x   = ScreenFontGetX();
	u16 y   = ScreenFontGetY();

	ScriptDrawSelect(c, sel);

	for(;;)
	{
		WaitForVsync();
		key = KeyGet();

		if(key == KEY_NONE)
		{
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
			if(sel+1 >= c[2]) continue;
			sel++;

			ScreenFontSetXY(x, y);
			ScriptDrawSelect(c, sel);
		}
	}

	ScreenFontDrawCls();
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
		ScreenFontNewLineTxt();
	}

	FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicStart(u8 no, bool isLoop)
{
	char buf[64];
	_Sprintf(buf, SIZUKU_SND_STR, no);

	u8* pSnd = GBFSGetFilePointer(buf);

	if(pSnd == NULL)
	{
		//ファイルがなくても支障はないので、エラーにしていないです
		TRACEOUT("[BGM not found: %s]\n", buf);
		return;
	}

	AdStart(pSnd, GBFSGetFileLength(), isLoop);
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicStop()
{
	AdStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptMusicFadeOut()
{
	//TODO FadeOut処理
	ScriptMusicStop();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptDebugScn(u16 no)
{
	char buf[64];
	_Sprintf(buf, "scn = %03d", no);

	Mode3DrawFillBox(0, 0, 8*9, 11, COLOR_BLACK);
	Mode3DrawFontStr(0, 0, (u8*)buf, COLOR_WHITE);
	ScreenImgUpdate();
}
//---------------------------------------------------------------------------
EWRAM_CODE void ScriptDebugTxt(u8 no)
{
	char buf[64];
	_Sprintf(buf, "txt = %03d", no);

	Mode3DrawFillBox(8*9, 0, 8*9+7*9, 11, COLOR_BLACK);
	Mode3DrawFontStr(8*9, 0, (u8*)buf, COLOR_WHITE);
	ScreenImgUpdate();
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

	TRACEOUT("[History Add]\n");
	p->pTxtCur[0] = pTxtCur;


	if(p->cnt+1 < HISTORY_CNT)
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
EWRAM_CODE void HistoryReferebce()
{
	ST_HISTORY* p = &History;

	u16 key;
	u16 x      = ScreenFontGetX();
	u16 y      = ScreenFontGetY();
	u8  selMax = p->cnt;
	u8  sel    = 1;

	ScreenCursorMoveOut();
	ScreenFontDrawClsOAM();
	ScreenFontClearXY();

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

			ScreenFontDrawClsOAM();
			ScreenFontClearXY();
			HistoryParserTxt(p->pTxtCur[sel]);
		}
		else if(key & KEY_RIGHT)
		{
			if(sel == 1) break;
			sel--;

			ScreenFontDrawClsOAM();
			ScreenFontClearXY();
			HistoryParserTxt(p->pTxtCur[sel]);
		}
	}

	//画面を復帰させます
	FontLeafSetAttr(FONT_LEAF_COLOR_WHITE);
	ScreenFontDrawRestore();
	ScreenFontSetXY(x, y);

	ScreenCursorMoveIn();
}
//---------------------------------------------------------------------------
//「雫」テキストパーサ本体(履歴表示用)
EWRAM_CODE void HistoryParserTxt(u8* c)
{
	u8  c1;
	u16 buf[200], txt[200];
	u16 i, len;

	for(;;)
	{
		if(c[0] & 0x80 || c[0] == 'r')
		{
			i = 0;

			do
			{
				if(c[0] == 'r')
				{
					c++;
					continue;
				}

				buf[i++] = ((c[0] & 0x7f) << 8) + c[1];
				c += 2;

			} while(c[0] & 0x80 || c[0] == 'r');

			//禁則文字処理
			len = ScreenFontSetHyphenation(buf, txt, i);

			if( ScreenFontIsCnt(len) == TRUE )
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
