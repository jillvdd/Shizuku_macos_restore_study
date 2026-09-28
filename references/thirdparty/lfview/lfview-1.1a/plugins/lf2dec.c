/*
 * lf2dec.c
 * Decode Leaf LF2 format.
 * 10/12/1997 by TF
 *
 * $Id: lf2dec.c,v 1.2 2000/12/28 15:51:50 tf Exp $
 */
#include <stdio.h>
#include <stdlib.h>

#include "lf2.h"

static LF2 *init_lf2(void);
static int read_magic(FILE *);
static void read_palette(FILE *, LF2 *);
static void read_palette_from_data(unsigned char *, LF2 *);
static void read_color_num(FILE *, LF2 *);
static void read_size(FILE *, LF2 *);
static void read_unknown(FILE *, LF2 *);
static void read_transparent(FILE *, LF2 *);
static void skip_padding(FILE *, int);
static int extract_body(FILE *, LF2 *);
static int extract_body_from_data(unsigned char *, LF2 *);

LF2 *read_lf2(char *filename)
{
  LF2 *lf2;
  FILE *fp;

  fp = fopen(filename, "r");
  if (fp == NULL) {
    fprintf(stderr, "read_lf2:Can't open %s.\n", filename);
    return NULL;
  }

  lf2 = init_lf2();
  
  if (read_magic(fp) < 0) {
    fclose(fp);
    return NULL;
  }
  read_size(fp, lf2);
  read_unknown(fp, lf2);

  skip_padding(fp, 1);
  read_transparent(fp, lf2);
  skip_padding(fp, 3);
  read_color_num(fp, lf2);
  skip_padding(fp, 1);
  read_palette(fp, lf2);

  if (extract_body(fp, lf2) < 0) {
    fclose(fp);
    return NULL;
  }

  fclose(fp);
  return lf2;
}

LF2 *read_lf2_from_data(unsigned char *data, int size)
{
  LF2 *lf2;

  lf2 = init_lf2();
  
  /* check magic number 'LEAF256\0' */
  if (data[0] != 0x4c || data[1] != 0x45 || data[2] != 0x41 ||
      data[3] != 0x46 || data[4] != 0x32 || data[5] != 0x35 ||
      data[6] != 0x36 || data[7] != 0x0) {
    fprintf(stderr, "This file isn't LF2 format.\n");
    free_lf2(lf2);
    return NULL;
  }
  
  lf2->xoffset = (data[9] << 8) | data[8];
  lf2->yoffset = (data[11] << 8) | data[10];
  lf2->width = (data[13] << 8) | data[12];
  lf2->height = (data[15] << 8) | data[14];

  lf2->size = lf2->width * lf2->height;

  lf2->transparent = data[0x12];
  lf2->color_num = data[0x16];

  read_palette_from_data(data, lf2);

  if (extract_body_from_data(data, lf2) < 0) {
    return NULL;
  }

  return lf2;
}

static LF2 *init_lf2(void)
{
  LF2 *lf2;

  lf2 = (LF2 *)malloc(sizeof(LF2));
  if (lf2 == NULL) {
    fprintf(stderr, "read_lf2: Can't allocate memory.\n");
    return NULL;
  }
  
  return lf2;
}

void free_lf2(LF2 *lf2)
{
  if (lf2 != NULL) {
    if (lf2->image != NULL) {
      free(lf2->image);
    }
    free(lf2);
  }
}


/*
 * Private functions
 */
static int read_magic(FILE *fp)
{
  char buf[9];
  int i;

  for (i = 0; i < 8; i++) {
    buf[i] = fgetc(fp);
  }
  buf[8] = '\0';    /* for safe */
  
  if (strcmp("LEAF256", buf)) {
    fprintf(stderr, "This file isn't LF2 format.\n");
    return -1;
  }
  return 0;
}

static void read_unknown(FILE *fp, LF2 *lf2)
{
  lf2->unknown = fgetc(fp);
#ifdef DEBUG
  fprintf(stderr, "unknown: %02x(%d)\n", lf2->unknown, lf2->unknown);
#endif
}

static void read_size(FILE *fp, LF2 *lf2)
{
  int upper, lower;

  /* x offset */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lf2->xoffset = (lower << 8) | upper;

  /* y offset */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lf2->yoffset = (lower << 8) | upper;

  /* width */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lf2->width = (lower << 8) | upper;

  /* height */
  upper = fgetc(fp);
  lower = fgetc(fp);
  lf2->height = (lower << 8) | upper;

  /* set image size */
  lf2->size = lf2->width * lf2->height;
}

static void read_palette(FILE *fp, LF2 *lf2)
{
  int i;
  
  for (i = 0; i < lf2->color_num; i++) {
    lf2->palette[i][LF2_B] = fgetc(fp);
    lf2->palette[i][LF2_G] = fgetc(fp);
    lf2->palette[i][LF2_R] = fgetc(fp);
  }

#ifdef DEBUG
  for (i = 0; i < lf2->color_num; i++) {
    fprintf(stderr, "%03d: %02x %02x %02x\n", i,
	    lf2->palette[i][LF2_R],
	    lf2->palette[i][LF2_G],
	    lf2->palette[i][LF2_B]);
  }
#endif
}

