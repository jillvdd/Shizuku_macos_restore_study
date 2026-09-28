@echo off
echo compiling conversion tools
echo (you'll need MinGW in front of your path for this)
gcc -Wall -O2 myima.c readwav.c -s -o wav28ad.exe
gcc -Wall -O2 bin2h.c -s -o bin2h.exe
gcc -Wall -O2 gbfs.c djbasename.c -s -o gbfs.exe
gcc -Wall -O2 padbin.c -s -o padbin.exe
