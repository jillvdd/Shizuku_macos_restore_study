/*
 * leafpak.c
 * decode LEAF archive files.
 * 3/12/1998 by TF
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "leafpak.h"

static void check_magic(LEAFPACK *);
static void alloc_leafpack(LEAFPACK *);

/*
 * Open an archive file and extact its file table.
 */
LEAFPACK *leafpack_open(const char *filename)
{
  LEAFPACK *lp = NULL;
  
  lp = (LEAFPACK *)malloc(sizeof(LEAFPACK));
  if (lp == NULL) {
    fprintf(stderr, "leafpack_open: Memory allocation error.\n");
    return NULL;
  }
  
  lp->fp = fopen(filename, "r");
  if (lp->fp == NULL) {
    fprintf(stderr, "leafpack_open: Can't open %s\n", filename);
    return NULL;
  }
  
  check_magic(lp);

  switch (lp->archive_type) {
  case LVN:
    lp1_open(lp);
    alloc_leafpack(lp);
    lp1_extract_table(lp);
    break;
  case FANDISK:
    lp2_open(lp);
    alloc_leafpack(lp);
    lp2_extract_table(lp);
    break;
  case PSTH:
    lp->basename = strdup(filename);
    lp3_open(lp);
    lp3_extract_table(lp);
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "leafpack_open: unexpected error.\n");
    exit(1);
  }
  
  return lp;
}

/*
 * Get a magic included in a file in an archive.
 */
void leafpack_read_magic(LEAFPACK *lp, const char *file, char *buf)
{
  switch (lp->archive_type) {
  case LVN:
    lp1_read_magic(lp, file, buf);
    break;
  case FANDISK:
    lp2_read_magic(lp, file, buf);
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "leafpack_read_magic: unexpected error.\n");
    exit(1);
  }
}

int leafpack_extract_file(LEAFPACK *lp, const char *file)
{
  int result;

  switch (lp->archive_type) {
  case LVN:
    result = lp1_extract_file(lp, file);
    break;
  case FANDISK:
    result = lp2_extract_file(lp, file);
    break;
  case PSTH:
    result = lp3_extract_file(lp, file);
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "leafpack_read_magic: unexpected error.\n");
    exit(1);
  }

  return result;
}

unsigned char *leafpack_extract_file_to_data(LEAFPACK *lp, const char *file, int *size)
{
  unsigned char *result;

  switch (lp->archive_type) {
  case LVN:
    result = lp1_extract_file_to_data(lp, file, size);
    break;
  case FANDISK:
    result = lp2_extract_file_to_data(lp, file, size);
    break;
  case PSTH:
    result = lp3_extract_file_to_data(lp, file, size);
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "leafpack_read_magic: unexpected error.\n");
    exit(1);
  }

  return result;
}

void leafpack_extract_all(LEAFPACK *lp)
{
  switch (lp->archive_type) {
  case LVN:
    lp1_extract_all(lp);
    break;
  case FANDISK:
    /* lp2_extract_all(lp); */
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "leafpack_extract_all: unexpected error.\n");
    exit(1);
  }
}

/*
 * PRIVATE FUNCTIONS
*/
static void alloc_leafpack(LEAFPACK *lp)
{
  int i;

  /* initialize a filename table */
  lp->name = (char **)calloc(lp->file_num, sizeof(char *));
  for (i = 0; i < lp->file_num; i++) {
    lp->name[i] = (char *)calloc(FNAME_LEN, sizeof(char));
  }

  /* initialize table entories */
  lp->pos = (int *)calloc(lp->file_num, sizeof(int));
  lp->len = (int *)calloc(lp->file_num, sizeof(int));
  lp->nextpos = (int *)calloc(lp->file_num, sizeof(int));
}

static void check_magic(LEAFPACK *lp)
{
  char buf[9];
  
  fread(buf, 1, 8, lp->fp);
  buf[8] = '\0';

  if (!strcmp(buf, "LEAFPACK")) {
    fprintf(stderr, "This file is a visual novel archive.\n");
    lp->archive_type = LVN;
  } else if (lp3_check_magic(lp, buf)) {
    fprintf(stderr, "This file is a To Heart for PS's archive.\n");
    fseek(lp->fp, 0L, SEEK_SET);
    lp->archive_type = PSTH;
  } else {
    fprintf(stderr, "This file may be a fan disk archive.\n");
    fseek(lp->fp, 0L, SEEK_SET);
    lp->archive_type = FANDISK;
  }
}

/*
 * Free allocated memories and close file.
 */
void leafpack_close(LEAFPACK *lp)
{
  int i;

  if (lp->fp != NULL) {
    fclose(lp->fp);
  }
  lp->fp = NULL;

  for (i = 0; i < lp->file_num; i++) {
    free(lp->name[i]);
  }
  
  free(lp->name);
  free(lp->pos);
  free(lp->len);
  free(lp->nextpos);
  free(lp);
}

void leafpack_print_type(LEAFPACK *lp)
{
  switch (lp->archive_type) {
  case LVN:
    lp1_print_type(lp);
    break;
  case FANDISK:
    /* lp2_print_type(lp); */
    break;
  case PSTH:
    /* lp3_print_type(lp); */
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "print_type: unexpected error.\n");
    exit(1);
  }
}

void leafpack_print_table(LEAFPACK *lp, int verbose)
{
  switch (lp->archive_type) {
  case LVN:
    lp1_print_table(lp, verbose);
    break;
  case FANDISK:
    /* lp2_print_table(lp, verbose); */
    break;
  case PSTH:
    /* lp3_print_table(lp, verbose); */
    break;
  default:
    /* should not reach here. */
    fprintf(stderr, "print_type: unexpected error.\n");
    exit(1);
  }
}
