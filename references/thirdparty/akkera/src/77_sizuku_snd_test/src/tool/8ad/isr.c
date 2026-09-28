/* isr.c
   Generic interrupt service routine for GBA

Copyright 2003 Damian Yerrick

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
volatile int retraces = 0;
volatile int keypresses = 0;
volatile int want_reset = 0;

#include "pin8gba.h"

void isr(void)
{
  unsigned int interrupts = INTACK;

  INTENABLE = 0;

  if(interrupts & INT_VBLANK)
  {
    retraces++;
  }
  if(interrupts & INT_JOY)
  {
    keypresses++;
  }
  if(interrupts & INT_TIMER(1))  /* timer 1 done: done. */
  {
    TIMER[0].control = 0;
    DMA[1].control = 0;
  }

  if(want_reset)
  {
    asm volatile ("mov r0,#0x8c; bx r0" ::: "r0", "r1", "r2", "r3");
  }

  BIOS_INTACK = interrupts;
  INTACK = interrupts;
  INTENABLE = 1;
}
