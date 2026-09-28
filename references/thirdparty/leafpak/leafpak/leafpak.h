/*
 * leafpak.h
 * 10/06/1997 by TF <tf@imou.to>
*/

#ifndef ___INCLUDE_LEAFPAK_H
#define ___INCLUDE_LEAFPAK_H

#define KEY_LEN 11

typedef struct {
  FILE *fp;
  int type;
  int file_num;
  char **name;
  int *pos;
  int *len;
  int *nextpos;
  int key[KEY_LEN];
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

extern LEAFPACK *leafpack_open(const char *);
extern void leafpack_close(LEAFPACK *);
extern void print_type(LEAFPACK *);
extern void leafpack_read_magic(LEAFPACK *, const char *, char *);
extern void print_table(LEAFPACK *, int);
extern int leafpack_extract_file(LEAFPACK *, const char *);
extern void extract_all(LEAFPACK *);
extern int *leafpack_extract_file_to_data(LEAFPACK *, const char *, int *);

#endif
