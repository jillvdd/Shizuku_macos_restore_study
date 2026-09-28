/* playad.iwram.c
   8AD decoder and demo

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
#ifndef DEMO
#define DEMO 0
#endif

#define MIXBUF_SIZE 304

#include <stdlib.h>
#include "pin8gba.h"

/* change to "#if 0" for a ROM or "#if 1" for a multiboot */
#if 0
MULTIBOOT
#endif


typedef struct ADGlobals
{
  const unsigned char *data;
  int last_sample;
  int last_index;
} ADGlobals;

ADGlobals ad;


#define SAMPLE_TIME (280896/MIXBUF_SIZE)

static int cur_mixbuf = 0;
static signed char mixbuf[2][MIXBUF_SIZE];


static void dsound_switch_buffers(const signed char *src)
{
  DMA[1].control = 0;

  /* no-op to let DMA registers catch up */
  asm volatile ("eor r0, r0; eor r0, r0" ::: "r0");

  DMA[1].src = src;
  DMA[1].dst = (void *)0x040000a0; /* write to FIFO A address */
  DMA[1].count = 1;
  DMA[1].control = DMA_DSTUNCH | DMA_SRCINC | DMA_REPEAT | DMA_U32 |
                   DMA_SPECIAL | DMA_ENABLE;
}


/* dsound_vblank() *********************
   Call this first in your vblank handler.
*/
void dsound_vblank(void)
{
  dsound_switch_buffers(mixbuf[cur_mixbuf]);
  cur_mixbuf = !cur_mixbuf;
}



void start_ad(const unsigned char *data)
{
  ad.data = data;
  ad.last_sample = 0;
  ad.last_index = 0;
}


__attribute__ ((long_call)) void decode_ad(signed char *dst, const unsigned char *src, unsigned int len);

/* mixer() *****************************
   Call this sometime each frame.
*/
void mixer(void)
{
  decode_ad(mixbuf[cur_mixbuf], ad.data, MIXBUF_SIZE);
  ad.data += MIXBUF_SIZE >> 1;
}


static void set_bias(void)
{
  asm volatile("mov r2, #2; lsl r2, #8; swi 0x19" ::: "r0", "r1", "r2", "r3");
  SETSNDRES(1);
}


void init_sound(void)
{
  TIMER[0].control = 0;
  //turn on sound circuit
  SNDSTAT = SNDSTAT_ENABLE;
  //full volume, enable sound 3 to left and right
  DMGSNDCTRL = DMGSNDCTRL_LVOL(7) | DMGSNDCTRL_RVOL(7) |
               DMGSNDCTRL_LSQR1 | DMGSNDCTRL_RSQR1 | 
               DMGSNDCTRL_LSQR2 | DMGSNDCTRL_RSQR2 | 
               DMGSNDCTRL_LTRI | DMGSNDCTRL_RTRI |
               DMGSNDCTRL_LNOISE | DMGSNDCTRL_RNOISE;
  DSOUNDCTRL = 0x0b0e;
  TIMER[0].count = 0x10000 - SAMPLE_TIME;
  TIMER[0].control = TIMER_16MHZ | TIMER_ENABLE;

  TRICTRL = TRICTRL_2X32 | TRICTRL_BANK(0) | TRICTRL_ENABLE;
  TRILENVOL = 0;
  TRIFREQ = 1046 | FREQ_RESET | FREQ_HOLD;
  SQR1SWEEP = SQR1SWEEP_OFF;
  set_bias();
}




/* DEMO ******************************************/

#if DEMO
/*
MULTIBOOT
*/
#include "gbfs.h"
#include "chr.h"
void isr(void);
#define SCR_MAP 16
ISR saved_isr;
const GBFS_FILE *samples;

#define NUM_PIECES 8

static const char pieces[NUM_PIECES][32] =
{
  "p8d.8gbm",
  "p8demo.8gbm",
  "cthulu.8gbm",
  "idltd.8gbm",
  "kalinka.8gbm",
  "_todwin.8gbm",
  "korobeyniki.8gbm",
  "_gameover.8gbm"
};


static void wait4vbl(void)
{
  asm volatile("mov r2, #0; swi 0x05" ::: "r0", "r1", "r2", "r3");
}


/* upcvt_4bit() ************************
   Convert a 1-bit font to GBA 4-bit format.
*/
void upcvt_4bit(void *dst, const u8 *src, size_t len)
{
  u32 *out = dst;

  for(; len > 0; len--)
  {
    u32 dst_bits = 0;
    u32 src_bits = *src++;
    u32 x;

    for(x = 0; x < 8; x++)
    {
      dst_bits <<= 4;
      dst_bits |= src_bits & 1;
      src_bits >>= 1;
    }
    *out++ = dst_bits;
  }
}


