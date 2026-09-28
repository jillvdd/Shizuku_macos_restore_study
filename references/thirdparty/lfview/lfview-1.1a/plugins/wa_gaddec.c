/*
 * wa_gad.c
 * decode GAD format images in the `White Album'.
 * 1998/06/17 by TF
 * 1999/05/08 updated
 * Special Thanks to KISAKA Toshihiro
 */
#include <stdio.h>
#include <stdlib.h>
#include "wa_gad.h"
#include "leaf_util.h"

#define RING_BUF_SIZ 0x800

static GAD *gad_new(void);
static int set_palette_from_data(GAD *, unsigned char *, int);
static void get_plain_palette(GAD *, unsigned char *, int, int);
static void get_compressed_palette(GAD *, unsigned char *, int, int);
static int extract_gad(GAD *, unsigned char *, int);
static void optimize_palette(GAD *);

GAD *read_gad(const char *filename)
{
  return NULL;
}

void gad_free(GAD *gad)
{
  int i;
  if (gad == NULL) {
    return;
  }

  for (i = 0; i < gad->num; i++) {
    free(gad->image[i]);
  }
  if (gad->image != NULL) {
    free(gad->image);
  }
  if (gad != NULL) {
    free(gad);
  }
}

GAD *read_gad_from_data(unsigned char *palette, int psize, unsigned char *body, int bsize)
{
  GAD *gad;

  gad = gad_new();
  if (set_palette_from_data(gad, palette, psize) < 0) {
    fprintf(stderr, "read_gad_from_data: Can't read palette.\n");
    gad_free(gad);
    return NULL;
  }
  if (extract_gad(gad, body, bsize) < 0) {
    fprintf(stderr, "read_gad_from_data: Can't decode body.\n");
    gad_free(gad);
    return NULL;
  }

  optimize_palette(gad);

  return gad;
}

static GAD *gad_new(void)
{
  int i;
  GAD *gad;

  gad = (GAD *)malloc(sizeof(GAD));
  if (gad == NULL) {
    fprintf(stderr, "gad_new: memory allocation error.\n");
    exit(1);
  }
  gad->width = 0;
  gad->height = 0;
  gad->color_num = 0;
  gad->num = 0;
  gad->transparent = -1;
  for (i = 0; i < 256; i++) {
    gad->palette[i][LF_R] = -1;
    gad->palette[i][LF_G] = -1;
    gad->palette[i][LF_B] = -1;
  }
  gad->image = NULL;
  return gad;
}

static int set_palette_from_data(GAD *gad, unsigned char *palette, int psize)
{
  if (palette[1] == 0) {
    /* plain palette */
    gad->color_num = palette[0];
    get_plain_palette(gad, palette, psize, 2);
#ifdef DEBUG
    fprintf(stderr, "  plain palette(size=%d)\n", gad->color_num);
#endif
  } else {
    /* compressed palette */
    get_compressed_palette(gad, palette, psize, 0);
#ifdef DEBUG
    fprintf(stderr, "  compressed palette(size=%d)\n", gad->color_num);
#endif
  }
  return 0;
}

static void get_plain_palette(GAD *gad, unsigned char *palette, int psize, int idx)
{
  int i, id;
  
  for (i = 0; i < gad->color_num; i++) {
    id = palette[idx++];    /* palette ID */
    /*
     * Does the palette order(B-G-R) differ with 'Saorin to issho(R-G-B)'?
     */
    gad->palette[id][LF_B] = palette[idx++];
    gad->palette[id][LF_G] = palette[idx++];
    gad->palette[id][LF_R] = palette[idx++];
  }
}

/*
 * This function may not be used in White Album.
 */
