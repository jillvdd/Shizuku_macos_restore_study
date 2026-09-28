@echo off

cd data

if not exist MAX_DATA.PAK goto err

call _make_snd.bat
call _make_scn.bat

if not exist tr_002.8ad goto b2

gbfs.exe ..\test.gbfs *.dat *.8ad
goto be

:b2
gbfs.exe ..\test.gbfs *.dat

:be
del *.DAT 2> nul
del *.8ad 2> nul
del decomp.wav 2> nul

echo done!
pause
goto end

:err
echo 　※MAX_DATA.PAKが見つかりませんでした。
echo 　　処理を中止します。
pause

:end
