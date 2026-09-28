/*
 * LEAF Visual Novel System For X
 * (c) Copyright 1999 Go Watanabe mailto:go@denpa.org
 * All rights reserverd.
 *
 * ORIGINAL LVNS (c) Copyright 1996-1999 LEAF/AQUAPLUS Inc.
 *
 * $Id: lfpack.c,v 1.1 2002/07/29 05:24:38 go Exp $
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <sys/types.h>

/* 暗号化用キー */
typedef enum {
  SHIZUKU = 0,
  KIZUATO = 1,
  TOHEART = 2,
} KeyType;

#define KEY_LEN 11
int key[][KEY_LEN] = {
  /* SHIZUKU (Windows95) */
  { 0x71, 0x48, 0x6a, 0x55, 0x9f, 0x13, 0x58, 0xf7, 0xd1, 0x7c, 0x3e },
  /* KIZUATO (Windows95) */
  { 0x71, 0x48, 0x6a, 0x55, 0x9f, 0x13, 0x58, 0xf7, 0xd1, 0x7c, 0x3e },
  /* To Heart */
  { 0xd1, 0x58, 0x6a, 0x56, 0x9a, 0x13, 0xa5, 0xf7, 0x7c, 0x3e, 0x74 },
};

char lfinfo[500][24]; /* きめうち */

#define PUTWORD(a,fp) putc((a) & 0xff, fp); putc(((a) >> 8) & 0xff, fp)
#define SETLONG(a, p) *(p) = (a) & 0xff; *(p+1) = ((a) >> 8) & 0xff; *(p+2) = ((a) >> 16) & 0xff; *(p+3) = ((a) >> 24) & 0xff

int
main(int argc, char **argv)
{
  const char *usage = "usage: %s [-t type] archivename file [file ....]\n";
  KeyType keytype = TOHEART;

  int c;
  extern char *optarg;
  extern int optind;

  /* オプションの処理 */
  while ((c = getopt(argc, argv, "t:")) != -1) {
	switch (c) {
	case 't':
	  keytype = atoi(optarg);
	  if (keytype > TOHEART) {
          fprintf(stderr, "bad type\n");
		exit(1);
	  }
	  break;
	default:
	  fprintf(stderr, usage, argv[0]);
	  exit(1);
	}
  }
  
  /* 引数チェック */
  if (optind + 2 > argc) {
	fprintf(stderr, usage, argv[0]);
	exit(1);
  }  

  /* 本体生成 */
  {
	int num, i;
	long pos = 0;
	FILE *fp;

	if ((fp = fopen(argv[optind], "w")) == NULL) {
	  perror(argv[optind]);
	  exit(1);
	}
	optind++;
	
	num = argc - optind;

	/* MAGIC CODE */
	putc('L', fp);
	putc('E', fp);
	putc('A', fp);
	putc('F', fp);
	putc('P', fp);
	putc('A', fp);
	putc('C', fp);
	putc('K', fp);

	/* ファイル個数 */
	PUTWORD(num, fp);
	pos = 10;	       /* MAGIC NUMBER !! */

	/* ファイル出力 */
	for (i=0; i<num;i++) {
	  FILE *in;
	  int len;
	  const u_char *filename = argv[optind++];

	  if ((in = fopen(filename, "r")) == NULL) {
		perror(filename);	
		exit(1);
	  }


      fprintf(stderr, "%s\n", filename);
	  /* 名前の正規化 */
      memset(lfinfo[i], ' ', 11);
      lfinfo[11] == '\0';
	  {
		const u_char *p = filename;
		int len = 0;
		while (*p != '.' && len < 8) {
		  if (!*p)
			break;
		  lfinfo[i][len++] = *p++;
		}	
		/* 拡張子の処理 */
		if ((p = strrchr(filename, '.'))) {
		  p++;
		  len = 0;
		  while (*p && len < 3) {
			lfinfo[i][8 + len++] = *p++;
		  }		
		}
	  }

	  /* ヘッダに位置情報格納 */
	  SETLONG(pos, lfinfo[i] + 12);

	  fprintf(stderr, "%11.11s\n", lfinfo[i]);
	  /* ファイルコピー */
	  len = 0;
	  {
		int k = 0;
		int c;
		while ((c = getc(in)) != EOF) {
		  putc((c + key[keytype][k]) & 0xff, fp);  /* 簡易暗号化 */
		  k = (++k) % KEY_LEN;
		  pos++; len++;
		}
		if (ferror(in)) {
		  perror(filename);
		  exit(1);
		}
	  }
	  
	  /* ヘッダにサイズ情報格納 */
	  SETLONG(len, lfinfo[i] + 16);
	  SETLONG(pos, lfinfo[i] + 20);
	  fclose(in);
	}

	/* ヘッダ出力 */
	{
	  int k=0;

	  for (i=0; i<KEY_LEN;i++)
		fprintf(stderr, "%x ", key[keytype][i]);
	  fprintf(stderr, "\n");


	  for (i=0; i<num;i++) {
		int j;
		for (j=0; j<24; j++) {
		  putc((lfinfo[i][j] + key[keytype][k]) & 0xff, fp); /* 簡易暗号化 */
		  k = (++k) % KEY_LEN;
		}
	  }
	}
  }
}
