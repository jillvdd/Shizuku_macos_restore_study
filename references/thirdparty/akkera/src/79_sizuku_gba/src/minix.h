
#ifndef PRINTF_H
#define PRINTF_H
#ifdef __cplusplus
extern "C" {
#endif

//===========================================================================
typedef char* va_list;

#ifndef _SIZE_T
#define _SIZE_T
typedef unsigned int size_t;
#endif

//===========================================================================
#define	TRACEOUT			_Printf
//#define TRACEOUT(...)

//===========================================================================

EWRAM_CODE u8    _Strlen(u8* str);
EWRAM_CODE u8*   _Strcpy(u8* ret, u8* s2);
EWRAM_CODE u8*   _Strncpy(u8* ret, u8* s2, u32 size);
EWRAM_CODE u8*   _Strcat(u8* ret, u8* s2);
EWRAM_CODE s8    _Strcmp(u8* s1, u8* s2);
EWRAM_CODE s8    _Strncmp(u8* s1, u8* s2, u32 size);
EWRAM_CODE u8*   _Memcpy(u8* s1, u8* s2, u32 size);
EWRAM_CODE s8    _Memcmp(u8* s1, u8* s2, u32 size);
EWRAM_CODE u8*   _Memset(u8* s, u8 c, u32 size);
EWRAM_CODE u32   _Atoi(u8* s);
EWRAM_CODE void* _Bsearch(void* key, void* base, size_t nmemb, size_t size, int (*compar)(void* , void*));


EWRAM_CODE void  _Puts(char* str);
EWRAM_CODE void  _Putc(char c);
EWRAM_CODE int   _Printf(char* format, ...);
EWRAM_CODE int   _Sprintf(char* buf, char* format, ...);


EWRAM_CODE int   _DoPrnt(char* buf, char* fmt, va_list ap);
EWRAM_CODE char* _O_print(va_list* ap, int flags, char* s, char c, int precision, int is_signed);
EWRAM_CODE char* _Gnum(char* f, int* ip, va_list* app);
EWRAM_CODE char* _I_compute(unsigned long val, int base, char* s, int nrdigits);


#ifdef __cplusplus
}
#endif
#endif

