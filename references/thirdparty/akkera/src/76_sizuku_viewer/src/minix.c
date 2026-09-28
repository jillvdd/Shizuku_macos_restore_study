//MINIX 2.0.4のソースコード を拝借させて頂いています(BSDライセンス)
//http://www.minix3.org/doc/faq.html#legal

#include "inc.h"
#include "div_arm.h"

#include "minix.h"

//===========================================================================
#define	EOF				(-1)
#define __vasz(x)				((sizeof(x)+sizeof(int)-1) & ~(sizeof(int) -1))
#define va_start(ap, parmN)		((ap) = (va_list)&parmN + __vasz(parmN))
#define va_arg(ap, type)		(*((type *)((va_list)((ap) = (void *)((va_list)(ap) + __vasz(type))) - __vasz(type))))
#define va_end(ap)				
#define toupper(c)				(c + ('A' - 'a'))

#define FL_LJUST        0x0001          /* left-justify field */
#define FL_SIGN         0x0002          /* sign in signed conversions */
#define FL_SPACE        0x0004          /* space in signed conversions */
#define FL_ALT          0x0008          /* alternate form */
#define FL_ZEROFILL     0x0010          /* fill with zero's */
#define FL_SHORT        0x0020          /* optional h */
#define FL_LONG         0x0040          /* optional l */
#define FL_LONGDOUBLE   0x0080          /* optional L */
#define FL_WIDTHSPEC    0x0100          /* field width is specified */
#define FL_PRECSPEC     0x0200          /* precision is specified */
#define FL_SIGNEDCONV   0x0400          /* may contain a sign */
#define FL_NOASSIGN     0x0800          /* do not assign (in scanf) */
#define FL_NOMORE       0x1000          /* all flags collected */

