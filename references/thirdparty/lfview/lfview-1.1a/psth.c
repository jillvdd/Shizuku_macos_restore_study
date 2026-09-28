/*
 * psth.c
 * decode 'To Heart for Playstation' archive files.
 * 1/30/2000 by TF
 * originally written by Melody-Yoshi
 */
#include<stdio.h>
#include<string.h>
#include<stdlib.h>

#include "leafpak.h"
#include "plugins/psth.h"

#define PSTH_FILE_NUM 8000

#define PSTH_0 0
#define PSTH_1 1
#define PSTH_2 2
#define PSTH_3 3

#undef OUTPUT_BMP
/* #define OUTPUT_BMP */

/*
 * static variables
 */
static unsigned char *bz, *bf, *mem, pal[512];
static int xwide, ywide, num, outflag;
static PSTH_IMG img;

/*
 * static functions
 */
static void extract_image0(LEAFPACK *, int);
static void extract_image1(LEAFPACK *, int);
static void extract_image23(int, LEAFPACK *, int);
static void read_table_image0(LEAFPACK * lp);
static void read_table_image1(LEAFPACK * lp);
static void read_table_image23(int, LEAFPACK * lp);

static int decode(unsigned char *, unsigned char *);
static void hmx12_hdr(LEAFPACK *, unsigned char *, unsigned char *, unsigned char *, int);
static void hmx12(LEAFPACK *, unsigned char *, unsigned char *, unsigned char *, int, int);
static int tblcalc(unsigned char *, int, int, int, short *, short *);
static void copyn88(unsigned char *, unsigned char *, short, short, int, int, int, int, int, short, short);
static void outfile(char *, int, int);
static void outbmp8(char *, int, int);
static void outbmp(char *, int);

#ifdef OUTPUT_BMP
static void writelong(long, FILE *);
static void writeshort(short, FILE *);
#endif

#if 0
int main(int argc, char *argv[])
{
    LEAFPACK *lp;
    int i;
    char fn[96], fz[96];
    char *s;
    outflag = 0;

    if (argc == 0) {
	fprintf(stderr, "usage: leaffpak_ps [-lx] archive [files]");
	exit(1);
    }
    strcpy(fz, fn);
    strcat(fz, argv[1]);

    lp = (LEAFPACK *) malloc(sizeof(LEAFPACK));
    if (lp == NULL) {
	fprintf(stderr, "leafpack_open: Can't alloc memory\n");
	exit(1);
    }
    lp->fp = fopen(argv[1], "r");

    if (lp->fp == NULL) {
	fprintf(stderr, "leafpack_open: Can't open %s\n", argv[1]);
	exit(1);
    }
    s = rindex(argv[1], '/');

    strcpy(fz, ++s);
    for (i = 0; fz[i]; i++) {
	if (fz[i] == '.')
	    break;
    }
    fz[i] = 0;
    lp->basename = strdup(fz);

    lp3_open(lp);
    lp3_extract_table(lp);

    if (argc == 1) {
	/* analyze(lp); */
    } else {
	for (i = 2; i < argc; i++) {
	    lp3_extract_file(lp, argv[i]);
	}
    }
    lp3_close(lp);

    return 0;
}
#endif

