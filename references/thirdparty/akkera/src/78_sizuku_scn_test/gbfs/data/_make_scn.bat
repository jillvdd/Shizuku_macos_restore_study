@echo off

leafpak e MAX_DATA.PAK
del *.KNJ
del *.P16
del *.LFG

rem python scndec.py
scndec.exe
