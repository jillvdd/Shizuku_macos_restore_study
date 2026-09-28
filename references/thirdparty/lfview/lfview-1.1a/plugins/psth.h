/*
 * psth.h
 * Header file for programs dealing with PSTH format.
 * 01/30/2000 by TF
*/

#ifndef ___INCLUDE_PSTH_H
#define ___INCLUDE_PSTH_H

#include <stdio.h>

#define PSTH_R 0
#define PSTH_G 1
#define PSTH_B 2

#define UNKNOWN -1
#define INDEXED 0
#define RGB 1

typedef struct {
  int type;
  int palette_size;
  int *palette; /* order is R-G-B */
  int width;
  int height;
  int *image; /* size is width * height */
} PSTH_IMG;

extern void free_psth(PSTH_IMG *);

extern PSTH_IMG *read_psth(char *);
extern PSTH_IMG *read_psth_from_data(unsigned char *, int);

#endif
