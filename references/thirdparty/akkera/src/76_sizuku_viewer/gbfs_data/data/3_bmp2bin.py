# coding: Shift_JIS

import os
import sys

exe  = 'git.exe'
opt  = '-ffconvert.git'
dir  = os.listdir(os.getcwd() + '\\')
file = [i for i in dir if i.find('.BMP') != -1]

# BMP->PNG
for i in range(len(file)):
      print 'bmp2bin ... ' + file[i]
      os.system(exe + ' ' + file[i] + ' ' + opt)

#      print exe + ' ' + file[i] + ' ' + opt
