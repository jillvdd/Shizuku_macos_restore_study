/* libgbfs.c
   access object in a GBFS file

Copyright 2002-2004 Damian Yerrick

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

*/


/* This code assumes a LITTLE ENDIAN target.  It'll need a boatload
   of itohs and itohl calls if converted to run on Sega Genesis.  It
   also assumes that the target uses 16-bit short and 32-bit longs.
*/


//---------------------------------------------------------------------------
//typedef unsigned short u16;
//typedef unsigned long u32;
//#include <stdlib.h>
//#include <string.h>
#include "inc.h"
#include "minix.h"
#include "gbfs.h"

/* change this to the end of your ROM, or to 0x02040000 for multiboot */
#define GBFS_1ST_SEARCH_LIMIT ((const u32 *)0x02040000)
#define GBFS_2ND_SEARCH_START ((const u32 *)0x08000000)
#define GBFS_2ND_SEARCH_LIMIT ((const u32 *)0x0a000000)

/* a power of two, less than or equal to the argument passed to
   padbin.  Increasing the stride makes find_first_gbfs_file()
   faster at the cost of a slightly larger binary. */
#define GBFS_ALIGNMENT 256



//---------------------------------------------------------------------------
EWRAM_CODE const GBFS_FILE *find_first_gbfs_file(const void *start)
{
	/* align the pointer */
	const u32 *here = (const u32 *)((unsigned long)start & (-GBFS_ALIGNMENT));
	static char rest_of_magic[] = "ightGBFS\r\n\x1a\n";

	/* Linear-search first in multiboot space. */
	while(here < GBFS_1ST_SEARCH_LIMIT)
	{
		/* We have to keep the magic code in two pieces; otherwise,
		   this function may find itself and think it's a GBFS file.
		   This obviously won't work if your compiler stores this
		   numeric literal just before the literal string, but Devkit
		   Advance R4 and R5 seem to keep numeric constant pools
		   separate enough from string pools for this to work.
		*/

		if(*here == 0x456e6950)				/* ASCII code for little endian "PinE" */
		{
			/* We've matched the first four bytes.
			   If the rest of the magic matches, then we've found a file. */

			if(!_Memcmp((u8*)here + 4, (u8*)rest_of_magic, 12))
			{
				return (const GBFS_FILE *)here;
			}
		}
		here += GBFS_ALIGNMENT / sizeof(*here);
	}


	if(here < GBFS_2ND_SEARCH_START)
	{
		/* Now search in ROM space. */
		here = GBFS_2ND_SEARCH_START;
	}

	while(here < GBFS_2ND_SEARCH_LIMIT)
	{
		if(*here == 0x456e6950)				/* ASCII code for little endian "PinE" */
		{
			if(!_Memcmp((u8*)here + 4, (u8*)rest_of_magic, 12))
			{
				return (const GBFS_FILE *)here;
			}
		}

		here += GBFS_ALIGNMENT / sizeof(*here);
	}

	return 0;
}
//---------------------------------------------------------------------------
EWRAM_CODE const void *skip_gbfs_file(const GBFS_FILE *file)
{
	return ((char *)file + file->total_len);
}
//---------------------------------------------------------------------------
EWRAM_CODE static int namecmp(const void *a, const void *b)
{
	return _Memcmp((u8*)a, (u8*)b, 24);
}
//---------------------------------------------------------------------------
EWRAM_CODE const void *gbfs_get_obj(const GBFS_FILE *file, const char *name, u32 *len)
{
	char  key[24] = {0};
	_Strncpy((u8*)key, (u8*)name, 24);

	const  GBFS_ENTRY *dirbase = (const GBFS_ENTRY *)((const char *)file + file->dir_off);
	size_t n_entries = file->dir_nmemb;
	const  GBFS_ENTRY *here = _Bsearch(key, (void*)dirbase, n_entries, sizeof(GBFS_ENTRY), (void*)namecmp);


	if(!here)
	{
		return NULL;
	}

	if(len)
	{
		*len = here->len;
	}

	return (char *)file + here->data_offset;
}
//---------------------------------------------------------------------------
EWRAM_CODE const void *gbfs_get_nth_obj(const GBFS_FILE *file, size_t n, char *name, u32 *len)
{
	const GBFS_ENTRY *dirbase = (const GBFS_ENTRY *)((const char *)file + file->dir_off);
	size_t n_entries = file->dir_nmemb;
	const GBFS_ENTRY *here = dirbase + n;

	if(n >= n_entries)
	{
		return NULL;
	}

	if(name)
	{
		_Strncpy((u8*)name, (u8*)here->name, 24);
		name[24] = 0;
	}

	if(len)
	{
		*len = here->len;
	}

	return (char *)file + here->data_offset;
}
//---------------------------------------------------------------------------
EWRAM_CODE void *gbfs_copy_obj(void *dst, const GBFS_FILE *file, const char *name)
{
	u32 len;
	const void *src = gbfs_get_obj(file, name, &len);

	if(!src)
	{
		return NULL;
	}

	_Memcpy((u8*)dst, (u8*)src, len);

	return dst;
}
//---------------------------------------------------------------------------
EWRAM_CODE size_t gbfs_count_objs(const GBFS_FILE *file)
{
	return file ? file->dir_nmemb : 0;
}

