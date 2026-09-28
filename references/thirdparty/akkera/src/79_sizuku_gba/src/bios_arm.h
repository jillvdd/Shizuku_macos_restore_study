
#ifndef	BIOS_ARM_H
#define	BIOS_ARM_H
#ifdef __cplusplus
extern "C" {
#endif

#include "header\gba.h"

#define CPUSET_SRC_FIX		(1<<24)
#define CPUSET_16BIT		(0<<26)
#define CPUSET_32BIT		(1<<26)

IWRAM_CODE void LZ77UnCompWram(void *Srcp, void *Destp);
IWRAM_CODE void LZ77UnCompVram(void *Srcp, void *Destp);
IWRAM_CODE void CpuSet(u32 src, u32 dst, u32 flag);
IWRAM_CODE void CpuFastSet(u32 src, u32 dst, u32 flag);

/*
0x0B	CpuSet
	ソースアドレスから 指定したアドレスに 16-bitの値をコピーします (DMAの様に)
	Input: R0=source, R1=dest, R2=count and flags

	Input: r0 = source address, r1 = dest address,
	r2 = Length and mode:
	bit 24 = Fixed source address (0 - copy, 1 = set with word at r0)
	bit 26 = 32 or 16 bit transfer (0=16bit,1=32bit)
	bits 15 - 0 = number of transfers 


0x0C	CpuFastSet
	ソースアドレスから 指定したアドレスに 32-bitの値をコピーします (DMAの様に)
	Input: R0=source, R1=dest, R2=count and flags

	Also performs a memory transfer, in 32-byte blocks, using LDMIA/STMIA instructions
	Performs a memory transfer.
	Input: r0 = source address, r1 = dest address 
	r2 = Length and mode:
	bit 24 = Fixed source address (0 - copy, 1 = set with word at r0)
	bits 15 - 0 = number of transfers 
*/

#ifdef __cplusplus
}
#endif
#endif

