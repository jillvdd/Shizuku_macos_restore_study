/*
 * lfview.h
 * 1998/3/11 by TF
 */
#ifndef ___INCLUDE_LFVIEW_H
#define ___INCLUDE_LFVIEW_H

/*
 * defines
 */
#define LFG_IMG 0
#define LF2_IMG 1
#define GRP_HATSUNE_IMG 2

#define FORWARD 0
#define BACKWARD 1

#define FILE_MODE 0
#define ARCHIVE_MODE 1

#define MAX_IMG 60

#define USAGE "Usage: %s [-root] [-geometry HPos[VPos]] [-a LEAF-archive-file] files ...\n"\
	"HPos: +Number : Left space is Number\n"\
	"      -Number : Right space is Number\n"\
	"      +left   : Left space is zero(same '+0')\n"\
	"      +center : Left space and right space is same(default)\n"\
	"      +right  : Right space is zero(same '-0')\n"\
	"VPos: +Number : Top space is Number\n"\
	"      -Number : Bottom space is Number\n"\
	"      +top    : Top space is zero(same '+0')\n"\
	"      +center : Top space and bottom space is same(default)\n"\
	"      +bottom : Bottom space is zero(same '-0')\n"\
	"Key: space: next image\n"\
	"     backspace: previous image\n"\
	"     q: quit\n"

/*
 * function prototypes
 */

/* mask.c */
Pixmap create_mask(Display *, int, int, int *, int);

#endif
