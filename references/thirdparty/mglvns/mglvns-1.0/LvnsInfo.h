/*
 * LEAF Visual Novel System For X
 * (c) Copyright 1999,2000 Go Watanabe mailto:go@denpa.org
 * All rights reserverd.
 *
 * ORIGINAL LVNS (c) Copyright 1996-1999 LEAF/AQUAPLUS Inc.
 *
 * $Id: LvnsInfo.h,v 1.1 2002/07/29 05:03:30 go Exp $
 *
 */

#ifndef __LvnsInfo_h
#define __LvnsInfo_h

#include <sys/types.h>

#ifdef DEBUG
#define dprintf(a) fprintf a
#else
#define dprintf(a)
#endif

#ifndef Bool
#define Bool int
#endif

#ifndef True
#define True 1
#endif

#ifndef False
#define False 0
#endif

#include "leafpack.h"   /* Leaf Pack File   */
#include "lvnsimage.h"  /* Leaf Image Data  */

#define VERSION "LEAF Visual Novel System for X\n"\
                " ==== XLVNS 1-2-3 Ver 3.0beta ====\n"\
                "(c) Copyright 1999,2000 Go Watanabe\n"\
                "Original LVNS (c)LEAF/AQUAPLUS\n"

#define INTERVAL 100

#ifndef XLVNSPACKDIR
#define XLVNSPACKDIR "/usr/local/share/xlvns"
#endif

#define NOCHARACTER 255

/* EUC コードからパックした JIS コードへ… */
#define EucToJisPack(code)  ((((code>>8)&0x7f)-33)*94 + ((code&0x7f)-33))

#define LVNS     lvns->system_state
#define WIDTH	(lvns->system_state->width)
#define HEIGHT	(lvns->system_state->height)
#define XPOS(x,y)    ((x) * 24 + lvns->tvram[lvns->current_tvram].row[y].offset)
#define YPOS(y)      ((y) * 28 + 8)
#define R_XPOS(x, y) (((x) - lvns->tvram[lvns->current_tvram].row[y].offset)/24)
#define R_YPOS(y)    (((y) - 8) / 28)

struct LvnsInfo;

typedef enum {
    LVNS_CURSOR_PAGE,
    LVNS_CURSOR_KEY,
}LvnsCursorType;

typedef enum {
    LVNS_EFFECT_NONE,
    LVNS_EFFECT_NORMAL,            /* 単純表示 */
    LVNS_EFFECT_FADE_MASK,         /* マスクフェード */
    LVNS_EFFECT_WIPE_TTOB,         /* 上からワイプ */
    LVNS_EFFECT_WIPE_LTOR,         /* 左からワイプ */
    LVNS_EFFECT_FADEOUT,           /* Palette フェード */
    LVNS_EFFECT_WHITEOUT,          /* Palette ホワイトアウト */
    LVNS_EFFECT_WIPE_MASK_LTOR,    /* 左からワイプ(マスク) */
    LVNS_EFFECT_FADE_SQUARE,       /* ひし形◆フェード */
    LVNS_EFFECT_WIPE_SQUARE_LTOR,  /* ひし形◆左ワイプ */
    LVNS_EFFECT_SLIDE_LTOR,        /* 左から縦スライド */
    LVNS_EFFECT_SLANTTILE,         /* 斜ずれ横モザイクスライド */
    LVNS_EFFECT_GURUGURU,          /* ぐるぐる */
    LVNS_EFFECT_VERTCOMPOSITION,   /* 縦方向ではさみこみ */
    LVNS_EFFECT_CIRCLE_SHRINK,     /* 中心方向にちじむ */
    LVNS_EFFECT_LEFT_SCROLL,       /* 左にスクロール */
    LVNS_EFFECT_TOP_SCROLL,        /* 上にスクロール */
    LVNS_EFFECT_RAND_RASTER,       /* ランダム行表示 */
    LVNS_EFFECT_BLOOD,             /* 血がだらだら   */
    LVNS_EFFECT_VIBRATO,           /* 画面を揺らす */
} LvnsEffectType;                  /* エフェクト種別 */

typedef Bool (*LvnsFunc)(struct LvnsInfo *lvns);
typedef void (*LvnsBackEffectSetFunc)(struct LvnsInfo *lvns);
typedef void (*LvnsBackEffectFunc)(struct LvnsInfo *lvns);
typedef struct {
    LvnsBackEffectSetFunc set;
    LvnsBackEffectFunc func;
} LvnsBackEffectInfo;


