/*
 * $Id: sarpack.h,v 1.1 2002/07/29 05:24:39 go Exp $
 */


#ifndef __SARPACK_H
#define __SARPACK_H

typedef struct {

	u_char *addr;      /* 先頭アドレス         */
	size_t size;       /* サイズ               */
	int file_num;      /* パック中のファイル数 */

	struct FileInfo {
		char *name;    /* ファイル名                   */
		off_t pos;     /* ファイル先頭からのオフセット */
		size_t len;    /* ファイルのサイズ             */
	} *files;

} SarPack;

extern SarPack *sarpack_new(const char *packname);
extern void     sarpack_delete(SarPack *);

extern int sarpack_find(SarPack *p, const char *name);
extern u_char *sarpack_extract(SarPack *p, int index, size_t *sizeret);

#endif







