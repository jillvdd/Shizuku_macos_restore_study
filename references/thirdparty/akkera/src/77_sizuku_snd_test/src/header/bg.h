// BGに関する設定

#ifndef	BG_H
#define BG_H
#ifdef __cplusplus
extern "C" {
#endif

// REG_DISPCNT

// BGモード
#define DISP_BGMODE(x)	(x)
// モード４，５で表示するバッファ
#define DISP_SELECTBUFFER(x)	((x)<<4)

// Hblank中のスプライト描画プロセス制御
#define DISP_HBLANK_PROCESS_ON	(0<<5)
#define DISP_HBLANK_PROCESS_OFF	(1<<5)

// スプライトのマッピング方法
#define DISP_SPRITE_TYPE_1D	(1<<6)
#define DISP_SPRITE_TYPE_2D	(0<<6)

// BG描画の強制ブランク
#define DISP_FORCE_BLANK	(1<<7)

// BGやスプライト面、ウィンドウの表示設定
#define DISP_BG0	(1<<8)
#define DISP_BG1	(1<<9)
#define DISP_BG2	(1<<10)
#define DISP_BG3	(1<<11)
#define DISP_OBJ	(1<<12)

#define DISP_WND0	(1<<13)
#define DISP_WND1	(1<<14)
#define DISP_OBJWND	(1<<15)


// REG_DISPSTAT

// Vblank,Hblank,Vcountの現在の状態
#define DSTAT_BIT_VBLANK	(1)
#define DSTAT_BIT_HBLANK	(1<<1)
#define DSTAT_BIT_VCOUNT	(1<<2)

#define DSTAT_USE_VBLANK	(1<<3)
#define DSTAT_USE_HBLANK	(1<<4)
#define DSTAT_USE_VCOUNT	(1<<5)

#define DSTAT_VCOUNT_LINE(x)	((x)<<8)



// BGxCNTに入れる設定

// BGの大きさ
// BG0,1の場合
#define	BG_SIZEA_256_256	0
#define	BG_SIZEA_512_256	(1<<14)
#define	BG_SIZEA_256_512	(2<<14)
#define	BG_SIZEA_512_512	(3<<14)
// BG2,3の場合
#define	BG_SIZEB_128_128	0
#define	BG_SIZEB_256_256	(1<<14)
#define	BG_SIZEB_512_512	(2<<14)
#define	BG_SIZEB_1024_1024	(2<<14)

// BG2,3のみ回転時にオーバーラップする場合
#define	BG_OVERLAP	(1<<13)

// スクリーンベースアドレス 数値×2KB  0-31
#define BG_MAPBASE(x)	((x)<<8)

// BGカラーモード
#define	BG_COLOR_16		0
#define	BG_COLOR_256	(1<<7)

// モザイク設定
#define	BG_MOZAIC_ON	(1<<6)

// BGキャラクタベースアドレス 数値×16KB  0-3
#define	BG_CHARBASE(x)	((x)<<2)

// 優先順位 0-3 0に近いほど前面に描画
#define	BG_PRIORITY(x)	(x)



// マップデータ設定

// 16色パレットの場合 数値のパレット番号を使う
#define	BG_MAP_PAL(x)	((x)<<12)

// X,Y方向のフリップ
#define	BG_MAP_YFLIP	(1<<11)
#define	BG_MAP_XFLIP	(1<<10)

// 使用するタイル番号を指定する
#define	BG_MAP_TILE(x)	(x)


// VRAMでタイルキャラクタを指定する位置
// BG_CHARBASE(x)と同じ数値を入れる
#define	MEM_BG_CHR(x)	((u16*)(0x6000000 + (x)*0x4000))

// VRAMでマップデータを指定する位置
// BG_MAPBASE(x)と同じ数値を入れる
#define	MEM_BG_MAP(x)	((u16*)(0x6000000 + (x)* 0x800))

// BGメモリアドレス
#define	MEM_BG_PAL	((u16*)0x5000000)

#ifdef __cplusplus
}
#endif
#endif
