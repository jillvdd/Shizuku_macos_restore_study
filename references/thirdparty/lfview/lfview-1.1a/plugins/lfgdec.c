/*
 * lfgdec.c
 * Decode LEAF LFG format.
 * 09/21/1997 by TF
 */
/* Changes
 * 10/07/1997: add '*_from_data' functions. These functions are
 *             used with leafpak.[hc] codes.
 */
#include <stdio.h>
#include <stdlib.h>

#include "lfg.h"

static LFG* new_lfg(void);
static int read_magic(FILE *);
static void read_palette(FILE *, LFG *);
static void read_palette_from_data(unsigned char *, int, LFG *);
static void read_size(FILE *, LFG *);
static void read_type(FILE *, LFG *);
static void read_transparent(FILE *, LFG *);
static void skip_padding(FILE *, int);
static void read_image_size(FILE *, LFG *);
static void extract_body(FILE *, LFG *);
static void extract_body_from_data(unsigned char *, int, LFG *);
static void convert_indexed_image(LFG *);

LFG *read_lfg(FILE *fp)
{
  LFG *lfg;

  lfg = new_lfg();
  
  if (read_magic(fp) < 0) {
    free_lfg(lfg);
    return NULL;
  }
  read_palette(fp, lfg);
  read_size(fp, lfg);
  read_type(fp, lfg);
  read_transparent(fp, lfg);
  skip_padding(fp, PADDING_LENGTH);
  read_image_size(fp, lfg);
  
  extract_body(fp, lfg);
  
  convert_indexed_image(lfg);
  
  return lfg;
}

LFG *read_lfg_from_data(unsigned char *data, int size)
{
  LFG *lfg;

  lfg = new_lfg();

  /* check magic number 'LEAFCODE' */
  if (data[0] != 0x4c || data[1] != 0x45 || data[2] != 0x41 ||
      data[3] != 0x46 || data[4] != 0x43 || data[5] != 0x4f ||
      data[6] != 0x44 || data[7] != 0x45) {
    fprintf(stderr, "This file isn't LFG format.\n");
    free_lfg(lfg);
    return NULL;
  }
      
  read_palette_from_data(data, 8, lfg);
  
  /* image size */
  lfg->xoffset = (data[33] << 8 | data[32]) * 8;
  lfg->yoffset = data[35] << 8 | data[34];
  lfg->width = ((data[37] << 8 | data[36]) + 1) * 8;
  lfg->height = (data[39] << 8 | data[38]) + 1;

  /* image type */
  if (data[40] == 0) {
    lfg->direction = VERTICAL;
  } else {
    lfg->direction = HORIZONTAL;
  }

  /* transparent color */
  lfg->transparent = data[41];

  /* data[42], data[43] is padding */

  /* data size after extracting */
  lfg->size = data[44] | (data[45] << 8) | (data[46] << 16) | (data[47] << 24);

  extract_body_from_data(data, 48, lfg);
  
  convert_indexed_image(lfg);

  return lfg;
}

void free_lfg(LFG *lfg)
{
  if (lfg == NULL) {
    fprintf(stderr, "free_lfg: Warning; NULL LFG file.\n");
    return;
  }
  if (lfg->body != NULL) {
    free(lfg->body);
  }
  if (lfg->image != NULL) {
    free(lfg->image);
  }
  free(lfg);
}

/*
 * Memory allocation adnd initialization for LFG struct.
 */
static LFG* new_lfg(void)
{
  LFG *lfg;
  
  lfg = (LFG *)malloc(sizeof(LFG));
  if (lfg == NULL) {
    fprintf(stderr, "read_lfg: Can't allocate memory.\n");
    exit(1);
  }
  lfg->body = NULL;
  lfg->image = NULL;
  
  return lfg;
}

/*
 * Check if this is LFG file.
 */
static int read_magic(FILE *fp)
{
  char buf[9];
  int i;

  for (i = 0; i < 8; i++) {
    buf[i] = fgetc(fp);
  }
  buf[8] = '\0';
  
  if (strcmp("LEAFCODE", buf)) {
    fprintf(stderr, "This file isn't LFG format.\n");
    return -1;
  }
  return 0;
}

