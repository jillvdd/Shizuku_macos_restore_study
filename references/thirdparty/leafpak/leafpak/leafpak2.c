/*
 * leafpak2.c
 * decode leaf archive file
 * 10/17/1997 by TF <tf@imou.to>
*/
/*
 * Changes:
 * 10/31/2000 TAKAHASHI Kaoru <kaoru@kaisei.org>
 *            Fixed a probrem when fopen(,"w") failed.
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FNAME_LEN 13

#define LIST 0
#define EXTRACT 1

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

typedef struct {
  FILE *fp;
  int file_num;
  char **name;
  int *position;
  int *length;
  int *unknown1;
  int *unknown2;
} LEAFPACK2;

LEAFPACK2 *leafpack2_init(const char *);
void leafpack2_close(LEAFPACK2 *);
void print_table(LEAFPACK2 *, int);
void leafpack2_extract_all(LEAFPACK2 *);
int leafpack2_extract_file(LEAFPACK2 *, const char *);

static void get_table(LEAFPACK2 *);
static int get_longword(FILE *);
static void usage_exit(void);
static void regularize_name(char *name);

int main(int argc, char *argv[])
{
  LEAFPACK2 *lp;
  int mode, verbose = FALSE;
  char *pak;
  int i;

  switch (argc) {
  case 1:
    /* no file or option is specified */
    usage_exit();
    break;
  case 2:
    /* filename or option is specified. */
    mode = LIST;
    pak = argv[1];
    break;
  default:
    /* option and archive file should be specified. */
    /* in this case, an 'x' option exract whole archive. */
    pak = argv[2];
    if (!strncmp(argv[1], "h", 1)) {
      usage_exit();
    } else if (!strncmp(argv[1], "v", 1)) {
      verbose = TRUE;
    } else if (!strncmp(argv[1], "l", 1)) {
      /* list mode has priority to extract mode */
      mode = LIST;
    } else if (!strncmp(argv[1], "e", 1) || !strncmp(argv[1], "x", 1)) {
      mode = EXTRACT;
    } else {
      /* bad option */
      usage_exit();
    }
  }

  lp = leafpack2_init(pak);
  if (lp == NULL) {
    fprintf(stderr, "Aborted.\n");
    exit(1);
  }

  get_table(lp);
  
  switch (mode) {
  case LIST:
    print_table(lp, verbose);
    break;
  case EXTRACT:
    if (argc == 3) {
      printf("Extract whole archive.\n");
      leafpack2_extract_all(lp);
    } else {
      for (i = 3; i < argc; i++) {
	leafpack2_extract_file(lp, argv[i]);
      }
    }
    break;
  default:
    /* sholud not reach here. */
    fprintf(stderr, "Unexpected error.\n");
    exit(1);
  }

  leafpack2_close(lp);
  return 0;
}

LEAFPACK2 *leafpack2_init(const char *filename)
{
  LEAFPACK2 *lp;

  lp = (LEAFPACK2 *)malloc(sizeof(LEAFPACK2));
  if (lp == NULL) {
    fprintf(stderr, "init_leafpack2: Memory allocation error.\n");
    return NULL;
  }
  
  lp->fp = fopen(filename, "r");
  if (lp->fp == NULL) {
    fprintf(stderr, "init_leafpack2: Can't open %s.\n", filename);
    return NULL;
  }

  return lp;
}

void leafpack2_close(LEAFPACK2 *lp)
{
  int i;

  if (lp == NULL) {
    return;
  }
  
  for (i = 0; i < lp->file_num; i++) {
    free(lp->name[i]);
  }
  free(lp->position);
  free(lp->length);
  free(lp->unknown1);
  free(lp->unknown2);
  
  free(lp);
}

void print_table(LEAFPACK2 *lp, int verbose)
{
  int i;

  if (lp == NULL) {
    fprintf(stderr, "print_table: no data.\n");
    return;
  }

  if (verbose == TRUE) {
    printf("Filename      Position    Size       ?1     ?2\n");
    printf("----------------------------------------------\n");
    for (i = 0; i < lp->file_num; i++) {
      printf("%12s  %08x %7d %7d %7d\n",
	     lp->name[i], lp->position[i], lp->length[i],
	     lp->unknown1[i], lp->unknown2[i]);
    }
  } else {
    printf("Filename      Position    Size\n");
    printf("------------------------------\n");
    for (i = 0; i < lp->file_num; i++) {
      printf("%12s  %08x %7d\n", lp->name[i], lp->position[i], lp->length[i]);
    }
  }

  printf("\n%d files in archive.\n", lp->file_num);
}

static void get_table(LEAFPACK2 *lp)
{
  int i, j;

  /* get how many files */
  lp->file_num = get_longword(lp->fp);

  /* allocate memory for a table */
  lp->name = (char **)calloc(lp->file_num, sizeof(char *));
  lp->position = (int *)calloc(lp->file_num, sizeof(int));
  lp->length = (int *)calloc(lp->file_num, sizeof(int));
  lp->unknown1 = (int *)calloc(lp->file_num, sizeof(int));
  lp->unknown2 = (int *)calloc(lp->file_num, sizeof(int));

  for (i = 0; i < lp->file_num; i++) {
    lp->name[i] = (char *)calloc(FNAME_LEN, sizeof(char));
  }

  for (i = 0; i < lp->file_num; i++) {
    for (j = 0; j < FNAME_LEN - 1; j++) {
      lp->name[i][j] = fgetc(lp->fp);
    }
    lp->name[i][FNAME_LEN - 1] = '\0';
    regularize_name(lp->name[i]);
    lp->unknown1[i] = get_longword(lp->fp);
    lp->length[i] = get_longword(lp->fp);
    lp->unknown2[i] = get_longword(lp->fp);
    lp->position[i] = get_longword(lp->fp);
  }

}

static int get_longword(FILE *fp)
{
  int b1, b2, b3, b4;

  b1 = fgetc(fp);
  b2 = fgetc(fp);
  b3 = fgetc(fp);
  b4 = fgetc(fp);

  return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
}

static void usage_exit(void)
{
  fprintf(stderr, "Usage: leafpak2 [ehlxv] archive [file1 file2 ...]");
  exit(1);
}

void leafpack2_extract_all(LEAFPACK2 *lp)
{
  int i, j;
  FILE *fp;

  for (i = 0; i < lp->file_num; i++) {
    printf("extracting %s...", lp->name[i]);
    fflush(stdout);
    
    fp = fopen(lp->name[i], "w");
    if (fp == NULL) {
      printf("Can't write %s\n",lp->name[i]);
    } else {
      fseek(lp->fp, (long)lp->position[i], SEEK_SET);
    
      for (j = 0; j < lp->length[i]; j++) {
	fputc(fgetc(lp->fp), fp);
      }
    
      fclose(fp);
      printf("done.\n");
    }
  }

#ifdef DEBUG
  if (fgetc(lp->fp) == EOF) {
    printf("reached the EOF\n");
  }
#endif
}

int leafpack2_extract_file(LEAFPACK2 *lp, const char *filename)
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
    printf("%s isn't included in this archive.\n", filename);
    return 1;
  }

  printf("extracting %s...", filename);
  fflush(stdout);

  fp = fopen(filename, "w");
  if (fp == NULL) {
    printf("Can't write %s.\n", filename);
    return 1;
  }
  fseek(lp->fp, (long)lp->position[i], SEEK_SET);

  for (j = 0; j < lp->length[i]; j++) {
    fputc(fgetc(lp->fp), fp);
  }

  fclose(fp);
  printf("done.\n");

  return 0;
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