static void read_palette_from_data(unsigned char *data, LF2 *lf2)
{
  int i;
  int base = 0x18;
  
  for (i = 0; i < lf2->color_num; i++) {
    lf2->palette[i][LF2_B] = data[base++];
    lf2->palette[i][LF2_G] = data[base++];
    lf2->palette[i][LF2_R] = data[base++];
  }
}

static void read_color_num(FILE *fp, LF2 *lf2)
{
  lf2->color_num = fgetc(fp);
}

static void read_transparent(FILE *fp, LF2 *lf2)
{
  lf2->transparent = fgetc(fp);
  if (lf2->transparent == 0xff) {
    /* Transparent color isn't used */
#ifdef DEBUG
    fprintf(stderr, "Transparent color isn't used.\n");
#endif
  }
}

static void skip_padding(FILE *fp, int num)
{
  int i;

  for (i = 0; i < num; i++) {
    fgetc(fp);
  }
  return;
}

static int extract_body(FILE *fp, LF2 *lf2)
{
  int ring[0x1000];
  int i, j;
  int c, m;
  int flag;
  int upper, lower;
  int pos, len;
  int data;
  int idx;
  
  lf2->image = (int *)calloc(lf2->size, sizeof(int));
  if (lf2->image == NULL) {
    fprintf(stderr, "extract_body: Can't allocate memory.\n");
    return -1;
  }
  
  /* initialize the ring buffer */
  for (i = 0; i < sizeof(ring) / sizeof(ring[0]); i++){
    ring[i] = 0;
  }
  
  /* extract data */
  for (i = 0, c = 0, m = 0xfee; i < lf2->size;){
    /* flag bits, which indicates data or location */
    if (--c < 0) {
      flag = fgetc(fp);
      flag ^= 0xff;
      c = 7;
    }
    
    if(flag & 0x80){
      /* data */
      data = fgetc(fp);
      if (data == EOF) {
	fprintf(stderr, "Data may be truncated.\n");
	return -1;
      }
      data ^= 0xff;
      ring[m++] = data;
      idx = (i % lf2->width) + lf2->width * (lf2->height - i / lf2->width - 1);
      lf2->image[idx] = data;
      i++;
      m &= 0xfff;
    } else {
      /* copy from the ring buffer */
      upper = fgetc(fp);
      if (upper == EOF) {
	fprintf(stderr, "Data may be truncated.\n");
	return -1;
      }
      upper ^= 0xff;

      lower = fgetc(fp);
      if (lower == EOF) {
	fprintf(stderr, "Data may be truncated.\n");
	return -1;
      }
      lower ^= 0xff;
      
      len = (upper & 0x0f) + 3;
      pos = (upper >> 4) + (lower << 4);

      for(j = 0; j < len; j++){
	idx = (i % lf2->width) + lf2->width * (lf2->height - i / lf2->width - 1);
	ring[m++] = lf2->image[idx] =  ring[pos++];
	i++;
	m &= 0xfff;
	pos &= 0xfff;
      }
    }
    flag = flag << 1;
  }
#ifdef DEBUG
  if (fgetc(fp) != EOF) {
    fprintf(stderr, "Error: Didn't reach EOF.\n");
  } else {
    fprintf(stderr, "Got all data.\n");
  }
#endif

  return 0;
}

static int extract_body_from_data(unsigned char *data, LF2 *lf2)
{
  int ring[0x1000];
  int i, j;
  int c, m;
  int flag;
  int upper, lower;
  int pos, len;
  int d;
  int idx;
  int p;

  p = 0x18 + lf2->color_num * 3;

  lf2->image = (int *)calloc(lf2->size, sizeof(int));
  if (lf2->image == NULL) {
    fprintf(stderr, "extract_body: Can't allocate memory.\n");
    return -1;
  }
  
  /* initialize ring buffer */
  for (i = 0; i < 0xfff; i++){
    ring[i] = 0;
  }
  
  /* extract data */
  for (i = 0, c = 0, m = 0xfee; i < lf2->size;){
    /* flag bits, which indicates data or location */
    if (--c < 0) {
      flag = data[p++];
      flag ^= 0xff;
      c = 7;
    }
    
    if(flag & 0x80){
      /* data */
      d = data[p++];
      d ^= 0xff;
      ring[m++] = d;
      idx = (i % lf2->width) + lf2->width * (lf2->height - i / lf2->width - 1);
      lf2->image[idx] = d;
      i++;
      m &= 0xfff;
    } else {
      /* copy from ring buffer */
      upper = data[p++];
      upper ^= 0xff;

      lower = data[p++];
      lower ^= 0xff;
      
      len = (upper & 0x0f) + 3;
      pos = (upper >> 4) + (lower << 4);

      for(j = 0; j < len; j++){
	idx = (i % lf2->width) + lf2->width * (lf2->height - i / lf2->width - 1);
	if (idx > 0 && idx < lf2->size) {
	  ring[m++] = lf2->image[idx] = ring[pos++];
	} else {
	  ring[m++] = ring[pos++];
	}
	i++;
	m &= 0xfff;
	pos &= 0xfff;
      }
    }
    flag = flag << 1;
  }

  return 0;
}