typedef struct {
    enum {
        LVNS_ANIM_NONE,
        LVNS_ANIM_IMAGE,
        LVNS_ANIM_IMAGE2,
        LVNS_ANIM_IMAGE_ADD,
        LVNS_ANIM_IMAGE_ADD2,
        LVNS_ANIM_DISP,
        LVNS_ANIM_SOUND,
        LVNS_ANIM_WAIT,
    } type;
    const char *name;
    int time;
    int x;
    int y;
    LvnsImage *image;
} LvnsAnimationData;    /* 単純アニメ処理用 */

typedef struct {
    enum {
        LVNS_SCRIPT_BG,                 /* 背景ロード       */
        LVNS_SCRIPT_DISP,               /* 画像表示(BGから) */
        LVNS_SCRIPT_DISP_VRAM,          /* 画像表示         */
        LVNS_SCRIPT_CLEAR,              /* 画像消去         */               
        LVNS_SCRIPT_CLEARDISP,          /* 画像消去表示     */               
        LVNS_SCRIPT_MUSIC,              /* 音楽再生         */
        LVNS_SCRIPT_MUSIC_FADE,
        LVNS_SCRIPT_WAIT_MUSIC,         /* 音楽終了待ち     */
        LVNS_SCRIPT_ANIM,
        LVNS_SCRIPT_KEY,
        LVNS_SCRIPT_TEXT,
        LVNS_SCRIPT_TEXT_CENTER,
        LVNS_SCRIPT_WAIT,               /* 指定時間待ち         */
        LVNS_SCRIPT_TIMER_INIT,         /* 待ち時間タイマ初期化 */
        LVNS_SCRIPT_TIMER_WAIT,         /* 指定時間経過まで待つ */
        LVNS_SCRIPT_FUNC,               /* 関数呼び出し         */
        LVNS_SCRIPT_KEY_JUMP,
        LVNS_SCRIPT_EXIT,
        LVNS_SCRIPT_END
    } type;
    void *data0;
    void *data1;
    void *data2;
} LvnsScriptData;       /* OP/ED スクリプト処理用 */

typedef struct LvnsScript {
    LvnsScriptData *data;       /* スクリプトデータ       */
    int cur;                    /* 実行カーソル           */
    int state;                  /* ステート               */
} LvnsScript;

typedef int LvnsScriptFunc(struct LvnsInfo *lvns, LvnsScript *scr, void *param1, void *param2);

typedef struct {
    int scn;   /* シナリオ番号 */
    int text;  /* テキスト番号 */
} LvnsHistoryData;      /* 回想モード用 */

typedef struct {
    char *command;
    int enable;
} LvnsCommandInfo;   /* 外部制御用 */

typedef struct {
    int width;              /* 内部描画領域のサイズ */
    int height;             
    const char *leafpack_name;   /* データ用パックファイル名称   */
    const char *scnpack_name;    /* シナリオ用パックファイル名称 */
    const char *scn_name;         /* シナリオファイルベース名称 */
    const char *fonttable_name;  /* コードコンバートテーブル名称 */
    void (*margeCharacter)(struct LvnsInfo *lvns);   /* キャラクタ合成 */
    void (*clearScreen)(struct LvnsInfo *lvns);      /* 仮想 VRAM の消去 */
    void (*loadBG)(struct LvnsInfo *lvns, int no);   /* 背景読み込み */
    LvnsCommandInfo* (*getCommandList)(struct LvnsInfo *lvns);  /* 外部操作一覧 */
    void (*execCommand)(struct LvnsInfo *lvns, const char *command);     /* 外部操作 */
    void (*drawChar)(struct LvnsInfo *lvns, int x, int y, int, int);

    int cursor_key;
    int cursor_page;

} LvnsSystemState;

