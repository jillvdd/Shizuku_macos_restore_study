@echo off

echo === assets ===
tools\wav28ad sample\chordbasic.wav sample\demo1.8ad
tools\gbfs ad.gbfs text.chr sample\demo1.8ad
tools\bin2h text.chr > chr.h

echo === code ===
arm-agb-elf-gcc -Wall -O -marm -mthumb-interwork -c isr.c
if errorlevel 1 goto end
arm-agb-elf-gcc -Wall -O -marm -mthumb-interwork -c playad.iwram.c -o playad.iwram.o
if errorlevel 1 goto end
arm-agb-elf-gcc -Wall -O -mthumb -mthumb-interwork -o 1.elf -DDEMO isr.o playad.iwram.o playad.c libgbfs.c
if errorlevel 1 goto end
arm-agb-elf-objcopy -O binary 1.elf 1.bin

gbafix -tADPCM_DEMO 1.bin
tools\padbin 256 1.bin
copy /b 1.bin+ad.gbfs playad.gba
start playad.gba

:end
