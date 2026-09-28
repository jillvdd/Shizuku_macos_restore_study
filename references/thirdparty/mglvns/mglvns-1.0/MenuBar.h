/*
 * MenuBar
 * $Id: MenuBar.h,v 1.1 2002/07/29 05:24:38 go Exp $
 */
#ifndef __MenuBar_h
#define __MenuBar_h

#include <X11/Composite.h>

typedef struct _MenuBarClassRec *MenuBarWidgetClass;
typedef struct _MenuBarRec *MenuBarWidget;
extern WidgetClass menuBarWidgetClass;

/* public functions */
void XtMenuBarWidgetAddMenu(MenuBarWidget fssw, Widget menu);

#endif

