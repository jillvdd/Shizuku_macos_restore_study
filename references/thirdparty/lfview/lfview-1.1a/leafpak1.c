/*
 * leafpak.c
 * decode leaf archive file.
 * 10/06/1997 by TF
 */
/*
 * Changes:
 *  3/12/1998 generalize to support the fandisk format.
 * 10/17/1997 Add auto key calculation.
 *            Support maxxdata.pak in 'Saorin to Issho!!'
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "leafpak.h"

static int lp1_get_file_num(FILE *);
static void lp1_set_type(LEAFPACK *);
static void lp1_regularize_name(char *);
static void lp1_guess_key(LEAFPACK *);

#ifdef DEBUG
static void lp1_verify_key(LEAFPACK *);
#endif

/*
 * Open a leafpak(type1) archive.
 */
int lp1_open(LEAFPACK *lp)
{
  lp->file_num = lp1_get_file_num(lp->fp);
  lp1_set_type(lp);
  
  if (lp->type == UNKNOWN) {
    lp1_guess_key(lp);
  }

  return 0;
}

/*
 * Extract all archive into current directory. Archive file
 * shuold already be opend.
 */
void lp1_extract_all(LEAFPACK *lp)
{
  int i, k;
  int val, pos;
  FILE *fp;

  for (i = 0; i < lp->file_num; i++) {
    fp = fopen(lp->name[i], "w");
    printf("extracting %s...", lp->name[i]);
    fflush(stdout);

    pos = lp->pos[i];
    fseek(lp->fp, (long)pos, SEEK_SET);
    k = 0;
    while (pos != lp->nextpos[i]) {
      val = (fgetc(lp->fp) - lp->key[k]) & 0xff;
      k = (++k) % KEY_LEN; 
      fputc(val, fp);
      pos++;
    }
    fclose(fp);
    printf("done.\n");
  }
  printf("\nAll files are extracted.\n");
}

/*
 * Extract a file specified by name from archive. Archive file
 * shuold already be opened.
 */
int lp1_extract_file(LEAFPACK *lp, const char *file)
{
  int i = 0, k = 0;
  int val, pos;
  FILE *fp;

  /* lookup table */
  while (i < lp->file_num) {
    if (!strcasecmp(file, lp->name[i])) {
      break;
    }
    i++;
  }
  
  if (i == lp->file_num) {
    fprintf(stderr, "%s isn't included in this archive.\n", file);
    return 1;
  }

  printf("extracting %s...", file);
  fflush(stdout);

  fp = fopen(file, "w");
  pos = lp->pos[i];
  fseek(lp->fp, (long)pos, SEEK_SET);
  while (pos != lp->nextpos[i]) {
    val = (fgetc(lp->fp) - lp->key[k]) & 0xff;
    k = (++k) % KEY_LEN; 
    fputc(val, fp);
    pos++;
  }
  fclose(fp);
  printf("done.\n");

  return 0;
}

/*
 * a char array 'buf' should have size more than 9.
*/
void lp1_read_magic(LEAFPACK *lp, const char *file, char *buf)
{
  int i = 0;
  int pos;

  /* lookup table */
  while (i < lp->file_num) {
    if (!strcasecmp(file, lp->name[i])) {
      break;
    }
    i++;
  }
  
  if (i == lp->file_num) {
    printf("%s isn't included in archive.\n", file);
    buf[0] = '\0';
    return;
  }

  pos = lp->pos[i];
  fseek(lp->fp, (long)pos, SEEK_SET);
  for (i = 0; i < 8; i++) {
    buf[i] = (fgetc(lp->fp) - lp->key[i]) & 0xff; 
  }
  buf[8] =  '\0';

  return;
}

unsigned char *lp1_extract_file_to_data(LEAFPACK *lp, const char *file, int *size)
{
  int i = 0, j = 0, k = 0;
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
    fprintf(stderr, "%s isn't included in archive.\n", file);
    return NULL;
  }

  *size = lp->len[i];

  printf("extracting %s...", file);
  fflush(stdout);

  res = (unsigned char *)calloc(lp->len[i], sizeof(unsigned char));
  pos = lp->pos[i];
  fseek(lp->fp, (long)pos, SEEK_SET);
  while (pos != lp->nextpos[i]) {
    res[j] = (fgetc(lp->fp) - lp->key[k]) & 0xff;
    k = (++k) % KEY_LEN; 
    pos++;
    j++;
  }
  printf("done.\n");

  return res;
}

/*
 * PRIVATE FUNCTIONS
*/
static int lp1_get_file_num(FILE *fp)
{
  int u, l;
  
  l = fgetc(fp);
  u = fgetc(fp);

  return u << 8 | l;
}

/*
 * Type is set by the number of files included in an archive file.
 * (And this type is used to select an encryption key!)
 * Then we can't extract an unkown archive.
 */
/*
 * 10/16/1997: Add auto key calculation feature(experimental).
 */
static void lp1_set_type(LEAFPACK *lp)
{
  lp1_guess_key(lp);

  if (lp->file_num == 0x0248 || lp->file_num == 0x03e1) {
    lp->type = TOHEART;
    return;
  } else if (lp->file_num == 0x01fb) {
    lp->type = KIZUWIN;
    return;
  } else if (lp->file_num == 0x0193) {
    lp->type = SIZUWIN;
    return;
  } else if (lp->file_num == 0x0072) {
    lp->type = SAORIN;
  } else {
    lp->type = UNKNOWN;
  }
  
#ifdef DEBUG
  lp1_verify_key(lp);
#endif
}

