/*
 * xutil.c
 * X11 utilities.
 * 3/26/1998 by TF
 */
#include <stdio.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "xutil.h"

XVisualInfo xut_get_vinfo(ScreenInfo *si)
{
  XVisualInfo vinfo;
  int i;
  int deplist[] = {32, 24, 16, 8, 4, 1};

  for (i = 0; i < sizeof(deplist) / sizeof(deplist[0]); i++) {
    if (deplist[i] < 16) {
      if (XMatchVisualInfo(si->disp, si->scr, deplist[i], PseudoColor, &vinfo) != 0) {
	fprintf(stderr, "Pseudo color, depth = %d.\n", deplist[i]);
	return vinfo;
      }
    }
    if (XMatchVisualInfo(si->disp, si->scr, deplist[i], DirectColor, &vinfo) != 0) {
      fprintf(stderr, "Direct color, depth = %d.\n", deplist[i]);
      return vinfo;
    }
    if (XMatchVisualInfo(si->disp, si->scr, deplist[i], TrueColor, &vinfo) != 0) {
      fprintf(stderr, "True color, depth = %d.\n", deplist[i]);
      return vinfo;
    }
  }
  
  fprintf(stderr, "Error: No visual matched.\n");
  exit(1);
}

XImage *xut_create_ximage_indexed(ScreenInfo *si, int *src, int width, int height, Color *palette, int pal_size, int trans_index, int *colors, unsigned long pixel[]) {
  int i, j, k;
  char *image;
  int byte_pixel;
  int p;
  XColor xcolor;
  XImage *ximg;
  XColor xc[256];
  
  if (src == NULL) {
    fprintf(stderr, "Warning: No source image.\n");
    return NULL;
  }

  for (byte_pixel = 1; si->vinfo.depth > byte_pixel * 8; byte_pixel <<= 1) ;

  /* create colormap */
  if (si->vinfo.class == DirectColor || si->vinfo.class == TrueColor) {
    for (i = 0, j = 0; i < pal_size; i++) {
      xcolor.red = palette[i].r << 8;
      xcolor.green = palette[i].g << 8;
      xcolor.blue = palette[i].b << 8;
      if (XAllocColor(si->disp, si->cmap, &xcolor) == 0) {
	fprintf(stderr, "Color cell allocation failure.\n");
	(*colors)--;
      } else {
	pixel[j] = xcolor.pixel;
	j++;
      }
    }
  } else if (si->vinfo.class == PseudoColor) {
    if (!XAllocColorCells(si->disp, si->cmap, False, NULL, 0, pixel, pal_size + 1)) {
      fprintf(stderr, "Using private colormap.\n");
      si->cmap = XCreateColormap(si->disp, si->rootwin,
				 si->vinfo.visual, AllocNone);
      if (!XAllocColorCells(si->disp, si->cmap, False, NULL, 0,
			    pixel, pal_size)) {
	fprintf(stderr, "Can't get enough colors(%d).\n", pal_size + 1);
	return NULL;
      }
      si->private = True;
    }
    for (i = 0; i < pal_size; i++) {
      xc[i].pixel = pixel[i];
      xc[i].flags = DoRed | DoGreen | DoBlue;
      xc[i].red = palette[i].r << 8;
      xc[i].green = palette[i].g << 8;
      xc[i].blue = palette[i].b << 8;
    }
  } else {
    fprintf(stderr, "Unsupported visual.\n");
    exit(1);
  }

  /* kuh01_3.grp in Comic Party(Bustup.pak) has zero-width */
  if (width == 0 || height == 0) {
    fprintf(stderr, "This image has invalid size(%d, %d).\n", width, height);
    return NULL;
  }
  ximg = XCreateImage(si->disp, si->vinfo.visual, si->vinfo.depth,
		      ZPixmap, 0, 0, width, height, byte_pixel * 8, 0);
  image = (char *)calloc(width * height, byte_pixel);
  if (image == NULL) {
    perror("calloc");
    exit(1);
  }

  for (i = 0, k = 0; i < height; i++) {
    for (j = 0; j < width; j++) {
      p = pixel[src[i * width + j]];
      switch (byte_pixel) {
      case 1:
 	*((char *)image + k) = p;
 	break;
      case 2:
 	*((short *)image + k) = p;
 	break;
      case 4:
 	*((int *)image + k) = p;
 	break;
      }
      k++;
    }
  }
  
  ximg->data = (char *)image;
  ximg->bitmap_unit = byte_pixel * 8;
  ximg->bytes_per_line = width * byte_pixel;
  ximg->bits_per_pixel = byte_pixel * 8;
  ximg->red_mask = si->vinfo.visual->red_mask;
  ximg->green_mask = si->vinfo.visual->green_mask;
  ximg->blue_mask = si->vinfo.visual->blue_mask;

#ifdef DEBUG
  fprintf(stderr, "done.\n");
#endif

  return ximg;
}

XImage *xut_create_ximage_rgb() {
  fprintf(stderr, "Warning: this function isn't implemented, yet.\n");
  return NULL;
}

void xut_put_ximage_on_root(ScreenInfo sinfo, XImage *ximg, int width, int height)
{
  Pixmap bg_pixmap;
  Screen *screen;
  int sx, sy, x, y;

  screen = DefaultScreenOfDisplay(sinfo.disp);
  sx = WidthOfScreen(screen);
  sy = HeightOfScreen(screen);
  x = (sx - width) / 2;
  y = (sy - height) / 2;
  
  bg_pixmap = XCreatePixmap(sinfo.disp, sinfo.rootwin, sx, sy, sinfo.vinfo.depth);
  XSetWindowBackgroundPixmap(sinfo.disp, sinfo.rootwin, bg_pixmap);
  XPutImage(sinfo.disp, bg_pixmap, sinfo.gc, ximg, 0, 0, x, y, width, height);
  XClearWindow(sinfo.disp, sinfo.rootwin);
}
