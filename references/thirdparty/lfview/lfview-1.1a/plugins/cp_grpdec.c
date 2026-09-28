/*
 * cp_grp.c
 * decode GRP format images in the `Comic Party (Demo)'.
 * 1999/5/7 by TF
 */
#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include "cp_grp.h"
#include "leaf_util.h"

#define RING_BUF_SIZ 0x800

static GRP *grp_new(void);
static int set_palette_from_data(GRP *, unsigned char *, int);
static void get_plain_palette(GRP *, unsigned char *, int, int);
static void get_compressed_palette(GRP *, unsigned char *, int, int);
static int extract_image(GRP *, unsigned char *, int);
static void optimize_palette(GRP *);

static int pal_min;

GRP *read_cgrp(const char *filename)
{
  return NULL;
}

void cgrp_free(GRP *grp)
{
  if (grp == NULL) {
    return;
  }
  if (grp->image != NULL) {
    free(grp->image);
  }
  if (grp != NULL) {
    free(grp);
  }
}

GRP *read_cgrp_from_data(unsigned char *palette, int psize, unsigned char *body, int bsize)
{
  GRP *grp;

  grp = grp_new();
  pal_min = INT_MAX;

  if (set_palette_from_data(grp, palette, psize) < 0) {
    fprintf(stderr, "read_grp_from_data: Can't read palette.\n");
    grp_free(grp);
    return NULL;
  }
  if (extract_image(grp, body, bsize) < 0) {
    fprintf(stderr, "read_grp_from_data: Can't decode body.\n");
    grp_free(grp);
    return NULL;
  }

  optimize_palette(grp);

  return grp;
}

static GRP *grp_new(void)
{
  int i;
  GRP *grp;

  grp = (GRP *)malloc(sizeof(GRP));
  if (grp == NULL) {
    fprintf(stderr, "grp_new: memory allocation error.\n");
    exit(1);
  }
  grp->width = 0;
  grp->height = 0;
  grp->color_num = 0;
  grp->transparent = -1;
  /*
   * Caution: Unformatted items in array are referred.
   */
  for (i = 0; i < 256; i++) {
    grp->palette[i][GRP_R] = 0;
    grp->palette[i][GRP_G] = 0;
    grp->palette[i][GRP_B] = 0;
  }
  grp->image = NULL;
  return grp;
}

static int set_palette_from_data(GRP *grp, unsigned char *palette, int psize)
{
  if (palette[1] == 0) {
    /* plain palette */
    grp->color_num = palette[0];
    get_plain_palette(grp, palette, psize, 2);
#ifdef DEBUG
    fprintf(stderr, "  plain palette(size=%d)\n", grp->color_num);
#endif
  } else {
    /* compressed palette */
    get_compressed_palette(grp, palette, psize, 0);
#ifdef DEBUG
    fprintf(stderr, "  compressed palette(size=%d)\n", grp->color_num);
#endif
  }
  return 0;
}

static void get_plain_palette(GRP *grp, unsigned char *palette, int psize, int idx)
{
  int i, id;

  for (i = 0; i < grp->color_num; i++) {
    id = palette[idx++];    /* palette ID */
    if (id < pal_min) {
      pal_min = id;
    }

    grp->palette[id][GRP_B] = palette[idx++];
    grp->palette[id][GRP_G] = palette[idx++];
    grp->palette[id][GRP_R] = palette[idx++];
#ifdef DEBUG
    printf("%02x: %02x, %02x, %02x\n",
	   id, grp->palette[id][GRP_R], grp->palette[id][GRP_G], grp->palette[id][GRP_B]);
#endif
  }
}

/*
 * This function may not be used in Comic Party.
 */