typedef struct LvnsInfo {
    int type;               /* システムの種別 */
    void *system_depend;                /* 動作システム依存情報 */

    /* ------------------------------------------------------------ */

    LvnsSystemState *system_state;     /* システムステート */

    char *data_path;       /* データ検索基本パス */
    char *savedata_path;   /* データ保存位置 */
 
    LeafPack *leafpack;     /* データ用パックファイル */
    LeafPack *scnpack;      /* シナリオ用パックファイル */
    u_char *leaf_font_data; /* Leaf FONT のデータ   */

    u_char *leaf_to_euc;    /* コードコンバートテーブル Leaf -> EUC  */
    u_short *jis_to_leaf;   /* コードコンバートテーブル JIS Pack -> Leaf */

    /* 現在の状態 データの保存用 */
    enum bgtype {
        LVNS_VISUAL,
        LVNS_HCG,
        LVNS_BACKGROUND
    } bg_type;
    int bg_no;
    int left_no;
    int right_no;
    int center_no;

    Bool savepoint_flag;
    struct SavePoint{
        enum bgtype bg_type;
        int bg_no;
        int left_no;     /* 立ち絵状態保存用 */
        int right_no;    
        int center_no;
        int scn;         /* シナリオ番号保存用 */
        int blk;         /* シナリオブロック保存用       */
        long scn_offset; /* シナリオデータ保存用カーソル */
        int current_music;
    } savepoint;
    struct SavePoint selectpoint;


    /* ------------------------------------------------------ */
    /* テキストレイヤ処理系 */

#define TEXT_WIDTH  25
#define TEXT_HEIGHT 16

    struct {
        /* テキストレイヤ用仮想VRAM */
	
	struct TextVramLine {
	    int offset;
	    struct TextVram {
		int changed;    /* 更新されたかどうか */
		int code;       /* 文字のコード       */
		int attribute;  /* 文字の属性         */
	    } column[TEXT_WIDTH];
	} row[TEXT_HEIGHT];

        int cur_x;
        int cur_y;
        int o_cur_x;
        int o_cur_y;
    } tvram[2];
    int current_tvram;

    /* カーソルの状態 */
    int cursor_state;
    
    /* テキストカーソルの状態 */
    int text_cursor_state;     

    /* 選択肢の情報 */
    Bool select_mode;
    int select_num;
    struct {
	int no;
	int offset;
    } select_info[12];
    
    int text_attr;

    /* ---------------------------------------------------------- */
    /* シナリオパーサ */

    int start_scn_num;    /* 起動時シナリオ番号(for DEBUG) */

    u_char *scn_data;     /* シナリオデータ             */
    u_char *scn_cur_head; /* シナリオデータ先頭         */
    u_char *scn_cur;      /* シナリオデータカーソル     */

    u_char *scn_text;     /* シナリオテキスト           */
    u_char *scn_text_cur; /* テキスト部カーソル         */
    size_t  scn_length;

    int scn_current;      /* 現在のシナリオ番号   */
    int blk_current;      /* 現在のシナリオブロック */

    void (*scn_func)(struct LvnsInfo *);           /* シナリオエンジン */
    void (*menu_init_func)(struct LvnsInfo *);     /* メニュー初期化用 */
    Bool (*menu_func)(struct LvnsInfo *);          /* メニュー処理用   */

    /* 状態遷移 */
    enum LvnsState {
        LVNS_STOP,
        LVNS_SCENARIO,          /* シナリオパース中     */
        LVNS_WAIT_DARKEN,       /* 画面を暗くする       */
        LVNS_WAIT_LIGHTEN,      /* 画面を明るくする     */
        LVNS_WAIT_CLEARDISP,    /* 消去後表示           */
        LVNS_WAIT_CLEAR,        /* 消去エフェクト処理中 */
        LVNS_WAIT_DISP,         /* 表示エフェクト処理中 */
        LVNS_WAIT_DISP_KEY,     /* 表示エフェクト処理中 */
        LVNS_WAIT_KEY,          /* キー入力待ち     */
        LVNS_WAIT_KEY2,         /* キー入力待ち(カーソル表示無し) */
        LVNS_WAIT_PAGE,         /* 改ページ待ち     */
        LVNS_WAIT_SELECT,       /* 選択待ち         */
        LVNS_WAIT_MUSIC,        /* BGM 終了待ち     */
        LVNS_WAIT_MUSIC_FADE,   /* BGM FADE 処理待ち */
        LVNS_WAIT_SOUND,        /* サウンド再生完了待ち   */
        LVNS_WAIT_ANIM,         /* アニメーション終了待ち */
        LVNS_WAIT_FUNCTION,     /* 専用処理呼び出し */
        LVNS_MENU,              /* メニュー処理     */
        LVNS_MENU2,             /* メニュー処理 (キャンセル無し) */
        LVNS_WAIT_MENU,         /* メニュー選択待ち */ 
        LVNS_WAIT_MENU2,        /* メニュー選択待ち (キャンセル無し)*/ 
   } state;      

    enum LvnsState state_bak; /* 状態のバックアップ */

    Bool cleard;              /* 画面消去完了フラグ */
    Bool noredisp;            /* シナリオ戻った時文字があっても再描画をしない*/
    Bool image_mode;

    /* シナリオモード */
    enum {
        LVNS_DATA,      /* シナリオスクリプト */
        LVNS_TEXT,      /* テキストシナリオ   */
        LVNS_TEXT_CLEAR, /* テキストシナリオ   */
        LVNS_ADDTEXT,   /* 追加テキスト       */
    } scn_mode;
    
    Bool            image_changed; /* 更新状態チェックフラグ          */
    Bool            image_dark;    /* 現在の暗さ                      */
    Bool            image_touched; /* テキストが一回でも描画されたか? */

    Bool            text_written;  /* テキストが描画されている */
    Bool            text_changed;  /* テキストが更新された     */
    Bool            text_flushed;  /* テキストが全消去された   */

    Bool            key_clicked;   /* クリックフラグ   */

    Bool            fast_text;    /* テキストすっ飛ばしフラグ       */
    Bool            fast_disp;    /* 表示エフェクトすっとばしフラグ */

    int             char_wait_time;         /* 文字表示待ち時間     */
    int             char_wait_time_default; /* 標準文字表示待ち時間 */
    
    int             wait_time;   /* 待ち時間指定       */
    int             wait_scn;    /* シナリオ用待ち時間 */

    Bool            force_fast_disp; /* 見た文書でもすっとばす */
    Bool            key_click_fast; /* キークリックで文書を高速表示許可 */
    Bool            seen_mode;    /* 全文既読とみなすモード(for DEBUG) */
    Bool            demo_mode;    /* オートデモモード */

    int             demo_cnt;     /* デモ用カウンタ   */
    int             demo_choice;  /* デモメニュー用選択 */

    Bool            interval_disp; /* インターバル中に表示するか? */

    /* ------------------------------------------------------- */
    /* 画像描画系 */

    LvnsImage *vram_bg;    /* 背景データ保持用        */
    LvnsImage *vram;       /* 背景合成作業用仮想 VRAM */

    int latitude;          /* 現在の画像の明るさ 0-255          */
    int latitude_dark;     /* 画面が暗い時の輝度の指定          */

    LvnsEffectType effect_clear; /* 消去時エフェクト     */
    LvnsEffectType effect_disp;  /* 表示時エフェクト     */
    int effect_state;            /* エフェクト用ステート */

    LvnsBackEffectInfo *effect_back;
    LvnsBackEffectInfo *effect_back_next;
    int effect_back_state;               /* 背景エフェクト用ステート */


    /* ---------------------------------------------------------- */
    /* アニメーション処理用 */
    LvnsAnimationData *anim_data;
    int anim_off_x;
    int anim_off_y;

    /* ---------------------------------------------------------- */
    /* 専用処理呼び出し用 */
    LvnsFunc func;
    int func_state;

    /* -------------------------------------------------------- */
    /* 音楽再生系 */

    void *music_depend;                           /* 環境依存データ    */
    void (*InitMusic)(void *dep);                 /* BGM初期化         */
    void (*CloseMusic)(void *dep);

    void (*StartMusic)(void *dep, int no);        /* BGM開始           */
    void (*StopMusic)(void *dep);                 /* BGM停止           */
    void (*PauseMusic)(void *dep);                /* BGM一時停止       */
    void (*SetMusicVolume)(void *dep, int no);    /* BGMボリューム指定 */
    int  (*GetMusicState)(void *dep);             /* BGM演奏中チェック */

    /* ループの処理は自前 */
    int current_music;                            /* 現在演奏中の音楽     */
    Bool loop_music;                              /* ループかどうか       */
    int next_music;                               /* 次のシーンからの音楽 */
    Bool loop_next_music;                         /* ループかどうか       */

    int current_music_volume;                     /* 現在のボリューム設定 */
    int music_fade_mode;                          /* フェードモード       */
    int music_fade_flag;                          /* フェードの方向       */

    /* -------------------------------------------------------- */
    /* サウンド再生系 */

    void *sound_depend;                              /* 環境依存データ */
    void (*InitSound)(void *dep);
    void (*CloseSound)(void *dep);

    void (*LoadSound)(void *dep, const char *name);
    void (*StartSound)(void *dep);
    void (*StopSound)(void *dep);
    int  (*GetSoundState)(void *dep);

    /* ループ処理は自前 */
    int sound_loop;
    int sound_count;

} LvnsInfo;

