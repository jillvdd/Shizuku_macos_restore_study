/*
 * cp_grp.h
 * 1999/5/7 by TF
 */

#ifndef ___INCLUDE_CP_GRP_H
#define ___INCLUDE_CP_GRP_H

#include "hat_grp.h"

GRP *read_cgrp(const char *);
GRP *read_cgrp_from_data(unsigned char *, int, unsigned char *, int);
void cgrp_free(GRP *);

#endif