int lp3_open(LEAFPACK *lp)
{
    int i;
    char *tmp, *h, *t;

    num = 0;
    img.palette = NULL;
    img.image = NULL;

    fseek(lp->fp, 0L, SEEK_END);
    lp->size = ftell(lp->fp);
    fseek(lp->fp, 0L, SEEK_SET);

    switch (lp->size) {		/* ファイルサイズで分岐 */
    case 40873984L:
	/*
	 * 072.PAK(エンディング,
	 * ウォーターシューティング．アスペクト比修正要) 221 files
	 */
	lp->archive_minor_type = PSTH_0;
	break;
    case 428032L:		/* 074.PAK(ミニゲーム: お嬢様は魔女) */
    case 1046528L:		/* 075.PAK(ミニゲーム: 落ちゲー) */
    case 137216L:		/* 076.PAK(志保ちゃんJUMP) */
	lp->archive_minor_type = PSTH_1;
	break;
    case 4343808L:		/* 073.PAK(志保ちゃんJUMP, 1840 files) */
	lp->archive_minor_type = PSTH_2;
	break;
    default:
	lp->archive_minor_type = PSTH_3;
	/*
	 * 000, 001, 003-016, 022, 064-068, 070-071, 077 : 画像無し 
	 * 002: segv 調査要: 移動マップ 
	 * 017: 背景: アスペクト比修正要(横長) 
	 * 018: 背景: アスペクト比修正要(縦長?) 
	 * 019: イベント絵: アスペクト比修正要(横長) 
	 * 020: イベント絵: アスペクト比修正要(横長), 19 と中身が同じっぽい…
	 * 021: マップ, チビキャラ 7942 files  
	 * 023: 立ち絵(あかり) 
	 * 024: 立ち絵(芹香) 
	 * 025: 立ち絵(智子) 
	 * 026: 立ち絵(志保) 
	 * 027: 立ち絵(葵) 
	 * 028: 立ち絵(マルチ) 
	 * 029: 立ち絵(琴音) 
	 * 030: 立ち絵(レミィ) 
	 * 031: 立ち絵(雅史) 
	 * 032: 立ち絵(レミィ: 弓道着) 
	 * 033: 立ち絵(シンディ) 
	 * 034: 立ち絵(坂下) 
	 * 035: 立ち絵(3人組) 
	 * 036: 立ち絵(綾香) 
	 * 037: 立ち絵(みねちゃん) 
	 * 038: 立ち絵(あかりママ) 
	 * 039: 立ち絵(迷子の女の子) 
	 * 040: 立ち絵(あかり私服) 
	 * 041: 立ち絵(芹香) 
	 * 042: 立ち絵(セバスチャン) 
	 * 043: 立ち絵(矢島) 
	 * 044: 立ち絵(量産型マルチ) 
	 * 045: 立ち絵(あかりと眼鏡の子(捻挫イベント)) 
	 * 046: 立ち絵(セリオ) 
	 * 047: 立ち絵(長瀬主任) 
	 * 048: 立ち絵(あかり: 風邪) 
	 * 049: 立ち絵(サッカー部のやつ．誰だっけ(^_^; ) 
	 * 050: 立ち絵(智子の父) 
	 * 051: 立ち絵(あかり: 制服エプロン) 
	 * 052: 立ち絵(理緒) 
	 * 053: 立ち絵(理緒の弟) 
	 * 054: 立ち絵(レミィ弟) 
	 * 055: 立ち絵(レミィ父) 
	 * 056: 立ち絵(レミィ母) 
	 * 057: 立ち絵(こさおりん) 
	 * 058: 立ち絵(琴音のクラスメート) 
	 * 059: 立ち絵(弓道部の先輩1) 
	 * 060: 立ち絵(弓道部の先輩2) 
	 * 061: 立ち絵(レミィ犬) 
	 * 062: 立ち絵(理緒) 
	 * 063: タイトル 
	 * (snip)
	 * 069: コンプリート時のマルチとくま 
	 * v01: 画像無し: segv で落ちる 
	 * v02: 画像無し: segv で落ちる 
	 * v03: 画像無し 
	 */
	break;
    }

    lp->archive_type = PSTH;
    lp->pos = (int *)calloc(PSTH_FILE_NUM, sizeof(int));
    lp->nextpos = (int *)calloc(PSTH_FILE_NUM, sizeof(int));
    lp->len = (int *)calloc(PSTH_FILE_NUM, sizeof(int));
    lp->block = (int *)calloc(PSTH_FILE_NUM, sizeof(int));
    lp->bid = (int *)calloc(PSTH_FILE_NUM, sizeof(int));
    lp->name = (char **)calloc(PSTH_FILE_NUM, sizeof(char **));
    for (i = 0; i < PSTH_FILE_NUM; i++) {
	lp->name[i] = (char *)calloc(13, sizeof(char *));
    }

    /* decide basename */
    tmp = strdup(lp->basename);
    free(lp->basename);
    if ((h = rindex(tmp, '/')) == NULL) {
      h = tmp;
    } else {
      h++;
    }
    if ((t = index(h, '.')) != NULL) *t = '\0';
    lp->basename = strdup(h);
    free(tmp);
    
    /* alloc work area */
    mem = (unsigned char *)malloc(0x80000);
    bz = (unsigned char *)malloc(0x80000);
    bf = (unsigned char *)malloc(0x80000);
    if (mem == NULL || bz == NULL || bf == NULL) {
	fprintf(stderr, "lp3_open: Can't alloc memory\n");
	exit(1);
    }

    return 0;
}

int lp3_close(LEAFPACK *lp)
{
    int i;

    fclose(lp->fp);

    free(lp->pos);
    free(lp->nextpos);
    free(lp->len);
    free(lp->block);
    free(lp->bid);
    for (i = 0; i < PSTH_FILE_NUM; i++) {
	free(lp->name[i]);
    }
    free(lp->name);
    free(lp);

    /* free work area */
    free(bf);
    free(bz);
    free(mem);

    return 0;
}

int lp3_check_magic(LEAFPACK *lp, const char *buf)
{
    if (buf[5] == 'B' && buf[6] == 'A' && buf[7] == 'N') {
	return TRUE;
    }
    if (buf[5] == 'B' && buf[6] == 'G' && buf[7] == '_') {
	return TRUE;
    }
    if (buf[0] == 'T' && buf[1] == 'B' && buf[2] == 'L' && buf[3] == '1') {
	return TRUE;
    }
    if (buf[0] == 'X' && buf[1] == 'X' && buf[2] == 'X' && buf[3] == 'X') {
	return TRUE;
    }
    if (buf[4] == (char)0x81 && buf[5] == (char)0x10 && buf[6] == (char)0xe1 && buf[7] == (char)0x81) {
	return TRUE;
    }
    return FALSE;
}

void lp3_extract_table(LEAFPACK *lp)
{
    num = 0;

    switch (lp->archive_minor_type) {
    case PSTH_0:
	read_table_image0(lp);
	break;
    case PSTH_1:
	read_table_image1(lp);
	break;
    case PSTH_2:
	read_table_image23(1, lp);
	break;
    case PSTH_3:
	read_table_image23(0, lp);
	break;
    default:
	fprintf(stderr, "Unknown minor type.\n");
	exit(1);
    }
    printf("extracted table.\n");
}

