
#ifndef IWRAM_ARM_H
#define IWRAM_ARM_H

#ifdef __cplusplus
extern "C" {
#endif

//---------------------------------------------------------------------------
IWRAM_CODE void IRQUserHandler();

IWRAM_CODE void DMAChainInit();
IWRAM_CODE void DMAChainAdd(u32 src, u32 dst, u16 size, u16 mode);
IWRAM_CODE void DMAChainTransfer();



#ifdef __cplusplus
}
#endif
#endif

