#ifndef ___INCLUDE_X_UTIL
#define ___INCLUDE_X_UTIL

#include <X11/Xlib.h>
#include <X11/Xutil.h>

#define XUT_R 0
#define XUT_G 1
#define XUT_B 2

typedef struct {
  Display *disp;
  Window win;
  Window rootwin;
  XVisualInfo vinfo;
  int scr;
  GC gc;
  Colormap cmap;
  Bool private;
} ScreenInfo;

typedef struct {
  int r;
  int g;
  int b;
} Color;

typedef struct {
  int type;
  XImage *ximg;
  Pixmap mask;
  int width;
  int height;
  int *image;
  int color_num;
  Color *palette;
  int transparent;
} Image;

XVisualInfo xut_get_vinfo(ScreenInfo *);
XImage *xut_create_ximage_indexed(ScreenInfo *, int *, int, int, Color *, int, int, int *, unsigned long[]);
XImage *xut_create_ximage_rgb(void);
void xut_put_ximage_on_root(ScreenInfo, XImage *, int, int);

#endif
