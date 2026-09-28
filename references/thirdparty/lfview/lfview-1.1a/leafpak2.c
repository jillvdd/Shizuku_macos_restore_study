/*
 * leafpak2.c
 * 3/12/1998 by TF
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "leafpak.h"

static int get_longword(FILE *);
static void regularize_name(char *);

void lp2_read_magic(LEAFPACK *lp, const char *file, char *buf)
{
  int i = 0;
  char *dot;

  /* lookup table */
  while (i < lp->file_num) {
    if (!strcasecmp(file, lp->name[i])) {
      break;
    }
    i++;
  }
  
  if (i == lp->file_num) {
    fprintf(stderr, "%s isn't included in archive.\n", file);
    buf[0] = '\0';
    return;
  }

  dot = strchr(file, '.');
  if (!strcasecmp(dot, ".c16")) {
    strcpy(buf, "HAT_C16");
  } else if (!strcasecmp(dot, ".grp")) {
    strcpy(buf, "HAT_GRP");
  }
}

int lp2_open(LEAFPACK *lp)
{
  lp->file_num = get_longword(lp->fp);
  return 0;
}

void lp2_extract_table(LEAFPACK *lp)
{
  int i, j;

  for (i = 0; i < lp->file_num; i++) {
    for (j = 0; j < FNAME_LEN - 1; j++) {
      lp->name[i][j] = fgetc(lp->fp);
    }
    lp->name[i][FNAME_LEN - 1] = '\0';
    regularize_name(lp->name[i]);
    get_longword(lp->fp); /* unknown */
    lp->len[i] = get_longword(lp->fp);
    get_longword(lp->fp); /* unknown */
    lp->pos[i] = get_longword(lp->fp);
    lp->nextpos[i] = lp->pos[i] + lp->len[i];
  }
}

int lp2_extract_file(LEAFPACK *lp, const char *filename)
{
  int i = 0, j;
  FILE *fp;

  /* lookup table */
  while (i < lp->file_num) {
    if (!strcasecmp(filename, lp->name[i])) {
      break;
    }
    i++;
  }

  if (i == lp->file_num) {
    fprintf(stderr, "%s isn't included in this archive.\n", filename);
    return 1;
  }

  printf("extracting %s...", filename);
  fflush(stdout);

  fp = fopen(filename, "w");
  fseek(lp->fp, (long)lp->pos[i], SEEK_SET);

  for (j = 0; j < lp->len[i]; j++) {
    fputc(fgetc(lp->fp), fp);
  }

  fclose(fp);
  printf("done.\n");

  return 0;
}

unsigned char *lp2_extract_file_to_data(LEAFPACK *lp, const char *file, int *size)
{
  int i = 0;
  int pos;
  unsigned char *res;

  /* lookup table */
  while (i < lp->file_num) {
    if (!strcasecmp(file, lp->name[i])) {
      break;
    }
    i++;
  }

  if (i == lp->file_num) {
    fprintf(stderr, "%s isn't included in this archive.\n", file);
    return NULL;
  }

  *size = lp->len[i];

  printf("extracting %s...", file);
  fflush(stdout);

  res = (unsigned char *)calloc(lp->len[i], sizeof(unsigned char));
  pos = lp->pos[i];
  fseek(lp->fp, (long)pos, SEEK_SET);
  fread(res, *size, 1, lp->fp);

  printf("done.\n");

  return res;
}

/*
 * PRIVATE FUNCTION
 */
static int get_longword(FILE *fp)
{
  int b1, b2, b3, b4;

  b1 = fgetc(fp);
  b2 = fgetc(fp);
  b3 = fgetc(fp);
  b4 = fgetc(fp);

  return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
}

static void regularize_name(char *name)
{
  char buf[FNAME_LEN];
  int i = 0;
  
  strcpy(buf, name);
  while (buf[i] != 0) {
    name[i] = buf[i];
    i++;
  }
}