int lp3_extract_file(LEAFPACK * lp, const char *name)
{
    int i, id = -1;

    num = 0;

    for (i = 0; i < lp->file_num; i++) {
	if (!strcmp(name, lp->name[i])) {
	    id = i;
	    break;
	}
    }
    if (id < 0) {
	printf("file: %s is not included in the archive.\n", name);
	return 0;
    }
    switch (lp->archive_minor_type) {
    case PSTH_0:
	extract_image0(lp, id);
	break;
    case PSTH_1:
	extract_image1(lp, id);
	break;
    case PSTH_2:
	extract_image23(1, lp, id);
	break;
    case PSTH_3:
	extract_image23(0, lp, id);
	break;
    default:
	fprintf(stderr, "Unknown minor type.\n");
	exit(1);
    }
    printf("completed.\n");

    return 0;
}

unsigned char *lp3_extract_file_to_data(LEAFPACK *lp, const char *name, int *size)
{
    int i, id = -1;
    int *result;

    num = 0;

    for (i = 0; i < lp->file_num; i++) {
	if (!strcmp(name, lp->name[i])) {
	    id = i;
	    break;
	}
    }
    if (id < 0) {
	printf("file: %s is not included in the archive.\n", name);
	return 0;
    }
    switch (lp->archive_minor_type) {
    case PSTH_0:
	extract_image0(lp, id);
	break;
    case PSTH_1:
	extract_image1(lp, id);
	break;
    case PSTH_2:
	extract_image23(1, lp, id);
	break;
    case PSTH_3:
	extract_image23(0, lp, id);
	break;
    default:
	fprintf(stderr, "Unknown minor type.\n");
	exit(1);
    }

    /* id(2) + type(1) + width(1) + height(1) + palette_size(1)
       + palette(3*ps) + image(w*h) */
    *size = 6 + img.palette_size * 3 + img.width * img.height;
    result = (int *)calloc(*size, sizeof(int));
    if (result == NULL) {
      fprintf(stderr, "lp3_extract_file_to_data: can't alloc memory\n");
      exit(1);
    }
    result[0] = 0x5053; /* PS */
    result[1] = 0x5448; /* TH */
    result[2] = img.type;
    result[3] = img.width;
    result[4] = img.height;
    result[5] = img.palette_size;
    memcpy(&result[6], img.palette, sizeof(int) * 3 * img.palette_size);
    memcpy(&result[6 + 3 * img.palette_size],
	   img.image, sizeof(int) * img.width * img.height);

    return (unsigned char *)result;
}

void read_table_image23(int x, LEAFPACK *lp)
{
    int i, j, k, l, n;
    int l1, l2, n0, blk;

    fseek(lp->fp, 0L, SEEK_SET);

    for (blk = 0;; blk++) {
	j = 0;
	l1 = ftell(lp->fp);
	n0 = num;
	i = fread(mem, 1, 0x800, lp->fp);
	if (i < 0x800)
	    break;

	while (mem[j + 0x7FC] + mem[j + 0x7FD] + mem[j + 0x7FE] + mem[j + 0x7FF]) {
	    j += 0x800;
	    fread(&mem[j], 1, 0x800, lp->fp);
	}
	if (mem[0] == 'T' && mem[1] == 'B' && mem[2] == 'L' && mem[3] == '1') {
	    j = mem[4] | (mem[5] << 8);
	    for (i = 0; i < j; i++) {
		k = mem[i * 4 + 8] | (mem[i * 4 + 9] << 8) | (mem[i * 4 + 10] << 16);
		hmx12_hdr(lp, &mem[k], bf, bz, x);
	    }
	} else {
	    j = mem[0] | (mem[1] << 8) | (mem[2] << 16) | (mem[3] << 24);
	    if (j > 0x200 && j < 0x80000) {	/* 適当 */
		hmx12_hdr(lp, mem, bf, bz, x);
	    }
	}
	l2 = ftell(lp->fp);
	for (n = n0, l = 0; n < num; n++, l++) {
	    sprintf(lp->name[n], "%s%03x.bmp", lp->basename, n);
	    lp->pos[n] = l1;
	    lp->nextpos[n] = l2;
	    lp->len[n] = l2 - l1;
	    lp->block[n] = blk;
	    lp->bid[n] = l;
	}
    }

    lp->file_num = num;
#ifdef DEBUG
    for (i = 0; i < num; i++) {
	printf("%d:%s: %08x\t%d[%d-%d]\n", i, lp->name[i], lp->pos[i], lp->len[i], lp->block[i], lp->bid[i]);
    }
    printf("tbl: %d files\n", lp->file_num);
#endif
}

void hmx12_hdr(LEAFPACK * lp, unsigned char *s, unsigned char *w, unsigned char *d, int f)
{
    int a, i, j, k, m, p, r;

    if (f == 1 && num == 0x31D) {	/* 073.PAK */
	p = decode(s, d);
	if (p == 0x55700) {
	    memcpy(w, d, p);
	    return;
	} else {
	    memcpy(&w[0x60000], d, p);
	}
	p = 0x55700;
    } else {
	p = decode(s, w);
	if (p < 8)
	    return;
    }
    if (w[0] == 'B' && w[1] == 'A' && w[2] == 'N' && w[3] == 'K') {
	for (p = (p & 0xFFFFC) - 4; p >= 0; p -= 4) {
	    if (w[p] == 'C' && w[p + 1] == 'O' && w[p + 2] == 'L' && w[p + 3] == '_') {
		a = p + 8;
	    } else if (w[p] == 'P' && w[p + 1] == 'T' && w[p + 2] == 'N' && w[p + 3] == '_') {
		break;
	    }
	}
	j = w[p + 4];
	m = w[p + 6] | (w[p + 7] << 8);
	p += 8;

	for (i = 0; i < j; i++) {
	    k = i * 4 + p;
	    r = w[k] | (w[k + 1] << 8);
	    k = (i == j - 1) ? (m - r) : (w[k + 4] | (w[k + 5] << 8)) - r;
	    r = p + j * 4 + r * 12;
	    if ((w[r] & 0x80) == 0)
		continue;	/* MASK画像の判別 */
	    /* sprintf(lp->name[num], "%s%03x.bmp", lp->basename, num); */
	    num++;
	}
    } else if (w[0] == 'B' && w[1] == 'G' && w[2] == '_' && w[3] == '_') {
	/* sprintf(lp->name[num], "%s%03x.bmp", lp->basename, num); */
	num++;
    }
}