#ifdef DEBUG
static void lp1_verify_key(LEAFPACK *lp)
{
  int i;
  int result = TRUE;

  if (lp->type == UNKNOWN || lp->type == SAORIN) {
    return;
  }

  for (i = 0; i < KEY_LEN; i++) {
    if (key_const[lp->type][i] != lp->key[i]) {
      fprintf(stderr, "Warning: An auto-calculated key is bad.\n");
      result = FALSE;
      break;
    }
  }

  if (result == FALSE) {
    for (i = 0; i < KEY_LEN; i++) {
      lp->key[i] = key_const[lp->type][i];
    }
  }
}
#endif

void lp1_extract_table(LEAFPACK *lp)
{
  int i, j;
  int k = 0;
  int b[4];

  /* set a position to the head of the header part */
  fseek(lp->fp, (long)(-24 * lp->file_num), SEEK_END);

  for (i = 0; i < lp->file_num; i++) {
    /* get filename */
    for (j = 0; j < 12; j++) {
      lp->name[i][j] = (fgetc(lp->fp) - lp->key[k]) & 0xff;
      k = (++k) % KEY_LEN; 
    }
    lp1_regularize_name(lp->name[i]);

    /* a position in the archive file */
    for (j = 0; j < 4; j++) {
      b[j] = (fgetc(lp->fp) - lp->key[k]) & 0xff;
      k = (++k) % KEY_LEN; 
    }
    lp->pos[i] = (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];

    /* file length */
    for (j = 0; j < 4; j++) {
      b[j] = (fgetc(lp->fp) - lp->key[k]) & 0xff;
      k = (++k) % KEY_LEN; 
    }
    lp->len[i] = (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
    
    /* the head of the next file */
    for (j = 0; j < 4; j++) {
      b[j] = (fgetc(lp->fp) - lp->key[k]) & 0xff;
      k = (++k) % KEY_LEN; 
    }
    lp->nextpos[i] = (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
  }
}

static void lp1_regularize_name(char *name)
{
  char buf[12];
  int i = 0;

  strcpy(buf, name);
  while (i < 8 && buf[i] != 0x20) {
    name[i] = buf[i];
    i++;
  }

  name[i++] = '.';

  /* file extention */
  name[i++] = buf[8];
  name[i++] = buf[9];
  name[i++] = buf[10];

  name[i] = '\0';
}

void lp1_print_type(LEAFPACK *lp)
{
  printf("Archive file: ");

  switch (lp->type) {
  case SIZUWIN:
    printf("SHIZUKU for Windows95\n\n");
    break;
  case KIZUWIN:
    printf("KIZUATO for Windows95\n\n");
    break;
  case TOHEART:
    printf("To Heart\n\n");
    break;
  case SAORIN:
    printf("Saorin to Issho!! (maxxdata.pak)\n\n");
    break;
  default:
    printf("Unknown\n\n");
  }
}

void lp1_print_table(LEAFPACK *lp, int verbose)
{
  int i;

  if (verbose == TRUE) {
    printf("Key: ");
    for (i = 0; i < KEY_LEN; i++) {
      printf("%02x ", lp->key[i]);
    }
    printf("\n\n");
  }
  
  if (verbose == TRUE) {  
    printf("Filename      Position  Length   Next\n");
    printf("------------  --------  -------  --------\n");
  } else {
    printf("Filename       Length\n");
    printf("------------   -------\n");
  }
  for (i = 0; i < lp->file_num; i++) {
    printf("%12s  ", lp->name[i]);
    if (verbose == TRUE) {
      printf("%08x ", lp->pos[i]);
    }
    printf("%8d  ", lp->len[i]);
    if (verbose == TRUE) {
      printf("%08x", lp->nextpos[i]);
    }
    printf("\n");
  }
  printf("%d files.\n", lp->file_num);
}

/*
 * Calculate key using length of archive data.
 * To use this function, the archive must include at least 3 files.
 */
static void lp1_guess_key(LEAFPACK *lp)
{
  int buf[72];
  int i;

  /* find the top of table */
  fseek(lp->fp, (long)(-24 * lp->file_num), SEEK_END);

  /* read 3 table entries, needed to calculate keys. */
  for (i = 0; i < 72; i++) {
    buf[i] = fgetc(lp->fp);
  }
  
  /* zero */
  lp->key[0] = buf[11];
  
  /* 1st position, (maybe :-)) constant */
  lp->key[1] = (buf[12] - 0x0a) & 0xff;
  lp->key[2] = buf[13];
  lp->key[3] = buf[14];
  lp->key[4] = buf[15];

  /* 2nd position, from 1st next position */
  lp->key[5] = (buf[38] -  buf[22] + lp->key[0]) & 0xff;
  lp->key[6] = (buf[39] -  buf[23] + lp->key[1]) & 0xff;
  
  /* 3rd position, from 2nd next position */
  lp->key[7] = (buf[62] - buf[46] + lp->key[2]) & 0xff;
  lp->key[8] = (buf[63] - buf[47] + lp->key[3]) & 0xff;

  /* 1st next position, from 2nd position */
  lp->key[9] = (buf[20] - buf[36] + lp->key[3]) & 0xff;
  lp->key[10] = (buf[21] - buf[37] + lp->key[4]) & 0xff;
}
/* end of file */
