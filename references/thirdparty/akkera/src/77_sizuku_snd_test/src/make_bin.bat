@echo off

:loop
del test.gba
make -f makefile.txt

if exist test.gba goto run

:miss
pause
cls
goto loop

:run
padbin 256 Test.gba
copy /b Test.gba+test.gbfs test.mb.gba
test.mb.gba
pause
goto loop

