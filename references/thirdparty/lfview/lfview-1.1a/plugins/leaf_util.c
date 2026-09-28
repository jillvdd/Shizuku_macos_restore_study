#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "leaf_util.h"

/*
 * Decode LZ77 data
 */
int extract_lz77(unsigned char *src, int ssize, unsigned char *result, int rsize, int rbufsize)
{
  int idx = 0;
  int flag, b;
  int d1, d2, d3;
  int i, j, i0;
  int len, pos, m;
  int *ring;

  /* initialize the ring buffer */
  ring = (int *)calloc(rbufsize, sizeof(int));
  if (ring == NULL) {
    perror("calloc");
    exit(1);
  }
  memset(ring, 0, rbufsize * sizeof(int));
  
  /* common part of extraction of the body */
  for (i = 0, b = 0, m = 0; i < rsize;) {
    if (--b < 0) {
      if (idx > ssize) {
	fprintf(stderr, "EOF on reading a flag(%d/%d).\n", i, rsize);
	break;
      }
      flag = src[idx++];
      b = 7;
    }
    
    if (flag & 0x01) {
      /* data */
      if (idx > ssize) {
	fprintf(stderr, "EOF on reading a byte(%d/%d).\n", i, rsize);
	break;
      }
      d1 = src[idx++];
      ring[m++] = result[i++] = d1;
      m &= rbufsize - 1;
    } else {
      d3 = -1;
      /* copy from the ring buffer */
      if (idx > ssize) {
	fprintf(stderr, "EOF on extracting.(%d/%d).\n", i, rsize);
	break;
      }
      d1 = src[idx++];
      if (idx > ssize) {
	fprintf(stderr, "EOF on extracting.(%d/%d).\n", i, rsize);
	break;
      }
      d2 = src[idx++];
      
      /* This format isn't the simple LZ77. */
      if ((d1 & 0x0f) == 0x0f) {
	if (idx > ssize) {
	  fprintf(stderr, "EOF on extracting.(%d/%d).\n", i, rsize);
	  break;
	}
	d3 = src[idx++];
	len = d3 + 18;
	pos = (d1 >> 4) + (d2 << 4);
      } else {
	len = (d1 & 0x0f) + 3;
	pos = (d1 >> 4) + (d2 << 4);
      }

      i0 = i;
      for (j = 0; j < len; j++) {
	result[i++] = ring[pos++];
	pos &= rbufsize - 1;
      }
      for (j = 0; j < len; j++) {
	ring[m++] = result[i0++];
	m &= rbufsize - 1;
      }
    }
    flag = flag >> 1;
  }

  free(ring);

  return 0;
}