static void read_palette(FILE *fp, LFG *lfg)
{
  int i, j = 0, rgb = R;
  int c, upper, lower;
  
  for (i = 0; i < 24; i++) {
    c = fgetc(fp);
    upper = (c & 0xf0) >> 4;
    lower = c & 0xf;

    /* upper byte */
    lfg->palette[j][rgb] = (upper << 4) | upper;
    rgb = (rgb + 1) % 3;
    if (rgb == 0) {
      j++;
    }

    /* lower byte */
    lfg->palette[j][rgb] = (lower << 4) | lower;
    rgb = (rgb + 1) % 3;
    if (rgb == 0) {
      j++;
    }
  }

#ifdef DEBUG
  for (i = 0; i < 16; i++) {
    fprintf(stderr, "%02d: %02x %02x %02x\n", i,
	   lfg->palette[i][R],
	   lfg->palette[i][G],
	   lfg->palette[i][B]);
  }
#endif
}

static void read_palette_from_data(unsigned char *data, int pos, LFG *lfg)
{
  int i, j = 0, rgb = R;
  int upper, lower;
  
  for (i = 0; i < 24; i++) {
    upper = (data[pos] & 0xf0) >> 4;
    lower = data[pos] & 0xf;
    pos++;

    /* upper byte */
    lfg->palette[j][rgb] = (upper << 4) | upper;
    rgb = (rgb + 1) % 3;
    if (rgb == 0) {
      j++;
    }

    /* lower byte */
    lfg->palette[j][rgb] = (lower << 4) | lower;
    rgb = (rgb + 1) % 3;
    if (rgb == 0) {
      j++;
    }
  }
}

static void read_size(FILE *fp, LFG *lfg)
{
  int upper, lower;

  /* x offset */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lfg->xoffset = (lower << 8 | upper) * 8;

  /* y offset */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lfg->yoffset = lower << 8 | upper;

  /* width */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lfg->width = ((lower << 8 | upper) + 1) * 8;

  /* height */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lfg->height = (lower << 8 | upper) + 1;

#ifdef DEBUG
  fprintf(stderr, "size: %d x %d +%d +%d\n",
	 lfg->width, lfg->height, lfg->xoffset, lfg->yoffset);
#endif
}

/*
 * the direction pixels are tiled has two types,
 * vertical(per 2 pixels) or horizontal.
 */
static void read_type(FILE *fp, LFG *lfg)
{
  if (fgetc(fp) == 0) {
    lfg->direction = VERTICAL;
  } else {
    lfg->direction = HORIZONTAL;
  }

#ifdef DEBUG
  if (lfg->direction == VERTICAL) {
    fprintf(stderr, "Direction: vertical\n");
  } else {
    fprintf(stderr, "Direction: horizontal\n");
  }
#endif
}

static void read_transparent(FILE *fp, LFG *lfg)
{
  lfg->transparent = fgetc(fp);
  if (lfg->transparent == 0xff) {
    /* Transparent color isn't used */
#ifdef DEBUG
    fprintf(stderr, "Transparent color isn't used.\n");
#endif
  } else if (lfg->transparent < 0 || lfg->transparent > 15) {
    fprintf(stderr, "palette number of transparent color is invalid.\n");
    exit(1);
  }
}

static void skip_padding(FILE *fp, int length)
{
  int i;

  for (i = 0; i < length; i++) {
    fgetc(fp);
  }
  return;
}

/*
 * Read the data size after extraction.
 */
static void read_image_size(FILE *fp, LFG *lfg)
{
  int a, b, c, d;
  
  a = fgetc(fp);
  b = fgetc(fp);
  c = fgetc(fp);
  d = fgetc(fp);
  
  lfg->size = a | (b << 8) | (c << 16) | (d << 24);

#ifdef DEBUG
  fprintf(stderr, "data size: %d\n", lfg->size);
#endif  
}

