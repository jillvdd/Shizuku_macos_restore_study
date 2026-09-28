@echo off

bin2s sjis2leaf.txt > sjis2leaf.s
bin2s mplus_sfnt.txt > mplus_sfnt.s
bin2s null.8ad > null8ad.s


git mplus_s10r.bmp -fmplus_s10r.git


git spr.bmp -ffspr.git
git k12x10w.bmp -fk12x10w.git
git k12x10g.bmp -fk12x10g.git
