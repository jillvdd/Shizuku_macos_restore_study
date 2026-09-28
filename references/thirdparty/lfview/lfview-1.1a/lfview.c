/*
 * lfview.c
 * Display LEAF format images on X11.
 * 10/12/1997 by TF
 */
/*
 * Changes
 *  8/12/2000 Support 8bpp images in Inagawa de Ikou.
 *  6/ 5/1999 Support Comic Party.
 *  5/ 8/1999 Support Comic Party(Demo version).
 *  6/17/1998 Support White Album images.
 *  4/ 8/1998 exclude image decoders to plug-ins.
              They supports Linux,
                          OpenBSD, NEC EWS4800(Thanks to Mr. Monaka), 
                          FreeBSD(Thanks to Mr. Nogaya & Mr. Monaka).
 *  3/28/1998 exclude image decode routines.
 *  3/26/1998 Support PsuedoColor.
 *  3/25/1998 Fix a problem that it crashes when colors can't be
              allocated. (Thanks to Mr. Monaka)
 *  3/24/1998 Fix a critical bug. (Didn't deal with LFG's offset when
 *            creating its mask.)
 *  3/11/1998 Support going back over non-image, shape extention
 *  3/ 9/1998 Support 24/32 bpp (Thanks to Mr. Kurosawa)
 * 10/27/1997 Add -root option. Fix some bugs.
*/

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/extensions/shape.h>
#include <dlfcn.h>
#include "xutil.h"

#define MAIN

#include "leafpak.h"
#include "lfview.h"

enum {
  PosSet, /* Number */
  PosMin, /* Left/Top */
  PosMid, /* Center */
  PosMax, /* Right/Bottom*/
};

enum {
  BasedMin = 0x0000,	/* Enabled used with PosSet flag */
  BasedMax = 0x0100,	/* Enabled used with PosSet flag */
};

void put_ximage_on_root(ScreenInfo, XImage *, int, int, int, int, int, int);

static void init_win(void);
static void set_win_property(ScreenInfo, int, int, const char *, int, int, Pixmap, int, int, int, int);
static void finish_win(ScreenInfo);
static char *strip_filename(char *);
static void next_index(int *, int *, int);
static void setup_plugins(const char *);
static void close_plugins(void *);
static void *get_sym(void *, char *);

unsigned char *get_source(const char *, int, LEAFPACK *, int *);

#ifndef PLUGINDIR
#define PLUGINDIR "/somewhere/to/install/plugin"
#endif

#ifndef BASE_PLUGIN
#define BASE_PLUGIN "liblfv_leaf.so"
#endif

static int create_image(Image *);
static int free_image(Image *);

unsigned long pixel[256];

static int colors;
static ScreenInfo si;

typedef struct {
  int (*get)(Image *, unsigned char **, int *, int *);
  int (*check)(unsigned char *, int, const char *);
  int (*query)(const char *, unsigned char *, char ***, int*);
} PLUGIN;

PLUGIN *plugins = NULL;
int n_plugins = 0;

void *plugin_handle;

