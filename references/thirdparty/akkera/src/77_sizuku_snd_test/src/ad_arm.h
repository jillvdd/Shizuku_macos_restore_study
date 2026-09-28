
#ifndef AD_ARM_H
#define AD_ARM_H
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define MIXBUF_SIZE				224			//18157Hz = 304  13379Hz = 224
#define SAMPLE_TIME				(280896 / MIXBUF_SIZE)

//---------------------------------------------------------------------------
enum {
	AD_START  = 0x01,
	AD_LOOP,
	AD_STOP,
};
//---------------------------------------------------------------------------
typedef struct ADGlobals
{
	u8  stat;
	u8* data;
	u8* dataSt;
	u8* end;
	s16 last_sample;
	s32 last_index;
	u32 cur_mixbuf;
	s8  mixbuf[2][MIXBUF_SIZE];
} ADGlobals;

//---------------------------------------------------------------------------
IWRAM_CODE void AdInit();

IWRAM_CODE void AdStart(u8* pData, u32 len, bool isLoop);
IWRAM_CODE void AdReStart();
IWRAM_CODE void AdEnd();

IWRAM_CODE bool AdIsEndData();
IWRAM_CODE bool AdIsLoop();
IWRAM_CODE void AdClearBuffer();

IWRAM_CODE void AdDecode(s8* dst, u8* src, u32 len);
IWRAM_CODE void AdBuffer(s8* src);
IWRAM_CODE void AdVblank();
IWRAM_CODE void AdMixer();


#ifdef __cplusplus
}
#endif
#endif
