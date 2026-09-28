/*
 * LEAF Visual Novel System For X
 * (c) Copyright 1999,2000 Go Watanabe mailto:go@denpa.org
 * All rights reserverd.
 *
 * ORIGINAL LVNS (c) Copyright 1996-1999 LEAF/AQUAPLUS Inc.
 *
 * $Id: LvnsCoreDepend.c,v 1.1 2002/07/29 05:03:30 go Exp $
 */

/*
 * 環境に依存した各種処理を行う。これらの関数は、環境ごとに
 * 書き直す必要がある。
 * lvns->system_depend に環境依存情報が入っているので
 * これを参照することができる。
 */

#include <stdio.h>
#include <stdlib.h>

#include "LvnsCoreP.h"
#include "LvnsInfo.h"
#include "lvnsimage_sximage.h"

/* ---------------------------------------------------------------- */

/*
 * 仮想 VRAM 描画系
 */

/* 
 * 全画面をリフレッシュして実際の画面に反映させる
 */
void
LvnsFlushWindow(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_set_pixmap_area(LCW.sximage, 0, 0, WIDTH, HEIGHT);
    super_ximage_copy_area_win(LCW.sximage, 0, 0, WIDTH, HEIGHT);
    super_ximage_sync(LCW.sximage);
}

/*
 * 画面を部分的にリフレッシュして実際の画面に反映させる
 */
void
LvnsFlushWindowArea(LvnsInfo *lvns, int x, int y, int w, int h)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
#if 0
    dprintf((stderr, "FlushWindow %d %d %d %d\n", x, y, w, h));
#endif
    super_ximage_set_pixmap_area(LCW.sximage, x, y, w, h);
    super_ximage_copy_area_win(LCW.sximage, x, y, w, h);
}

void
LvnsSyncWindow(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_sync(LCW.sximage);
}

/* 全体を描画(フラッシュ無し) */
void
LvnsDrawWindow(LvnsInfo *lvns) 
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_copy_to_sximage(lvns->vram, LCW.sximage, 0, 0);
}

/* 部分描画(フラッシュ無し) */
void
LvnsDrawWindowArea(LvnsInfo *lvns, int x, int y, int w, int h, int x2, int y2)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_copy_area_to_sximage(lvns->vram, LCW.sximage, x, y, w, h, x2, y2);
}

/*
 * 全画面画面消去(フラッシュ無し)
 */
void
LvnsClearWindow(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_clear_area(LCW.sximage, 0, 0, WIDTH, HEIGHT,
                            LCW.sximage->pixels[lvns->vram->black]);
}

/*
 * 部分画面消去(フラッシュ無し)
 */
void
LvnsClearWindowArea(LvnsInfo *lvns, int x, int y, int w, int h)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_clear_area(LCW.sximage, x, y, w, h,
                            LCW.sximage->pixels[lvns->vram->black]);
}

/*
 * 特定のインデックスにカラーを割り当てる
 */
void
LvnsSetPaletteIndex(LvnsInfo *lvns, int index, int r, int g, int b)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_set_palette(LCW.sximage, index, r, g, b);
}

/*
 * パレット設定(通常)
 * 全部を設定する…
 */
void
LvnsSetPalette(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_set_pal_to_sximage(lvns->vram, LCW.sximage);
}

/*
 * パレット設定(multiple)
 */
void
LvnsSetPaletteMulti(LvnsInfo *lvns, int par16)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_set_pal_to_sximage_multi(lvns->vram, LCW.sximage, par16);
}

/*
 * パレット設定(screen)
 */
void
LvnsSetPaletteScreen(LvnsInfo *lvns, int par16)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_set_pal_to_sximage_screen(lvns->vram, LCW.sximage, par16);
}

/* 
 * マスクパターンでウインドウに対して描画を行う(フラッシュ無し)
 */
void
LvnsDrawWindowMask(LvnsInfo *lvns, int x, int y, int state)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_copy_mask_unit_to_sximage(lvns->vram, LCW.sximage, 
                                        x, y, state);
}

/* 
 * 矩形パターンでウィンドウに対して描画を行う(フラッシュ無し)
 */
void
LvnsDrawWindowSquareMask(LvnsInfo *lvns, int x, int y, int state)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    lvnsimage_copy_squaremask_unit_to_sximage(lvns->vram, LCW.sximage, 
                                              x, y, state);
}

/*
 * 表示されている画面のオフセットをずらす(振動用)
 */
void
LvnsSetDispOffset(LvnsInfo *lvns, int xoff, int yoff, int maxoff)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
#if 0
    super_ximage_clear_area_win(LCW.sximage, -maxoff, -maxoff, 
                                maxoff*2, HEIGHT+maxoff*2,
                                LCW.sximage->pixels[lvns->vram->black]);
    super_ximage_clear_area_win(LCW.sximage, -maxoff, -maxoff, 
                                WIDTH+maxoff*2, maxoff*2,
                                LCW.sximage->pixels[lvns->vram->black]);
    super_ximage_clear_area_win(LCW.sximage, +WIDTH-maxoff, 0, 
                                maxoff*2, HEIGHT+maxoff,
                                LCW.sximage->pixels[0]);
    super_ximage_clear_area_win(LCW.sximage, 0, +HEIGHT-maxoff, 
                                WIDTH+maxoff, maxoff*2,
                                LCW.sximage->pixels[lvns->vram->black]);