int main(int argc, char *argv[])
{
  XEvent ev;
  KeySym key;
  char string[10];
  int img_index, max_index, min_index, type;
  int img_num = 0, img_id = 0, img_id_d;
  Bool loop, load;
  int mode = FILE_MODE;
  int root_mode = False;
  int shape_mode = False;
  LEAFPACK *lp = NULL;
  char **table;
  int direction = FORWARD;
  int n, i, j;
  unsigned char *data[3];
  int size[2];
  Image img[MAX_IMG];
  char **flist;
  int n_flist;
	int PosHFlag=PosMid;
	int PosH=0;
	int PosVFlag=PosMid;
	int PosV=0;

  if (argc == 1) {
    fprintf(stderr, USAGE, strip_filename(argv[0]));
    exit(1);
  }

  init_win();
  setup_plugins(BASE_PLUGIN);

  table = argv;
  max_index = argc;
  load = True;

  /* parse argument */
  for (img_index = 1; img_index < argc; img_index++) {
    if (!strcmp(argv[img_index], "-a") && argc > img_index + 1) {
      mode = ARCHIVE_MODE;
      img_index++;
      lp = leafpack_open(argv[img_index]);
      if (lp == NULL) {
	fprintf(stderr, "Aborted.\n");
	exit(1);
      }
      leafpack_print_type(lp);
    } else if (!strcmp(argv[img_index], "-root")) {
      fprintf(stderr, "Put images on the root window.\n");
      root_mode = True;
    } else if (!strcmp(argv[img_index], "-geometry") && argc>img_index+1) {
	/* Image Pos Setting*/
	char *p=argv[++img_index];
	/* pserse H position */
	if(p[0]=='+' && isdigit(p[1])){
		/* Left based num */
		PosHFlag=PosSet | BasedMin;
		PosH=strtol(p+1,&p,10);
	}else if(p[0]=='-' && isdigit(p[1])){
		/* Right based num */
		PosHFlag=PosSet | BasedMax;
		PosH=strtol(p+1,&p,10);
	}else{
		int i;
		static const char *HPosStr[3]={"+left","+center","+right"};
		for(i=0;i<3;i++){
			if(strncmp(p,HPosStr[i],strlen(HPosStr[i]))==0){
				PosHFlag=PosMin+i;
				p+=strlen(HPosStr[i]);
				break;
			}
		}
	}
	if(p[0]=='+' && isdigit(p[1])){
		/* Top based num */
		PosVFlag=PosSet | BasedMin;
		PosV=strtol(p+1,&p,10);
	}else if(p[0]=='-' && isdigit(p[1])){
		/* Bottom based num */
		PosVFlag=PosSet | BasedMax;
		PosV=strtol(p+1,&p,10);
	}else{
		int i;
		static const char *VPosStr[3]={"+top","+center","+bottom"};
		for(i=0;i<3;i++){
			if(strncmp(p,VPosStr[i],strlen(VPosStr[i]))==0){
				PosVFlag=PosMin+i;
				p+=strlen(VPosStr[i]);
				break;
			}
		}
	}
    } else if (!strcmp(argv[img_index], "-shape")) {
      int event_base, error_base;
      if (XShapeQueryExtension(si.disp, &event_base, &error_base) == False) {
	fprintf(stderr, "X11 Shape Extention isn't supported.\n");
	shape_mode = False;
      } else {
	fprintf(stderr, "Enable X11 Shape Extention.\n");
	shape_mode = True;
      }
    } else {
      break;
    }
  }

  if (mode == ARCHIVE_MODE && argc == img_index) {
    /* extract all file in the archive */
    img_index = 0;
    max_index = lp->file_num;
    table = lp->name;
  }

  /* remember the index of the first argument for back */
  min_index = img_index;

  while (img_index < max_index) {
    if (load == True) {
      /* get an image */
      data[0] = get_source(table[img_index], mode, lp, &(size[0]));
      if (data[0] == NULL) {
	fprintf(stderr, "Can't get the data.\n");
	goto next;
      }

      /* check image type */
      for (type = 0; type < n_plugins; type++) {
	if ((*plugins[type].check)(data[0], size[0], table[img_index]) == True) break;
      }
      
      if (type == n_plugins) {
	fprintf(stderr, "%s: Non-image data.\n", table[img_index]);
	free(data[0]);
	next_index(&direction, &img_index, min_index);
	continue;
      }
      
      (*plugins[type].query)(table[img_index], data[0], &flist, &n_flist);
      
      for (i = 0; i < n_flist; i++) {
	data[i + 1] = get_source(flist[i], mode, lp, &(size[i + 1]));
	free(flist[i]);
	if (data[i + 1] == NULL) {
	  for (j = 0; j < i; j++) {
	    free(data[i]);
	  }
	  for (j = i + 1 ; j < n_flist + 1; j++) {
	    free(flist[j]);
	  }
	  goto next;
	}
      }
      if (i > 0) free(flist);
      
      if ((*plugins[type].get)(img, data, size, &img_num) < 0) {
	next_index(&direction, &img_index, min_index);
	continue;
      }

      load = False;
      img_id = 0;

      for (i = 0; i < n_flist + 1; i++) {
	free(data[i]);
      }
    }

    fprintf(stderr, "creating image...\n");

    if (create_image(&img[img_id]) < 0) {
      next_index(&direction, &img_index, min_index);
      load = True;
      continue;
    }
    
    if (root_mode) {
      /* exit immediately */
      loop = False;
      img_index = max_index;

      put_ximage_on_root(si, img[img_id].ximg, img[img_id].width, img[img_id].height, PosHFlag, PosH, PosVFlag, PosV);
    } else {
      loop = True;
      {
	unsigned long vmask;
	XSetWindowAttributes att;
	vmask = CWColormap;

	att.colormap = si.cmap;
	XChangeWindowAttributes(si.disp, si.win, vmask, &att);
      }

      set_win_property(si, img[img_id].width, img[img_id].height,
	       strip_filename(table[img_index]), shape_mode, root_mode, img[img_id].mask,
		       PosHFlag, PosH, PosVFlag, PosV);
      XPutImage(si.disp, si.win, si.gc, img[img_id].ximg, 0, 0, 0, 0,
		img[img_id].width, img[img_id].height);
    }
    XFlush(si.disp);

    while (loop) {
      XNextEvent(si.disp, &ev);
      img_id_d = 0;
      switch (ev.type) {
      case KeyPress:
	n = XLookupString((XKeyEvent*)&ev, string, 10, &key, NULL);
	string[n] = '\0';
	if (n > 0) {
	  switch (key) {
	  case XK_space: /* go to the next image */
	    XSelectInput(si.disp, si.win, ExposureMask);
	    if (!strcmp(string, "S_SPACE")) {
	      img_id_d = 10;
	    } else {
	      img_id_d = 1;
	    }
	    loop = False;
	    direction = FORWARD;
	    break;
	  case XK_Tab: /* skip 10 images */
	    XSelectInput(si.disp, si.win, ExposureMask);
	    img_id_d = 10;
	    loop = False;
	    direction = FORWARD;
	    break;
	  case XK_BackSpace: /* back to the previous image */
	  case XK_Delete:
	    XSelectInput(si.disp, si.win, ExposureMask);
	    if (!strcmp(string, "S_BS")) {
	      img_id_d = -10;
	    } else {
	      img_id_d = -1;
	    }
	    loop = False;
	    direction = BACKWARD;
	    break;
	  case XK_q: /* exit program */
	    img_index = max_index;
	    loop = False;
	  }
	}
      case Expose:
	XPutImage(si.disp, si.win, si.gc, img[img_id].ximg, 0, 0, 0, 0,
		  img[img_id].width, img[img_id].height);
	XSelectInput(si.disp, si.win, KeyPressMask | ExposureMask);
	XFlush(si.disp);
	break;
      }
    }
    free_image(&img[img_id]);

  next:

    img_id += img_id_d;
    if (img_id >= img_num) {
      img_index += img_id - img_num + 1;
      load = True;
    }
    if (img_id < 0) {
      img_index--;
      load = True;
      if (img_index < min_index) {
	fprintf(stderr, "Warning: Already the first data.\n");
	img_index = min_index;
	direction = FORWARD;
      }
    }
  }

  finish_win(si);
  close_plugins(plugin_handle);

  if (mode == ARCHIVE_MODE) {
    leafpack_close(lp);
  }
  
  return 0;
}

