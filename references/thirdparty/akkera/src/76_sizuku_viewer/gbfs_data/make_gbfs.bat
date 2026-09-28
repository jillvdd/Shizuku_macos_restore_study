@echo off

cd data

leafpak e MAX_DATA.PAK
del *.KNJ
del *.P16
del *.DAT


rem LFG -> BMP
rem python 1_lfg2bmp.py
1_lfg2bmp.exe
del *.LFG


rem BMP -> BMP(resize)
rem python 2_resize.py
2_resize.exe


rem BMP -> BIN
rem python 3_bmp2bin.py
3_bmp2bin.exe
del *.BMP

rem MAKE GBFS
ren *.bin *.
gbfs.exe ..\test.gbfs *.img
del *.img

echo done!
pause