/*
 * LEAF Visual Novel System For X
 * (c) Copyright 1999,2000 Go Watanabe mailto:go@denpa.org
 * All rights reserverd.
 *
 * ORIGINAL LVNS (c) Copyright 1996-1999 LEAF/AQUAPLUS Inc.
 *
 * $Id: lvnsimage_sximage.h,v 1.2 2002/07/29 05:24:39 go Exp $
 */

/*
 * LVNSImage
 * 8bit indexed colored image
 */

#ifndef __lvnsimage_sximage_h_
#define __lvnsimage_sximage_h_

#include "lvnsimage.h"
#include "sximage.h"

void lvnsimage_sximage_init(void);

void lvnsimage_set_pal_to_sximage(LvnsImage *image, SuperXImage *sximage);
void lvnsimage_set_pal_to_sximage_multi(LvnsImage *image, SuperXImage *sximage, int par16);
void lvnsimage_set_pal_to_sximage_screen(LvnsImage *image, SuperXImage *sximage, int par16);

void lvnsimage_copy_to_sximage(LvnsImage *image, 
                              SuperXImage *sximage,
                              int x, int y);

void lvnsimage_copy_area_to_sximage(LvnsImage *src, SuperXImage *dst, 
                                  int x, int y, int w, int h, int x2, int y2);
void lvnsimage_copy_mask_unit_to_sximage(LvnsImage *src, SuperXImage *dst, 
									 int x, int y, int x2, int y2, int mask);
void lvnsimage_copy_squaremask_unit_to_sximage(LvnsImage *src, SuperXImage *dst, 
									   int x, int y, int x2, int y2, int mask);

void sximage_box(SuperXImage *image, int x, int y, int w, int h, int idx);

#endif