static void get_compressed_palette(GRP *grp, unsigned char *palette, int psize, int idx)
{
  int osize, esize;
  unsigned char *dst;
  int i;

#ifdef DEBUG
  fprintf(stderr, "compressed palette\n");
#endif

  osize = LONGWORD(palette[idx], palette[idx + 1], palette[idx + 2], palette[idx + 3]);
  esize = LONGWORD(palette[idx + 4], palette[idx + 5], palette[idx + 6], palette[idx + 7]);

  if (osize != psize) {
    fprintf(stderr, "get_compressed_palette: Invalid header.\n");
  }
  dst = (unsigned char *)calloc(esize, sizeof(unsigned char));
  if (dst == NULL) {
    perror("calloc");
    exit(1);
  }

  extract_lz77(palette + 8, osize - 8, dst, esize, RING_BUF_SIZ);

  grp->color_num = dst[0];

  for (i = 2; i < esize; i += 4) {
    if (dst[i] < pal_min) {
      pal_min = dst[i];
    }
    grp->palette[dst[i]][GRP_B] = dst[i + 1];
    grp->palette[dst[i]][GRP_G] = dst[i + 2];
    grp->palette[dst[i]][GRP_R] = dst[i + 3];
#ifdef DEBUG
    printf("%02x: %02x, %02x, %02x\n",
       dst[i], dst[i + 1], dst[i + 2], dst[i + 3]);
#endif
  }
  free(dst);
}

static int extract_image(GRP *grp, unsigned char *body, int bsize)
{
  int i, j;
  int idx = 8;
  unsigned char *dst;

  grp->orig_size = LONGWORD(body[0], body[1], body[2], body[3]);
  grp->extracted_size = LONGWORD(body[4], body[5], body[6], body[7]);

#ifdef DEBUG  
  fprintf(stderr, "src size=%d(=%d), extracted size=%d\n", grp->orig_size, bsize,
	  grp->extracted_size);
#endif

  dst = (unsigned char *)calloc(grp->extracted_size, sizeof(unsigned char));
  if (dst == NULL) {
    perror("calloc");
    exit(1);
  }
  extract_lz77(body + 8, bsize - 8, dst, grp->extracted_size, RING_BUF_SIZ);

  /*
   * dst[0] - dst[4] specify the location of the image.
   *   X = WORD(dst[0], dst[1];
   *   Y = WORD(dst[2], dst[3];
   */
  grp->width = WORD(dst[4], dst[5]);
  grp->height = WORD(dst[6], dst[7]);
  grp->image = (int *)calloc(grp->width * grp->height, sizeof(int));
  if (grp->image == NULL) {
    perror("calloc");
    exit(1);
  }

  for (i = 0; i < grp->height; i++) {
    for (j = 0; j < grp->width; j++) {
      grp->image[i * grp->width + j] = dst[idx++];
      if (grp->image[i * grp->width + j] == 0) {
	/* sometimes, zeroes in the image aren't included the palette. */
	grp->image[i * grp->width + j] = pal_min;
      }
    }
  }
  free(dst);

  /* transparent specification may be embedded in the game's executable. */
  grp->transparent = grp->image[0];
  
  return 0;
}

static void optimize_palette(GRP *grp)
{
  int col[256];
  int idx[256];
  int i, j;

  for (i = 0; i < 256; i++) col[i] = -1;

  for (i = 0; i < grp->width * grp->height; i++) {
    col[grp->image[i]] = 0;
  }

  for (i = 0, j = 0; i < 255; i++) {
    if (col[i] == 0) {
      grp->palette[j][GRP_R] = grp->palette[i][GRP_R];
      grp->palette[j][GRP_G] = grp->palette[i][GRP_G];
      grp->palette[j][GRP_B] = grp->palette[i][GRP_B];
      idx[i] = j;
      j++;
    }
  }
  if (grp->transparent >= j) {
    if (j < 256) {
      grp->transparent = j;
      grp->color_num = j + 1;
    }  else {
      grp->transparent = 255;
    }
  } else {
    grp->transparent = idx[grp->transparent];
  }
  for (i = 0; i < grp->width * grp->height; i++) {
    if (grp->image[i] < 0) {
      grp->image[i] = idx[grp->image[0]];
    } else {
      grp->image[i] = idx[grp->image[i]];
    }
  }
}
