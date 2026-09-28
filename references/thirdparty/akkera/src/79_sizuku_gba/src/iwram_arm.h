
#ifndef IWRAM_ARM_H
#define IWRAM_ARM_H

#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
#define MAX_DMA_CHAIN			10

//---------------------------------------------------------------------------
typedef struct {
	u32 src;
	u32 dst;
	u16 size;
	u16 mode;
} ST_DMA;


typedef struct {
	u16    cnt;
	ST_DMA buf[MAX_DMA_CHAIN];
} ST_DMA_CHAIN;

//---------------------------------------------------------------------------
IWRAM_CODE void IRQUserHandler();
IWRAM_CODE void Mode3DrawImage2(u16 sx, u16 sy, u16 cx, u16 cy, u16* img);




IWRAM_CODE void DMAChainInit();
IWRAM_CODE void DMAChainAdd(u32 src, u32 dst, u16 size, u16 mode);
IWRAM_CODE void DMAChainTransfer();


#ifdef __cplusplus
}
#endif
#endif

