@echo off

bin2s mplus_jfnt.txt > mplus_jfnt.s
bin2s mplus_sfnt.txt > mplus_sfnt.s


git mplus_j10r.bmp -ffconvert.git
git mplus_s10r.bmp -ffconvert.git


git spr.bmp -ffspr.git