/* LvnsText.c テキスト制御 */
void LvnsLocate(LvnsInfo *lvns, int x, int y);
void LvnsPutChar(LvnsInfo *lvns, int c, int attr);
void LvnsPutCharNormal(LvnsInfo *lvns, int c, int attr);
void LvnsPuts(LvnsInfo *lvns, u_char *str, int attr);
void LvnsPutsCenter(LvnsInfo *lvns, int y, u_char *str, int attr);
void LvnsClearText(LvnsInfo *lvns);
void LvnsSetTextOffset(LvnsInfo *lvns, int offset);
void LvnsNewLineText(LvnsInfo *lvns);
void LvnsPageWait(LvnsInfo *lvns);
void LvnsKeyWait(LvnsInfo *lvns);

/* LvnsAnim.c アニメーション処理 */
void LvnsInitAnimation(LvnsInfo *lvns, LvnsAnimationData *data);
void LvnsSetAnimation(LvnsInfo *lvns, LvnsAnimationData *data, 
                          int off_x, int off_y);
Bool LvnsAnimation(LvnsInfo *lvns);

/* LvnsMusic.c 音楽制御 */
void LvnsSetMusicVolume(LvnsInfo *lvns, int no);
void LvnsStartMusic(LvnsInfo *lvns, int no);
void LvnsStopMusic(LvnsInfo *lvns);
void LvnsPauseMusic(LvnsInfo *lvns);

