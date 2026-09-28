
#ifndef RAND_H
#define RAND_H
#ifdef __cplusplus
extern "C" {
#endif


EWRAM_CODE void _Srand(u32 s);
EWRAM_CODE u32  _Rand(void);


#ifdef __cplusplus
}
#endif
#endif

