/*
 * hat_grp.h
 * 1993/3/12 by TF
 */

#ifndef ___INCLUDE_HAT_GRP_H
#define ___INCLUDE_HAT_GRP_H

#define GRP_R 0
#define GRP_G 1
#define GRP_B 2

typedef struct {
  int orig_size;
  int extracted_size;
  int type;
  int width;
  int height;
  int color_num;
  int transparent;     /* the palette num. of transparent color */
  int palette[256][3];
  int *image;
} GRP;

GRP *read_grp(const char *);
GRP *read_grp_from_data(unsigned char *, int, unsigned char *, int);
void grp_free(GRP *);

#endif
