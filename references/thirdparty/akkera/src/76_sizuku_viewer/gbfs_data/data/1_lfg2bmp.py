# coding: Shift_JIS

import os
import sys

exe = 'LFGBMP.EXE'
dir = os.listdir(os.getcwd() + '\\')
lfg = [i for i in dir if i.find('.LFG') != -1]


# LFG->BMP
for i in range(len(lfg)):
     os.system(exe + ' ' + lfg[i])
