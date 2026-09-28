# coding: Shift_JIS

import os
import sys
import Image
import struct

path = os.getcwd()

#--------------------------------------------------------------------
exe = 'LFGBMP.EXE'
dir  = os.listdir(path)
lfg = [i for i in dir if i.find('.LFG') != -1]

for i in range(len(lfg)):
     os.system(exe + ' ' + lfg[i])


#--------------------------------------------------------------------
exe  = 'convert.exe'
opt  = ''
dir  = os.listdir(path)
file = [i for i in dir if i.find('.BMP') != -1]

for i in range(len(file)):
     print 'resize ... ' + file[i]
     imgData  = Image.open(file[i])
     iw, ih   = imgData.size

     if iw >= 600:
          opt = "-resize 240x160!";
     else:
          iw  = int((iw * 0.37) + 0.5)
          ih  = int((ih * 0.40) + 0.5)
          if(iw % 2 != 0): iw -= 1
          if(ih % 2 != 0): ih -= 1
          opt = "-resize %dx%d!" % (iw, ih)

#     print exe + ' ' + opt + ' ' + file[i] + ' ' + file[i]
     os.system(exe + ' ' + opt + ' ' + file[i] + ' ' + file[i])


#--------------------------------------------------------------------
exe  = 'git.exe'
opt  = '-ffdeclfg.git'
dir  = os.listdir(path)
file = [i for i in dir if i.find('.BMP') != -1]

for i in range(len(file)):
      print 'bmp2bin ... ' + file[i]
      imgData  = Image.open(file[i])
      iw, ih   = imgData.size

      os.system(exe + ' ' + file[i] + ' ' + opt)

      f = open(file[i][:-4] + ".img.bin", "rb")
      x = f.read()
      f.close()

      f = open(file[i][:-4] + ".img.bin", 'wb')
      f.write(struct.pack('HH', iw, ih))
      f.write(x);
      f.close()