static void extract_body(FILE *fp, LFG *lfg)
{
  int ring[0x1000];
  int i, j;
  int c, m;
  int flag;
  int upper, lower;
  int pos, len;
  
  lfg->body = (int *)calloc(lfg->size, sizeof(int));
  if (lfg->body == NULL) {
    fprintf(stderr, "extract_body: Can't allocate memory.\n");
    exit(1);
  }
  
  /* initialize ring buffer */
  for (i = 0; i < 0xfff; i++){
    ring[i] = 0;
  }
  
  /* extract data */
  for (i = 0, c = 0, m = 0xfee; i < lfg->size;){
    /* flag bits, which indicates data or location */
    if (--c < 0){
      flag = fgetc(fp);
      c = 7;
    }
    
    if(flag & 0x80){
      /* data */
      ring[m++] = lfg->body[i++] = fgetc(fp);
      m &= 0xfff;
    } else {
      /* copy from ring buffer */
      upper = fgetc(fp);
      lower = fgetc(fp);
      
      len = (upper & 0x0f) + 3;
      pos = (upper >> 4) + (lower << 4);
      if (pos < 0 || pos > 0xfff) { /* must always be false. */
	fprintf(stderr, "Invalid position.\n");
	exit(1);
      }
      
      for(j = 0; j < len; j++){
	ring[m++] = lfg->body[i++] = ring[pos++];
	m &= 0xfff;
	pos &= 0xfff;
      }
    }
    flag = flag << 1;
  }

  /* check if the extracted size is correct. */
  if (i != lfg->size) {
    fprintf(stderr, "Warning: Extracted data may be invalid.\n");
  }
}

static void extract_body_from_data(unsigned char *data, int idx, LFG *lfg)
{
  int ring[0x1000];
  int i, j;
  int c, m;
  int flag;
  int upper, lower;
  int pos, len;
  
  lfg->body = (int *)calloc(lfg->size, sizeof(int));
  if (lfg->body == NULL) {
    fprintf(stderr, "extract_body: Can't allocate memory.\n");
    exit(1);
  }
  
  /* initialize ring buffer */
  for (i = 0; i < 0xfff; i++){
    ring[i] = 0;
  }
  
  /* extract data */
  for (i = 0, c = 0, m = 0xfee; i < lfg->size;){
    /* flag bits, which indicates data or location */
    if (--c < 0){
      flag = data[idx++];
      c = 7;
    }
    
    if(flag & 0x80){
      /* data */
      ring[m++] = lfg->body[i++] = data[idx++];
      m &= 0xfff;
    } else {
      /* copy from ring buffer */
      upper = data[idx++];
      lower = data[idx++];
      
      len = (upper & 0x0f) + 3;
      pos = (upper >> 4) + (lower << 4);
      if (pos < 0 || pos > 0xfff) { /* must always be false. */
	fprintf(stderr, "Invalid position.\n");
	exit(1);
      }
      
      for(j = 0; j < len; j++){
	ring[m++] = lfg->body[i++] = ring[pos++];
	m &= 0xfff;
	pos &= 0xfff;
      }
    }
    flag = flag << 1;
  }

  /* check if the extracted size is correct. */
  if (i != lfg->size) {
    fprintf(stderr, "Warning: Extracted data may be invalid.\n");
  }
}

static void convert_indexed_image(LFG *lfg)
{
  int i;
  int pix1, pix2;
  int x = 0, y = 0;

  lfg->image = (int *)calloc((lfg->width - lfg->xoffset) * (lfg->height - lfg->yoffset), sizeof(int));
  if (lfg->image == NULL) {
    fprintf(stderr, "convert_indexed_image: Can't allocate memory.\n");
    exit(1);
  }
  
  for (i = 0; i < lfg->size; i++) {
    pix1 = (lfg->body[i] & 0x80) >> 4 |
      (lfg->body[i] & 0x20) >> 3 |
      (lfg->body[i] & 0x08) >> 2 |
      (lfg->body[i] & 0x02) >> 1;
    pix2 = (lfg->body[i] & 0x40) >> 3 |
      (lfg->body[i] & 0x10) >> 2 |
      (lfg->body[i] & 0x04) >> 1 |
      (lfg->body[i] & 0x01);
    if (lfg->direction == VERTICAL) {
      lfg->image[(lfg->width - lfg->xoffset) * y + x] = pix1;
      lfg->image[(lfg->width - lfg->xoffset) * y + x + 1] = pix2;
      if (++y > lfg->height - lfg->yoffset - 1) {
	y = 0;
	x += 2;
      }
    } else { /* HORIZONTAL */
      lfg->image[(lfg->width - lfg->xoffset) * y + x] = pix1;
      lfg->image[(lfg->width - lfg->xoffset) * y + x + 1] = pix2;
      x += 2;
      if (x > (lfg->width - lfg->xoffset) - 1) {
	x = 0;
	y++;
      }
    }
  }
}

/* end of file */
