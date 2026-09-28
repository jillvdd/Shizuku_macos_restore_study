/*
 * LEAF Visual Novel System For X
 * (c) Copyright 1999,2000 Go Watanabe mailto:go@denpa.org
 * All rights reserverd.
 *
 * ORIGINAL LVNS (c) Copyright 1996-1999 LEAF/AQUAPLUS Inc.
 *
 * $Id: LvnsImage.c,v 1.1 2002/07/29 05:03:30 go Exp $
 *
 */

/*
 * Lvns 画像処理まわり
 * シナリオエンジンからのみ利用すること。
 */

#include <stdio.h>
#include "LvnsInfo.h"

/*
 * 背景画像を設定する(番号指定)
 */
void
LvnsLoadBackground(LvnsInfo *lvns, const char *basename, int no)
{
    char name[20];
    sprintf(name, basename, no);
    (void)LvnsLoadImage(lvns, name, lvns->vram_bg);
}

/**
 * 表示処理を行う
 */
void
LvnsDisp(LvnsInfo *lvns, LvnsEffectType effect_disp)
{
    dprintf((stderr, "表示処理\n"));

    /* 絵を仮想VRAMに設定 */
    lvnsimage_copy(lvns->vram_bg, lvns->vram);
    lvns->system_state->margeCharacter(lvns);

    /* 表示開始 */
    lvns->effect_disp  = effect_disp;
    LvnsSetState(lvns, LVNS_WAIT_DISP);
    lvns->cleard = False;
    lvns->image_dark = False;

    if (!lvns->fast_disp && !lvns->fast_text)
        lvns->wait_scn = 800; /* XXX */
}

/**
 * 消去処理を行う
 */
void
LvnsClear(LvnsInfo *lvns,  LvnsEffectType effect_clear)
{
    dprintf((stderr, "消去処理\n"));
    LvnsDispWindow(lvns, False); /* いったん文字消去 */
    if (effect_clear) {
        lvns->effect_clear = effect_clear;
        LvnsSetState(lvns, LVNS_WAIT_CLEAR);
    }
    lvns->cleard = True;
}

/**
 * 消去処理を行う
 */
void
LvnsClearDisp(LvnsInfo *lvns,  
                  LvnsEffectType effect_clear, 
                  LvnsEffectType effect_disp)
{
    dprintf((stderr, "消去表示処理\n"));
    lvns->effect_disp = effect_disp;
    if (effect_clear) {
        lvns->effect_clear = effect_clear;
        LvnsSetState(lvns, LVNS_WAIT_CLEARDISP);
    } else {
        LvnsSetState(lvns, LVNS_WAIT_DISP);
    }
    lvns->image_dark = False;

    if (!lvns->fast_disp && !lvns->fast_text)
        lvns->wait_scn = 800; /* XXX */
}