void extract_image23(int x, LEAFPACK * lp, int id)
{
    int i, j, k, b;

    fseek(lp->fp, 0L, SEEK_SET);

    num = 0;
    b = lp->block[id];
    while (lp->block[num] != b) {
	num++;
    }

    fseek(lp->fp, lp->pos[num], SEEK_SET);
    fread(mem, 1, lp->len[num], lp->fp);

    if (mem[0] == 'T' && mem[1] == 'B' && mem[2] == 'L' && mem[3] == '1') {
	j = mem[4] | (mem[5] << 8);
	xwide = j << 8;
	ywide = 224;
	for (i = 0; i < j; i++) {
	    k = mem[i * 4 + 8] | (mem[i * 4 + 9] << 8) | (mem[i * 4 + 10] << 16);
	    hmx12(lp, &mem[k], bf, bz, x, id);
	}
    } else {
	j = mem[0] | (mem[1] << 8) | (mem[2] << 16) | (mem[3] << 24);
	if (j > 0x200 && j < 0x80000) {		/* 適当 */
	    hmx12(lp, mem, bf, bz, x, id);
	}
    }
}

void read_table_image1(LEAFPACK * lp)
{
    int i, j;

    fseek(lp->fp, 0L, SEEK_SET);

    for (num = 0;; num++) {
	j = 0;
	lp->pos[num] = ftell(lp->fp);
	sprintf(lp->name[num], "%s%03x.bmp", lp->basename, num);

	i = fread(mem, 1, 0x800, lp->fp);
	if (i < 0x800) {
	    break;
	}
	while (mem[j + 0x7FC] + mem[j + 0x7FD] + mem[j + 0x7FE] + mem[j + 0x7FF]) {
	    j += 0x800;
	    fread(&mem[j], 1, 0x800, lp->fp);
	}
	lp->nextpos[num] = ftell(lp->fp);
	lp->len[num] = lp->nextpos[num] - lp->pos[num];
	printf("%s\t%08x\t%d\n", lp->name[num], lp->pos[num], lp->len[num]);
    }
    lp->file_num = num;
    printf("tbl: read %d files\n", num);
}

void extract_image1(LEAFPACK * lp, int id)
{
    int i, j;

    if (id < 0 || id > lp->file_num) {
	fprintf(stderr, "extract_image1: Invalid image id.\n");
	return;
    }
    fseek(lp->fp, lp->pos[id], SEEK_SET);
    fread(mem, 1, lp->len[id], lp->fp);

    if (mem[3] || mem[2] > 5)
	return;
    decode(mem, bz);
    if (bz[0] != 0x10)
	return;

    i = bz[16] | (bz[17] << 8);
    i *= bz[18];
    i <<= 1;
    memcpy(pal, &bz[20], i);
    i = (bz[8] | (bz[9] << 8) | (bz[10] << 16)) + 8;
    ywide = bz[i + 10] | (bz[i + 11] << 8);
    xwide = (bz[i + 8] | (bz[i + 9] << 8)) << 1;
    j = bz[4];
    memcpy(bz, &bz[i + 12], xwide * ywide);
    if (j == 9) {
	outfile(lp->basename, id, 256);
    } else {
	xwide <<= 1;
	outfile(lp->basename, id, 16);
    }
}

void read_table_image0(LEAFPACK * lp)
{
    int i, j, k, m, n;
    int l, l1, l2, n0, blk;

    fseek(lp->fp, 0L, SEEK_SET);

    for (blk = 0;; blk++) {
	l1 = ftell(lp->fp);
	n0 = num;
	if (l1 == 0x0958800) {
	    fseek(lp->fp, 0x24A0800L, SEEK_SET);
	    l1 = 0x24A0800L;
	}
	if (l1 == 0x2585800) {
	    fseek(lp->fp, 0x2593800L, SEEK_SET);
	    l1 = 0x2593800L;
	}
	j = 0;
	i = fread(mem, 1, 0x800, lp->fp);
	if (i < 0x800) {
	    break;
	}
	while (mem[j + 0x7FC] + mem[j + 0x7FD] + mem[j + 0x7FE] + mem[j + 0x7FF]) {
	    j += 0x800;
	    fread(&mem[j], 1, 0x800, lp->fp);
	}
	if (mem[0] == 'T' && mem[1] == 'B' && mem[2] == 'L' && mem[3] == '1') {
	    j = mem[4] | (mem[5] << 8);
	    for (i = 0; i < j; i++) {
		if (k == 0x28800 && i == 3)
		    m = 3;
		else if (k == 0x268B800)
		    m = 2;
		else
		    m = 1;
		if ((mem[i * 4 + 11] & 0x80) == 0)
		    continue;
		hmx12_hdr(lp, &mem[mem[i * 4 + 8] | (mem[i * 4 + 9] << 8) | (mem[i * 4 + 10] << 16)], bf, bz, m);
	    }
	} else {
	    j = mem[0] | (mem[1] << 8) | (mem[2] << 16) | (mem[3] << 24);
	    if (j > 0x200 && j < 0x80000) {	/* 適当 */
		hmx12_hdr(lp, mem, bf, bz, 1);
	    }
	}
	l2 = ftell(lp->fp);
	for (n = n0, l = 0; n < num; n++, l++) {
	    sprintf(lp->name[n], "%s%03x.bmp", lp->basename, n);
	    lp->pos[n] = l1;
	    lp->nextpos[n] = l2;
	    lp->len[n] = l2 - l1;
	    lp->block[n] = blk;
	    lp->bid[n] = l;
	}
    }
    lp->file_num = num;

    for (i = 0; i < num; i++) {
	printf("%s: %08x\t%d[%d-%d]\n", lp->name[i], lp->pos[i], lp->len[i], lp->block[i], lp->bid[i]);
    }
    printf("tbl: %d files\n", lp->file_num);
}

