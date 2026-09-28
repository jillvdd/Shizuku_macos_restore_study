# coding: Shift_JIS

import os
import sys
import Image

exe  = 'convert.exe'
opt1 = '-resize 240x160!'
opt2 = '-resize 37%x40%'
opt  = ''

path = os.getcwd()
dir  = os.listdir(path)
file = [i for i in dir if i.find('.BMP') != -1]

for i in range(len(file)):
     print 'resize ... ' + file[i]
     imgData  = Image.open(file[i])
     iw, ih   = imgData.size

     if iw >= 600:
          opt = opt1;
     else:
          opt = opt2;

     os.system(exe + ' ' + opt + ' ' + file[i] + ' ' + file[i])
#     print exe + ' ' + opt + ' ' + file[i] + ' ' + file[i]
