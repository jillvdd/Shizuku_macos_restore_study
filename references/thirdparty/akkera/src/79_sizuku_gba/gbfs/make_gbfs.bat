@echo off

cd data

if not exist MAX_DATA.PAK goto err
if not exist leafpak.exe goto err
if not exist LFGBMP.EXE goto err

leafpak e MAX_DATA.PAK
del *.KNJ
del *.P16

call _make_snd.bat
call _make_scn.bat
call _make_img.bat

if not exist tr_002.8ad goto b2

gbfs.exe ..\test.gbfs *.dat *.img *.8ad
goto be

:b2
gbfs.exe ..\test.gbfs *.dat *.img

:be
del *.DAT 2> nul
del *.8ad 2> nul
del decomp.wav 2> nul
del *.LFG 2> nul
del *.img 2> nul
del *.BMP 2> nul


echo done!
pause
goto end

:err
echo 　※指定されたファイルが見つかりませんでした。
echo 　　処理を中止します。
pause

:end