void extract_image0(LEAFPACK * lp, int id)
{
    int i, j, k, m, b;

    fseek(lp->fp, 0L, SEEK_SET);

    num = 0;
    b = lp->block[id];
    while (lp->block[num] != b) {
	num++;
    }

    fseek(lp->fp, lp->pos[num], SEEK_SET);
    fread(mem, 1, lp->len[num], lp->fp);

    if (mem[0] == 'T' && mem[1] == 'B' && mem[2] == 'L' && mem[3] == '1') {
	j = mem[4] | (mem[5] << 8);
	xwide = j << 8;
	ywide = 224;
	for (i = 0; i < j; i++) {
	    if (k == 0x28800 && i == 3)
		m = 3;
	    else if (k == 0x268B800)
		m = 2;
	    else
		m = 1;
	    if ((mem[i * 4 + 11] & 0x80) == 0)
		continue;
	    hmx12(lp, &mem[mem[i * 4 + 8] | (mem[i * 4 + 9] << 8) | (mem[i * 4 + 10] << 16)], bf, bz, m, id);
	}
    } else {
	j = mem[0] | (mem[1] << 8) | (mem[2] << 16) | (mem[3] << 24);
	if (j > 0x200 && j < 0x80000) {		/* 適当 */
	    hmx12(lp, mem, bf, bz, 1, id);
	}
    }
}

void hmx12(LEAFPACK * lp, unsigned char *s, unsigned char *w, unsigned char *d, int f, int id)
{
    int a, i, j, k, m, p, r, t;
    short x, y;

    if (f == 1 && num == 0x31D) {	/* 073.PAK */
	p = decode(s, d);
	if (p == 0x55700) {
	    memcpy(w, d, p);
	    return;
	} else {
	    memcpy(&w[0x60000], d, p);
	}
	p = 0x55700;
    } else {
	p = decode(s, w);
	if (p < 8)
	    return;
    }
    if (w[0] == 'B' && w[1] == 'A' && w[2] == 'N' && w[3] == 'K') {
	for (p = (p & 0xFFFFC) - 4; p >= 0; p -= 4) {
	    if (w[p] == 'C' && w[p + 1] == 'O' && w[p + 2] == 'L' && w[p + 3] == '_') {
		a = p + 8;
	    } else if (w[p] == 'P' && w[p + 1] == 'T' && w[p + 2] == 'N' && w[p + 3] == '_') {
		break;
	    }
	}
	j = w[p + 4];
	m = w[p + 6] | (w[p + 7] << 8);
	p += 8;
	if (tblcalc(w, j, m, p, &x, &y)) {
	    xwide = 128;
	    ywide = 96;
	} else {
	    xwide = 512;
	    ywide = 224;
	}
	for (i = 0; i < j; i++) {
	    k = i * 4 + p;
	    r = w[k] | (w[k + 1] << 8);
	    k = (i == j - 1) ? (m - r) : (w[k + 4] | (w[k + 5] << 8)) - r;
	    r = p + j * 4 + r * 12;
	    if ((w[r] & 0x80) == 0)
		continue;	/* MASK画像の判別 */
	    memset(d, 0, xwide * ywide);
	    if (w[4] == 1) {
		if (f < 2) {
		    t = (f == 0) ? 224 : 240;
		    memcpy(pal, &w[a], 512);
		    if (f == 1) {
			if (num >= 0x31D && num <= 0x327) {
			    memcpy(pal, &w[0x60008 + (num - 0x31D) * 512], 512);
			} else if (num >= 0x334 && num <= 0x336) {
			    memcpy(pal, &w[a + (num - 0x333) * 512], 512);
			}
			if (num >= 0x6A6)
			    t = 224;
		    }
		} else {	/* 強引(072.PAK) */
		    t = 240;
		    if (f == 2) {
			if (i == 6)
			    memcpy(pal, &w[a + 512], 512);
			else if (i == 7)
			    memcpy(pal, &w[a + 1024], 512);
			else
			    memcpy(pal, &w[a], 512);
		    } else {
			if (i >= 27) {
			    memcpy(pal, &w[a + 1024], 512);
			} else if (i >= 18) {
			    memcpy(pal, &w[a + 512], 512);
			} else {
			    memcpy(pal, &w[a], 512);
			}
		    }
		}
	    } else {
		memcpy(pal, &w[a + w[r + 2] * 32], 32);
	    }
	    for (r += (k - 1) * 12; k > 0; k--, r -= 12) {	/* 前の方が優先 */
		copyn88(w, d, w[r + 4] | (w[r + 5] << 8), w[r + 6] | (w[r + 7] << 8), w[r + 8] & 0xF0, (w[r + 9] & 0xF0) + (w[r] & 15) * t - w[8], w[r + 10], w[r + 11], 240, x, y);
	    }
	    if (w[4] == 1) {
		outfile(lp->basename, num, 256);
	    } else {
		outfile(lp->basename, num, 16);
	    }
	    num++;
	}
    } else if (w[0] == 'B' && w[1] == 'G' && w[2] == '_' && w[3] == '_') {
	xwide = w[7] * 256;
	ywide = 224;
	for (p = (p & 0xFFFFC) - 4; p >= 0; p -= 4) {
	    if (w[p] == 'C' && w[p + 1] == 'O' && w[p + 2] == 'L' && w[p + 3] == '_')
		break;
	}
	if (f == 1 && num == 0x17F)
	    memcpy(pal, &w[p + 520], 512);	/* 073.PAK */
	else if (p >= 0)
	    memcpy(pal, &w[p + 8], 512);
	k = w[7];
	if (w[4] == 2) {
	    for (xwide <<= 1, i = 0; i < k; i++) {
		copyn88(w, d, i * 512, 0, 0, i * 256, 512, 256, 512, 0, 0);
	    }
	    xwide >>= 1;
	    outfile(lp->basename, num, 1);
	    num++;
	} else {
	    for (i = 0; i < k; i++) {
		copyn88(w, d, i * 256, 0, 0, i * 256, 256, 224, 256, 0, 0);
	    }
	    outfile(lp->basename, num, 256);
	    num++;
	}
    }
    /* printf("ex: %d files\n", num); */
}