void LvnsStartMusicLoop(LvnsInfo *lvns, int no);
void LvnsStartMusicLoop2(LvnsInfo *lvns, int no);
void LvnsSetNextMusic(LvnsInfo *lvns, int no);
void LvnsSetNextMusicLoop(LvnsInfo *lvns, int no);
void LvnsFadeMusic(LvnsInfo *lvns);
void LvnsStartNextMusic(LvnsInfo *lvns);

void LvnsLoopMusic(LvnsInfo *lvns);
void LvnsWaitMusic(LvnsInfo *lvns);
void LvnsWaitMusicFade(LvnsInfo *lvns);

/* LvnsSound.c 効果音制御 */
void LvnsLoadSound(LvnsInfo *lvns, const char* basename, int no);
void LvnsLoadSound2(LvnsInfo *lvns, const char* name);
void LvnsStartSound(LvnsInfo *lvns, int count);
void LvnsStopSound(LvnsInfo *lvns);
void LvnsWaitSound(LvnsInfo *lvns);
void LvnsLoopSound(LvnsInfo *lvns);

/* LvnsBackEffect.c 背景エフェクト制御 */
void LvnsSetBackEffect(LvnsInfo *lvns, LvnsBackEffectInfo *info);
void LvnsSetNextBackEffect(LvnsInfo *lvns, LvnsBackEffectInfo *info);
void LvnsBackEffectSetState(LvnsInfo *lvns);
void LvnsBackEffect(LvnsInfo *lvns);

/* LvnsScript.c OP/ED 用 スクリプト処理 */
int LvnsRunScript(LvnsInfo *lvns, LvnsScript *script);

/* LvnsImage.c 画像制御 */
void LvnsLoadBackground(LvnsInfo *lvns, const char *basename, int no);
void LvnsClear(LvnsInfo *lvns, LvnsEffectType effect_clear);
void LvnsDisp(LvnsInfo *lvns, LvnsEffectType effect_disp);
void LvnsClearDisp(LvnsInfo *lvns,
                       LvnsEffectType effect_clear,
                       LvnsEffectType effect_disp);

/* LvnsFile.c ファイル読み込み */
u_char *LvnsLoadData(LvnsInfo *lvns, const char *name, size_t *size);
LvnsImage *LvnsLoadImage(LvnsInfo *lvns, const char *name, LvnsImage *over);
void LvnsLoadScenario(LvnsInfo *lvns, int scn, int blk);
void LvnsLoadScenarioBlock(LvnsInfo *lvns, int blk);
void LvnsLoadScenarioText(LvnsInfo *lvns, int no);
u_char *LvnsGetScenarioText(LvnsInfo *lvns, int no);

