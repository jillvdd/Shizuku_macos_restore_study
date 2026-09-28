/*
 * lfg.h
 * about LEAF LFG(16 colors) format 
 * 09/21/1997 by TF
 */

#ifndef ___INCLUDE_LFG_H
#define ___INCLUDE_LFG_H

#define R 0
#define G 1
#define B 2

#define LFG_R 0
#define LFG_G 1
#define LFG_B 2

#define VERTICAL 0
#define HORIZONTAL 1

#define PADDING_LENGTH 2

typedef struct {
  int width;
  int height;
  int xoffset;
  int yoffset;
  int direction;       /* vertical or horizontal */
  int transparent;     /* the palette num. of transparent color */
  int size;            /* the size of image */
  int palette[16][3];
  int *body;           /* extracted data */
  int *image;          /* indexed image */
} LFG;

extern LFG *read_lfg(FILE *);
extern LFG *read_lfg_from_data(unsigned char *, int);
extern void free_lfg(LFG *);

#endif