/* itoa_lpad() *************************
   Convert n into a string of len characters, left-padded with
   lpad_chr.  buf points to a buffer of at least (len + 1) chars.
*/
void itoa_lpad(char *buf, size_t len, unsigned int n, int lpad_chr)
{
  buf[len] = 0;
  if(n == 0)
    n = 0;

  /* extract each digit */
  do {
    /* assumes compiler can optimize n % 10 and n / 10 into one op
       also assumes digits appear consecutively in 0123456789 order
       (this is true of ascii) */
    buf[--len] = (n % 10) + '0';
    n = n / 10;
  } while(n && len);

  /* left pad */
  while(len)
    buf[--len] = lpad_chr;
}


/* ntclrline() *************************
   Clear a line of the map.
*/
void ntclrline(u32 nt, u32 y, u32 c)
{
  u32 x;
  u32 *here = (u32 *)(MAP[nt][y]);
  
  /* duplicate c into the high word */
  c &= 0x0000ffff;
  c |= c << 16;

  /* clear the line 2 characters at a time */
  for(x = 16; x > 0; x--)
    *here++ = c;
}


/* nttextout() *************************
   Write the given text to a nametable.
*/
void nttextout(u32 nt, u32 x, u32 y, u32 c, const char *str)
{
  while(*str)
    MAP[nt][y][x++] = (*str++ & 0xff) | c;
}


/* ntcls() *****************************
   Clear the screen.
*/
void ntcls(u32 nt, u32 c)
{
  u32 x;
  u32 *here = (u32 *)(MAP[nt][0]);
  
  /* duplicate c into the high word */
  c &= 0x0000ffff;
  c |= c << 16;

  /* clear the screen 2 characters at a time */
  for(x = 512; x > 0; x--)
    *here++ = c;
}


/* init_all() **************************
   Set up the display.

   VRAM:
     0000  font (16-bit, 256 tiles)
     2000  map (32x32 tiles)

*/
void init_video(void)
{
  LCDMODE = 0 | LCDMODE_BLANK;
  BLENDMODE = 0;
  BGCTRL[0] = BGCTRL_PAT(0) | BGCTRL_16C | BGCTRL_NAME(SCR_MAP) |
              BGCTRL_H32 | BGCTRL_V32;
  BGCTRL[1] = 0;
  BGCTRL[2] = 0;
  BGCTRL[3] = 0;
  BGSCROLL[0].x = 0;
  BGSCROLL[0].y = 0;
  PALRAM[0] = RGB(31, 31, 31);
  PALRAM[1] = RGB(0, 0, 0);

  /* load pattern table */
  upcvt_4bit(VRAM, text_chr, text_chr_len);

  ntcls(SCR_MAP, ' ');

  /* clear OAM and set up a single sprite image */
  {
    const struct OAM_SPRITE hidden = {160, 20, 0, 0};
    u32 x;
    const u32 arrow[8] =
    {
      0x00000000,
      0x00010000,
      0x00100000,
      0x01111111,
      0x00100000,
      0x00010000,
      0x00000000,
      0x00000000
    };
    u32 *spr_vram = (u32 *)0x06010000;

    for(x = 0; x < 128; x++)
      OAM[x] = hidden;
    for(x = 0; x < 8; x++)
      spr_vram[x] = arrow[x];
  }

  wait4vbl();
  LCDMODE = 0 | LCDMODE_BG0 | LCDMODE_SPR;
}


#define ROM_BANKSWITCH (volatile u16 *)(0x096B592E)
#define WRITE_LOC_1 (volatile u16 *)(0x987654*2+0x8000000)
#define WRITE_LOC_2 (volatile u16 *)(0x012345*2+0x8000000)
#define WRITE_LOC_3 (volatile u16 *)(0x007654*2+0x8000000)
#define WRITE_LOC_4 (volatile u16 *)(0x765400*2+0x8000000)
#define WRITE_LOC_5 (volatile u16 *)(0x013450*2+0x8000000)

