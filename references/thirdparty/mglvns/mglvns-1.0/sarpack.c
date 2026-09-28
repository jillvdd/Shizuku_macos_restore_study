/*
 * $Id: sarpack.c,v 1.1 2002/07/29 05:24:39 go Exp $
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>

#include "sarpack.h"


void *filemap(const char *path, size_t *size);
void  fileunmap(void *addr, size_t size);

#ifdef MAIN
/* ------------------------------------------------------------------
 * sample main
 */

/*
 * テーブルの内容を表示する
 */
void 
print_table(SarPack *sp)
{
    int             i;
    for (i = 0; i < sp->file_num; i++) {
		printf("%20s  ", sp->files[i].name);
		printf("%08x ", (u_int)sp->files[i].pos);
		printf("%08x ", sp->files[i].len);
		printf("\n");
    }
    printf("%d files.\n", sp->file_num);
}

int
main(int argc, char **argv)
{
    SarPack *sp;
 
    if (argc < 2) {
        fprintf(stderr, "usage: %s packfile\n", argv[0]);
        exit(1);
    }
    
    if ((sp = sarpack_new(argv[1])) == NULL) {
        exit(1);
    }

    print_table(sp);
    sarpack_delete(sp);
    
    return 0;
}
#endif   

/*
 * ファイルテーブルの展開
 */
static void 
extract_table(SarPack * sp)
{
	int i, j;
    u_char *p = sp->addr + 2;
	off_t pos = p[0]<<24 | p[1]<<16 | p[2]<<8 | p[3];

	p = sp->addr + 6;
    for (i = 0; i < sp->file_num; i++) {
		sp->files[i].name = p;
		while (*p != '\0')
			p++;
		p++;
		sp->files[i].pos = pos + (p[0]<<24 | p[1]<<16 | p[2]<<8 | p[3]);
		sp->files[i].len = p[4]<<24 | p[5]<<16 | p[6]<<8 | p[7];
		p += 8;
	}
}

/*
 * ファイルを開いてファイル一覧テーブルを取得する。
 */
SarPack *
sarpack_new(const char *path)
{
    SarPack *sp;
	u_char *addr;
	size_t size;

	if ((addr = filemap(path, &size)) == NULL)
		return NULL;

	/* データ領域確保 */
	if ((sp = malloc(sizeof(SarPack))) == NULL) {
		perror("sarpack_open");
		fileunmap(addr, size);
		return NULL;
	}
	
	sp->addr     = addr;
	sp->size     = size;
	sp->file_num = addr[0]<<8 | addr[1];
	
    /* ファイル用データ領域確保 */
    if ((sp->files = calloc(sizeof(sp->files[0]), sp->file_num)) == NULL) {
        perror("sarpack_open");
        sarpack_delete(sp);
        return NULL;
    }

    /* ファイルテーブルの取得 */
    extract_table(sp);

    return sp;
}

/*
 * Free allocated memories and close file.
 */
void 
sarpack_delete(SarPack * sp)
{
    if (sp) {
        /* マップ解放 */
        fileunmap(sp->addr, sp->size);
        free(sp);
    }
}

int
sarpack_find(SarPack *sp, const char *name)
{
    int i = 0;
    while (i < sp->file_num) {
		if (!strcasecmp(name, sp->files[i].name)) {
			return i;
		}
		i++;
    }
    return -1;
}

u_char *
sarpack_extract(SarPack * sp, int index, size_t *sizeret)
{
    if (sizeret)
        *sizeret = sp->files[index].len;     /* サイズ */
    return sp->addr + sp->files[index].pos;  /* 転送元 */
}
        
