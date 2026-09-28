/*
 * leafpak.h
 * written: 10/06/1997 by TF
 * last modified: 01/30/2000
*/

#ifndef ___INCLUDE_LEAFPAK_H
#define ___INCLUDE_LEAFPAK_H

#include <stdio.h>

#define KEY_LEN 11
#define FNAME_LEN 13

#define LVN 0
#define FANDISK 1
#define PSTH 2

typedef struct {
  FILE *fp;
  int archive_type; /* LVN, FANDISK or PSTH */
  int type; /* game title ID */
  int file_num;
  char **name;
  int *pos;
  int *len;
  int *nextpos;
  int key[KEY_LEN];

  /* mainly used by To Heart for PS */
  int archive_minor_type; /* PSTH has some variation */
  char *basename;		/* basename of archive file  */
  int size;			/* whole size of archive file */
  int *block;			/* when multiple images are in a data block */
  int *bid;			/* index in a block */
} LEAFPACK;

/* SHIZUKU for Windows95 */
#define SIZUWIN 0

/* KIZUATO for Windows95 */
#define KIZUWIN 1

/* To Heart */
#define TOHEART 2

/* Saorin to Issho!! */
#define SAORIN 3

/* Unknown type */
#define UNKNOWN -1

#ifdef MAIN
int key_const[][KEY_LEN] = {
  /* SHIZUKU (Windows95) */
  { 0x71, 0x48, 0x6a, 0x55, 0x9f, 0x13, 0x58, 0xf7, 0xd1, 0x7c, 0x3e },
  /* KIZUATO (Windows95) */
  { 0x71, 0x48, 0x6a, 0x55, 0x9f, 0x13, 0x58, 0xf7, 0xd1, 0x7c, 0x3e },
  /* To Heart */
  { 0xd1, 0x58, 0x6a, 0x56, 0x9a, 0x13, 0xa5, 0xf7, 0x7c, 0x3e, 0x74 },
};

#else
extern int key_const[][KEY_LEN];
#endif

#define LIST 0
#define EXTRACT 1

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

/* leafpak.c */
extern LEAFPACK *leafpack_open(const char *);
extern void leafpack_close(LEAFPACK *);
extern void leafpack_print_type(LEAFPACK *);
extern void leafpack_read_magic(LEAFPACK *, const char *, char *);
extern void print_table(LEAFPACK *, int);
extern int leafpack_extract_file(LEAFPACK *, const char *);
extern void leafpack_extract_all(LEAFPACK *);
extern unsigned char *leafpack_extract_file_to_data(LEAFPACK *, const char *, int *);

/* leafpak1.c */
extern int lp1_open(LEAFPACK *);
extern void lp1_read_magic(LEAFPACK *, const char *, char *);
extern void lp1_extract_table(LEAFPACK *);
extern void lp1_print_type(LEAFPACK *);
extern void lp1_print_table(LEAFPACK *, int);
extern void lp1_extract_all(LEAFPACK *);
extern int lp1_extract_file(LEAFPACK *, const char *);
extern unsigned char *lp1_extract_file_to_data(LEAFPACK *, const char *, int *);

/* leafpak2.c */
extern int lp2_open(LEAFPACK *);
extern void lp2_read_magic(LEAFPACK *, const char *, char *);
extern void lp2_extract_table(LEAFPACK *);
extern int lp2_extract_file(LEAFPACK *, const char *);
extern unsigned char *lp2_extract_file_to_data(LEAFPACK *, const char *, int *);

/* psth.c */
extern int lp3_open(LEAFPACK *);
extern int lp3_close(LEAFPACK *);
extern void lp3_extract_table(LEAFPACK *);
extern int lp3_extract_file(LEAFPACK *, const char *);
extern int lp3_check_magic(LEAFPACK *, const char *);
extern unsigned char *lp3_extract_file_to_data(LEAFPACK *, const char *, int *);

#endif
