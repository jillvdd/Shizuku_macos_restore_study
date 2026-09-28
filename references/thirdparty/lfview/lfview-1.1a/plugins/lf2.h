/*
 * lf2.h
 * Header file for programs dealing with Leaf LF2 format.
 * 10/12/1997 by TF
*/

#ifndef ___INCLUDE_LF2_H
#define ___INCLUDE_LF2_H

#include <stdio.h>

#define LF2_R 0
#define LF2_G 1
#define LF2_B 2

typedef struct {
  int width;
  int height;
  int xoffset;
  int yoffset;
  int color_num;
  int unknown;         /* unknown, yet */
  int direction;       /* vertical or horizontal */
  int transparent;     /* the palette num. of transparent color */
  int size;            /* the size of image */
  int palette[256][3];
  int *image;
} LF2;

extern void free_lf2(LF2 *);

extern LF2 *read_lf2(char *);
extern LF2 *read_lf2_from_data(unsigned char *, int);
#endif
