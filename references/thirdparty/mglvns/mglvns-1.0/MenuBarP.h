/*
 * MenuBar
 * $Id: MenuBarP.h,v 1.1 2002/07/29 05:24:38 go Exp $
 */

#ifndef __MenuBarP_h
#define __MenuBarP_h

#include <X11/IntrinsicP.h>
#include <X11/StringDefs.h>
#include <X11/CompositeP.h>

#include "MenuBar.h"

typedef struct {
	XtPointer extension;
} MenuBarClassPart;

typedef struct _MenuBarClassRec {
  	CoreClassPart             core_class;
	CompositeClassPart        composite_class;
	MenuBarClassPart          menubar_class;
} MenuBarClassRec;

extern MenuBarClassRec fullScreenShellClassRec;

typedef struct _MenuBarPart {
	Widget menubar; /* メニューバー部 */
	int height;     /* メニュー消去限界サイズ */
} MenuBarPart;

typedef struct _MenuBarRec {
	CorePart 	     core;
	CompositePart 	 composite;
	MenuBarPart  menubar;
} MenuBarRec;

/* convinient defines */
#define COREWIDTH  (mbw->core.width)
#define COREHEIGHT (mbw->core.height)
#define MBW        (mbw->menubar)

/* semi public functions */

#endif