/*
 * 座標テーブルから最小値を得る 
 */
int tblcalc(unsigned char *w, int j, int m, int p, short *xx, short *yy)
{
    int i, k, r;
    short q, u, v, x, y;
    for (i = 0, u = v = 0, x = y = 32767; i < j; i++) {
	k = i * 4 + p;
	r = w[k] | (w[k + 1] << 8);
	k = (i == j - 1) ? (m - r) : (w[k + 4] | (w[k + 5] << 8)) - r;
	r = p + j * 4 + r * 12;
	if ((w[r] & 0x80) == 0)
	    continue;
	for (; k > 0; k--, r += 12) {
	    q = (short)(w[r + 4] | (w[r + 5] << 8));
	    if (q < x)
		x = q;
	    q += w[r + 10];
	    if (q > u)
		u = q;
	    q = (short)(w[r + 6] | (w[r + 7] << 8));
	    if (q < y)
		y = q;
	    q += w[r + 11];
	    if (q > v)
		v = q;
	}
    }
    *xx = (x < 0) ? (-x) : 0;
    *yy = (y < 0) ? (-y) : 0;
    x = (x < 0) ? (-x) : 0;
    y = (y < 0) ? (-y) : 0;
    u += x;
    v += y;
    if (u < 128 && v < 96)
	return 1;
    return 0;
}

/*
 * 圧縮データの解凍 
 */
int decode(unsigned char *s, unsigned char *d)
{
    int j, k, p, q, t;
    unsigned char c;

    t = s[0] | (s[1] << 8) | (s[2] << 16);
    if (t < 8)
	return (0);
    for (p = 4, q = 0; p < t;) {
	c = s[p++];
	if ((c & 0x80) == 0) {
	    j = (c << 8) | s[p++];
	    k = (j & 0x3FF);
	    for (j = (j >> 10) + 2; j > 0; j--, q++)
		d[q] = d[q - k];
	} else {
	    if (c >= 0xA0) {
		if (c < 0xE0) {
		    j = (int)(c & 0x1F) + 2;
		    c = s[p++];
		} else if (c != 0xFF) {
		    j = (int)(c & 0x1F) + 2;
		    c = 0;
		} else {
		    j = s[p++] + 2;
		    c = 0;
		}
		for (; j > 0; j--, q++)
		    d[q] = c;
	    } else {
		for (j = (int)(c & 0x1F); j > 0; j--, p++, q++)
		    d[q] = s[p];
	    }
	}
    }
    return q;
}

/*
 * PUT(sx,sy) SRC(tx,ty,dx,dy) SRC-WIDTH(wx) OFFSET(ox,oy) 
 */
void copyn88(unsigned char *s, unsigned char *d, short sx, short sy, int tx, int ty, int dx, int dy, int wx, short ox, short oy)
{
    int x, y;

    sx += ox;
    sy += oy;
    if (s[4] >= 1) {		/* CI8 */
	for (y = 0; y < dy; y++) {
	    for (x = 0; x < dx; x++) {
		d[(y + sy) * xwide + x + sx] = s[(y + ty) * wx + x + tx + 12];
	    }
	}
    } else {			/* CI4 */
	for (y = 0; y < dy; y++) {
	    for (x = 0; x < dx; x += 2) {
		d[((y + sy) * xwide + x + sx) / 2] = s[((y + ty) * wx + x + tx) / 2 + 12];
	    }
	}
    }
}

/*
 * ファイルの出力 
 */
