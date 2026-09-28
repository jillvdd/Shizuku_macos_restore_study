
#ifndef	SOUND_H
#define SOUND_H
#ifdef __cplusplus
extern "C" {
#endif

#define SOUNDCNT_L	*(volatile u16*)0x4000080
#define SOUNDCNT_H	*(volatile u16*)0x4000082
#define SOUNDCNT_X	*(volatile u16*)0x4000084
#define SOUNDBIAS	*(volatile u16*)0x4000088


#define FIFO_A		0x40000A0
#define FIFO_B		0x40000A4



  //SOUNDCNT_L
#define ENABLE_SOUND1_LEFT		0x1000
#define ENABLE_SOUND2_LEFT		0x2000
#define ENABLE_SOUND3_LEFT		0x4000
#define ENABLE_SOUND4_LEFT		0x8000

#define ENABLE_SOUND1_RIGHT		0x0100
#define ENABLE_SOUND2_RIGHT		0x0200
#define ENABLE_SOUND3_RIGHT		0x0400
#define ENABLE_SOUND4_RIGHT		0x0800



  //SOUNDCNT_H
#define RESET_DSOUND_A			0x0800
#define DSOUND_A_TIMER0			0x0000
#define DSOUND_A_TIMER1			0x0400
#define ENABLE_DSOUND_A_LEFT	0x0200
#define ENABLE_DSOUND_A_RIGHT	0x0100
#define DSOUND_A_FULL_OUTPUT	0x0004

#define RESET_DSOUND_B			0x8000
#define DSOUND_B_TIMER0			0x0000
#define DSOUND_B_TIMER1			0x4000
#define ENABLE_DSOUND_B_LEFT	0x2000
#define ENABLE_DSOUND_B_RIGHT	0x1000
#define DSOUND_B_FULL_OUTPUT	0x0008

  //SOUNDCNT_X
#define ENABLE_SOUND_MASTER		0x0080
#define ENABLE_SOUND1			0x0001
#define ENABLE_SOUND2			0x0002
#define ENABLE_SOUND3			0x0004
#define ENABLE_SOUND4			0x0008

#ifdef __cplusplus
}
#endif
#endif
