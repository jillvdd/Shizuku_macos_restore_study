if not exist %1.wav goto end

sox.exe %1.wav -c 1 -r 13379 tmp.wav
wav28ad.exe tmp.wav %1.8ad
del tmp.wav

:end