static void init_win(void)
{
  KeySym l_shift[1];
  KeySym r_shift[1];

  if ((si.disp = XOpenDisplay(NULL)) == NULL) {
    fprintf(stderr, "init_win: Can't open window.\n");
    exit(1);
  }

  si.scr = DefaultScreen(si.disp);
  si.rootwin = RootWindow(si.disp, si.scr);
  si.win = XCreateSimpleWindow(si.disp, si.rootwin,
			       0, 0, 1, 1, 2, 0, 1);
  XMapWindow(si.disp, si.win);
  XSelectInput(si.disp, si.win, ExposureMask);
  
  si.gc = XCreateGC(si.disp, si.rootwin, 0, 0);
  si.vinfo = xut_get_vinfo(&si);
  si.private = False;

  si.cmap = DefaultColormap(si.disp, si.scr);

  switch (si.vinfo.class) {
  case DirectColor:
  case TrueColor:
  case PseudoColor:
    break;
  case StaticGray:
  case GrayScale:
    fprintf(stderr, "Error: This visual class isn't supported.\n");
    exit(1);
  default:
    fprintf(stderr, "Error: Unknown visual class.\n");
    exit(1);
  }

  /* define special keys */
  l_shift[0] = XK_Shift_R;
  r_shift[0] = XK_Shift_L;
  XRebindKeysym(si.disp, XK_space, l_shift, 1, "S_SPACE", strlen("S_SPACE"));
  XRebindKeysym(si.disp, XK_space, r_shift, 1, "S_SPACE", strlen("S_SPACE"));
  XRebindKeysym(si.disp, XK_BackSpace, l_shift, 1, "S_BS", strlen("S_BS"));
  XRebindKeysym(si.disp, XK_BackSpace, r_shift, 1, "S_BS", strlen("S_BS"));
  XRebindKeysym(si.disp, XK_Delete, l_shift, 1, "S_BS", strlen("S_BS"));
  XRebindKeysym(si.disp, XK_Delete, r_shift, 1, "S_BS", strlen("S_BS"));
}