//===========================================================================
EWRAM_CODE u8 _Strlen(u8* str)
{
	u8 i = 0;

	while(str[i] != '\0')
	{
		i++;
	}

	return i;
}
//===========================================================================
EWRAM_CODE u8* _Strcpy(u8* ret, u8* s2)
{
	u8* s1 = ret;

	while( (*s1++ = *s2++) != '\0' )
	{
		//EMPTY
	}

	return ret;
}
//===========================================================================
EWRAM_CODE u8* _Strncpy(u8* ret, u8* s2, u32 size)
{
	u8 *s1 = ret;

	if(size == 0)
	{
		goto End;
	}

	while((*s1++ = *s2++) && --size > 0)
	{
		//EMPTY
	}

	if((*--s2 == '\0') && --size > 0)
	{
		do
		{
			*s1++ = '\0';
		
		} while(--size > 0);
	}

End:
	return ret;
}
//===========================================================================
EWRAM_CODE u8* _Strcat(u8* ret, u8* s2)
{
	u8* s1 = ret;

	while (*s1++ != '\0')
	{
		//EMPTY
	}
	s1--;

	while( (*s1++ = *s2++) != '\0' )
	{
		//EMPTY
	}

	return ret;
}
//===========================================================================
EWRAM_CODE s8 _Strcmp(u8* s1, u8* s2)
{
	while(*s1 == *s2++)
	{
		if(*s1++ == '\0')
		{
			return 0;
		}
	}

	if(*s1   == '\0') return -1;
	if(*--s2 == '\0') return  1;

	return (s8)*s1 - (s8)*s2;
}
//===========================================================================
EWRAM_CODE s8 _Strncmp(u8* s1, u8* s2, u32 size)
{
	if(size == 0)
	{
		goto End;
	}

	do {
		if(*s1 != *s2++)
		{
			break;
		}

		if(*s1++ == '\0')
		{
			return 0;
		}

	} while (--size > 0);

	if(size > 0)
	{
		if(*s1   == '\0') return -1;
		if(*--s2 == '\0') return  1;

		return *s1 - *s2;
	}

End:
	return 0;
}
//===========================================================================
EWRAM_CODE u8* _Memcpy(u8* s1, u8* s2, u32 size)
{
	u8* p1 = s1;
	u8* p2 = s2;

	if(size == 0)
	{
		goto End;
	}

	size++;
	while(--size > 0)
	{
		*p1++ = *p2++;
	}

End:
	return s1;
}
//===========================================================================
EWRAM_CODE s8 _Memcmp(u8* s1, u8* s2, u32 size)
{
	u8* p1 = s1;
	u8* p2 = s2;

	if(size)
	{
		size++;
		while(--size > 0)
		{
			if(*p1++ == *p2++)
			{
				continue;
			}

			return (s8)*--p1 - (s8)*--p2;
		}
	}

	return 0;
}
//===========================================================================
EWRAM_CODE u8* _Memset(u8* s, u8 c, u32 size)
{
	u8 *s1 = s;

	if(size == 0)
	{
		goto End;
	}

	size++;
	while(--size > 0)
	{
		*s1++ = c;
	}

End:
	return s;
}
//===========================================================================
EWRAM_CODE u32 _Atoi(u8* s)
{
	u32 num = 0;

	while(*s != '\0')
	{
		num = (*s++ - '0') + num * 10;
	}

	return num;
}
//===========================================================================
EWRAM_CODE void* _Bsearch(void* key, void* base, size_t nmemb, size_t size, int (*compar)(void* , void*))
{
	void* mid_point;
	int   cmp;

	while(nmemb > 0)
	{
		mid_point = (char *)base + size * (nmemb >> 1);

		if((cmp = (*compar)(key, mid_point)) == 0)
		{
			return (void *)mid_point;
		}

		if(cmp >= 0)
		{
			base  = (char *)mid_point + size;
			nmemb = (nmemb - 1) >> 1;
		}
		else
		{
			nmemb >>= 1;
		}
	}

	return (void *)NULL;
}
//===========================================================================
//VBAのデバックログを出力します
EWRAM_CODE void _Puts(char* str)
{
#if defined ( __thumb__ )
//THUMB code
    asm volatile("mov r0, %0;"
                 "swi 0xff;"
                 : // no ouput
                 : "r" (str)
                 : "r0");
#else
//ARM code
     asm volatile("mov r0, %0;"
                  "swi 0xff0000;"
                  : // no ouput
                  : "r" (str)
                  : "r0");
#endif
}
//===========================================================================
EWRAM_CODE void _Putc(char c)
{
	char str[2];

	str[0] = c;
	str[1] = '\0';

	_Puts(str);
}
//===========================================================================
EWRAM_CODE int _Printf(char* format, ...)
{
	va_list ap;
	char    buf[256];
	int     retval;

	va_start(ap, format);
	retval = _DoPrnt(buf, format, ap);
	va_end(ap);

	_Puts(buf);

	return retval;
}
//===========================================================================
EWRAM_CODE int _Sprintf(char* buf, char* format, ...)
{
	va_list ap;
	int     retval;

	va_start(ap, format);
	retval = _DoPrnt(buf, format, ap);
	va_end(ap);

	return retval;
}
//===========================================================================
EWRAM_CODE int _DoPrnt(char* str, char* fmt, va_list ap)
{
	char*			s;
	int				i, j;
	volatile int	zfill;
	int				c, width, precision=0, flags, between_fill;
	int				nrchars=0;
	const char*		oldfmt;
	char			*s1, buf[256];

	while ((c = *fmt++) != NULL)
	{
		if (c != '%')
		{
			*str++ = c;
			nrchars++;
			continue;
		}
		flags = 0;
		do {
			switch(*fmt) {
			case '-':	flags |= FL_LJUST;	break;
			case '+':	flags |= FL_SIGN;	break;
			case ' ':	flags |= FL_SPACE;	break;
			case '#':	flags |= FL_ALT;	break;
			case '0':	flags |= FL_ZEROFILL; break;
			default:	flags |= FL_NOMORE;	continue;
			}
			fmt++;
		} while(!(flags & FL_NOMORE));

		oldfmt = fmt;
		fmt = _Gnum(fmt, &width, &ap);
		if (fmt != oldfmt) flags |= FL_WIDTHSPEC;

		if (*fmt == '.') {
			fmt++; oldfmt = fmt;
			fmt = _Gnum(fmt, &precision, &ap);
			if (precision >= 0) flags |= FL_PRECSPEC;
		}

		if ((flags & FL_WIDTHSPEC) && width < 0) {
			width = -width;
			flags |= FL_LJUST;
		}
		if (!(flags & FL_WIDTHSPEC)) width = 0;

		if (flags & FL_SIGN) flags &= ~FL_SPACE;

		if (flags & FL_LJUST) flags &= ~FL_ZEROFILL;


		s = s1 = buf;

		switch (*fmt) {
		case 'h':	flags |= FL_SHORT; fmt++; break;
		case 'l':	flags |= FL_LONG; fmt++; break;
		case 'L':	flags |= FL_LONGDOUBLE; fmt++; break;
		}

		switch (c = *fmt++) {
		default:
			*str++ = c;
			nrchars++;
			continue;
		case 'n':
			if (flags & FL_SHORT)
				*va_arg(ap, short *) = (short) nrchars;
			else if (flags & FL_LONG)
				*va_arg(ap, long *) = (long) nrchars;
			else
				*va_arg(ap, int *) = (int) nrchars;
			continue;
		case 's':
			s1 = va_arg(ap, char *);
			if (s1 == NULL)
				s1 = "(null)";
			s = s1;
			while (precision || !(flags & FL_PRECSPEC)) {
				if (*s == '\0')
					break;
				s++;
				precision--;
			}
			break;
		case 'b':
		case 'o':
		case 'u':
		case 'x':
		case 'X':
			if (!(flags & FL_PRECSPEC)) precision = 1;
			else if (c != 'p') flags &= ~FL_ZEROFILL;
			s = _O_print(&ap, flags, s, c, precision, 0);
			break;
		case 'd':
		case 'i':
			flags |= FL_SIGNEDCONV;
			if (!(flags & FL_PRECSPEC)) precision = 1;
			else flags &= ~FL_ZEROFILL;
			s = _O_print(&ap, flags, s, c, precision, 1);
			break;
		case 'c':
			*s++ = va_arg(ap, int);
			break;
/*
#ifndef NOFLOAT
		case 'G':
		case 'g':
			if ((flags & FL_PRECSPEC) && (precision == 0))
				precision = 1;
		case 'f':
		case 'E':
		case 'e':
			if (!(flags & FL_PRECSPEC)) 
				precision = 6;

			if (precision >= sizeof(buf))
				precision = sizeof(buf) - 1;

			flags |= FL_SIGNEDCONV;
			s = _f_print(&ap, flags, s, c, precision);
			break;
#endif	//NOFLOAT
*/
//		case 'r':
//			ap = va_arg(ap, va_list);
//			fmt = va_arg(ap, char *);
//			continue;
		}
		zfill = ' ';
		if (flags & FL_ZEROFILL) zfill = '0';
		j = s - s1;

		/* between_fill is true under the following conditions:
		 * 1- the fill character is '0'
		 * and
		 * 2a- the number is of the form 0x... or 0X...
		 * or
		 * 2b- the number contains a sign or space
		 */
		between_fill = 0;
		if ((flags & FL_ZEROFILL)
		    && (((c == 'x' || c == 'X') && (flags & FL_ALT))
			|| (c == 'p')
			|| ((flags & FL_SIGNEDCONV)
			    && ( *s1 == '+' || *s1 == '-' || *s1 == ' '))))
		{
			between_fill++;
		}

		if ((i = width - j) > 0)
		{
			if (!(flags & FL_LJUST))		/* right justify */
			{
				nrchars += i;

				if (between_fill)
				{
					if (flags & FL_SIGNEDCONV)
					{
						j--; nrchars++;
						*str++ = *s1++;
					}
					else
					{
						j -= 2; nrchars += 2;
						*str++ = *s1++;
						*str++ = *s1++;
				    }
				}

				do
				{
					*str++ = zfill;
				} while (--i);
			}
		}

		nrchars += j;
		while (--j >= 0)
		{
			*str++ = *s1++;
		}

		if (i > 0) nrchars += i;
		while (--i >= 0)
		{
			*str++ = zfill;
		}
	}

	*str++ = '\0';

	return nrchars;
}
//===========================================================================
/* _Gnum() is used to get the width and precision fields of a format. */
EWRAM_CODE char* _Gnum(char* f, int* ip, va_list* app)
{
	register int	i, c;

	if (*f == '*') {
		*ip = va_arg((*app), int);
		f++;
	} else {
		i = 0;
		while ((c = *f - '0') >= 0 && c <= 9) {
			i = i*10 + c;
			f++;
		}
		*ip = i;
	}
	return f;
}
//===========================================================================
/* print an ordinal number */
EWRAM_CODE char* _O_print(va_list* ap, int flags, char* s, char c, int precision, int is_signed)
{
	long signed_val;
	unsigned long unsigned_val;
	char *old_s = s;
	int base = 0;

	switch (flags & (FL_SHORT | FL_LONG)) {
	case FL_SHORT:
		if (is_signed) {
			signed_val = (short) va_arg(*ap, int);
		} else {
			unsigned_val = (unsigned short) va_arg(*ap, unsigned);
		}
		break;
	case FL_LONG:
		if (is_signed) {
			signed_val = va_arg(*ap, long);
		} else {
			unsigned_val = va_arg(*ap, unsigned long);
		}
		break;
	default:
		if (is_signed) {
			signed_val = va_arg(*ap, int);
		} else {
			unsigned_val = va_arg(*ap, unsigned int);
		}
		break;
	}

	if (is_signed) {
		if (signed_val < 0) {
			*s++ = '-';
			signed_val = -signed_val;
		} else if (flags & FL_SIGN) *s++ = '+';
		else if (flags & FL_SPACE) *s++ = ' ';
		unsigned_val = signed_val;
	}
	if ((flags & FL_ALT) && (c == 'o')) *s++ = '0';
	if (!unsigned_val) {
		 if (!precision)
			return s;
	} else if (((flags & FL_ALT) && (c == 'x' || c == 'X'))
		    || c == 'p') {
		*s++ = '0';
		*s++ = (c == 'X' ? 'X' : 'x');
	}

	switch (c) {
	case 'b':	base = 2;	break;
	case 'o':	base = 8;	break;
	case 'd':
	case 'i':
	case 'u':	base = 10;	break;
	case 'x':
	case 'X':
	case 'p':	base = 16;	break;
	}

	s = _I_compute(unsigned_val, base, s, precision);

	if (c == 'X')
		while (old_s != s) {
			*old_s = toupper(*old_s);
			old_s++;
		}

	return s;
}
//===========================================================================
EWRAM_CODE char* _I_compute(unsigned long val, int base, char* s, int nrdigits)
{
	int c;

	c   = _UMod(val, base);
	val = _Div(val, base);

	if (val || nrdigits > 1)
		s = _I_compute(val, base, s, nrdigits - 1);
	*s++ = (c>9 ? c-10+'a' : c+'0');

	return s;
}
