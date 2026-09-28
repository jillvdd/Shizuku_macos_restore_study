#ifndef INCLUDE_LEAF_UTIL_H
#define INCLUDE_LEAF_UTIL_H

#define LONGWORD(a,b,c,d) (((d)<< 24)|((c)<< 16)|((b)<< 8)|(a))
#define WORD(a,b) (((b)<< 8)|(a))

int extract_lz77(unsigned char *, int, unsigned char *, int, int);

#endif /* INCLUDE_LEAF_UTIL_H */

