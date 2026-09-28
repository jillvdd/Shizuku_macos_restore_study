import os
import struct

#-------------------------------
#LZSS decode
def decode(src, dst, size):
    Index = 0xfee
    buf   = [0x00] * 0x1011

    i = 0
    j = 0

    FlagCount = 0
    Flag      = 0x00
    LFlag     = 0x0000
    Len       = 0
    LIndex    = 0x0000

    while size > 0:
        if FlagCount > 0:
            FlagCount -= 1
            Flag <<= 1
        else:
            Flag = ~ord(src[i]) & 0xff
            i += 1
            FlagCount = 7

        if Flag & 0x80:
#            print "i=%d j=%d src=%d dst=%d" % (i, j, len(src), len(dst))
            dst[j] = ~ord(src[i]) & 0xff
            buf[Index] = dst[j]

            Index = (Index + 1) & 0x0fff
            i += 1
            j += 1
            size -= 1
        else:
            LFlag = ~( ord(src[i]) + (ord(src[i+1]) << 8) ) & 0xffff
            i += 2
            
            Len   = (LFlag & 0xf) + 3
            size -= Len

            LIndex = LFlag >> 4

            while Len > 0:
                Len -= 1

                dst[j] = buf[LIndex]
                buf[Index] = dst[j]

                j += 1
                LIndex = (LIndex + 1) & 0x0fff
                Index  = (Index  + 1) & 0x0fff

#-------------------------------
def resize(src):
    t = len(src) & 0xf
    if t != 0x0:
        src += [0x00] * (0x10 - t)
    return len(src)

#-------------------------------
def scnDecode(filename):
    f = open(filename, "rb")
    x = f.read()
    f.close()

    d1, d2 = struct.unpack("HH", x[0:4])
    d1 *= 0x10  #event offset
    d2 *= 0x10  #message offset

    d1LZ   = x[d1:d2]
    d2LZ   = x[d2:len(x)]

    d1Size = struct.unpack("I", d1LZ[0:4])[0]
    d2Size = struct.unpack("I", d2LZ[0:4])[0]

    d1Data = [0x00] * d1Size
    d2Data = [0x00] * d2Size

    decode(d1LZ[4:], d1Data, d1Size)
    decode(d2LZ[4:], d2Data, d2Size)

    offset1 = resize(d1Data)
    offset2 = resize(d2Data)

    f = open(filename, 'wb')
    f.write(struct.pack('HHHHLL', 0x10, 0x10 + offset1, d1Size, d2Size, 0, 0))

    for i in range(len(d1Data)):
        f.write(struct.pack('B',d1Data[i]))

    for i in range(len(d2Data)):
        f.write(struct.pack('B',d2Data[i]))

    f.close

#-------------------------------
dir = os.listdir(os.getcwd() + '\\')
dat = [i for i in dir if i.find('.DAT') != -1]

for i in range(len(dat)):
    print "scnDecoding %s ..." % dat[i]
    scnDecode(dat[i])
