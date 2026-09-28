/*
 * dummy plugin for To Heart for Playstation
 * 01/30/2000 by FUJIWARA Teruyoshi
 */

#include <stdio.h>
#include <string.h>

#include "psth.h"

PSTH_IMG *read_psth(char *filename) {
  return NULL;
}

static PSTH_IMG *init_psth(void)
{
  PSTH_IMG *psth;

  psth = (PSTH_IMG *)malloc(sizeof(PSTH_IMG));
  if (psth == NULL) {
    fprintf(stderr, "init_psth: can't alloc memory\n");
    exit(1);
  }

  psth->type = UNKNOWN;
  psth->width = 0;
  psth->height = 0;
  psth->palette_size = 0;
  psth->palette = NULL;
  psth->image = NULL;
}

PSTH_IMG *read_psth_from_data(unsigned char *data, int size) {
  int *d;
  PSTH_IMG *psth;

  d = (int *)data;
  psth = init_psth();

  if (d[0] != 0x5053 || d[1] != 0x5448) {
    fprintf(stderr, "This file isn't To Heart(PS) format.\n");
    free_psth(psth);
    return NULL;
  }

  psth->type = d[2];
  psth->width = d[3];
  psth->height = d[4];
  psth->palette_size = d[5];
  psth->palette = (int *)calloc(3 * psth->palette_size, sizeof(int));
  psth->image = (int *)calloc(psth->width * psth->height, sizeof(int));
  if(psth->palette == NULL || psth->image == NULL) {
    fprintf(stderr, "read_psth_from_data: can't alloc memory\n");
    exit(1);
  }
  memcpy(psth->palette, &d[6], sizeof(int) * 3 * psth->palette_size);
  memcpy(psth->image, &d[6 + 3 * psth->palette_size],
	 sizeof(int) * psth->width * psth->height);

  return psth;
}

void free_psth(PSTH_IMG *psth)
{
  if (psth->palette != NULL) free(psth->palette);
  if (psth->image != NULL) free(psth->image);
  if (psth != NULL) free(psth);
}