void outfile(char *fn, int no, int c)
{
    int s, w, x, y, z;
    if (c == 1) {
	for (y = xwide * ywide * 2 - 2, x = xwide * ywide * 3 - 3; y >= 0; y -= 2, x -= 3) {
	    z = (bz[y + 1] << 8) | bz[y];
	    bz[x + 2] = (z & 0x1F) << 3;
	    bz[x + 1] = (z & 0x3E0) >> 2;
	    bz[x] = (z & 0x7C00) >> 7;
	}
    }
    if (outflag == 0) {
	if (c == 1) {
	    outbmp(fn, no);
	} else {
	    outbmp8(fn, no, c);
	}
    } else {			/* 補間縮小 */
	if (c == 16) {
	    for (y = xwide * ywide / 2 - 1, x = xwide * ywide * 3 - 6; y >= 0; y--, x -= 6) {
		z = (bz[y] & 15) << 1;
		z = (pal[z + 1] << 8) | pal[z];
		bz[x + 2] = (z & 0x1F) << 3;
		bz[x + 1] = (z & 0x3E0) >> 2;
		bz[x] = (z & 0x7C00) >> 7;
		z = (bz[y] & 240) >> 3;
		z = (pal[z + 1] << 8) | pal[z];
		bz[x + 5] = (z & 0x1F) << 3;
		bz[x + 4] = (z & 0x3E0) >> 2;
		bz[x + 3] = (z & 0x7C00) >> 7;
	    }
	} else if (c == 256) {
	    for (y = xwide * ywide - 1, x = xwide * ywide * 3 - 3; y >= 0; y--, x -= 3) {
		z = bz[y] << 1;
		z = (pal[z + 1] << 8) | pal[z];
		bz[x + 2] = (z & 0x1F) << 3;
		bz[x + 1] = (z & 0x3E0) >> 2;
		bz[x] = (z & 0x7C00) >> 7;
	    }
	}
	for (w = y = z = 0; y < ywide; y++) {
	    for (x = 0; x < xwide; x++, z += 3) {
		s = x & 15;
		if (s == 0 || s == 3 || s == 5 || s == 8 || s == 10 || s == 13) {
		    bz[w] = (bz[z] + bz[z + 3]) >> 1;
		    bz[w + 1] = (bz[z + 1] + bz[z + 4]) >> 1;
		    bz[w + 2] = (bz[z + 2] + bz[z + 5]) >> 1;
		    w += 3;
		} else if (s == 2 || s == 7 || s == 12 || s == 15) {
		    memcpy(&bz[w], &bz[z], 3);
		    w += 3;
		}
	    }
	}
	z = xwide;
	xwide = (xwide * 5) >> 3;
	outbmp(fn, no);
	xwide = z;
    }
}

#ifdef OUTPUT_BMP
/*
 * OUTPUT BMP FILE 
 */
void outbmp8(char *fn, int no, int c)
{
    int i, sx, xpad;
    char fz[96];
    unsigned short k;
    FILE *fo;

    if (c == 16) {
	for (i = xwide * ywide - 1; i >= 0; i--)
	    bz[i] = ((bz[i] & 0xF0) >> 4) | ((bz[i] & 0x0F) << 4);
    }
    sprintf(fz, "%s%03x.bmp", fn, no);
    if ((fo = fopen(fz, "wb")) == 0) {
	printf("file create errror.[%s]\n", fz);
	exit(1);
    }
    sx = (c == 256) ? xwide : xwide / 2;
    xpad = (4 - (sx & 3)) & 3;
    fputc('B', fo);
    fputc('M', fo);		/* ID */
    writelong((long)c * 4L + 54L + (long)(sx + xpad) * (long)ywide, fo);	/* FILE SIZE */
    writelong(0L);		/* RESERVED */
    writelong((long)c * 4L + 54L, fo);	/* IMAGE OFFSET */
    writelong(40L, fo);		/* INFO SIZE */
    writelong((long)xwide, fo);	/* dx */
    writelong((long)ywide, fo);	/* dy */
    writeshort(1, fo);		/* PLAIN */
    if (c == 256)
	writeshort(8, fo);	/* DEPTH */
    else
	writeshort(4, fo);
    writelong(0L, fo);		/* COMPRESS TYPE */
    writelong(0L, fo);
    writelong(0L, fo);		/* x per meter */
    writelong(0L, fo);		/* y per meter */
    writelong((long)c, fo);	/* COLOR */
    writelong(0L, fo);
    for (i = 0; i < c; i++) {
	k = (pal[i * 2 + 1] << 8) | pal[i * 2];
	fputc((k & 0x7C00) >> 7, fo);	/* BLUE */
	fputc((k & 0x3E0) >> 2, fo);	/* GREEN */
	fputc((k & 0x1F) << 3, fo);	/* RED */
	fputc(0, fo);
    }
    for (i = ywide - 1; i >= 0; i--) {
	fwrite(&bz[i * sx], 1, sx, fo);
	for (k = 0; k < xpad; k++)
	    fputc(0, fo);
    }
    fclose(fo);
}

