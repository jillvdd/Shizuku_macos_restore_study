   ___              _
  / _ \            | |
 | (_) |  __ _   __| |
  > _ <  / _` | / _` |
 | (_) || (_| || (_| |
  \___/  \__,_| \__,_|

An adaptive digital pulse code modulation codec with a GBA player
By Damian Yerrick


=== Explanation ===

Adaptive digital pulse code modulation is a compression technique for
audio that provides decent compression performance without taking
forever to decode on slow hardware.  Unlike LPC, ADPCM does not
crap itself in the presence of background noise.  And because ADPCM
can handle two pitches at the same time, you can even compress music
with it.  See 'myima.txt' in the source distribution to learn how
ADPCM works.

8ad is an ADPCM codec designed to be decoded on the Game Boy Advance
system.  Use it for your demo or your dance simulation game.
It doesn't even take a lot of CPU time: about 6 percent for a mono
stream at 18157 Hz played from ROM.


=== Changing the wav file ===

Make sure the wav file is mono and 18157 Hz.  A 16-bit wav file works
best, even though the GBA's sound output hw is 8-bit, because it
introduces noise at as few places as possible.  Then change the
wav file name in 'mk.bat' to match where your wav file is stored.

The resulting ROM will use about 9 KiB per second of audio.  If your
file is smaller than about 27 seconds (a .ad file smaller than 240
KiB), you can change a line at the top of playad.c to make the ROM
multibootable, which means you can run it without a flash cartridge
by sending it to the GBA's RAM via multiboot.


=== Compilation ===

If you got a binary distribution, you can get the source (with a
shorter wav file) at http://www.pineight.com/gba/

To compile this on Windows:

1. install devkit advance r5 beta 3 or later from
   http://devkitadv.sourceforge.net/
2. install a recent mingw from
   http://www.mingw.org/
3. put mingw in your path
4. cd tools
   mk
5. put devkit advance in your path
6. cd ..
   mk


Copyright information

© 2003 Damian Yerrick

Many files, including all GBA-side code, fall under a permissive
copyright license.  Other files fall under the GNU General Public
License (in file COPYING) or the GNU Lesser General Public License
(in file COPYING.LIB).

The audio files, on the other hand...
