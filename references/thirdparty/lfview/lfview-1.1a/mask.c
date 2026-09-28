/*
 * mask.c
 * create mask from an indexed image
 * 1998/3/11 by TF
 */
#include <stdio.h>
#include <X11/Xlib.h>

Pixmap create_mask(Display *disp, int width, int height, int *img, int transparent)
{
  Pixmap mask;
  int i, j, k;
  long black, white;
  GC gc;

  mask = XCreatePixmap(disp, RootWindow(disp, 0), width, height, 1);
  gc = XCreateGC(disp, mask, 0, 0);
  black = BlackPixel(disp, 0);
  white = WhitePixel(disp, 0);
  
  /* Clear Pixmap */
  XSetForeground(disp, gc, white);
  XFillRectangle(disp, mask, gc, 0, 0, width, height);
  
  /* Transparent */
  XSetForeground(disp, gc, black);
  for (i = 0, k = 0; i < height; i++) {
    for (j = 0; j < width; j++) {
      if (img[i * width + j] == transparent) {
	XDrawPoint(disp, mask, gc, j, i);
      }
    }
  }
  XFreeGC(disp, gc);

  return mask;
}