static void set_win_property(ScreenInfo sinfo, int width, int height, const char *name, int shape_mode, int root_mode, Pixmap mask, int PosHFlag,int PosH,int PosVFlag,int PosV)
{
  Screen *screen;
  Window root;
  int sx, sy, x, y, w, h, b, d;

  XResizeWindow(sinfo.disp, sinfo.win, width, height);
  if (root_mode == False) {
    screen = DefaultScreenOfDisplay(sinfo.disp);
    sx = WidthOfScreen(screen);
    sy = HeightOfScreen(screen);
    XGetGeometry(sinfo.disp, sinfo.win, &root, &x, &y, &w, &h, &b, &d);
    switch(PosHFlag&0xff){
    case PosSet:
      if(PosHFlag&BasedMax)
	x=sx-width-PosH;
      else
	x=PosH;
      break;
    case PosMin:
      x=0;
      break;
    case PosMax:
      x=(sx-width);
      break;
    default:
      x = (sx - width) / 2;
      break;
    }
    switch(PosVFlag&0xff){
    case PosSet:
      if(PosHFlag&BasedMax)
	y=sy-height-PosV;
      else
	y=PosV;
      break;
    case PosMin:
      y=0;
      break;
    case PosMax:
      y=(sy-height);
      break;
    default:
      y = (sy - height) / 2;
      break;
    }
    XMoveWindow(sinfo.disp, sinfo.win, x, y);
  }
  XSetStandardProperties(sinfo.disp, sinfo.win,
			 name, name, (Pixmap)NULL,
			 (char **)NULL, (int)NULL, (XSizeHints *)NULL);
  if (shape_mode && mask != (Pixmap)NULL) {
    XShapeCombineMask(sinfo.disp, sinfo.win, ShapeBounding, 0, 0,
		      mask, ShapeSet);
  }
}

static void finish_win(ScreenInfo si)
{
  XFreeGC(si.disp, si.gc);
  XCloseDisplay(si.disp);
}

int create_image(Image *img)
{
  colors = img->color_num;
  img->ximg = xut_create_ximage_indexed(&si, img->image,
					img->width, img->height,
					img->palette, img->color_num,
					img->transparent,
					&colors, pixel);
  if (img->ximg == NULL) {
    return -1;
  }
  
  img->mask = create_mask(si.disp, img->width, img->height,
			  img->image, img->transparent);
  return 0;
}

int free_image(Image *img)
{
  if (img->image != NULL) {
    free(img->image);
    img->image = NULL;
  }
  if (img->palette != NULL) {
    free(img->palette);
    img->palette = NULL;
  }
  if (img->ximg != NULL) {
    XDestroyImage(img->ximg);
    img->ximg = NULL;
  }
  if (si.private) {
    XFreeColormap(si.disp, si.cmap); 
    si.private = False;
    si.cmap = DefaultColormap(si.disp, si.scr);
  } else {
    XFreeColors(si.disp, si.cmap, pixel, colors, 0);
  }
  
  if (img->mask != (Pixmap)NULL) {
    XFreePixmap(si.disp, img->mask);
    img->mask = (Pixmap)NULL;
  }

  return 0;
}

static char *strip_filename(char *filename)
{
  char *ptr;
  
  ptr = strrchr(filename, '/');
  
  if (ptr == NULL) {
    return filename;
  }
  return ++ptr;
}

unsigned char *get_source(const char *filename, int mode, LEAFPACK *lp, int *size)
{
  unsigned char *data;
  FILE *fp;

  if (mode == FILE_MODE) {
    fp = fopen(filename, "r");
    fseek(fp, 0L, SEEK_END);
    *size = ftell(fp);
    data = (unsigned char *)calloc(*size, sizeof(unsigned char));
    if (data == NULL) {
      perror("calloc");
      exit(1);
    }
    fseek(fp, 0L, SEEK_SET);
    fread(data, *size, 1, fp);
    fclose(fp);
  } else { /* ARCHIVE_MODE */
    data = leafpack_extract_file_to_data(lp, filename, size);
  }

  return data;
}

