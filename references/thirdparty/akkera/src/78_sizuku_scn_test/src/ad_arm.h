
#ifndef AD_ARM_H
#define AD_ARM_H
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define MIXBUF_SIZE				224						//18157Hz = 304  13379Hz = 224
#define SAMPLE_TIME				(280896 / MIXBUF_SIZE)

//---------------------------------------------------------------------------
enum {
	AD_START = 0x01,
	AD_LOOP,
	AD_STOP,
};

//---------------------------------------------------------------------------
IWRAM_CODE void AdInit();

IWRAM_CODE void AdStart(u8* pData, u32 len, bool isLoop);
IWRAM_CODE void AdReStart();
IWRAM_CODE void AdStop();

IWRAM_CODE bool AdIsEndData();
IWRAM_CODE bool AdIsLoop();

IWRAM_CODE void AdBufferDecode(s8* dst, u8* src, u32 len);
IWRAM_CODE void AdBufferSend();
IWRAM_CODE void AdBufferMixer();
IWRAM_CODE void AdBufferClear();

IWRAM_CODE u8   AdGetStat();
IWRAM_CODE void AdWaitForVsync();

#ifdef __cplusplus
}
#endif
#endif
