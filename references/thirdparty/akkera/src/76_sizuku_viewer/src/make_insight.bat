@echo off
set SDLDIR=C:\devkitPro\vba\1.7.2-SDL-Win32
set GDBDIR=C:\devkitPro\insight\bin
set DEBUG=1

:loop
del Test.gba
make -f makefile.txt
if exist test.gba goto run

:miss
pause
cls
goto loop

:run
start %SDLDIR%\VisualBoyAdvance-SDL.exe -Gtcp -2 Test.elf
start %GDBDIR%\arm-eabi-insight.exe Test.elf
pause
goto loop
