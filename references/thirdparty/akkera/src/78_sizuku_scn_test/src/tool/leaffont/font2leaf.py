import os
import Image

#------------------------------------

f = open('sizfont.txt', 'rb')
x1 = f.read()
f.close()

f = open('k12x10_fnt.txt', 'rb')
x2 = f.read()
f.close()

z1 = Image.open("k12x10.bmp")
z2 = Image.new('RGB', (12*1853, 10) )

#------------------------------------
def getIdx(c1, c2):
    for j in range(0, len(x2), 2):
        if x2[j+0] == c1 and x2[j+1] == c2:
            return j

    print "Err"
    exit()

#------------------------------------
zx = 0;
for i in range(0, len(x1), 2):
    c1  = x1[i+0]
    c2  = x1[i+1]
    idx = getIdx(c1, c2) / 2
    print "[%d --> %d]" % (i, idx)

    box = (idx * 12,0, idx * 12 + 12, 10)
    im  =  z1.crop(box)
    z2.paste(im, (zx*12, 0))
    zx += 1

z2.save('a.bmp', 'BMP')