/* LvnsEffect.c */
void LvnsInitClearEffect(LvnsInfo *lvns);
void LvnsInitDispEffect(LvnsInfo *lvns);
Bool LvnsDispEffect(LvnsInfo *lvns);
Bool LvnsClearEffect(LvnsInfo *lvns);
Bool LvnsDarken(LvnsInfo *lvns, int to_latitude, int diff);
Bool LvnsLighten(LvnsInfo *lvns, int to_latitude, int diff);
const char* LvnsEffectName(LvnsEffectType type);

/* LvnsEtc.c */
void LvnsInitSavePoint(LvnsInfo *lvns, struct SavePoint *sp);
void LvnsSetSavePoint(LvnsInfo *lvns, struct SavePoint *sp);

/* LvnsControl.c */
void LvnsMotion(LvnsInfo *lvns, int x, int y);
void LvnsClickLeft(LvnsInfo *lvns);
void LvnsClickRight(LvnsInfo *lvns);
void LvnsImageMode(LvnsInfo *lvns);
void LvnsSkipTillSelect(LvnsInfo *lvns);
void LvnsCursorUp(LvnsInfo *lvns);
void LvnsCursorDown(LvnsInfo *lvns);

/* システム依存関数群 */
void LvnsFlushWindow(LvnsInfo *lvns);
void LvnsFlushWindowArea(LvnsInfo *lvns, int x, int y, int w, int h);
void LvnsDrawWindow(LvnsInfo *lvns);
void LvnsDrawWindowArea(LvnsInfo *lvns, int x, int y, int w, int h, int x2, int y2);
void LvnsClearWindow(LvnsInfo *lvns);
void LvnsClearWindowArea(LvnsInfo *lvns, int x, int y, int w, int h);
void LvnsSetPaletteIndex(LvnsInfo *lvns, int idx, int r, int g, int b);
void LvnsSetPalette(LvnsInfo *lvns);
void LvnsSetPaletteMulti(LvnsInfo *lvns, int par16);
void LvnsSetPaletteScreen(LvnsInfo *lvns, int par16);
void LvnsDrawWindowMask(LvnsInfo *lvns, int x, int y, int state);
void LvnsDrawWindowSquareMask(LvnsInfo *lvns, int x, int y, int state);
void LvnsSetDispOffset(LvnsInfo *lvns, int xoff, int yoff, int maxoff);
void LvnsSyncWindow(LvnsInfo *lvns);

void LvnsPutPattern(LvnsInfo *lvns, int x, int y, int index, u_char *data);
void LvnsPutPattern2(LvnsInfo *lvns, int x, int y, int index, u_char *data);
void LvnsResetTimer(LvnsInfo *lvns, int no);
long LvnsGetTimer(LvnsInfo *lvns, int no);

void LvnsStartEngine(LvnsInfo *lvns);
void LvnsStopEngine(LvnsInfo *lvns);
void LvnsEnd(LvnsInfo *lvns);

void LvnsDrawBox(LvnsInfo *lvns, int x, int y, int w, int h, int idx);

time_t LvnsGetFileTime(LvnsInfo *lvns, const char *path);

/* Lvns.c */
void LvnsInitialize(LvnsInfo *lvns);
void LvnsDestroy(LvnsInfo *lvns);
void LvnsClearCursor(LvnsInfo *lvns);
void LvnsDrawCursor(LvnsInfo *lvns, LvnsCursorType cursor_type);
void LvnsClearTextCursor(LvnsInfo *lvns);
void LvnsDrawTextCursor(LvnsInfo *lvns);
void LvnsDrawMenu(LvnsInfo *lvns);

void LvnsDispWindow(LvnsInfo *lvns, int text_mode);

void LvnsInterval(LvnsInfo *lvns);
long LvnsMainEngine(LvnsInfo *lvns);
void LvnsStartSystem(LvnsInfo *lvns);
void LvnsSetState(LvnsInfo *lvns, enum LvnsState state);

void LvnsSetFunction(LvnsInfo *lvns, LvnsFunc func);

#endif