#endif
    super_ximage_copy_area_win2(LCW.sximage, -maxoff*2, -maxoff*2, WIDTH+maxoff*4, HEIGHT+maxoff*4, -maxoff*2 + xoff, -maxoff*2 + yoff);
    super_ximage_sync(LCW.sximage);
}

/* 
 * 文字パターン表示 (雫/痕 用)
 */
void
LvnsPutPattern(LvnsInfo *lvns, int x, int y, int index, u_char *data)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_put_pattern24_2(LCW.sximage, 
                                 x, y, LCW.sximage->pixels[index], data);
}

/* 
 * 文字パターン表示 (ToHeart 用)
 */
void
LvnsPutPattern2(LvnsInfo *lvns, int x, int y, int index, u_char *data)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    super_ximage_put_pattern24(LCW.sximage, 
                               x, y, LCW.sximage->pixels[index], data);
}

/* 
 * タイマをリセットする
 */
void
LvnsResetTimer(LvnsInfo *lvns, int no)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    gettimeofday(&LCW.timer[no], NULL);
}

/*
 * タイマ値を取得する
 */
long 
LvnsGetTimer(LvnsInfo *lvns, int no)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    struct timeval current;
    gettimeofday(&current, NULL);
    return (current.tv_sec - LCW.timer[no].tv_sec) * 1000 +
        (current.tv_usec - LCW.timer[no].tv_usec) / 1000;
}

/* ---------------------------------------------------------------- */

/*
 * メイン処理エンジンは、LvnsCoreMainEngine()
 *
 * ・シナリオ処理に状態遷移させた場合
 * ・帰り値が正の数だった場合にはその時間経過後
 * 
 * に呼び出される
 * 
 *
 * LvnsStartEngine() を呼ぶと、次回の処理ループで
 * LvnsMainEngine を呼び出すように設定すること
 *
 * LvnsStopEngine は処理の中断を行う。
 * 
 * メインの処理部では、LvnsMainEngine() を呼び出し、
 * 帰り値をチェックして次回の呼び出しを決定する
 */

/*
 * メイン処理エンジン(時間待ち駆動)
 */
static void
MainEngine(XtPointer cl, XtIntervalId * id)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget) cl;
    LvnsInfo *lvns  = &LCW.info;
    long waittime;
    struct timeval starttp;

    /* 補正用の時間の取得 */
    gettimeofday(&starttp, NULL);

#if 0
    dprintf((stderr, "MainEngine\n"));
#endif

    /* 処理と待ち時間取得 */
    waittime = LvnsMainEngine(lvns);

    /* 待ち時間が正の場合は次の呼び出しの設定 */
    if (waittime >= 0) {

        XtAppContext    app = XtWidgetToApplicationContext((Widget)lcw);

        /* 待ち時間の補正 */
        struct timeval curtp;
        long msec;

        gettimeofday(&curtp, NULL);
        msec = (curtp.tv_sec - starttp.tv_sec) * 1000 +
            (curtp.tv_usec - starttp.tv_usec) / 1000;
        
        if ((waittime -= msec) < 0)
            waittime = 0;

#if defined(__FreeBSD__)
        /* 
         * FreeBSD だけタイマの精度が悪いので
         * さらに補正する (T_T)
         */
        waittime += LCW.wait_add;
        LCW.wait_add = 0;
        if (waittime < 10) {
            LCW.wait_add = waittime;
            waittime = 0;
        }
#endif
        LCW.timewait_id = 
            XtAppAddTimeOut(app, waittime, MainEngine, lcw);
    } else {
        LCW.timewait_id = None;
    }
    
}

/*
 * メイン処理エンジンの起動 
 * 一連の処理が完結した次の処理ループでエンジンを呼び出す用指定
 */
void
LvnsStartEngine(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    if (LCW.timewait_id == None) {
        XtAppContext    app = XtWidgetToApplicationContext((Widget)lcw);
        LCW.timewait_id = XtAppAddTimeOut(app, 0, MainEngine, lcw);
    }
}

/*
 * メイン処理エンジンの停止 
 * 次回呼び出しの予約がかかっているエンジンを停止させる
 */
void
LvnsStopEngine(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    if (LCW.timewait_id) {
	XtRemoveTimeOut(LCW.timewait_id);
        LCW.timewait_id = None;
    }
}

/* 終了用 */
void
LvnsEnd(LvnsInfo *lvns)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    XtAppSetExitFlag(XtWidgetToApplicationContext((Widget)lcw));
}

void
LvnsDrawBox(LvnsInfo *lvns, int x, int y, int w, int h, int idx)
{
    LvnsCoreWidget lcw = (LvnsCoreWidget)lvns->system_depend;
    sximage_box(LCW.sximage, x, y, w, h, idx);
}

#include <sys/types.h>
#include <sys/stat.h>

time_t
LvnsGetFileTime(LvnsInfo *lvns, const char *path)
{
    struct stat sb;
    if (stat(path, &sb) < 0) {
        perror(path);
        return 0;
    }
    return sb.st_mtime;
}