static void get_compressed_palette(GAD *gad, unsigned char *palette, int psize, int idx)
{
  int osize, esize;
  unsigned char *dst;
  int i;

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

  gad->color_num = dst[0];

  for (i = 2; i < esize; i += 4) {
    gad->palette[dst[i]][LF_B] = dst[i + 1];
    gad->palette[dst[i]][LF_G] = dst[i + 2];
    gad->palette[dst[i]][LF_R] = dst[i + 3];
#ifdef DEBUG
    printf("%02x: %02x, %02x, %02x\n",
       dst[i], dst[i + 1], dst[i + 2], dst[i + 3]);
#endif
  }
  free(dst);
}

static int extract_gad(GAD *gad, unsigned char *body, int bsize)
{
  unsigned char *tmp_image;
  int i, j;
  int size;

  gad->orig_size = LONGWORD(body[0], body[1], body[2], body[3]);
  gad->extracted_size = LONGWORD(body[4], body[5], body[6], body[7]);

  tmp_image = (unsigned char *)calloc(gad->extracted_size, sizeof(unsigned char));
  if (tmp_image == NULL) {
    perror("calloc");
    exit(1);
  }
  extract_lz77(body + 8, bsize - 8, tmp_image, gad->extracted_size, RING_BUF_SIZ);

  gad->num= LONGWORD(tmp_image[0], tmp_image[1], tmp_image[2], tmp_image[3]);
  fprintf(stderr, "%d images included\n", gad->num);
  gad->offset = (int *)malloc(gad->num * sizeof(int));
  gad->width = (int *)malloc(gad->num * sizeof(int));
  gad->height = (int *)malloc(gad->num * sizeof(int));
  gad->image = (int **)malloc(gad->num * sizeof(int *));
  
  for (i = 0; i < gad->num; i++) {
    j = (i + 1) * 4;
    gad->offset[i] = LONGWORD(tmp_image[j], tmp_image[j + 1], tmp_image[j + 2], tmp_image[j + 3]);
  }

  for (i = 0; i < gad->num; i++) {
    if (i == gad->num - 1) {
      size = gad->extracted_size - gad->offset[i];
    } else {
      size = gad->offset[i + 1] - gad->offset[i];
    }

    gad->width[i] = WORD(tmp_image[gad->offset[i]],  tmp_image[gad->offset[i] + 1]);
    gad->height[i] = WORD(tmp_image[gad->offset[i] + 2],  tmp_image[gad->offset[i] + 3]);
    gad->image[i] = (int *)malloc(gad->width[i] * gad->height[i] * sizeof(int));  
    for (j = 0; j < gad->width[i] * gad->height[i]; j++) {
      gad->image[i][j] = (int)tmp_image[gad->offset[i] + 4 + j];
    }
  }

  /* transparent specification may be embedded in the game's executable. */
  gad->transparent = gad->image[0][0];
  free(tmp_image);

  return 0;
}

static void optimize_palette(GAD *gad)
{
  int col[256];
  int idx[256];
  int i, j;

  /* Use the first image to optimize colormap. It may be harmful! */
  for (i = 0; i < 256; i++) col[i] = -1;

  for (i = 0; i < gad->num; i++) {
    for (j = 0; j < gad->width[i] * gad->height[i]; j++) {
      col[gad->image[i][j]] = 0;
    }
  }

  for (i = 0, j = 0; i < 255; i++) {
    if (col[i] == 0) {
      gad->palette[j][LF_R] = gad->palette[i][LF_R];
      gad->palette[j][LF_G] = gad->palette[i][LF_G];
      gad->palette[j][LF_B] = gad->palette[i][LF_B];
      idx[i] = j;
      j++;
    }
  }
  if (gad->transparent >= j) {
    if (j < 256) {
      gad->transparent = j;
      gad->color_num = j + 1;
    }  else {
      gad->transparent = 255;
    }
  } else {
    gad->transparent = idx[gad->transparent];
  }
  for (i = 0; i < gad->num; i++) {
    for (j = 0; j < gad->width[i] * gad->height[i]; j++) {
      if (gad->image[i][j] < 0) {
	gad->image[i][j] = idx[gad->image[i][0]];
      } else {
	gad->image[i][j] = idx[gad->image[i][j]];
      }
    }
  }
}