void outbmp(char *fn, int no)
{
    int x, y, xpad;
    char fz[96];
    FILE *fo;

    sprintf(fz, "%s%03x.bmp", fn, no);
    if ((fo = fopen(fz, "wb")) == 0) {
	printf("file create error![%s]\n", fz);
	exit(1);
    }
    xpad = (4 - ((xwide * 3) & 3)) & 3;
    fputc('B', fo);
    fputc('M', fo);		/* ID */
    writelong(54L + (long)xwide * (long)ywide * 3L + (long)xpad * (long)ywide, fo);	/* FILE SIZE */
    writelong(0L, fo);		/* RESERVED */
    writelong(54L, fo);		/* IMAGE OFFSET */
    writelong(40L, fo);		/* INFO SIZE */
    writelong((long)xwide, fo);	/* dx */
    writelong((long)ywide, fo);	/* dy */
    writeshort(1, fo);		/* PLAIN */
    writeshort(24, fo);		/* DEPTH */
    writelong(0L, fo);		/* COMPRESS TYPE */
    writelong(0L, fo);
    writelong(0L, fo);		/* x per meter */
    writelong(0L, fo);		/* y per meter */
    writelong(0L, fo);
    writelong(0L, fo);
    for (y = ywide - 1; y >= 0; y--) {
	fwrite(&bz[y * xwide * 3], 1, xwide * 3, fo);
	for (x = 0; x < xpad; x++)
	    fputc(0, fo);
    }
    fclose(fo);
}

/*
 * WRITE SHORT VALUE 
 */
void writeshort(short n, FILE * fo)
{
    fputc(n & 255, fo);
    fputc((n >> 8) & 255, fo);
}

/*
 * WRITE LONG VALUE 
 */
void writelong(long n, FILE * fo)
{
    fputc((int)(n & 255), fo);
    n /= 256L;
    fputc((int)(n & 255), fo);
    n /= 256L;
    fputc((int)(n & 255), fo);
    n /= 256L;
    fputc((int)(n & 255), fo);
}

#else

#if 0
void outbmp8(char *fn, int no, int c)
{
    int i, j;
    unsigned short k;
    int sx, xpad;
    char fz[96];
    unsigned char r[255], g[255], b[255];
    int idx1, idx2;
    FILE *fo;

    if (c == 16) {
	for (i = xwide * ywide - 1; i >= 0; i--)
	    bz[i] = ((bz[i] & 0xF0) >> 4) | ((bz[i] & 0x0F) << 4);
    }
    sprintf(fz, "%s%03x.ppm", fn, no);
    if ((fo = fopen(fz, "wb")) == 0) {
	printf("file create error![%s]\n", fz);
	exit(1);
    }
    sx = (c == 256) ? xwide : xwide / 2;
    xpad = (4 - (sx & 3)) & 3;

    /* palette */
    for (i = 0; i < c; i++) {
	k = (pal[i * 2 + 1] << 8) | pal[i * 2];
	b[i] = (k & 0x7C00) >> 7;	/* BLUE */
	g[i] = (k & 0x3E0) >> 2;	/* GREEN */
	r[i] = (k & 0x1F) << 3;	/* RED */
	/* printf("%02x %02x %02x\n", r[i], g[i], b[i]); */
    }

    fprintf(fo, "P6\n");
    fprintf(fo, "# CREATOR: To Heart for PS image decoder\n");
    fprintf(fo, "%d %d\n", xwide, ywide);
    printf("size: %d %d\n", xwide, ywide);
    fprintf(fo, "255\n");

    for (i = 0; i < ywide; i++) {
	for (j = 0; j < sx; j++) {
	    if (c == 16) {
		idx1 = (bz[i * sx + j] & 0xf0) >> 4;
		fputc(r[idx1], fo);
		fputc(g[idx1], fo);
		fputc(b[idx1], fo);

		idx2 = bz[i * sx + j] & 0xf;
		fputc(r[idx2], fo);
		fputc(g[idx2], fo);
		fputc(b[idx2], fo);
	    } else {
		idx1 = bz[i * sx + j];
		fputc(r[idx1], fo);
		fputc(g[idx1], fo);
		fputc(b[idx1], fo);
	    }
	}
    }
    fclose(fo);
}
#else
void outbmp8(char *fn, int no, int c)
{
    int i, j;
    unsigned short k;
    int sx, xpad;

    if (c == 16) {
	for (i = xwide * ywide - 1; i >= 0; i--)
	    bz[i] = ((bz[i] & 0xF0) >> 4) | ((bz[i] & 0x0F) << 4);
    }
    sx = (c == 256) ? xwide : xwide / 2;
    xpad = (4 - (sx & 3)) & 3;

    if (img.palette != NULL) free(img.palette);
    if (img.image != NULL) free(img.image);

    img.type = INDEXED;
    img.palette_size = c;
    img.palette = (int *)calloc(c * 3, sizeof(int));
    img.image = (int *)calloc(xwide * ywide, sizeof(int));
    img.width = xwide;
    img.height = ywide;

    /* palette */
    for (i = 0; i < c; i++) {
	k = (pal[i * 2 + 1] << 8) | pal[i * 2];
	img.palette[i * 3] = (k & 0x1F) << 3;
	img.palette[i * 3 + 1] = (k & 0x3E0) >> 2;
	img.palette[i * 3 + 2] = (k & 0x7C00) >> 7;
	/* printf("%02x %02x %02x\n", r[i], g[i], b[i]); */
    }

    for (i = 0; i < ywide; i++) {
	for (j = 0; j < sx; j++) {
	    if (c == 16) {
	      img.image[i * sx + j * 2] = (bz[i * sx + j] & 0xf0) >> 4;
	      img.image[i * sx + j * 2 + 1] = bz[i * sx + j] & 0xf;
	    } else {
	      img.image[i * sx + j] = bz[i * sx + j];
	    }
	}
    }
}
#endif

void outbmp(char *fn, int no)
{
    fprintf(stderr, "16bpp is not supported yet.\n");
    exit(1);
}

#endif