static void next_index(int *direction, int *img_index, int min_index)
{
  if (*direction == FORWARD) {
    (*img_index)++;
  } else if (*direction == BACKWARD) {
    (*img_index)--;
    if (*img_index < min_index) {
      fprintf(stderr, "Warning: Already the first data.\n");
      *img_index = min_index;
      *direction = FORWARD;
    }
  } else {
    fprintf(stderr, "Unexpected error(invalid direction)\n");
    exit(1);
  }
}

static void close_plugins(void *handle)
{
  dlclose(handle);
}

static void *get_sym(void *handle, char *name)
{
  void *p;
  char buf[BUFSIZ]; /* size should be changed. */
  
  p = dlsym(handle, name);
  if (p == NULL) {
    sprintf(buf, "_%s", name);
    p = dlsym(handle, buf);
  }
  if (p == NULL) {
    fprintf(stderr, "get_sym: symbol %s not found.\n", name);
    exit(1);
  }
  
  return p;
}

#ifdef __FreeBSD__
/* dummy value, always ONE */
#define RTLD_LAZY	1
#endif

static void setup_plugins(const char *lib_name)
{
  int i;
  char buf[1024];
  int num;
  char **names;
  int (*query)(int *, char ***);
  
  sprintf(buf, "%s/.lfview/%s", getenv("HOME"), lib_name);
  plugin_handle = dlopen(buf, RTLD_LAZY);
  if (plugin_handle == NULL) {
    sprintf(buf, "%s/%s", PLUGINDIR, lib_name);
    plugin_handle = dlopen(buf, RTLD_LAZY);
    if (plugin_handle == NULL) {
      perror("setup_plugins: dlopen");
      exit(1);
    }
  }

  query = get_sym(plugin_handle, "plugin_query");
  (*query)(&num, &names);
  
  if (n_plugins == 0) {
    n_plugins = num;
    plugins = (PLUGIN *)malloc(n_plugins * sizeof(PLUGIN));
  } else {
    n_plugins += num;
    plugins = (PLUGIN *)realloc(plugins, n_plugins * sizeof(PLUGIN));
  }
  if (plugins == NULL) {
    perror("setup_plugins: calloc\n");
    exit(1);
  }
  
  for (i = 0; i < num; i++) {
    sprintf(buf, "plugin_get_%s", names[i]);
    plugins[i].get = get_sym(plugin_handle, buf);
    sprintf(buf, "plugin_is_%s", names[i]);
    plugins[i].check = get_sym(plugin_handle, buf);
    sprintf(buf, "plugin_query_%s", names[i]);
    plugins[i].query = get_sym(plugin_handle, buf);
    free(names[i]);
  }
  free(names);
}

void put_ximage_on_root(ScreenInfo sinfo, XImage *ximg, int width, int height, int PosHFlag,int PosH,int PosVFlag,int PosV)
{
  Pixmap bg_pixmap;
  Screen *screen;
  int sx, sy, x, y;

  screen = DefaultScreenOfDisplay(sinfo.disp);
  sx = WidthOfScreen(screen);
  sy = HeightOfScreen(screen);
	switch(PosHFlag&0xff){
	case PosSet:
		if(PosHFlag&BasedMax)
			x=sx-width-PosH;
		else
			x=PosH;
		break;
	case PosMin:
		x=0;
		break;
	case PosMax:
		x=(sx-width);
		break;
	default:
		x = (sx - width) / 2;
		break;
	}
	switch(PosVFlag&0xff){
	case PosSet:
		if(PosHFlag&BasedMax)
			y=sy-height-PosV;
		else
			y=PosV;
		break;
	case PosMin:
		y=0;
		break;
	case PosMax:
		y=(sy-height);
		break;
	default:
		y = (sy - height) / 2;
		break;
	}
  
  bg_pixmap = XCreatePixmap(sinfo.disp, sinfo.rootwin, sx, sy, sinfo.vinfo.depth);
  XSetWindowBackgroundPixmap(sinfo.disp, sinfo.rootwin, bg_pixmap);
  XPutImage(sinfo.disp, bg_pixmap, sinfo.gc, ximg, 0, 0, x, y, width, height);
  XClearWindow(sinfo.disp, sinfo.rootwin);
}

/* end of file */
