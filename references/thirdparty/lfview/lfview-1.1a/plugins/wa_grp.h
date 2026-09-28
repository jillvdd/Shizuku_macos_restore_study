/*
 * wa_grp.h
 * 1998/6/17 by TF
 */

#ifndef ___INCLUDE_WA_GRP_H
#define ___INCLUDE_WA_GRP_H

#include "hat_grp.h"

GRP *read_wgrp(const char *);
GRP *read_wgrp_from_data(unsigned char *, int, unsigned char *, int);
void wgrp_free(GRP *);

#endif
