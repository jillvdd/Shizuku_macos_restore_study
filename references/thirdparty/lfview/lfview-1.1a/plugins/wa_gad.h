/*
 * wa_gad.h
 * 1998/6/17 by TF
 */

#ifndef ___INCLUDE_WA_GAD_H
#define ___INCLUDE_WA_GAD_H

#define LF_R 0
#define LF_G 1
#define LF_B 2

typedef struct {
  int orig_size;
  int extracted_size;
  int num;
  int color_num;
  int transparent;     /* the palette num. of transparent color */
  int palette[256][3];

  int *offset;
  int *width;
  int *height;
  int **image;
} GAD;

GAD *read_gad(const char *);
GAD *read_gad_from_data(unsigned char *, int, unsigned char *, int);
void gad_free(GAD *);

#endif