void reset_gba(void)
{
  unsigned int i;

  INTENABLE = 0;

  /* reset cart bankswitching */
  for(i=0;i<1;i++) *WRITE_LOC_1=0x5354;
  for(i=0;i<500;i++) *WRITE_LOC_2=0x1234;
  for(i=0;i<1;i++) *WRITE_LOC_2=0x5354;
  for(i=0;i<500;i++) *WRITE_LOC_2=0x5678;
  for(i=0;i<1;i++) *WRITE_LOC_1=0x5354;
  for(i=0;i<1;i++) *WRITE_LOC_2=0x5354;
  for(i=0;i<1;i++) *WRITE_LOC_4=0x5678;
  for(i=0;i<1;i++) *WRITE_LOC_5=0x1234;
  for(i=0;i<500;i++) *WRITE_LOC_2=0xabcd;
  for(i=0;i<1;i++) *WRITE_LOC_1=0x5354;   
  *ROM_BANKSWITCH=0;

  /* reset GBA */
  *(u16 *)0x03007ffa = 0;  /* reset to ROM (= 0) rather than RAM (= 1) */
  asm volatile(
    "mov r0, #0xfc  \n"  /* clear everything other than RAM */
    "swi 0x01       \n"
    "swi 0x00       \n"
    ::: "r0", "r1", "r2", "r3");
}


/* swi_3() *****************************
   Call swi 3 to stop the GBA.  Placed in a function wrapper to
   protect it against overzealous compiler optimization.
*/
static void swi_3(void)
{
  asm volatile("swi 0x03");
}

void halt_gba(void)
{
  /* Disable sound.  OMITTED */

  /* Disable video (force blank). */
  wait4vbl();
  LCDMODE = LCDMODE_BLANK;

  /* Disable all interrupts but the joypad. */
  INTENABLE = 0;
  INTMASK = INT_JOY;
  JOYIRQ = JOY_SELECT | JOY_START | JOYIRQ_ALL;
  INTENABLE = 1;

  /* Call swi 0x03 ("Stop") */
  swi_3();

  /* Afterward, software must reinitialize video mode, interrupts,
     and sound.  Turn on at least the basic vblank interrupt handler. */
  INTMASK = INT_VBLANK;
}


#define WSCNT           *(volatile u16 *)0x04000204
#define WSCNT_ROM31     0x0014

int main(void)
{
  unsigned int lj = 0x3ff;
  char buf[16];
  const unsigned char *test_8ad;
  const unsigned char *end;
  char stopped = 0;

  /* set the ISR */
  INTENABLE = 0;
  saved_isr = GET_MASTER_ISR();
  SET_MASTER_ISR(isr);
  /* turn on interrupt sources */
  LCDSTAT = LCDSTAT_VBLIRQ;
  /* turn on interrupt controller */
  INTMASK = INT_VBLANK;
  INTENABLE = 1;
  WSCNT = WSCNT_ROM31;

  samples = find_first_gbfs_file(find_first_gbfs_file);
  if(!samples)
  {
    LCDMODE = 0;
    PALRAM[0] = RGB(31, 0, 0);
    while(1);
  }
  {
    unsigned int len;

    test_8ad = gbfs_get_obj(samples, "demo1.8ad", &len);
    end = len + test_8ad;
  }

  init_video();
  nttextout(SCR_MAP, 1,  5, 0, "ADPCM Demo");
  nttextout(SCR_MAP, 1,  6, 0, "Code © 2003 Damian Yerrick");
  nttextout(SCR_MAP, 1,  7, 0, "This is free software with");
  nttextout(SCR_MAP, 1,  8, 0, "no warranty. Get source code");
  nttextout(SCR_MAP, 1,  9, 0, "at www.pineight.com/gba");
  nttextout(SCR_MAP, 1, 18, 0, "CPU time: ### scanlines");

  init_sound();
  start_ad(test_8ad);

  while(1)
  {
    unsigned int j = JOY ^ 0x3ff;

    wait4vbl();
    dsound_vblank();

    if((j & (JOY_A | JOY_B | JOY_SELECT | JOY_START)) ==
            (JOY_A | JOY_B | JOY_SELECT | JOY_START))
      reset_gba();

    if(j & ~lj & JOY_A)
    {
      start_ad(test_8ad);
      stopped = 0;
    }
    if(j & ~lj & JOY_SELECT)
    {
      halt_gba();
      LCDMODE = 0 | LCDMODE_BG0;
      lj = 0x3ff;
    }

    lj = j;


    j = LCD_Y;
    while(j == LCD_Y);
    j = -LCD_Y;
    if(!stopped)
    {
      if(end > ad.data)
      {
        mixer();
      }
      else
      {
        unsigned int i;

        for(i = 0; i < MIXBUF_SIZE * 2; i++)
          mixbuf[0][i] = 0;
        stopped = 1;
      }
    }

    j += LCD_Y;

    itoa_lpad(buf, 3, j, ' ');
    nttextout(SCR_MAP, 11, 18, 0, buf);
  }
}

#endif
