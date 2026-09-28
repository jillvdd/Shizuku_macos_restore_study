copy %1.wav tmp1.wav > nul

sox.exe tmp1.wav -c 1 -r 13379 tmp2.wav
wav28ad.exe tmp2.wav %1.8ad

del tmp1.wav
del tmp2.wav
