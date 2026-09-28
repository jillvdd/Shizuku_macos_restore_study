@echo off

cd gbfs
if not exist test.gbfs goto err
cd ..
copy /b Test.gba+gbfs\test.gbfs kscn.gba
goto end

:err
echo 　test.gbfsファイルが見つかりませんでした。
echo 　処理を中止します。
pause


:end
