#include <stdlib.h>
#include <string.h>
#include "lf2.h"
#include "lfg.h"
#include "hat_grp.h"
#include "wa_grp.h"
#include "wa_gad.h"
#include "cp_grp.h"
#include "plugins.h"
#include "psth.h"
#include "leaf_util.h"

static int grp_header_check(unsigned char *, int);

static char fname_saorin[][13] = {
  /* breakdown OMAKE CG */
  "brkcg000.grp", "brkcg001.grp",

  /* NAMA-HAM race OMAKE CG */
  "namcg000.grp", "namcg001.grp", "namcg002.grp",

  /* DOUJIN-SHI preview (saorin02.pak) */
  "dou000.grp", "dou001.grp", "dou002.grp", "dou003.grp", "dou004.grp",
  "dou005.grp", "dou006.grp", "dou007.grp", "dou008.grp", "dou009.grp",
  "dou010.grp", "dou011.grp", "dou012.grp", "dou013.grp", "dou014.grp",
  "dou015.grp", "dou016.grp", "dou017.grp", "dou018.grp", "dou019.grp",
  "dou020.grp", "dou021.grp", "dou022.grp", "dou023.grp", "dou024.grp",
  "dou025.grp",

  /* illustration (saorin03.pak) */
  "ill000.grp", "ill001.grp", "ill002.grp", "ill003.grp", "ill004.grp",
  "ill005.grp", "ill006.grp", "ill007.grp", "ill008.grp", "ill009.grp",
  "ill010.grp", "ill011.grp", "ill012.grp", "ill013.grp", "ill014.grp",
  "ill015.grp", "ill016.grp", "ill017.grp", "ill018.grp", "ill019.grp",
  "ill020.grp", "ill021.grp", "ill022.grp", "ill023.grp", "ill024.grp",
  "ill025.grp", "ill026.grp", "ill027.grp", "ill028.grp", "ill029.grp",
  "ill030.grp", "ill031.grp", "ill032.grp", "ill033.grp", "ill034.grp",
  "ill035.grp", "ill036.grp", "ill037.grp", "ill038.grp", "ill039.grp",
  "ill040.grp", "ill041.grp", "ill042.grp", "ill043.grp", "ill044.grp",
  "ill045.grp", "ill046.grp", "ill047.grp",

  /* old games (saorin04.pak) */
  "old000.grp", "old001.grp", "old002.grp", "old003.grp", "old004.grp",
  "old005.grp", "old006.grp", "old007.grp", "old008.grp", "old009.grp",
  "old010.grp", "old011.grp", "old012.grp", "old013.grp", "old014.grp",
  "old015.grp", "old016.grp", "old017.grp", "old018.grp", "old019.grp",
  
  /* KARAOKE background CG (saorin05.pak) */
  "song000.grp", "song001.grp", "song002.grp", "song003.grp", "song004.grp",
  "song005.grp", "song006.grp", "song007.grp", "song008.grp", "song009.grp",
  "song010.grp", "song011.grp", "song012.grp", "song013.grp",

  /* DR2 rough illustration preview (saorin06.pak) */
  "jns000.grp", "jns001.grp", "jns002.grp", "jns003.grp", "jns004.grp",
  "jns005.grp", "jns006.grp", "jns007.grp", "jns008.grp", "jns009.grp",
  "jns010.grp", "jns011.grp", "jns012.grp", "jns013.grp", "jns014.grp",
  "jns015.grp", "jns016.grp", "jns017.grp", "jns018.grp", "jns019.grp",
  "jns020.grp", "jns021.grp", "jns022.grp", "jns023.grp", "jns024.grp",
  "jns025.grp", "jns026.grp", "jns027.grp", "jns028.grp", "jns029.grp",
  "jns030.grp", "jns031.grp", "jns032.grp", "jns033.grp", "jns034.grp",
  "jns035.grp", "jns036.grp", "jns037.grp", "jns038.grp", "jns039.grp",
  "jns040.grp", "jns041.grp", "jns042.grp", "jns043.grp",

  /* DR2 rough illustration (saorin07.pak) */
  "jnk000.grp", "jnk001.grp", "jnk002.grp", "jnk003.grp", "jnk004.grp",
  "jnk005.grp", "jnk006.grp", "jnk007.grp", "jnk008.grp", "jnk009.grp",
  "jnk010.grp", "jnk011.grp", "jnk012.grp", "jnk013.grp", "jnk014.grp",
  "jnk015.grp", "jnk016.grp", "jnk017.grp", "jnk018.grp", "jnk019.grp",
  "jnk020.grp", "jnk021.grp", "jnk022.grp", "jnk023.grp", "jnk024.grp",
  "jnk025.grp", "jnk026.grp", "jnk027.grp", "jnk028.grp", "jnk029.grp",
  "jnk030.grp", "jnk031.grp", "jnk032.grp", "jnk033.grp", "jnk034.grp",
  "jnk035.grp", "jnk036.grp", "jnk037.grp", "jnk038.grp", "jnk039.grp",
  "jnk040.grp", "jnk041.grp", "jnk042.grp", "jnk043.grp",

  /* Filsnown rough illustration preview (saorin08.pak) */
  "fis000.grp", "fis001.grp", "fis002.grp", "fis003.grp", "fis004.grp",
  "fis005.grp", "fis006.grp", "fis007.grp", "fis008.grp", "fis009.grp",
  "fis010.grp", "fis011.grp", "fis012.grp", "fis013.grp", "fis014.grp",
  "fis015.grp", "fis016.grp", "fis017.grp", "fis018.grp", "fis019.grp",
  "fis020.grp", "fis021.grp", "fis022.grp", "fis023.grp", "fis024.grp",
  "fis025.grp", "fis026.grp", "fis027.grp", "fis028.grp", "fis029.grp",
  "fis030.grp", "fis031.grp", "fis032.grp", "fis033.grp", "fis034.grp",
  "fis035.grp", "fis036.grp", "fis037.grp", "fis038.grp", "fis039.grp",
  "fis040.grp", "fis041.grp", "fis042.grp", "fis043.grp", "fis044.grp",
  "fis045.grp", "fis046.grp", "fis047.grp", "fis048.grp",

  /* Filsnown rough illustration preview (saorin09.pak) */
  "fil000.grp", "fil001.grp", "fil002.grp", "fil003.grp", "fil004.grp",
  "fil005.grp", "fil006.grp", "fil007.grp", "fil008.grp", "fil009.grp",
  "fil010.grp", "fil011.grp", "fil012.grp", "fil013.grp", "fil014.grp",
  "fil015.grp", "fil016.grp", "fil017.grp", "fil018.grp", "fil019.grp",
  "fil020.grp", "fil021.grp", "fil022.grp", "fil023.grp", "fil024.grp",
  "fil025.grp", "fil026.grp", "fil027.grp", "fil028.grp", "fil029.grp",
  "fil030.grp", "fil031.grp", "fil032.grp", "fil033.grp", "fil034.grp",
  "fil035.grp", "fil036.grp", "fil037.grp", "fil038.grp", "fil039.grp",
  "fil040.grp", "fil041.grp", "fil042.grp", "fil043.grp", "fil044.grp",
  "fil045.grp", "fil046.grp", "fil047.grp", "fil048.grp",

  /* Shizuku rough illustration preview(saorin10.pak) */
  "sis000.grp", "sis001.grp", "sis002.grp", "sis003.grp", "sis004.grp", 
  "sis005.grp", "sis006.grp", "sis007.grp", "sis008.grp", "sis009.grp", 
  "sis010.grp", "sis011.grp", "sis012.grp", "sis013.grp", "sis014.grp", 
  "sis015.grp", "sis016.grp", "sis017.grp",

  /* Shizuku rough illustration (saorin11.pak) */  
  "siz000.grp", "siz001.grp", "siz002.grp", "siz003.grp", "siz004.grp",
  "siz005.grp", "siz006.grp", "siz007.grp", "siz008.grp", "siz009.grp",
  "siz010.grp", "siz011.grp", "siz012.grp", "siz013.grp", "siz014.grp",
  "siz015.grp", "siz016.grp", "siz017.grp",

  /* Kizuato rough illustration preview(saorin12.pak) */
  "kis000.grp", "kis001.grp", "kis002.grp", 

  /* Kizuato rough illustration (saorin13.pak) */
  "kiz000.grp", "kiz001.grp", "kiz002.grp",

  /* ??? (^_^;) rough illustration (saorin14.pak) */
  "fi2000.grp", "fi2001.grp", "fi2002.grp", "fi2003.grp", "fi2004.grp", 
  "fi2005.grp", "fi2006.grp", "fi2007.grp", "fi2008.grp", "fi2009.grp", 
  "fs2000.grp", "fs2001.grp", "fs2002.grp", "fs2003.grp", "fs2004.grp", 
  "fs2005.grp", "fs2006.grp", "fs2007.grp", "fs2008.grp", "fs2009.grp", 

  /* ??? (^_^;) rough illustration (saorin15.pak) */
  "nvb000.grp", "nvb001.grp", "nvb002.grp", "nvb003.grp", "nvb004.grp", 
  "nvb005.grp", "nvb006.grp", "nvb007.grp", "nvb008.grp", "nvb009.grp", 
  "nvb010.grp", "nvb011.grp", "nvs000.grp", "nvs001.grp", "nvs002.grp", 
  "nvs003.grp", "nvs004.grp", "nvs005.grp", "nvs006.grp", "nvs007.grp", 
  "nvs008.grp", "nvs009.grp", "nvs010.grp", "nvs011.grp", 

  /* To Heart illustration (saorin15.pak) */
  "nes000.grp", "nes001.grp", "nes002.grp", "nes003.grp", "nes004.grp", 
  "nes005.grp", "nes006.grp", "nes007.grp", "new000.grp", "new001.grp", 
  "new002.grp", "new003.grp", "new004.grp", "new005.grp", "new006.grp", 
  "new007.grp"
};

static char fname_comic[][13] = {
  /* Comic Party */
  /* Back.pak */
  "bg00.grp", "bg01.grp", "bg02.grp", "bg03.grp", "bg04.grp", "bg05.grp", 
  "bg06.grp", "bg07.grp", "bg08.grp", "bg09.grp", "bg10.grp", "bg100.grp", 
  "bg101.grp", "bg102.grp", "bg103.grp", "bg104.grp", "bg105.grp",
  "bg11.grp", "bg12.grp", "bg13.grp", "bg14.grp", "bg15.grp", "bg16.grp", 
  "bg17.grp", "bg18.grp", "bg19_0.grp", "bg19_1.grp", "bg19_2.grp", 
  "bg20_0.grp", "bg20_1.grp", "bg20_2.grp", "bg21_0.grp", "bg21_1.grp", 
  "bg21_2.grp", "bg22.grp", "bg23.grp", "bg24.grp", "bg25.grp", 
  "bg26.grp", "bg27.grp", "bg28.grp", "bg29.grp", "bg30.grp", "bg31.grp", 
  "bg33.grp", "bg34.grp", "bg35.grp", "bg36.grp", "bg37.grp", "bg38.grp", 
  "bg39.grp", "bg40.grp", "bg41.grp", "bg42.grp", "bg43.grp", "bg44.grp", 
  "bg45.grp", "bg46.grp", "bg47.grp", "bg48.grp", "bg49.grp", "bg50.grp", 
  "bg51.grp", "bg52.grp", "bg53.grp", "bg54.grp", "bg55.grp", "bg56.grp", 
  "bg57.grp", "bg58.grp", "bg59.grp", "bg60.grp", "bg61.grp", "bg63.grp", 
  "bg64.grp", "bg65.grp", "bg66.grp", "bg67.grp", "bg68.grp", "bg69.grp", 
  "bg70.grp", "bg71.grp", "bg72.grp", "bg73.grp", "bg74.grp", "bg75.grp", 
  "bg76.grp", "bg77.grp", "bg78.grp", "bg79.grp", "bg80.grp", "bg81.grp", 
  "bg82.grp", "bg83.grp", "bg84.grp", "bg85.grp", "bg86.grp", "bg87.grp", 
  "bg88.grp", "bg89.grp", "bg90.grp", "bg91.grp", "bg92.grp", "bg93.grp", 
  "bg94.grp", "bg95.grp", "bg96.grp", "bg97.grp", "bg98.grp", "bg99.grp", 

  /* Bustup.grp */
  "asa01_1.grp", "asa01_1a.grp", "asa01_1b.grp", "asa01_1c.grp", 
  "asa01_1d.grp", "asa01_2.grp", "asa01_2a.grp", "asa01_2b.grp", 
  "asa01_2c.grp", "asa01_2d.grp", "asa01_3.grp", "asa01_3a.grp", 
  "asa01_3b.grp", "asa01_3c.grp", "asa01_3d.grp", "asa01_4.grp", 
  "asa01_4a.grp", "asa01_4b.grp", "asa01_4c.grp", "asa01_4d.grp", 
  "asa01_5.grp", "asa01_5a.grp", "asa01_5b.grp", "asa01_5c.grp", 
  "asa01_5d.grp", "asa02_1.grp", "asa02_1a.grp", "asa02_1b.grp", 
  "asa02_1c.grp", "asa02_1d.grp", "asa02_2.grp", "asa02_2a.grp", 
  "asa02_2b.grp", "asa02_2c.grp", "asa02_2d.grp", "asa02_3.grp", 
  "asa02_3a.grp", "asa02_3b.grp", "asa02_3c.grp", "asa02_3d.grp", 
  "asa02_4.grp", "asa02_4a.grp", "asa02_4b.grp", "asa02_4c.grp", 
  "asa02_4d.grp", "asa02_5.grp", "asa02_5a.grp", "asa02_5b.grp", 
  "asa02_5c.grp", "asa02_5d.grp", "asa02_6.grp", "asa02_6a.grp", 
  "asa02_6b.grp", "asa02_6c.grp", "asa02_6d.grp", "asa03_1.grp", 
  "asa03_1a.grp", "asa03_1b.grp", "asa03_1c.grp", "asa03_1d.grp", 
  "asa03_2.grp", "asa03_2a.grp", "asa03_2b.grp", "asa03_2c.grp", 
  "asa03_2d.grp", "asa03_3.grp", "asa03_3a.grp", "asa03_3b.grp", 
  "asa03_3c.grp", "asa03_3d.grp", "asa03_4.grp", "asa03_4a.grp", 
  "asa03_4b.grp", "asa03_4c.grp", "asa03_4d.grp", "asa03_5.grp", 
  "asa03_5a.grp", "asa03_5b.grp", "asa03_5c.grp", "asa03_5d.grp", 
  "asa03_6.grp", "asa03_6a.grp", "asa03_6b.grp", "asa03_6c.grp", 
  "asa03_6d.grp", "asa04_1.grp", "asa04_1a.grp", "asa04_1b.grp", 
  "asa04_1c.grp", "asa04_1d.grp", "asa04_2.grp", "asa04_2a.grp", 
  "asa04_2b.grp", "asa04_2c.grp", "asa04_2d.grp", "asa04_3.grp", 
  "asa04_3a.grp", "asa04_3b.grp", "asa04_3c.grp", "asa04_3d.grp", 
  "asa05_1.grp", "asa05_1a.grp", "asa05_1b.grp", "asa05_1c.grp", 
  "asa05_1d.grp", "asa05_2.grp", "asa05_2a.grp", "asa05_2b.grp", 
  "asa05_2c.grp", "asa05_2d.grp", "asa05_3.grp", "asa05_3a.grp", 
  "asa05_3b.grp", "asa05_3c.grp", "asa05_3d.grp", "asa05_4.grp", 
  "asa05_4a.grp", "asa05_4b.grp", "asa05_4c.grp", "asa05_4d.grp", 
  "asa05_5.grp", "asa05_5a.grp", "asa05_5b.grp", "asa05_5c.grp", 
  "asa05_5d.grp", "aya01_1.grp", "aya01_1a.grp", "aya01_1b.grp", 
  "aya01_1c.grp", "aya01_1d.grp", "aya01_2.grp", "aya01_2a.grp", 
  "aya01_2b.grp", "aya01_2c.grp", "aya01_2d.grp", "aya01_3.grp", 
  "aya01_3a.grp", "aya01_3b.grp", "aya01_3c.grp", "aya01_3d.grp", 
  "aya01_4.grp", "aya01_4a.grp", "aya01_4b.grp", "aya01_4c.grp", 
  "aya01_4d.grp", "aya01_5.grp", "aya01_5a.grp", "aya01_5b.grp", 
  "aya01_5c.grp", "aya01_5d.grp", "aya02_1.grp", "aya02_1a.grp", 
  "aya02_1b.grp", "aya02_1c.grp", "aya02_1d.grp", "aya02_2.grp", 
  "aya02_2a.grp", "aya02_2b.grp", "aya02_2c.grp", "aya02_2d.grp", 
  "aya02_3.grp", "aya02_3a.grp", "aya02_3b.grp", "aya02_3c.grp", 
  "aya02_3d.grp", "aya02_4.grp", "aya02_4a.grp", "aya02_4b.grp", 
  "aya02_4c.grp", "aya02_4d.grp", "aya02_5.grp", "aya02_5a.grp", 
  "aya02_5b.grp", "aya02_5c.grp", "aya02_5d.grp", "aya03_1.grp", 
  "aya03_1a.grp", "aya03_1b.grp", "aya03_1c.grp", "aya03_1d.grp", 
  "aya03_2.grp", "aya03_2a.grp", "aya03_2b.grp", "aya03_2c.grp", 
  "aya03_2d.grp", "aya03_3.grp", "aya03_3a.grp", "aya03_3b.grp", 
  "aya03_3c.grp", "aya03_3d.grp", "aya03_4.grp", "aya03_4a.grp", 
  "aya03_4b.grp", "aya03_4c.grp", "aya03_4d.grp", "aya03_5.grp", 
  "aya03_5a.grp", "aya03_5b.grp", "aya03_5c.grp", "aya03_5d.grp", 
  "aya04_1.grp", "aya04_1a.grp", "aya04_1b.grp", "aya04_1c.grp", 
  "aya04_1d.grp", "aya04_2.grp", "aya04_2a.grp", "aya04_2b.grp", 
  "aya04_2c.grp", "aya04_2d.grp", "aya04_4.grp", "aya04_4a.grp", 
  "aya04_4b.grp", "aya04_4c.grp", "aya04_4d.grp", "aya05_1.grp", 
  "aya05_1a.grp", "aya05_1b.grp", "aya05_1c.grp", "aya05_1d.grp", 
  "aya05_2.grp", "aya05_2a.grp", "aya05_2b.grp", "aya05_2c.grp", 
  "aya05_2d.grp", "aya05_4.grp", "aya05_4a.grp", "aya05_4b.grp", 
  "aya05_4c.grp", "aya05_4d.grp", "aya06_1.grp", "aya06_1a.grp", 
  "aya06_1b.grp", "aya06_1c.grp", "aya06_1d.grp", "aya06_3.grp", 
  "aya06_3a.grp", "aya06_3b.grp", "aya06_3c.grp", "aya06_3d.grp", 
  "aya06_5.grp", "aya06_5a.grp", "aya06_5b.grp", "aya06_5c.grp", 
  "aya06_5d.grp", "aya07_1.grp", "aya07_1a.grp", "aya07_1b.grp", 
  "aya07_1c.grp", "aya07_1d.grp", "ban01_1.grp", "ban01_1a.grp",
  "ban01_1b.grp", "ban01_1c.grp", "ban01_1d.grp", "chi01_1.grp",
  "chi01_1a.grp", "chi01_1b.grp", "chi01_1c.grp", "chi01_1d.grp",
  "chi01_2.grp", "chi01_2a.grp", "chi01_2b.grp", "chi01_2c.grp",
  "chi01_2d.grp", "chi01_3.grp", "chi01_3a.grp", "chi01_3b.grp",
  "chi01_3c.grp", "chi01_3d.grp", "chi01_4.grp", "chi01_4a.grp",
  "chi01_4b.grp", "chi01_4c.grp", "chi01_4d.grp", "chi01_5.grp",
  "chi01_5a.grp", "chi01_5b.grp", "chi01_5c.grp", "chi01_5d.grp",
  "chi01_6.grp", "chi01_6a.grp", "chi01_6b.grp", "chi01_6c.grp",
  "chi01_6d.grp", "chi02_1.grp", "chi02_1a.grp", "chi02_1b.grp",
  "chi02_1c.grp", "chi02_1d.grp", "chi02_2.grp", "chi02_2a.grp",
  "chi02_2b.grp", "chi02_2c.grp", "chi02_2d.grp", "chi02_3.grp",
  "chi02_3a.grp", "chi02_3b.grp", "chi02_3c.grp", "chi02_3d.grp",
  "chi02_4.grp", "chi02_4a.grp", "chi02_4b.grp", "chi02_4c.grp",
  "chi02_4d.grp", "chi02_5.grp", "chi02_5a.grp", "chi02_5b.grp",
  "chi02_5c.grp", "chi02_5d.grp", "chi02_6.grp", "chi02_6a.grp",
  "chi02_6b.grp", "chi02_6c.grp", "chi02_6d.grp", "chi03_1.grp",
  "chi03_1a.grp", "chi03_1b.grp", "chi03_1c.grp", "chi03_1d.grp",
  "chi03_2.grp", "chi03_2a.grp", "chi03_2b.grp", "chi03_2c.grp",
  "chi03_2d.grp", "chi03_4.grp", "chi03_4a.grp", "chi03_4b.grp",
  "chi03_4c.grp", "chi03_4d.grp", "chi03_5.grp", "chi03_5a.grp",
  "chi03_5b.grp", "chi03_5c.grp", "chi03_5d.grp", "chi03_6.grp",
  "chi03_6a.grp", "chi03_6b.grp", "chi03_6c.grp", "chi03_6d.grp",
  "chi04_1.grp", "chi04_1a.grp", "chi04_1b.grp", "chi04_1c.grp",
  "chi04_1d.grp", "chi04_2.grp", "chi04_2a.grp", "chi04_2b.grp",
  "chi04_2c.grp", "chi04_2d.grp", "chi04_4.grp", "chi04_4a.grp",
  "chi04_4b.grp", "chi04_4c.grp", "chi04_4d.grp", "chi04_5.grp",
  "chi04_5a.grp", "chi04_5b.grp", "chi04_5c.grp", "chi04_5d.grp",
  "chi04_6.grp", "chi04_6a.grp", "chi04_6b.grp", "chi04_6c.grp",
  "chi04_6d.grp", "chi05_1.grp", "chi05_1a.grp", "chi05_1b.grp",
  "chi05_1c.grp", "chi05_1d.grp", "chi05_3.grp", "chi05_3a.grp",
  "chi05_3b.grp", "chi05_3c.grp", "chi05_3d.grp", "chi05_4.grp",
  "chi05_4a.grp", "chi05_4b.grp", "chi05_4c.grp", "chi05_4d.grp",
  "chi05_5.grp", "chi05_5a.grp", "chi05_5b.grp", "chi05_5c.grp",
  "chi05_5d.grp", "chi06_1.grp", "chi06_1a.grp", "chi06_1b.grp",
  "chi06_1c.grp", "chi06_1d.grp", "chi06_5.grp", "chi06_5a.grp",
  "chi06_5b.grp", "chi06_5c.grp", "chi06_5d.grp", "chi07_1.grp",
  "chi07_1a.grp", "chi07_1b.grp", "chi07_1c.grp", "chi07_1d.grp",
  "chi07_3.grp", "chi07_3a.grp", "chi07_3b.grp", "chi07_3c.grp",
  "chi07_3d.grp", "chi07_4.grp", "chi07_4a.grp", "chi07_4b.grp",
  "chi07_4c.grp", "chi07_4d.grp", "chi07_5.grp", "chi07_5a.grp",
  "chi07_5b.grp", "chi07_5c.grp", "chi07_5d.grp", "eim01_1.grp",
  "eim01_1a.grp", "eim01_1b.grp", "eim01_1c.grp", "eim01_1d.grp",
  "eim01_2.grp", "eim01_2a.grp", "eim01_2b.grp", "eim01_2c.grp",
  "eim01_2d.grp", "eim01_3.grp", "eim01_3a.grp", "eim01_3b.grp",
  "eim01_3c.grp", "eim01_3d.grp", "eim01_4.grp", "eim01_4a.grp",
  "eim01_4b.grp", "eim01_4c.grp", "eim01_4d.grp", "eim01_5.grp",
  "eim01_5a.grp", "eim01_5b.grp", "eim01_5c.grp", "eim01_5d.grp",
  "eim01_6.grp", "eim01_6a.grp", "eim01_6b.grp", "eim01_6c.grp",
  "eim01_6d.grp", "eim01_7.grp", "eim01_7a.grp", "eim01_7b.grp",
  "eim01_7c.grp", "eim01_7d.grp", "eim02_1.grp", "eim02_1a.grp",
  "eim02_1b.grp", "eim02_1c.grp", "eim02_1d.grp", "eim02_2.grp",
  "eim02_2a.grp", "eim02_2b.grp", "eim02_2c.grp", "eim02_2d.grp",
  "eim02_3.grp", "eim02_3a.grp", "eim02_3b.grp", "eim02_3c.grp",
  "eim02_3d.grp", "eim02_4.grp", "eim02_4a.grp", "eim02_4b.grp",
  "eim02_4c.grp", "eim02_4d.grp", "eim02_5.grp", "eim02_5a.grp",
  "eim02_5b.grp", "eim02_5c.grp", "eim02_5d.grp", "eim02_6.grp",
  "eim02_6a.grp", "eim02_6b.grp", "eim02_6c.grp", "eim02_6d.grp",
  "eim02_7.grp", "eim02_7a.grp", "eim02_7b.grp", "eim02_7c.grp",
  "eim02_7d.grp", "eim03_1.grp", "eim03_1a.grp", "eim03_1b.grp",
  "eim03_1c.grp", "eim03_1d.grp", "eim03_2.grp", "eim03_2a.grp",
  "eim03_2b.grp", "eim03_2c.grp", "eim03_2d.grp", "eim03_3.grp",
  "eim03_3a.grp", "eim03_3b.grp", "eim03_3c.grp", "eim03_3d.grp",
  "eim03_4.grp", "eim03_4a.grp", "eim03_4b.grp", "eim03_4c.grp",
  "eim03_4d.grp", "eim04_1.grp", "eim04_1a.grp", "eim04_1b.grp",
  "eim04_1c.grp", "eim04_1d.grp", "eim04_2.grp", "eim04_2a.grp",
  "eim04_2b.grp", "eim04_2c.grp", "eim04_2d.grp", "eim04_3.grp",
  "eim04_3a.grp", "eim04_3b.grp", "eim04_3c.grp", "eim04_3d.grp",
  "eim05_1.grp", "eim05_1a.grp", "eim05_1b.grp", "eim05_1c.grp",
  "eim05_1d.grp", "eim05_2.grp", "eim05_2a.grp", "eim05_2b.grp",
  "eim05_2c.grp", "eim05_2d.grp", "eim05_3.grp", "eim05_3a.grp",
  "eim05_3b.grp", "eim05_3c.grp", "eim05_3d.grp", "iku01_1.grp",
  "iku01_1a.grp", "iku01_1b.grp", "iku01_1c.grp", "iku01_1d.grp",
  "iku01_2.grp", "iku01_2a.grp", "iku01_2b.grp", "iku01_2c.grp",
  "iku01_2d.grp", "iku01_3.grp", "iku01_3a.grp", "iku01_3b.grp",
  "iku01_3c.grp", "iku01_3d.grp", "iku01_4.grp", "iku01_4a.grp",
  "iku01_4b.grp", "iku01_4c.grp", "iku01_4d.grp", "iku01_5.grp",
  "iku01_5a.grp", "iku01_5b.grp", "iku01_5c.grp", "iku01_5d.grp",
  "kuh01_1.grp", "kuh01_1a.grp", "kuh01_1b.grp", "kuh01_1c.grp",
  "kuh01_1d.grp", "kuh01_2.grp", "kuh01_2a.grp", "kuh01_2b.grp",
  "kuh01_2c.grp", "kuh01_2d.grp", "kuh01_3.grp", "kuh01_3a.grp",
  "kuh01_3b.grp", "kuh01_3c.grp", "kuh01_3d.grp", "kuh01_4.grp",
  "kuh01_4a.grp", "kuh01_4b.grp", "kuh01_4c.grp", "kuh01_4d.grp",
  "kuh01_5.grp", "kuh01_5a.grp", "kuh01_5b.grp", "kuh01_5c.grp",
  "kuh01_5d.grp", "kuh02_1.grp", "kuh02_1a.grp", "kuh02_1b.grp",
  "kuh02_1c.grp", "kuh02_1d.grp", "kuh02_2.grp", "kuh02_2a.grp",
  "kuh02_2b.grp", "kuh02_2c.grp", "kuh02_2d.grp", "kuh02_3.grp",
  "kuh02_3a.grp", "kuh02_3b.grp", "kuh02_3c.grp", "kuh02_3d.grp",
  "kuh02_4.grp", "kuh02_4a.grp", "kuh02_4b.grp", "kuh02_4c.grp",
  "kuh02_4d.grp", "kuh02_5.grp", "kuh02_5a.grp", "kuh02_5b.grp",
  "kuh02_5c.grp", "kuh02_5d.grp", "mak01_1.grp", "mak01_1a.grp",
  "mak01_1b.grp", "mak01_1c.grp", "mak01_1d.grp", "mak01_2.grp",
  "mak01_2a.grp", "mak01_2b.grp", "mak01_2c.grp", "mak01_2d.grp",
  "min01_1.grp", "min01_1a.grp", "min01_1b.grp", "min01_1c.grp",
  "min01_1d.grp", "min01_2.grp", "min01_2a.grp", "min01_2b.grp",
  "min01_2c.grp", "min01_2d.grp", "min01_3.grp", "min01_3a.grp",
  "min01_3b.grp", "min01_3c.grp", "min01_3d.grp", "min01_4.grp",
  "min01_4a.grp", "min01_4b.grp", "min01_4c.grp", "min01_4d.grp",
  "min01_5.grp", "min01_5a.grp", "min01_5b.grp", "min01_5c.grp",
  "min01_5d.grp", "min01_6.grp", "min01_6a.grp", "min01_6b.grp",
  "min01_6c.grp", "min01_6d.grp", "min02_1.grp", "min02_1a.grp",
  "min02_1b.grp", "min02_1c.grp", "min02_1d.grp", "min02_2.grp",
  "min02_2a.grp", "min02_2b.grp", "min02_2c.grp", "min02_2d.grp",
  "min02_3.grp", "min02_3a.grp", "min02_3b.grp", "min02_3c.grp",
  "min02_3d.grp", "min02_4.grp", "min02_4a.grp", "min02_4b.grp",
  "min02_4c.grp", "min02_4d.grp", "min02_5.grp", "min02_5a.grp",
  "min02_5b.grp", "min02_5c.grp", "min02_5d.grp", "min02_6.grp",
  "min02_6a.grp", "min02_6b.grp", "min02_6c.grp", "min02_6d.grp",
  "min03_1.grp", "min03_1a.grp", "min03_1b.grp", "min03_1c.grp",
  "min03_1d.grp", "min03_2.grp", "min03_2a.grp", "min03_2b.grp",
  "min03_2c.grp", "min03_2d.grp", "min03_3.grp", "min03_3a.grp",
  "min03_3b.grp", "min03_3c.grp", "min03_3d.grp", "min03_4.grp",
  "min03_4a.grp", "min03_4b.grp", "min03_4c.grp", "min03_4d.grp",
  "min03_5.grp", "min03_5a.grp", "min03_5b.grp", "min03_5c.grp",
  "min03_5d.grp", "min03_6.grp", "min03_6a.grp", "min03_6b.grp",
  "min03_6c.grp", "min03_6d.grp", "min04_1.grp", "min04_1a.grp",
  "min04_1b.grp", "min04_1c.grp", "min04_1d.grp", "min04_2.grp",
  "min04_2a.grp", "min04_2b.grp", "min04_2c.grp", "min04_2d.grp",
  "min04_3.grp", "min04_3a.grp", "min04_3b.grp", "min04_3c.grp",
  "min04_3d.grp", "min04_4.grp", "min04_4a.grp", "min04_4b.grp",
  "min04_4c.grp", "min04_4d.grp", "min04_5.grp", "min04_5a.grp",
  "min04_5b.grp", "min04_5c.grp", "min04_5d.grp", "min04_6.grp",
  "min04_6a.grp", "min04_6b.grp", "min04_6c.grp", "min04_6d.grp",
  "min05_1.grp", "min05_1a.grp", "min05_1b.grp", "min05_1c.grp",
  "min05_1d.grp", "min05_2.grp", "min05_2a.grp", "min05_2b.grp",
  "min05_2c.grp", "min05_2d.grp", "min05_3.grp", "min05_3a.grp",
  "min05_3b.grp", "min05_3c.grp", "min05_3d.grp", "min06_1.grp",
  "min06_1a.grp", "min06_1b.grp", "min06_1c.grp", "min06_1d.grp",
  "min06_2.grp", "min06_2a.grp", "min06_2b.grp", "min06_2c.grp",
  "min06_2d.grp", "min06_3.grp", "min06_3a.grp", "min06_3b.grp",
  "min06_3c.grp", "min06_3d.grp", "min07_1.grp", "min07_1a.grp",
  "min07_1b.grp", "min07_1c.grp", "min07_1d.grp", "min07_2.grp",
  "min07_2a.grp", "min07_2b.grp", "min07_2c.grp", "min07_2d.grp",
  "min07_3.grp", "min07_3a.grp", "min07_3b.grp", "min07_3c.grp",
  "min07_3d.grp", "min07_4.grp", "min07_4a.grp", "min07_4b.grp",
  "min07_4c.grp", "min07_4d.grp", "min07_5.grp", "min07_5a.grp",
  "min07_5b.grp", "min07_5c.grp", "min07_5d.grp", "min07_6.grp",
  "min07_6a.grp", "min07_6b.grp", "min07_6c.grp", "min07_6d.grp",
  "min08_1.grp", "min08_1a.grp", "min08_1b.grp", "min08_1c.grp",
  "min08_1d.grp", "min08_2.grp", "min08_2a.grp", "min08_2b.grp",
  "min08_2c.grp", "min08_2d.grp", "min08_3.grp", "min08_3a.grp",
  "min08_3b.grp", "min08_3c.grp", "min08_3d.grp", "min08_4.grp",
  "min08_4a.grp", "min08_4b.grp", "min08_4c.grp", "min08_4d.grp",
  "min08_5.grp", "min08_5a.grp", "min08_5b.grp", "min08_5c.grp",
  "min08_5d.grp", "min08_6.grp", "min08_6a.grp", "min08_6b.grp",
  "min08_6c.grp", "min08_6d.grp", "min09_1.grp", "min09_1a.grp",
  "min09_1b.grp", "min09_1c.grp", "min09_1d.grp", "min09_2.grp",
  "min09_2a.grp", "min09_2b.grp", "min09_2c.grp", "min09_2d.grp",
  "min09_3.grp", "min09_3a.grp", "min09_3b.grp", "min09_3c.grp",
  "min09_3d.grp", "min09_4.grp", "min09_4a.grp", "min09_4b.grp",
  "min09_4c.grp", "min09_4d.grp", "min09_5.grp", "min09_5a.grp",
  "min09_5b.grp", "min09_5c.grp", "min09_5d.grp", "min09_6.grp",
  "min09_6a.grp", "min09_6b.grp", "min09_6c.grp", "min09_6d.grp",
  "min10_1.grp", "min10_1a.grp", "min10_1b.grp", "min10_1c.grp",
  "min10_1d.grp", "min10_2.grp", "min10_2a.grp", "min10_2b.grp",
  "min10_2c.grp", "min10_2d.grp", "min10_3.grp", "min10_3a.grp",
  "min10_3b.grp", "min10_3c.grp", "min10_3d.grp", "min10_4.grp",
  "min10_4a.grp", "min10_4b.grp", "min10_4c.grp", "min10_4d.grp",
  "min10_5.grp", "min10_5a.grp", "min10_5b.grp", "min10_5c.grp",
  "min10_5d.grp", "min10_6.grp", "min10_6a.grp", "min10_6b.grp",
  "min10_6c.grp", "min10_6d.grp", "miz01_1.grp", "miz01_1a.grp",
  "miz01_1b.grp", "miz01_1c.grp", "miz01_1d.grp", "miz01_2.grp",
  "miz01_2a.grp", "miz01_2b.grp", "miz01_2c.grp", "miz01_2d.grp",
  "miz01_3.grp", "miz01_3a.grp", "miz01_3b.grp", "miz01_3c.grp",
  "miz01_3d.grp", "miz01_4.grp", "miz01_4a.grp", "miz01_4b.grp",
  "miz01_4c.grp", "miz01_4d.grp", "miz01_5.grp", "miz01_5a.grp",
  "miz01_5b.grp", "miz01_5c.grp", "miz01_5d.grp", "miz01_6.grp",
  "miz01_6a.grp", "miz01_6b.grp", "miz01_6c.grp", "miz01_6d.grp",
  "miz01_7.grp", "miz01_7a.grp", "miz01_7b.grp", "miz01_7c.grp",
  "miz01_7d.grp", "miz01_8.grp", "miz01_8a.grp", "miz01_8b.grp",
  "miz01_8c.grp", "miz01_8d.grp", "miz02_1.grp", "miz02_1a.grp",
  "miz02_1b.grp", "miz02_1c.grp", "miz02_1d.grp", "miz02_2.grp",
  "miz02_2a.grp", "miz02_2b.grp", "miz02_2c.grp", "miz02_2d.grp",
  "miz02_3.grp", "miz02_3a.grp", "miz02_3b.grp", "miz02_3c.grp",
  "miz02_3d.grp", "miz02_4.grp", "miz02_4a.grp", "miz02_4b.grp",
  "miz02_4c.grp", "miz02_4d.grp", "miz02_5.grp", "miz02_5a.grp",
  "miz02_5b.grp", "miz02_5c.grp", "miz02_5d.grp", "miz02_6.grp",
  "miz02_6a.grp", "miz02_6b.grp", "miz02_6c.grp", "miz02_6d.grp",
  "miz02_7.grp", "miz02_7a.grp", "miz02_7b.grp", "miz02_7c.grp",
  "miz02_7d.grp", "miz02_8.grp", "miz02_8a.grp", "miz02_8b.grp",
  "miz02_8c.grp", "miz02_8d.grp", "miz03_1.grp", "miz03_1a.grp",
  "miz03_1b.grp", "miz03_1c.grp", "miz03_1d.grp", "miz03_2.grp",
  "miz03_2a.grp", "miz03_2b.grp", "miz03_2c.grp", "miz03_2d.grp",
  "miz03_3.grp", "miz03_3a.grp", "miz03_3b.grp", "miz03_3c.grp",
  "miz03_3d.grp", "miz03_4.grp", "miz03_4a.grp", "miz03_4b.grp",
  "miz03_4c.grp", "miz03_4d.grp", "miz03_5.grp", "miz03_5a.grp",
  "miz03_5b.grp", "miz03_5c.grp", "miz03_5d.grp", "miz03_6.grp",
  "miz03_6a.grp", "miz03_6b.grp", "miz03_6c.grp", "miz03_6d.grp",
  "miz04_1.grp", "miz04_1a.grp", "miz04_1b.grp", "miz04_1c.grp",
  "miz04_1d.grp", "miz04_2.grp", "miz04_2a.grp", "miz04_2b.grp",
  "miz04_2c.grp", "miz04_2d.grp", "miz04_3.grp", "miz04_3a.grp",
  "miz04_3b.grp", "miz04_3c.grp", "miz04_3d.grp", "ona01_1.grp",
  "ona01_1a.grp", "ona01_1b.grp", "ona01_1c.grp", "ona01_1d.grp",
  "ona01_2.grp", "ona01_2a.grp", "ona01_2b.grp", "ona01_2c.grp",
  "ona01_2d.grp", "ona02_1.grp", "ona02_1a.grp", "ona02_1b.grp",
  "ona02_1c.grp", "ona02_1d.grp", "ona02_2.grp", "ona02_2a.grp",
  "ona02_2b.grp", "ona02_2c.grp", "ona02_2d.grp", "onb01_1.grp",
  "onb01_1a.grp", "onb01_1b.grp", "onb01_1c.grp", "onb01_1d.grp",
  "onb01_2.grp", "onb01_2a.grp", "onb01_2b.grp", "onb01_2c.grp",
  "onb01_2d.grp", "onb02_1.grp", "onb02_1a.grp", "onb02_1b.grp",
  "onb02_1c.grp", "onb02_1d.grp", "onb02_2.grp", "onb02_2a.grp",
  "onb02_2b.grp", "onb02_2c.grp", "onb02_2d.grp", "onc01_1.grp",
  "onc01_1a.grp", "onc01_1b.grp", "onc01_1c.grp", "onc01_1d.grp",
  "onc01_2.grp", "onc01_2a.grp", "onc01_2b.grp", "onc01_2c.grp",
  "onc01_2d.grp", "onc02_1.grp", "onc02_1a.grp", "onc02_1b.grp",
  "onc02_1c.grp", "onc02_1d.grp", "onc02_2.grp", "onc02_2a.grp",
  "onc02_2b.grp", "onc02_2c.grp", "onc02_2d.grp", "onn01_1.grp",
  "onn01_1a.grp", "onn01_1b.grp", "onn01_1c.grp", "onn01_1d.grp",
  "onn02_1.grp", "onn02_1a.grp", "onn02_1b.grp", "onn02_1c.grp",
  "onn02_1d.grp", "ota01_1.grp", "ota01_1a.grp", "ota01_1b.grp",
  "ota01_1c.grp", "ota01_1d.grp", "rei01_1.grp", "rei01_1a.grp",
  "rei01_1b.grp", "rei01_1c.grp", "rei01_1d.grp", "rei01_2.grp",
  "rei01_2a.grp", "rei01_2b.grp", "rei01_2c.grp", "rei01_2d.grp",
  "rei01_3.grp", "rei01_3a.grp", "rei01_3b.grp", "rei01_3c.grp",
  "rei01_3d.grp", "rei01_4.grp", "rei01_4a.grp", "rei01_4b.grp",
  "rei01_4c.grp", "rei01_4d.grp", "rei02_1.grp", "rei02_1a.grp",
  "rei02_1b.grp", "rei02_1c.grp", "rei02_1d.grp", "rei02_2.grp",
  "rei02_2a.grp", "rei02_2b.grp", "rei02_2c.grp", "rei02_2d.grp",
  "rei02_3.grp", "rei02_3a.grp", "rei02_3b.grp", "rei02_3c.grp",
  "rei02_3d.grp", "rei02_4.grp", "rei02_4a.grp", "rei02_4b.grp",
  "rei02_4c.grp", "rei02_4d.grp", "rei03_1.grp", "rei03_1a.grp",
  "rei03_1b.grp", "rei03_1c.grp", "rei03_1d.grp", "rei03_2.grp",
  "rei03_2a.grp", "rei03_2b.grp", "rei03_2c.grp", "rei03_2d.grp",
  "rei03_3.grp", "rei03_3a.grp", "rei03_3b.grp", "rei03_3c.grp",
  "rei03_3d.grp", "rei03_4.grp", "rei03_4a.grp", "rei03_4b.grp",
  "rei03_4c.grp", "rei03_4d.grp", "rei04_1.grp", "rei04_1a.grp",
  "rei04_1b.grp", "rei04_1c.grp", "rei04_1d.grp", "rei04_2.grp",
  "rei04_2a.grp", "rei04_2b.grp", "rei04_2c.grp", "rei04_2d.grp",
  "rei04_3.grp", "rei04_3a.grp", "rei04_3b.grp", "rei04_3c.grp",
  "rei04_3d.grp", "rei04_4.grp", "rei04_4a.grp", "rei04_4b.grp",
  "rei04_4c.grp", "rei04_4d.grp", "rei05_1.grp", "rei05_1a.grp",
  "rei05_1b.grp", "rei05_1c.grp", "rei05_1d.grp", "rei05_2.grp",
  "rei05_2a.grp", "rei05_2b.grp", "rei05_2c.grp", "rei05_2d.grp",
  "rei05_3.grp", "rei05_3a.grp", "rei05_3b.grp", "rei05_3c.grp",
  "rei05_3d.grp", "rei05_4.grp", "rei05_4a.grp", "rei05_4b.grp",
  "rei05_4c.grp", "rei05_4d.grp", "rei06_1.grp", "rei06_1a.grp",
  "rei06_1b.grp", "rei06_1c.grp", "rei06_1d.grp", "rei06_2.grp",
  "rei06_2a.grp", "rei06_2b.grp", "rei06_2c.grp", "rei06_2d.grp",
  "rei06_3.grp", "rei06_3a.grp", "rei06_3b.grp", "rei06_3c.grp",
  "rei06_3d.grp", "rei06_4.grp", "rei06_4a.grp", "rei06_4b.grp",
  "rei06_4c.grp", "rei06_4d.grp", "suz01_1.grp", "suz01_1a.grp",
  "suz01_1b.grp", "suz01_1c.grp", "suz01_1d.grp", "yu01_1.grp",
  "yu01_1a.grp", "yu01_1b.grp", "yu01_1c.grp", "yu01_1d.grp",
  "yu01_2.grp", "yu01_2a.grp", "yu01_2b.grp", "yu01_2c.grp",
  "yu01_2d.grp", "yu01_3.grp", "yu01_3a.grp", "yu01_3b.grp",
  "yu01_3c.grp", "yu01_3d.grp", "yu01_4.grp", "yu01_4a.grp",
  "yu01_4b.grp", "yu01_4c.grp", "yu01_4d.grp", "yu01_5.grp",
  "yu01_5a.grp", "yu01_5b.grp", "yu01_5c.grp", "yu01_5d.grp",
  "yu01_6.grp", "yu01_6a.grp", "yu01_6b.grp", "yu01_6c.grp",
  "yu01_6d.grp", "yu01_7.grp", "yu01_7a.grp", "yu01_7b.grp",
  "yu01_7c.grp", "yu01_7d.grp", "yu01_8.grp", "yu01_8a.grp",
  "yu01_8b.grp", "yu01_8c.grp", "yu01_8d.grp", "yu02_1.grp",
  "yu02_1a.grp", "yu02_1b.grp", "yu02_1c.grp", "yu02_1d.grp",
  "yu02_2.grp", "yu02_2a.grp", "yu02_2b.grp", "yu02_2c.grp",
  "yu02_2d.grp", "yu02_3.grp", "yu02_3a.grp", "yu02_3b.grp",
  "yu02_3c.grp", "yu02_3d.grp", "yu02_4.grp", "yu02_4a.grp",
  "yu02_4b.grp", "yu02_4c.grp", "yu02_4d.grp", "yu02_5.grp",
  "yu02_5a.grp", "yu02_5b.grp", "yu02_5c.grp", "yu02_5d.grp",
  "yu02_6.grp", "yu02_6a.grp", "yu02_6b.grp", "yu02_6c.grp",
  "yu02_6d.grp", "yu02_7.grp", "yu02_7a.grp", "yu02_7b.grp",
  "yu02_7c.grp", "yu02_7d.grp", "yu02_8.grp", "yu02_8a.grp",
  "yu02_8b.grp", "yu02_8c.grp", "yu02_8d.grp", "yu03_1.grp",
  "yu03_1a.grp", "yu03_1b.grp", "yu03_1c.grp", "yu03_1d.grp",
  "yu03_2.grp", "yu03_2a.grp", "yu03_2b.grp", "yu03_2c.grp",
  "yu03_2d.grp", "yu04_1.grp", "yu04_1a.grp", "yu04_1b.grp",
  "yu04_1c.grp", "yu04_1d.grp",

  /* EventCG.pak */
  "asa01_0.grp", "asa01_1.grp", "asa02_0.grp", "asa03_1.grp",
  "asa03_3.grp", "asa03_5.grp", "asa04_0.grp", "asa04_1.grp",
  "asa04_2.grp", "asa05_0.grp", "asa05_1.grp", "asa06_0.grp",
  "asa07_0.grp", "asa08_0.grp", "asa08_1.grp", "asa08_2.grp",
  "asa09_0.grp", "asa09_1.grp", "asa09_2.grp", "asa09_3.grp",
  "asa10_0.grp", "asa10_2.grp", "asa10_3.grp", "asa10_4.grp",
  "asa10_5.grp", "asa10_6.grp", "asa11_0.grp", "asa11_1.grp",
  "asa12_0.grp", "asa12_1.grp", "asa12_2.grp", "asa13_0.grp",
  "asa13_1.grp", "asa14_0.grp", "asa16_0.grp", "asa16_1.grp",
  "asa17_0.grp", "asa17_1.grp", "asa18_0.grp", "asa18_1.grp",
  "asa19_0.grp", "asa20_0.grp", "asa20_1.grp", "asa21_0.grp",
  "asa21_1.grp", "asa21_3.grp", "asa21_5.grp", "aya01_0.grp",
  "aya02_0.grp", "aya02_1.grp", "aya02_2.grp", "aya02_3.grp",
  "aya02_4.grp", "aya02_5.grp", "aya03_0.grp", "aya03_1.grp",
  "aya03_2.grp", "aya03_3.grp", "aya04_0.grp", "aya05_0.grp",
  "aya06_0.grp", "aya06_1.grp", "aya07_0.grp", "aya08_0.grp",
  "aya09_0.grp", "aya10_0.grp", "aya11_0.grp", "aya12_0.grp",
  "aya16_0.grp", "aya16_1.grp", "aya16_2.grp", "aya16_3.grp",
  "aya17_0.grp", "aya18_0.grp", "aya18_1.grp", "aya19_0.grp",
  "aya20_0.grp", "aya20_1.grp", "ban01_0.grp", "chi01_0.grp",
  "chi02_0.grp", "chi03_0.grp", "chi04_0.grp", "chi04_1.grp",
  "chi04_2.grp", "chi04_3.grp", "chi04_4.grp", "chi05_0.grp",
  "chi05_1.grp", "chi05_2.grp", "chi05_3.grp", "chi05_4.grp",
  "chi06_0.grp", "chi06_1.grp", "chi07_0.grp", "chi08_0.grp",
  "chi08_2.grp", "chi08_3.grp", "chi09_0.grp", "chi10_0.grp",
  "chi10_1.grp", "chi10_2.grp", "chi11_0.grp", "chi11_1.grp",
  "chi12_0.grp", "chi13_0.grp", "chi16_0.grp", "chi16_1.grp",
  "chi16_2.grp", "chi17_0.grp", "chi18_0.grp", "chi19_0.grp",
  "chi20_0.grp", "chi20_1.grp", "eim01_0.grp", "eim03_0.grp",
  "eim04_0.grp", "eim05_0.grp", "eim05_1.grp", "eim05_2.grp",
  "eim05_3.grp", "eim06_0.grp", "eim07_0.grp", "eim07_1.grp",
  "eim08_0.grp", "eim09_0.grp", "eim10_0.grp", "eim11_0.grp",
  "eim12_0.grp", "eim13_0.grp", "eim13_1.grp", "eim14_0.grp",
  "eim15_0.grp", "eim15_1.grp", "eim16_0.grp", "eim16_1.grp",
  "eim16_2.grp", "eim17_0.grp", "eim18_0.grp", "eim18_1.grp",
  "eim19_0.grp", "eim19_1.grp", "eim20_0.grp", "eim20_1.grp",
  "iku01_0.grp", "iku02_0.grp", "iku03_0.grp", "iku03_1.grp",
  "kuh01_0.grp", "min01_0.grp", "min01_1.grp", "min01_11.grp",
  "min01_3.grp", "min01_5.grp", "min01_7.grp", "min01_8.grp",
  "min01_9.grp", "min02_0.grp", "min03_0.grp", "min05_0.grp",
  "min05_1.grp", "min07_0.grp", "min07_1.grp", "min07_2.grp",
  "min07_3.grp", "min07_4.grp", "min07_5.grp", "min08_0.grp",
  "min08_1.grp", "min08_2.grp", "min09_0.grp", "min09_1.grp",
  "min09_2.grp", "min10_0.grp", "min11_0.grp", "min11_1.grp",
  "min11_2.grp", "min11_3.grp", "min12_0.grp", "min12_1.grp",
  "min13_0.grp", "min13_1.grp", "min13_2.grp", "min13_3.grp",
  "min14_0.grp", "min14_1.grp", "min15_0.grp", "min16_0.grp",
  "min16_1.grp", "min17_0.grp", "min17_1.grp", "min17_2.grp",
  "min17_3.grp", "min17_4.grp", "min17_5.grp", "min18_0.grp",
  "min18_1.grp", "min19_0.grp", "min19_1.grp", "min19_2.grp",
  "min19_3.grp", "min20_0.grp", "min20_1.grp", "min20_2.grp",
  "min20_3.grp", "miz01_0.grp", "miz02_0.grp", "miz03_0.grp",
  "miz03_1.grp", "miz03_2.grp", "miz03_3.grp", "miz04_0.grp",
  "miz04_1.grp", "miz04_2.grp", "miz04_3.grp", "miz05_0.grp",
  "miz06_0.grp", "miz07_0.grp", "miz08_0.grp", "miz09_0.grp",
  "miz10_0.grp", "miz11_0.grp", "miz11_1.grp", "miz12_0.grp",
  "miz13_0.grp", "miz13_1.grp", "miz13_2.grp", "miz13_3.grp",
  "miz14_0.grp", "miz14_1.grp", "miz14_2.grp", "miz14_3.grp",
  "miz14_4.grp", "miz14_5.grp", "miz15_0.grp", "miz16_0.grp",
  "miz16_1.grp", "miz17_0.grp", "miz18_0.grp", "miz18_1.grp",
  "miz19_0.grp", "miz19_1.grp", "miz20_0.grp", "miz20_1.grp",
  "rei01_0.grp", "rei01_1.grp", "rei02_0.grp", "rei03_0.grp",
  "rei04_0.grp", "rei04_1.grp", "rei05_0.grp", "rei06_0.grp",
  "rei07_0.grp", "rei08_0.grp", "rei08_1.grp", "rei09_0.grp",
  "rei09_1.grp", "rei09_2.grp", "rei10_0.grp", "rei10_1.grp",
  "rei11_0.grp", "rei12_0.grp", "rei12_1.grp", "yu01_0.grp",
  "yu02_0.grp", "yu02_1.grp", "yu03_0.grp", "yu05_0.grp", "yu06_0.grp",
  "yu07_0.grp", "yu09_0.grp", "yu09_1.grp", "yu09_2.grp", "yu10_0.grp",
  "yu11_0.grp", "yu11_1.grp", "yu11_2.grp", "yu11_3.grp", "yu13_0.grp",
  "yu13_1.grp", "yu14_0.grp", "yu14_1.grp", "yu15_0.grp", "yu16_0.grp",
  "yu16_1.grp", "yu17_0.grp", "yu17_1.grp", "yu18_0.grp", "yu18_1.grp",
  "yu19_0.grp", "yu20_0.grp", "yu20_1.grp",

  /* amuse.pak */
  "back.grp", "front.grp", "shutter.grp", "vehicl00.grp",
  "vehicl01.grp", "vehicl02.grp", "vehicl10.grp", "vehicl11.grp",
  "vehicl12.grp", "vehicl20.grp", "vehicl21.grp", "vehicl22.grp",
  "vehicl23.grp", "vehicl24.grp", "vehicl30.grp", "vehicl31.grp",
  "vehicl32.grp", "vehicl33.grp", "vehicl34.grp", "vehicl40.grp",
  "vehicl41.grp", "vehicl42.grp", "vehicl50.grp", "vehicl51.grp",
  "vehicl52.grp", "vehicl53.grp", "vehicl54.grp", "zombie00.grp",
  "zombie01.grp", "zombie02.grp", "zombie03.grp", "zombie04.grp",
  "zombie05.grp", "zombie06.grp", "zombie07.grp", "zombie08.grp",
  "zombie09.grp", "zombie10.grp", "zombie11.grp", "zombie12.grp",
  "zombie13.grp",

  /* arima.pak */
  "hrwrk00.grp", "hrwrk01.grp", "hrwrk02.grp", "hrwrk10.grp", 
  "hrwrk11.grp", "hrwrk12.grp", "wall.grp", 

  /* cgmode.pak */
  "asa.grp", "asa00.grp", "asa01.grp", "asa02.grp", "aya.grp",
  "aya00.grp", "aya01.grp", "aya02.grp", "chi.grp", "chi00.grp",
  "chi01.grp", "chi02.grp", "eim.grp", "eim00.grp", "eim01.grp",
  "eim02.grp", "iku.grp", "iku00.grp", "iku01.grp", "iku02.grp",
  "min.grp", "min00.grp", "min01.grp", "min02.grp", "miz.grp",
  "miz00.grp", "miz01.grp", "miz02.grp", "rei.grp", "rei00.grp",
  "rei01.grp", "rei02.grp", "yu.grp", "yu00.grp", "yu01.grp",
  "yu02.grp",
  
  /* cmkdate.pak */
  "asa01_0.grp", "asa01_1.grp", "asa01_2.grp", "asa01_3.grp",
  "asa01_4.grp", "asa01_5.grp", "asa02_0.grp", "asa02_1.grp",
  "asa02_2.grp", "asa02_3.grp", "asa02_4.grp", "asa02_5.grp",
  "back.grp", "hero01_0.grp", "hero01_1.grp", "hero01_2.grp",
  "hero02_0.grp", "hero02_1.grp", "hero02_2.grp", "miz01_0.grp",
  "miz01_1.grp", "miz01_2.grp", "miz02_0.grp", "miz02_1.grp",
  "miz02_2.grp", "miz03_0.grp", "miz03_1.grp", "miz03_2.grp",
  "rei01_0.grp", "rei01_1.grp", "rei01_2.grp", "rei02_0.grp",
  "rei02_1.grp", "rei02_2.grp",

  /* cmkmap.pak */
  "bchr000.grp", "bchr001.grp", "bchr002.grp", "bchr003.grp",
  "bchr010.grp", "bchr011.grp", "bchr012.grp", "bchr013.grp",
  "bchr020.grp", "bchr021.grp", "bchr022.grp", "bchr023.grp",
  "bchr030.grp", "bchr031.grp", "bchr032.grp", "bchr033.grp",
  "bchr040.grp", "bchr041.grp", "bchr042.grp", "bchr043.grp",
  "bchr050.grp", "bchr051.grp", "bchr052.grp", "bchr053.grp",
  "bchr060.grp", "bchr061.grp", "bchr062.grp", "bchr063.grp",
  "bchr070.grp", "bchr071.grp", "bchr072.grp", "bchr073.grp",
  "bchr100.grp", "bchr101.grp", "bchr102.grp", "bchr103.grp",
  "bchr110.grp", "bchr111.grp", "bchr112.grp", "bchr113.grp",
  "bstr00.grp", "bstr01.grp", "bstr02.grp", "bstr03.grp", "bstr04.grp",
  "bstr05.grp", "bstr06.grp", "bstr07.grp", "bstr08.grp", "bstr09.grp",
  "bstr10.grp", "chara000.grp", "chara001.grp", "chara002.grp",
  "chara003.grp", "chara010.grp", "chara011.grp", "chara012.grp",
  "chara013.grp", "chara020.grp", "chara021.grp", "chara022.grp",
  "chara023.grp", "chara030.grp", "chara031.grp", "chara032.grp",
  "chara033.grp", "chara040.grp", "chara041.grp", "chara042.grp",
  "chara043.grp", "chara050.grp", "chara051.grp", "chara052.grp",
  "chara053.grp", "chara060.grp", "chara061.grp", "chara062.grp",
  "chara063.grp", "chara070.grp", "chara071.grp", "chara072.grp",
  "chara073.grp", "chara080.grp", "chara081.grp", "chara082.grp",
  "chara083.grp", "chara090.grp", "chara091.grp", "chara092.grp",
  "chara093.grp", "chara100.grp", "chara101.grp", "chara102.grp",
  "chara103.grp", "chara110.grp", "chara111.grp", "chara112.grp",
  "chara113.grp", "map0.grp", "map1.grp", "map2.grp", "place00.grp",
  "place01.grp", "place02.grp", "place03.grp", "place04.grp",
  "place05.grp", "place06.grp", "place07.grp", "place08.grp",
  "place09.grp", "place10.grp", "place11.grp", "string00.grp",
  "string01.grp", "string02.grp", "string03.grp", "string04.grp",
  "string05.grp", "string06.grp", "string07.grp", "string08.grp",
  "string09.grp", "string10.grp", "town000.grp", "town001.grp",
  "town002.grp", "town003.grp", "town010.grp", "town011.grp",
  "town012.grp", "town013.grp", "town020.grp", "town021.grp",
  "town022.grp", "town023.grp", "town030.grp", "town031.grp",
  "town032.grp", "town033.grp", "town040.grp", "town041.grp",
  "town042.grp", "town043.grp", "town050.grp", "town051.grp",
  "town052.grp", "town053.grp", "town060.grp", "town061.grp",
  "town062.grp", "town063.grp", "town070.grp", "town071.grp",
  "town072.grp", "town073.grp", "town080.grp", "town081.grp",
  "town082.grp", "town083.grp", "town090.grp", "town091.grp",
  "town092.grp", "town093.grp", "town100.grp", "town101.grp",
  "town102.grp", "town103.grp", "town110.grp", "town111.grp",
  "town112.grp", "town113.grp", "yoshio.grp",

  /* comike.pak */
  "asa01_1.grp", "asa01_2.grp", "asa01_3.grp", "asa01_4.grp",
  "asa01_5.grp", "asa01_6.grp", "asa01_7.grp", "asa02_1.grp",
  "asa02_2.grp", "asa02_3.grp", "asa02_4.grp", "asa02_5.grp",
  "asa02_6.grp", "asa02_7.grp", "asaback.grp", "bird0.grp", "bird1.grp",
  "bird2.grp", "bird3.grp", "cargo0.grp", "cargo1.grp", "cargo2.grp",
  "cargo3.grp", "cargo4.grp", "chi01_1.grp", "chi01_10.grp",
  "chi01_11.grp", "chi01_12.grp", "chi01_13.grp", "chi01_14.grp",
  "chi01_15.grp", "chi01_16.grp", "chi01_2.grp", "chi01_3.grp",
  "chi01_4.grp", "chi01_5.grp", "chi01_6.grp", "chi01_7.grp",
  "chi01_8.grp", "chi01_9.grp", "chi02_1.grp", "chi02_10.grp",
  "chi02_11.grp", "chi02_12.grp", "chi02_13.grp", "chi02_14.grp",
  "chi02_15.grp", "chi02_16.grp", "chi02_2.grp", "chi02_3.grp",
  "chi02_4.grp", "chi02_5.grp", "chi02_6.grp", "chi02_7.grp",
  "chi02_8.grp", "chi02_9.grp", "desk0.grp", "desk1.grp", "desk2.grp",
  "desk3.grp", "fire0.grp", "fire1.grp", "fire2.grp", "gstal00.grp",
  "gstal01.grp", "gstal02.grp", "gstal10.grp", "gstal11.grp",
  "gstal12.grp", "gstal20.grp", "gstal21.grp", "gstal22.grp",
  "gstal30.grp", "gstal31.grp", "gstal32.grp", "gstar00.grp",
  "gstar01.grp", "gstar02.grp", "gstar10.grp", "gstar11.grp",
  "gstar12.grp", "gstar20.grp", "gstar21.grp", "gstar22.grp",
  "gstbl00.grp", "gstbl01.grp", "gstbl02.grp", "gstbl10.grp",
  "gstbl11.grp", "gstbl12.grp", "gstbl20.grp", "gstbl21.grp",
  "gstbl22.grp", "gstbl30.grp", "gstbl31.grp", "gstbl32.grp",
  "gstbr00.grp", "gstbr01.grp", "gstbr02.grp", "gstbr10.grp",
  "gstbr11.grp", "gstbr12.grp", "gstbr20.grp", "gstbr21.grp",
  "gstbr22.grp", "gstsml00.grp", "gstsml01.grp", "gstsml02.grp",
  "gstsml10.grp", "gstsml11.grp", "gstsml12.grp", "gstsml20.grp",
  "gstsml21.grp", "gstsml22.grp", "gstsml30.grp", "gstsml31.grp",
  "gstsml32.grp", "gstsmr00.grp", "gstsmr01.grp", "gstsmr02.grp",
  "gstsmr10.grp", "gstsmr11.grp", "gstsmr12.grp", "gstsmr20.grp",
  "gstsmr21.grp", "gstsmr22.grp", "gstspl00.grp", "gstspl01.grp",
  "gstspl02.grp", "gstspl10.grp", "gstspl11.grp", "gstspl12.grp",
  "gstspl20.grp", "gstspl21.grp", "gstspl22.grp", "gstspl30.grp",
  "gstspl31.grp", "gstspl32.grp", "gstspr00.grp", "gstspr01.grp",
  "gstspr02.grp", "gstspr10.grp", "gstspr11.grp", "gstspr12.grp",
  "gstspr20.grp", "gstspr21.grp", "gstspr22.grp", "gstwnl00.grp",
  "gstwnl01.grp", "gstwnl02.grp", "gstwnl10.grp", "gstwnl11.grp",
  "gstwnl12.grp", "gstwnl20.grp", "gstwnl21.grp", "gstwnl22.grp",
  "gstwnl30.grp", "gstwnl31.grp", "gstwnl32.grp", "gstwnr00.grp",
  "gstwnr01.grp", "gstwnr02.grp", "gstwnr10.grp", "gstwnr11.grp",
  "gstwnr12.grp", "gstwnr20.grp", "gstwnr21.grp", "gstwnr22.grp",
  "hero00.grp", "hero01.grp", "hero02.grp", "hero03.grp", "hero04.grp",
  "hero05.grp", "hero06.grp", "hero10.grp", "hero11.grp", "hero12.grp",
  "hero13.grp", "hero14.grp", "hero15.grp", "hero16.grp",
  "heroheb0.grp", "heroheb1.grp", "heroout0.grp", "heroout1.grp",
  "kuh01_1.grp", "kuh01_2.grp", "kuh01_3.grp", "kuh01_4.grp",
  "kuh01_5.grp", "kuh01_6.grp", "kuh01_7.grp", "kuh02_1.grp",
  "kuh02_2.grp", "kuh02_3.grp", "kuh02_4.grp", "kuh02_5.grp",
  "kuh02_6.grp", "kuh02_7.grp", "min01_1.grp", "min01_2.grp",
  "min01_3.grp", "min01_4.grp", "min01_5.grp", "min01_6.grp",
  "min01_7.grp", "min02_1.grp", "min02_2.grp", "min02_3.grp",
  "min02_4.grp", "min02_5.grp", "min02_6.grp", "min02_7.grp",
  "miz01_1.grp", "miz01_2.grp", "miz01_3.grp", "miz01_4.grp",
  "miz01_5.grp", "miz01_6.grp", "miz01_7.grp", "miz02_1.grp",
  "miz02_2.grp", "miz02_3.grp", "miz02_4.grp", "miz02_5.grp",
  "miz02_6.grp", "miz02_7.grp", "miz03_1.grp", "miz03_2.grp",
  "miz03_3.grp", "miz03_4.grp", "miz03_5.grp", "miz03_6.grp",
  "miz03_7.grp", "nbraya0.grp", "nbraya1.grp", "nbreimi0.grp",
  "nbreimi1.grp", "nbrnml0.grp", "nbrnml1.grp", "nbrnml10.grp",
  "nbrnml11.grp", "nbrnml2.grp", "nbrnml3.grp", "nbrnml4.grp",
  "nbrnml5.grp", "nbrnml6.grp", "nbrnml7.grp", "nbrnml8.grp",
  "nbrnml9.grp", "nbryu0.grp", "nbryu1.grp", "nmlback.grp",
  "rei01_1.grp", "rei01_10.grp", "rei01_11.grp", "rei01_12.grp",
  "rei01_2.grp", "rei01_3.grp", "rei01_4.grp", "rei01_5.grp",
  "rei01_6.grp", "rei01_7.grp", "rei01_8.grp", "rei01_9.grp",
  "rei02_1.grp", "rei02_10.grp", "rei02_11.grp", "rei02_12.grp",
  "rei02_2.grp", "rei02_3.grp", "rei02_4.grp", "rei02_5.grp",
  "rei02_6.grp", "rei02_7.grp", "rei02_8.grp", "rei02_9.grp",
  "stf01_1.grp", "stf01_2.grp", "sweat.grp", "wallback.grp",

  /* ending.pak */
  "end1.grp", "end2.grp", "list1.grp", "list10.grp", "list11.grp",
  "list12.grp", "list13.grp", "list14.grp", "list15.grp", "list16.grp",
  "list17.grp", "list18.grp", "list19.grp", "list2.grp", "list20.grp",
  "list21.grp", "list22.grp", "list23.grp", "list24.grp", "list25.grp",
  "list26.grp", "list27.grp", "list3.grp", "list4.grp", "list5.grp",
  "list6.grp", "list7.grp", "list8.grp", "list9.grp", "pic1.grp",
  "pic10.grp", "pic2.grp", "pic3.grp", "pic4.grp", "pic5.grp",
  "pic6.grp", "pic7.grp", "pic8.grp", "pic9.grp",

  /* exercise.pak */
  "hrexe0.grp", "hrexe1.grp", "hrexe2.grp", "wall.grp", 

  /* festival.pak */
  "back.grp", "heros0.grp", "heros1.grp", "heros2.grp", "heros3.grp",
  "heros4.grp", "herow0.grp", "herow1.grp", "herow2.grp", "min00.grp",
  "min01.grp", "min02.grp", "min10.grp", "min11.grp", "min12.grp",
  "obj000.grp", "obj001.grp", "obj002.grp", "obj003.grp", "obj004.grp",
  "obj005.grp", "obj006.grp", "obj007.grp", "obj008.grp", "obj009.grp",
  "obj010.grp", "obj011.grp", "obj012.grp", "obj100.grp", "obj101.grp",
  "obj102.grp", "obj103.grp", "obj104.grp", "obj105.grp", "obj106.grp",
  "obj107.grp", "obj108.grp", "obj109.grp", "obj110.grp", "obj111.grp",
  "obj112.grp", "yu0.grp", "yu1.grp", "yu2.grp", "yu3.grp", "yu4.grp",

  /* frame.pak */
  "btn00.grp", "btn01.grp", "confm1.grp", "confm10.grp", "confm11.grp",
  "confm2.grp", "confm3.grp", "confm4.grp", "confm5.grp", "confm6.grp",
  "confm7.grp", "confm8.grp", "confm9.grp", "confmbs.grp",
  "coverbs.grp", "cvroff0.grp", "cvroff1.grp", "genbtn.grp",
  "gendown.grp", "genkoh.grp", "genup.grp", "gsel00.grp", "gsel01.grp",
  "gsel02.grp", "gsel03.grp", "gsel04.grp", "gsel05.grp", "gsel06.grp",
  "gsel07.grp", "gsel10.grp", "gsel11.grp", "gsel12.grp", "gsel13.grp",
  "gsel14.grp", "gsel15.grp", "gsel16.grp", "gsel17.grp", "gsel20.grp",
  "gsel21.grp", "gsel22.grp", "gsel23.grp", "gsel24.grp", "gsel25.grp",
  "gsel26.grp", "gsel27.grp", "gsel30.grp", "gsel31.grp", "gsel32.grp",
  "gsel33.grp", "gsel34.grp", "gsel35.grp", "gsel36.grp", "gsel37.grp",
  "gsel3off.grp", "gsel4off.grp", "gselback.grp", "gselbtn0.grp",
  "gselbtn1.grp", "gselbtn2.grp", "gselbtn3.grp", "infomes.grp",
  "infomes2.grp", "inpkind0.grp", "inpkind1.grp", "inpkind2.grp",
  "inpkind3.grp", "mesonl.grp", "mesonr.grp", "mesons.grp",
  "mespushl.grp", "mespushr.grp", "mespushs.grp", "message0.grp",
  "message1.grp", "message2.grp", "message3.grp", "message4.grp",
  "message5.grp", "message6.grp", "message7.grp", "message8.grp",
  "name0.grp", "name1.grp", "name2.grp", "name3.grp", "name4.grp",
  "name5.grp", "name6.grp", "name7.grp", "name8.grp", "naminpbs.grp",
  "pgsel.grp", "pseloff0.grp", "pseloff1.grp", "pseloff2.grp",
  "pseloff3.grp", "pseloff4.grp", "pseloff5.grp", "pselon0.grp",
  "pselon1.grp", "pselon2.grp", "pselon3.grp", "pselon4.grp",
  "pselon5.grp", "saveload.grp", "seldown0.grp", "seldown1.grp",
  "seldown2.grp", "seldown3.grp", "seldown4.grp", "seldown5.grp",
  "seldown6.grp", "seldown7.grp", "sell00.grp", "sell01.grp",
  "sell02.grp", "sell10.grp", "sell11.grp", "sell12.grp", "sell20.grp",
  "sell21.grp", "sell22.grp", "sell30.grp", "sell31.grp", "sell32.grp",
  "sell40.grp", "sell41.grp", "sell42.grp", "sell50.grp", "sell51.grp",
  "sell52.grp", "sell60.grp", "sell61.grp", "sell62.grp", "sell70.grp",
  "sell71.grp", "sell72.grp", "sell80.grp", "sell81.grp", "sell82.grp",
  "selm00.grp", "selm01.grp", "selm02.grp", "selm10.grp", "selm11.grp",
  "selm12.grp", "selm20.grp", "selm21.grp", "selm22.grp", "selm30.grp",
  "selm31.grp", "selm32.grp", "selm40.grp", "selm41.grp", "selm42.grp",
  "selm50.grp", "selm51.grp", "selm52.grp", "selm60.grp", "selm61.grp",
  "selm62.grp", "selm70.grp", "selm71.grp", "selm72.grp", "selm80.grp",
  "selm81.grp", "selm82.grp", "selover0.grp", "selover1.grp",
  "selover2.grp", "selover3.grp", "selover4.grp", "selover5.grp",
  "selover6.grp", "selover7.grp", "sels00.grp", "sels01.grp",
  "sels02.grp", "sels10.grp", "sels11.grp", "sels12.grp", "sels20.grp",
  "sels21.grp", "sels22.grp", "sels30.grp", "sels31.grp", "sels32.grp",
  "sels40.grp", "sels41.grp", "sels42.grp", "sels50.grp", "sels51.grp",
  "sels52.grp", "sels60.grp", "sels61.grp", "sels62.grp", "sels70.grp",
  "sels71.grp", "sels72.grp", "sels80.grp", "sels81.grp", "sels82.grp",
  "titlebs.grp", "wiper0.grp", "wiper1.grp",

  /* guest.pak */
  "a01.grp", "a02.grp", "a03.grp", "a04.grp", "a05.grp", "a06.grp",
  "a07.grp", "a08.grp", "a09.grp", "a10.grp", "a11.grp", "a12.grp",
  "a13.grp", "a14.grp", "a15.grp", "a16.grp", "a17.grp", "a18.grp",
  "a19.grp", "a20.grp", "a21.grp", "a22.grp", "a23.grp", "a24.grp",
  "a25.grp", "a26.grp", "a27.grp", "a28.grp", "a29.grp", "a30.grp",
  "a31.grp", "a32.grp", "a33.grp", "a34.grp", "a35.grp", "a36.grp",
  "a37.grp", "a38.grp", "a39.grp", "a40.grp", "a41.grp", "a42.grp",
  "a43.grp", "a44.grp", "a45.grp", "a46.grp", "a47.grp", "a48.grp",
  "a49.grp", "a50.grp", "a51.grp", "a52.grp", "a53.grp", "a54.grp",
  "a55.grp", "a56.grp", "a57.grp", "a58.grp", "b01.grp", "b02.grp",
  "b03.grp", "b04.grp", "b05.grp", "b06.grp", "b07.grp", "b08.grp",
  "b09.grp", "b10.grp", "b11.grp", "b12.grp", "b13.grp", "b14.grp",
  "b15.grp", "b16.grp", "b17.grp", "b18.grp", "b19.grp", "b20.grp",
  "b21.grp", "b22.grp", "b23.grp", "b24.grp", "b25.grp", "b26.grp",
  "b27.grp", "b28.grp", "b29.grp", "b30.grp", "b31.grp", "b32.grp",
  "b33.grp", "b34.grp", "b35.grp", "b36.grp", "b37.grp", "b38.grp",
  "b39.grp", "b40.grp", "b41.grp", "b42.grp", "b43.grp", "b44.grp",
  "b45.grp", "b46.grp", "b47.grp", "b48.grp", "b49.grp", "b50.grp",
  "b51.grp", "b52.grp", "b53.grp", "b54.grp", "b55.grp", "b56.grp",
  "b57.grp", "b58.grp",

  /* hcosplay.pak */
  "back.grp", "cameraa0.grp", "cameraa1.grp", "cameraa2.grp",
  "cameraa3.grp", "cameraa4.grp", "camerab0.grp", "camerab1.grp",
  "cospl00.grp", "cospl01.grp", "cospl10.grp", "cospl11.grp",
  "hero01_0.grp", "hero01_1.grp", "hero01_2.grp", "hero02_0.grp",
  "hero02_1.grp", "hero02_2.grp", "rei01_0.grp", "rei01_1.grp",
  "rei01_2.grp",

  /* item.pak */
  "item00.grp", "item01.grp", "item02.grp", "item03.grp",
  "item04.grp", "item05.grp", "item06.grp", "item07.grp",
  "item08.grp", "item09.grp", "item10.grp",

  /* movie.pak */
  "action0.grp", "action1.grp", "action2.grp", "action3.grp",
  "chisa0.grp", "chisa1.grp", "chisa2.grp", "chisa3.grp", "chisa4.grp",
  "chisa5.grp", "horror0.grp", "horror1.grp", "horror2.grp",
  "horror3.grp", "love0.grp", "love1.grp", "love2.grp", "love3.grp",
  "min0.grp", "min1.grp", "min2.grp", "miz0.grp", "miz1.grp",
  "miz2.grp",

  /* newyear.pak */
  "back.grp", "chi0.grp", "chi1.grp", "chi2.grp", "chi3.grp",
  "chi4.grp", "chi5.grp", "hero00.grp", "hero01.grp", "hero02.grp",
  "hero03.grp", "hero04.grp", "hero05.grp", "hero06.grp", "hero07.grp",
  "hero08.grp", "hero09.grp", "hero10.grp", "hero11.grp", "hero12.grp",
  "hero13.grp", "hero14.grp", "hero15.grp", "min0.grp", "min1.grp",
  "min2.grp", "min3.grp", "min4.grp", "miz0.grp", "miz1.grp",
  "miz2.grp", "miz3.grp", "miz4.grp", "yu0.grp", "yu1.grp", "yu2.grp",
  "yu3.grp", "yu4.grp", "yu5.grp", "yu6.grp",

  /* opening.pak */
  "all.grp", "ariake1.grp", "ariake2.grp", "ariake3.grp", "ariake4.grp",
  "ariake5.grp", "ariake6.grp", "ariake7.grp", "ariake8.grp",
  "ariake9.grp", "ariakea.grp", "banro.grp", "cut-a1.grp", "cut-a2.grp",
  "cut-a3.grp", "cut-all.grp", "koma1.grp", "koma10.grp", "koma11.grp",
  "koma12.grp", "koma13.grp", "koma14.grp", "koma15.grp", "koma16.grp",
  "koma17.grp", "koma18.grp", "koma19.grp", "koma2.grp", "koma20.grp",
  "koma22.grp", "koma23.grp", "koma24.grp", "koma25.grp", "koma27.grp",
  "koma28.grp", "koma29.grp", "koma3.grp", "koma30.grp", "koma32.grp",
  "koma33.grp", "koma34.grp", "koma35.grp", "koma37.grp", "koma38.grp",
  "koma39.grp", "koma4.grp", "koma40.grp", "koma5.grp", "koma6.grp",
  "koma7.grp", "koma8.grp", "koma9.grp", "leaf.grp", "m1.grp", "m2.grp",
  "m3.grp", "m4.grp", "m5.grp", "m6.grp", "m6a.grp", "m7.grp", "m8.grp",
  "poster.grp", "rough1.grp", "rough2.grp", "rough3.grp", "tate.grp",
  "up1.grp", "up2.grp", "up3.grp", "up4.grp", "up4_1.grp", "up4_2.grp",
  "yoko.grp",

  /* param.pak */
  "advance0.grp", "advance1.grp", "base00.grp", "base01.grp",
  "base10.grp", "base11.grp", "base20.grp", "base21.grp", "base30.grp",
  "base31.grp", "base40.grp", "base41.grp", "base50.grp", "base51.grp",
  "base60.grp", "base61.grp", "base70.grp", "base71.grp", "base80.grp",
  "base81.grp", "bnum0.grp", "bnum1.grp", "bnum2.grp", "bnum3.grp",
  "bnum4.grp", "bnum5.grp", "bnum6.grp", "bnum7.grp", "bnum8.grp",
  "bnum9.grp", "brush.grp", "cal000.grp", "cal001.grp", "cal010.grp",
  "cal011.grp", "cal020.grp", "cal021.grp", "cal030.grp", "cal031.grp",
  "cal040.grp", "cal041.grp", "cal050.grp", "cal051.grp", "cal060.grp",
  "cal061.grp", "cal070.grp", "cal071.grp", "cal080.grp", "cal081.grp",
  "cal090.grp", "cal091.grp", "cal100.grp", "cal101.grp",
  "command0.grp", "command1.grp", "command2.grp", "command3.grp",
  "command4.grp", "command5.grp", "conte.grp", "cover0.grp",
  "cover1.grp", "cover2.grp", "cvrrdy0.grp", "cvrrdy1.grp",
  "footer0.grp", "footer1.grp", "footer2.grp", "footer3.grp",
  "footer4.grp", "footer5.grp", "footer6.grp", "footer7.grp",
  "footer8.grp", "header0.grp", "header1.grp", "header2.grp",
  "header3.grp", "header4.grp", "header5.grp", "header6.grp",
  "header7.grp", "header8.grp", "item0.grp", "item1.grp", "level0.grp",
  "level1.grp", "level2.grp", "level3.grp", "level4.grp", "level5.grp",
  "level6.grp", "numbl0.grp", "numbl1.grp", "numbl2.grp", "numbl3.grp",
  "numbl4.grp", "numbl5.grp", "numbl6.grp", "numbl7.grp", "numbl8.grp",
  "numbl9.grp", "numrd0.grp", "numrd1.grp", "numrd2.grp", "numrd3.grp",
  "numrd4.grp", "numrd5.grp", "numrd6.grp", "numrd7.grp", "numrd8.grp",
  "numrd9.grp", "numwt0.grp", "numwt1.grp", "numwt2.grp", "numwt3.grp",
  "numwt4.grp", "numwt5.grp", "numwt6.grp", "numwt7.grp", "numwt8.grp",
  "numwt9.grp", "param0.grp", "param1.grp", "penon.grp", "period.grp",
  "periodr.grp", "pnum0.grp", "pnum1.grp", "pnum2.grp", "pnum3.grp",
  "pnum4.grp", "pnum5.grp", "pnum6.grp", "pnum7.grp", "pnum8.grp",
  "pnum9.grp", "price0.grp", "price1.grp", "season0.grp", "season1.grp",
  "season2.grp", "season3.grp", "selbase.grp", "setbtn0.grp",
  "setbtn1.grp", "setbtn2.grp", "setbtn3.grp", "setbtn4.grp",
  "setbtn5.grp", "setbtn6.grp", "setting0.grp", "setting1.grp",
  "week0.grp", "week1.grp", "week2.grp", "week3.grp", "week4.grp",
  "week5.grp", "week6.grp", "yenbl.grp", "yenrd.grp",
  
  /* parttime.pak */
  "hrreg0.grp", "hrreg1.grp", "hrwrk00.grp", "hrwrk01.grp",
  "hrwrk02.grp", "hrwrk10.grp", "hrwrk11.grp", "hrwrk12.grp",
  "kuhreg0.grp", "kuhreg1.grp", "kuhwrk00.grp", "kuhwrk01.grp",
  "kuhwrk02.grp", "kuhwrk10.grp", "kuhwrk11.grp", "kuhwrk12.grp",
  "regist.grp", "wall.grp",

  /* present.pak */
  "busu_off.grp",
  "number0.grp", "number1.grp", "number2.grp", "number3.grp",
  "number4.grp", "number5.grp", "number6.grp", "number7.grp", 

  /* price.pak */
  "cover0.grp", "cover1.grp", "cover2.grp", "nedan.grp",
  "number0.grp", "number1.grp", "number2.grp", "number3.grp",
  "number4.grp", "number5.grp", "number6.grp", "number7.grp",
  "number8.grp", "number9.grp", "updown0.grp", "updown1.grp",
  
  /* print.pak */
  "book.grp", "chisa0.grp", "chisa1.grp", "chisa2.grp", 
  "chisa3.grp", "chisa4.grp", "foothold.grp", "machine.grp", 
  "wall.grp", 

  /* room.pak */
  "aya10.grp", "aya11.grp", "aya12.grp", "aya20.grp", "aya21.grp",
  "aya22.grp", "bed.grp", "chi00.grp", "chi01.grp", "chi02.grp",
  "chi03.grp", "chi04.grp", "chi05.grp", "chi06.grp", "chi07.grp",
  "chi08.grp", "chi09.grp", "desk.grp", "drink0.grp", "drink1.grp",
  "drink2.grp", "drink3.grp", "eim10.grp", "eim11.grp", "eim12.grp",
  "eim13.grp", "eim14.grp", "eim15.grp", "eim20.grp", "eim21.grp",
  "eim22.grp", "eim23.grp", "eim24.grp", "eim25.grp", "god00.grp",
  "god01.grp", "god02.grp", "god03.grp", "god10.grp", "god11.grp",
  "god12.grp", "god13.grp", "god20.grp", "god21.grp", "god22.grp",
  "god23.grp", "hotel.grp", "hraya10.grp", "hraya11.grp", "hraya12.grp",
  "hraya13.grp", "hraya14.grp", "hraya20.grp", "hraya21.grp",
  "hraya22.grp", "hraya23.grp", "hraya24.grp", "hrbd10.grp",
  "hrbd11.grp", "hrbd12.grp", "hrbd13.grp", "hrbd14.grp", "hrbd20.grp",
  "hrbd21.grp", "hrbd22.grp", "hrbd23.grp", "hrbd24.grp", "hrbed10.grp",
  "hrbed11.grp", "hrbed12.grp", "hrbed20.grp", "hrbed21.grp",
  "hrbed22.grp", "hrdp10.grp", "hrdp11.grp", "hrdp12.grp", "hrdp20.grp",
  "hrdp21.grp", "hrdp22.grp", "hrdwn1.grp", "hrdwn2.grp", "hrex10.grp",
  "hrex11.grp", "hrex12.grp", "hrex13.grp", "hrex20.grp", "hrex21.grp",
  "hrex22.grp", "hrex23.grp", "hrgd10.grp", "hrgd11.grp", "hrgd12.grp",
  "hrgd20.grp", "hrgd21.grp", "hrgd22.grp", "hrgod10.grp",
  "hrgod11.grp", "hrgod12.grp", "hrgod13.grp", "hrgod14.grp",
  "hrgod15.grp", "hrgod20.grp", "hrgod21.grp", "hrgod22.grp",
  "hrgod23.grp", "hrgod24.grp", "hrgod25.grp", "hrnml10.grp",
  "hrnml11.grp", "hrnml12.grp", "hrnml20.grp", "hrnml21.grp",
  "hrnml22.grp", "hrwk10.grp", "hrwk11.grp", "hrwk12.grp", "hrwk20.grp",
  "hrwk21.grp", "hrwk22.grp", "kuh10.grp", "kuh11.grp", "kuh20.grp",
  "kuh21.grp", "light0.grp", "light1.grp", "light2.grp", "light3.grp",
  "min00.grp", "min01.grp", "min02.grp", "min03.grp", "min04.grp",
  "min05.grp", "min10.grp", "min11.grp", "min12.grp", "min13.grp",
  "min14.grp", "min15.grp", "miz10.grp", "miz11.grp", "miz12.grp",
  "miz13.grp", "miz14.grp", "miz15.grp", "miz16.grp", "miz17.grp",
  "miz18.grp", "miz19.grp", "miz30.grp", "miz31.grp", "miz32.grp",
  "miz33.grp", "miz34.grp", "miz35.grp", "miz36.grp", "miz37.grp",
  "miz38.grp", "miz39.grp", "mouse0.grp", "mouse1.grp", "myroom.grp",
  "note.grp", "rei00.grp", "rei01.grp", "rei02.grp", "rei03.grp",
  "rei04.grp", "rei05.grp", "rei06.grp", "rei07.grp", "rei08.grp",
  "rei09.grp", "rei10.grp", "rei11.grp", "rei12.grp", "rei13.grp",
  "rei14.grp", "rei15.grp", "rei16.grp", "smoke0.grp", "smoke1.grp",
  "smoke2.grp", "sweat.grp", "yucln10.grp", "yucln11.grp",
  "yucln12.grp", "yucln20.grp", "yucln21.grp", "yucln22.grp",
  "yugame10.grp", "yugame11.grp", "yugame20.grp", "yugame21.grp",
  "yutch10.grp", "yutch11.grp", "yutch12.grp", "yutch20.grp",
  "yutch21.grp", "yutch22.grp", "yuwk10.grp", "yuwk11.grp",
  "yuwk12.grp", "yuwk20.grp", "yuwk21.grp", "yuwk22.grp",
  
  /* schedule.pak */
  "amdisp.grp", "btnoff.grp", "btnon.grp", "cgm.grp", "cgm00.grp",
  "cgm01.grp", "comipa.grp", "guest.grp", "guestl.grp", "guestr.grp",
  "heijitu.grp", "hldraw.grp", "hlprac.grp", "hltel0.grp", "hltel1.grp",
  "hltel2.grp", "hltel3.grp", "hltel4.grp", "hltel5.grp", "hltel6.grp",
  "hltel7.grp", "kyujitu.grp", "pmdisp.grp", "schd00.grp", "schd01.grp",
  "schd02.grp", "schd03.grp", "schd04.grp", "schd05.grp", "schd06.grp",
  "schd07.grp", "schd08.grp", "schd09.grp", "schd10.grp", "schd11.grp",
  "selframe.grp", "syuraba.grp", "useitem.grp",

  /* setting.pak */
  "aya10.grp", "aya11.grp", "aya12.grp", "aya13.grp", "aya14.grp",
  "aya15.grp", "aya20.grp", "aya21.grp", "aya22.grp", "aya23.grp",
  "aya24.grp", "aya25.grp", "hero10.grp", "hero11.grp", "hero12.grp",
  "hero13.grp", "hero14.grp", "hero15.grp", "hero20.grp", "hero21.grp",
  "hero22.grp", "hero23.grp", "hero24.grp", "hero25.grp", "heroa10.grp",
  "heroa11.grp", "heroa12.grp", "heroa13.grp", "heroa14.grp",
  "heroa15.grp", "heroa20.grp", "heroa21.grp", "heroa22.grp",
  "heroa23.grp", "heroa24.grp", "heroa25.grp", "minami00.grp",
  "minami01.grp", "minami02.grp", "minami03.grp", "minami10.grp",
  "minami11.grp", "minami12.grp", "minami13.grp", "objleft.grp",
  "objright.grp", "wall.grp",
  
  /* settle.pak */
  "kessan.grp", "number0.grp", "number1.grp", "number2.grp",
  "number3.grp", "number4.grp", "number5.grp", "number6.grp",
  "number7.grp", "number8.grp", "number9.grp", "rank0.grp", "rank1.grp",
  "rank2.grp", "rank3.grp", "rank4.grp",

  /* shopping.pak */
  "book.grp", "bookfrnt.grp", "drug.grp", "drugfrnt.grp", 
  "hero10.grp", "hero11.grp", "hero12.grp", "hero20.grp", 
  "hero21.grp", "hero22.grp", 

  /* univfest.pak */
  "back.grp", "chi0.grp", "chi1.grp", "chi2.grp", "eim00.grp",
  "eim01.grp", "eim02.grp", "eim03.grp", "eim04.grp", "eim05.grp",
  "eim06.grp", "eim07.grp", "eim08.grp", "eim09.grp", "eim10.grp",
  "eim11.grp", "eim12.grp", "eim13.grp", "food0.grp", "food1.grp",
  "food2.grp", "hero0.grp", "hero1.grp", "hero2.grp", "herow0.grp",
  "herow1.grp", "herow2.grp", "herow4.grp", "min00.grp", "min01.grp",
  "min02.grp", "shop.grp", "stdnt0.grp", "stdnt1.grp", "stdnt2.grp",
  "yu00.grp", "yu01.grp", "yu02.grp", "yu03.grp", "yu04.grp",
  "yu05.grp", "yu06.grp", "yu07.grp", "yu08.grp", "yu09.grp",
  "yu10.grp",
  
  /* Comic Party Demo(same as opening.pak, maybe) */
  "all.grp", "ariake1.grp", "ariake2.grp", "ariake3.grp", "ariake4.grp",
  "ariake5.grp", "ariake6.grp", "ariake7.grp", "ariake8.grp",
  "ariake9.grp", "ariakea.grp", "banro.grp", "cut-a1.grp", "cut-a2.grp",
  "cut-a3.grp", "cut-all.grp", "koma1.grp", "koma10.grp", "koma11.grp",
  "koma12.grp", "koma13.grp", "koma14.grp", "koma15.grp", "koma16.grp",
  "koma17.grp", "koma18.grp", "koma19.grp", "koma2.grp", "koma20.grp",
  "koma22.grp", "koma23.grp", "koma24.grp", "koma25.grp", "koma27.grp",
  "koma28.grp", "koma29.grp", "koma3.grp", "koma30.grp", "koma32.grp",
  "koma33.grp", "koma34.grp", "koma35.grp", "koma37.grp", "koma38.grp",
  "koma39.grp", "koma4.grp", "koma40.grp", "koma5.grp", "koma6.grp",
  "koma7.grp", "koma8.grp", "koma9.grp", "leaf.grp", "m1.grp", "m2.grp",
  "m3.grp", "m4.grp", "m5.grp", "m6.grp", "m7.grp", "m8.grp",
  "poster.grp", "rough1.grp", "rough2.grp", "rough3.grp", "tate.grp",
  "up1.grp", "up2.grp", "up3.grp", "up4.grp", "up4_1.grp", "up4_2.grp",
  "yoko.grp"
};

static char fname_inagawa[][13] = {
  /* ComicMs/Back.pak, ComicQz/Back.pak (these are same) */
  "bg00.grp", "bg01.grp", "bg02.grp", "bg03.grp", "bg04.grp",
  "bg05.grp", "bg06.grp", "bg07.grp", "bg08.grp", "bg09.grp",
  "bg10.grp", "bg11.grp", "bg12.grp", "bg13.grp", "bg14.grp",
  "bg15.grp", "bg16.grp", "bg17.grp", "bg18.grp", "bg19.grp",
  "bg20.grp", "bg21.grp", "bg22.grp", "bg23.grp", "bg24.grp",
  "bg25.grp", "bg26.grp", "bg27.grp", "bg28.grp", "bg29.grp",
  "bg30.grp", "bg31.grp", "bg32.grp", "bg33.grp", "bg34.grp",
  "bg35.grp", "bg40.grp", "bg41.grp", "bg42.grp", "bg43.grp",
  "bg44.grp", "bg45.grp", "bg46.grp",
  
  /* ComicMs/Bustup.pak */
  "asa01_1.grp", "asa01_2.grp", "asa01_3.grp", "asa01_4.grp",
  "asa01_5.grp", "asa02_1.grp", "asa02_2.grp", "asa02_3.grp",
  "asa02_5.grp", "asa02_6.grp", "asa03_1.grp", "asa03_2.grp",
  "asa03_3.grp", "asa03_4.grp", "asa03_5.grp", "asa03_6.grp",
  "asa04_1.grp", "asa04_2.grp", "asa04_3.grp", "asa04_5.grp",
  "asa04_6.grp", "aya01_1.grp", "aya01_2.grp", "aya01_3.grp",
  "aya01_4.grp", "aya01_5.grp", "aya02_1.grp", "aya02_2.grp",
  "aya03_1.grp", "aya03_3.grp", "aya03_5.grp", "aya04_1.grp",
  "aya04_2.grp", "aya04_3.grp", "aya04_4.grp", "aya04_5.grp",
  "ban01_1.grp", "chi01_1.grp", "chi01_2.grp", "chi01_3.grp",
  "chi01_4.grp", "chi01_5.grp", "chi01_6.grp", "chi02_1.grp",
  "chi02_2.grp", "chi02_3.grp", "chi02_5.grp", "chi03_1.grp",
  "chi03_2.grp", "chi03_3.grp", "chi03_4.grp", "chi03_6.grp",
  "chi04_1.grp", "chi04_2.grp", "chi04_3.grp", "chi05_1.grp",
  "chi05_2.grp", "chi05_3.grp", "eim01_1.grp", "eim01_2.grp",
  "eim01_3.grp", "eim01_4.grp", "eim01_5.grp", "eim01_6.grp",
  "eim01_7.grp", "eim02_1.grp", "eim02_2.grp", "eim02_3.grp",
  "eim02_4.grp", "eim02_5.grp", "eim02_6.grp", "eim02_7.grp",
  "iku01_1.grp", "iku01_2.grp", "iku01_3.grp", "iku01_4.grp",
  "iku01_5.grp", "iku02_1.grp", "iku02_2.grp", "iku02_3.grp",
  "iku02_4.grp", "iku02_5.grp", "iku03_1.grp", "iku03_2.grp",
  "iku03_3.grp", "iku03_5.grp", "kuh01_1.grp", "kuh01_2.grp",
  "kuh01_3.grp", "kuh01_4.grp", "kuh02_1.grp", "kuh02_2.grp",
  "kuh02_3.grp", "kuh02_4.grp", "kuh03_1.grp", "kuh03_2.grp",
  "kuh04_1.grp", "kuh04_2.grp", "kuh04_3.grp", "kuh04_4.grp",
  "mak01_1.grp", "mak01_2.grp", "min01_1.grp", "min01_2.grp",
  "min01_3.grp", "min01_4.grp", "min01_5.grp", "min02_1.grp",
  "min02_2.grp", "min02_3.grp", "min02_5.grp", "min03_1.grp",
  "min03_2.grp", "min03_3.grp", "min03_4.grp", "min03_5.grp",
  "min04_1.grp", "min04_2.grp", "min04_3.grp", "min04_5.grp",
  "miz01_1.grp", "miz01_2.grp", "miz01_3.grp", "miz01_4.grp",
  "miz01_5.grp", "miz01_6.grp", "miz01_7.grp", "miz01_8.grp",
  "miz02_1.grp", "miz02_2.grp", "miz02_3.grp", "miz02_5.grp",
  "miz02_6.grp", "ona01_1.grp", "ona02_1.grp", "onb01_1.grp",
  "onb02_1.grp", "onc01_1.grp", "onc02_1.grp", "onn01_1.grp",
  "onn02_1.grp", "ota01_1.grp", "rei01_1.grp", "rei01_2.grp",
  "rei01_3.grp", "rei01_4.grp", "rei02_1.grp", "rei02_2.grp",
  "rei02_3.grp", "rei02_4.grp", "rei03_1.grp", "rei03_2.grp",
  "rei03_3.grp", "rei03_4.grp", "rei04_1.grp", "rei04_2.grp",
  "rei04_3.grp", "rei04_4.grp", "suz01_1.grp", "yu01_1.grp",
  "yu01_2.grp", "yu01_3.grp", "yu01_4.grp", "yu02_1.grp",
  "yu02_2.grp", "yu02_3.grp",

  /* ComicMs/cgmode.pak */
  "asa.grp", "asa00.grp", "asa01.grp", "asa02.grp", "aya.grp",
  "aya00.grp", "aya01.grp", "aya02.grp", "chi.grp", "chi00.grp",
  "chi01.grp", "chi02.grp", "eim.grp", "eim00.grp", "eim01.grp",
  "eim02.grp", "iku.grp", "iku00.grp", "iku01.grp", "iku02.grp",
  "min.grp", "min00.grp", "min01.grp", "min02.grp", "miz.grp",
  "miz00.grp", "miz01.grp", "miz02.grp", "rei.grp", "rei00.grp",
  "rei01.grp", "rei02.grp", "yu.grp", "yu00.grp", "yu01.grp",
  "yu02.grp",

  /* ComicMs/frame.pak */
  "btn00.grp", "btn01.grp", "confm1.grp", "confm10.grp",
  "confm11.grp", "confm2.grp", "confm3.grp", "confm4.grp", "confm5.grp",
  "confm6.grp", "confm7.grp", "confm8.grp", "confm9.grp", "confmbs.grp",
  "coverbs.grp", "cvroff0.grp", "cvroff1.grp", "genbtn.grp",
  "gendown.grp", "genkoh.grp", "genup.grp", "gsel00.grp", "gsel01.grp",
  "gsel02.grp", "gsel03.grp", "gsel04.grp", "gsel05.grp", "gsel06.grp",
  "gsel07.grp", "gsel10.grp", "gsel11.grp", "gsel12.grp", "gsel13.grp",
  "gsel14.grp", "gsel15.grp", "gsel16.grp", "gsel17.grp", "gsel20.grp",
  "gsel21.grp", "gsel22.grp", "gsel23.grp", "gsel24.grp", "gsel25.grp",
  "gsel26.grp", "gsel27.grp", "gsel30.grp", "gsel31.grp", "gsel32.grp",
  "gsel33.grp", "gsel34.grp", "gsel35.grp", "gsel36.grp", "gsel37.grp",
  "gsel3off.grp", "gsel4off.grp", "gselback.grp", "gselbtn0.grp",
  "gselbtn1.grp", "gselbtn2.grp", "gselbtn3.grp", "infomes.grp",
  "infomes2.grp", "inpkind0.grp", "inpkind1.grp", "inpkind2.grp",
  "inpkind3.grp", "mesonl.grp", "mesonr.grp", "mesons.grp",
  "mespushl.grp", "mespushr.grp", "mespushs.grp", "message0.grp",
  "message1.grp", "message2.grp", "message3.grp", "message4.grp",
  "message5.grp", "message6.grp", "message7.grp", "message8.grp",
  "name0.grp", "name1.grp", "name2.grp", "name3.grp", "name4.grp",
  "name5.grp", "name6.grp", "name7.grp", "name8.grp", "naminpbs.grp",
  "pgsel.grp", "pseloff0.grp", "pseloff1.grp", "pseloff2.grp",
  "pseloff3.grp", "pseloff4.grp", "pseloff5.grp", "pselon0.grp",
  "pselon1.grp", "pselon2.grp", "pselon3.grp", "pselon4.grp",
  "pselon5.grp", "saveload.grp", "seldown0.grp", "seldown1.grp",
  "seldown2.grp", "seldown3.grp", "seldown4.grp", "seldown5.grp",
  "seldown6.grp", "seldown7.grp", "sell00.grp", "sell01.grp",
  "sell02.grp", "sell10.grp", "sell11.grp", "sell12.grp", "sell20.grp",
  "sell21.grp", "sell22.grp", "sell30.grp", "sell31.grp", "sell32.grp",
  "sell40.grp", "sell41.grp", "sell42.grp", "sell50.grp", "sell51.grp",
  "sell52.grp", "sell60.grp", "sell61.grp", "sell62.grp", "sell70.grp",
  "sell71.grp", "sell72.grp", "sell80.grp", "sell81.grp", "sell82.grp",
  "selm00.grp", "selm01.grp", "selm02.grp", "selm10.grp", "selm11.grp",
  "selm12.grp", "selm20.grp", "selm21.grp", "selm22.grp", "selm30.grp",
  "selm31.grp", "selm32.grp", "selm40.grp", "selm41.grp", "selm42.grp",
  "selm50.grp", "selm51.grp", "selm52.grp", "selm60.grp", "selm61.grp",
  "selm62.grp", "selm70.grp", "selm71.grp", "selm72.grp", "selm80.grp",
  "selm81.grp", "selm82.grp", "selover0.grp", "selover1.grp",
  "selover2.grp", "selover3.grp", "selover4.grp", "selover5.grp",
  "selover6.grp", "selover7.grp", "sels00.grp", "sels01.grp",
  "sels02.grp", "sels10.grp", "sels11.grp", "sels12.grp", "sels20.grp",
  "sels21.grp", "sels22.grp", "sels30.grp", "sels31.grp", "sels32.grp",
  "sels40.grp", "sels41.grp", "sels42.grp", "sels50.grp", "sels51.grp",
  "sels52.grp", "sels60.grp", "sels61.grp", "sels62.grp", "sels70.grp",
  "sels71.grp", "sels72.grp", "sels80.grp", "sels81.grp", "sels82.grp",
  "titlebs.grp", "wiper0.grp", "wiper1.grp",

  /* ComicMs/EventCG256.pak, ComicQz/EventCG256.pak (these are same) */
  "eg13.grp", "eg14.grp", "eg15.grp", "eg16.grp", "eg17.grp",
  "eg18.grp", "eg19.grp", "eg20.grp", "eg21.grp", "eg22.grp",
  "eg23.grp", "eg24.grp", "eg25.grp", "eg26.grp", "eg27.grp",
  "eg28.grp", "eg29.grp", "eg30.grp", "eg31.grp", "eg32.grp",
  "eg33.grp",

  /* ComicMs/ending.pak */
  "roll0.grp", "roll1.grp", "roll2.grp", "roll3.grp", "roll4.grp",
  "roll5.grp", "roll6.grp", "roll7.grp", "roll8.grp", "roll9.grp",

  /* ComicMs/openingavg.pak */
  "cgm_00.grp", "cgm_01.grp", "cgm_02.grp", "menucg0.grp",
  "menucg1.grp", "menuend0.grp", "menuend1.grp", "menusta0.grp",
  "menusta1.grp", "title.grp",

  /* ComicMs/peach.pak */
  "ase200.grp", "ase201.grp", "back100.grp", "back101.grp",
  "back102.grp", "back103.grp", "back200.grp", "back201.grp",
  "back202.grp", "back203.grp", "back300.grp", "back301.grp",
  "bhemo00.grp", "bpeach00.grp", "bpeach01.grp", "bpeach02.grp",
  "bpeach10.grp", "bpeach11.grp", "chi200.grp", "chi201.grp",
  "chi210.grp", "chi211.grp", "chi212.grp", "chi213.grp",
  "chi2200.grp", "chi2201.grp", "chi2202.grp", "chi2203.grp",
  "chi2204.grp", "chi2205.grp", "chi2206.grp", "chi2207.grp",
  "chi2208.grp", "chi2209.grp", "chi2210.grp", "chi2211.grp",
  "chi300.grp", "chi301.grp", "chi3010.grp", "chi3011.grp",
  "chi3012.grp", "chi3013.grp", "chi302.grp", "chi303.grp",
  "chi304.grp", "chi305.grp", "chi306.grp", "chi307.grp", "chi308.grp",
  "chi309.grp", "hemo100.grp", "hemo101.grp", "hemo110.grp",
  "hemo111.grp", "hemo200.grp", "hemo201.grp", "hemo202.grp",
  "hemo203.grp", "hemo204.grp", "hemo205.grp", "jiba100.grp",
  "kaban200.grp", "momo1000.grp", "momo1001.grp", "momo1002.grp",
  "momo1003.grp", "momo1004.grp", "momo1005.grp", "momo1006.grp",
  "momo1007.grp", "momo1008.grp", "momo1009.grp", "momo1010.grp",
  "peach200.grp", "peach201.grp", "peach202.grp", "peach203.grp",
  "peach210.grp", "peach211.grp", "peach212.grp", "peach213.grp",
  "peach214.grp", "peach215.grp", "peach216.grp", "peach217.grp",
  "peach218.grp", "peach300.grp", "peach301.grp", "peach302.grp",
  "peach303.grp", "peach310.grp", "peach311.grp", "peach312.grp",
  "peach313.grp", "peach314.grp", "peach315.grp", "peach316.grp",
  "peach317.grp", "plane100.grp", "title00.grp", "title01.grp",
  "title02.grp", "title03.grp", "title04.grp", "title05.grp",
  "title06.grp", "title07.grp", "title08.grp", "title09.grp",
  "with100.grp", "with101.grp", "with102.grp", "with103.grp",
  "with104.grp", "with105.grp", "with106.grp", "with107.grp",
  "with108.grp",

  /* ComicQz/EventCg64k.pak */
  /* not supported yet */

  /* ComicQz/FrameQuiz.pak */
  "album.grp", "arrow.grp", "base.grp", "base2.grp", "dialog.grp",
  "dice.grp", "ecth01.grp", "ecth02.grp", "ecth03.grp", "ecth04.grp",
  "ecth05.grp", "ecth06.grp", "ecth07.grp", "fin_0.grp", "fin_1.grp",
  "fin_2.grp", "kao.grp", "koma.grp", "koma2.grp", "logo.grp",
  "mask.grp", "mesframe.grp", "optbase.grp", "optparts.grp",
  "pointer.grp", "pop.grp", "pop_ov.grp", "quiz.grp", "restore.grp",
  "scroll.grp", "select.grp", "struct.grp", "tatemono.grp", "title.grp",
  "ttlparts.grp", "tutorial.grp",

  /* ComicQz/QuizData.pak */
  "0031_1.grp", "0031_2.grp", "0033_1.grp", "0034_1.grp",
  "0049_1.grp", "0049_2.grp", "0049_3.grp", "0049_4.grp", "0050_1.grp",
  "0050_2.grp", "0050_3.grp", "0050_4.grp", "0050_5.grp", "0050_6.grp",
  "0050_7.grp", "0050_8.grp", "0050_9.grp", "0051_1.grp", "0051_2.grp",
  "0051_3.grp", "0051_4.grp", "0051_5.grp", "0051_6.grp", "0051_7.grp",
  "0051_8.grp", "0051_9.grp", "0113_1.grp", "0113_2.grp", "0114_1.grp",
  "0114_2.grp", "0114_3.grp", "0114_4.grp", "0128_1.grp", "0128_2.grp",
  "0128_3.grp", "0128_4.grp", "0129_1.grp", "0129_2.grp", "0129_3.grp",
  "0129_4.grp", "0130_1.grp", "0130_2.grp", "0130_3.grp", "0130_4.grp",
  "0141_1.grp", "0141_2.grp", "0141_3.grp", "0141_4.grp", "0142_1.grp",
  "0142_2.grp", "0142_3.grp", "0142_4.grp", "0159_1.grp", "0159_2.grp",
  "0159_3.grp", "0159_4.grp", "0170_1.grp", "0170_2.grp", "0284_1.grp",
  "0284_2.grp", "0284_3.grp", "0284_4.grp", "0295_1.grp", "0296_1.grp",
  "0296_2.grp", "0296_3.grp", "0296_4.grp", "0297_1.grp", "0297_2.grp",
  "0297_3.grp", "0297_4.grp", "0298_1.grp", "0298_2.grp", "0298_3.grp",
  "0298_4.grp", "0338_1.grp", "0338_2.grp", "0338_3.grp", "0338_4.grp",
  "0380_1.grp", "0380_2.grp", "0380_3.grp", "0380_4.grp", "0409_1.grp",
  "0409_2.grp", "0409_3.grp", "0409_4.grp", "0434_1.grp", "0434_2.grp",
  "0434_3.grp", "0434_4.grp", "0435_1.grp", "0435_2.grp", "0435_3.grp",
  "0435_4.grp", "0481_1.grp", "0481_2.grp", "0481_3.grp", "0482_1.grp",
  "0482_2.grp", "0483_1.grp", "0484_1.grp", "0485_1.grp", "0486_1.grp",
  "0487_1.grp", "0488_1.grp", "0489_1.grp", "0489_2.grp", "0490_1.grp",
  "0499_1.grp", "0499_2.grp", "0499_3.grp", "0499_4.grp", "0508_1.grp",
  "0508_2.grp", "0508_3.grp", "0508_4.grp", "0511_1.grp", "0511_2.grp",
  "0512_1.grp", "0512_2.grp", "0514_1.grp", "0514_2.grp", "0514_3.grp",
  "0514_4.grp", "0515_1.grp", "0515_2.grp", "0515_3.grp", "0516_1.grp",
  "0516_2.grp", "0517_1.grp", "0518_1.grp", "0518_2.grp", "0518_3.grp",
  "0518_4.grp", "0519_1.grp", "0519_2.grp", "0519_3.grp", "0519_4.grp",
  "0520_1.grp", "0520_2.grp", "0520_3.grp", "0520_4.grp", "0521_1.grp",
  "0521_2.grp", "0521_3.grp", "0521_4.grp", "0524_1.grp", "0524_2.grp",
  "0524_3.grp", "0524_4.grp", "0524_5.grp", "0524_6.grp", "0524_7.grp",
  "0524_8.grp", "0524_9.grp", "0525_1.grp", "0526_1.grp", "0527_1.grp",
  "0528_1.grp", "0529_1.grp", "0530_1.grp", "0531_1.grp", "0532_1.grp",
  "0532_2.grp", "0533_1.grp", "0533_2.grp", "0534_1.grp", "0534_2.grp",
  "0535_1.grp", "0536_1.grp", "0537_1.grp", "0537_2.grp", "0571_1.grp",
  "0572_1.grp", "0573_1.grp", "0573_2.grp", "0573_3.grp", "0573_4.grp",
  "0574_1.grp", "0574_2.grp", "0574_3.grp", "0574_4.grp", "0574_5.grp",
  "0574_6.grp", "0574_7.grp", "0574_8.grp", "0574_9.grp", "0575_1.grp",
  "0575_2.grp", "0575_3.grp", "0575_4.grp", "0575_5.grp", "0575_6.grp",
  "0575_7.grp", "0575_8.grp", "0575_9.grp", "0580_1.grp", "0580_2.grp",
  "0582_1.grp", "0590_1.grp", "0590_2.grp", "0691_1.grp", "0691_2.grp",
  "0691_3.grp", "0691_4.grp", "0716_1.grp", "0716_2.grp", "0716_3.grp",
  "0716_4.grp", "0717_1.grp", "0717_2.grp", "0717_3.grp", "0717_4.grp",
  "0718_1.grp", "0718_2.grp", "0718_3.grp", "0718_4.grp", "0777_1.grp",
  "0777_2.grp", "0777_3.grp", "0777_4.grp", "0797_1.grp", "0797_2.grp",
  "0797_3.grp", "0797_4.grp", "0797_5.grp", "0797_6.grp", "0797_7.grp",
  "0797_8.grp", "0797_9.grp", "0798_1.grp", "0798_2.grp", "0798_3.grp",
  "0798_4.grp", "0798_5.grp", "0798_6.grp", "0798_7.grp", "0798_8.grp",
  "0798_9.grp", "0799_1.grp", "0799_2.grp", "0799_3.grp", "0799_4.grp",
  "0799_5.grp", "0799_6.grp", "0799_7.grp", "0799_8.grp", "0799_9.grp",
  "0800_1.grp", "0800_2.grp", "0800_3.grp", "0800_4.grp", "0800_5.grp",
  "0800_6.grp", "0800_7.grp", "0800_8.grp", "0800_9.grp", "0801_1.grp",
  "0801_2.grp", "0802_1.grp", "0802_2.grp", "0803_1.grp", "0803_2.grp",
  "0804_1.grp", "0804_2.grp", "0805_1.grp", "0805_2.grp", "0806_1.grp",
  "0806_2.grp", "0807_1.grp", "0808_1.grp", "0809_1.grp", "0828_1.grp",

  /* ComicQz/bustup.pak */
  "asa01_1.grp", "asa01_2.grp", "asa01_3.grp", "asa01_4.grp",
  "asa01_5.grp", "asa02_1.grp", "asa02_2.grp", "asa02_3.grp",
  "asa02_5.grp", "asa02_6.grp", "asa03_1.grp", "asa03_2.grp",
  "asa03_3.grp", "asa03_4.grp", "asa03_5.grp", "asa03_6.grp",
  "asa04_1.grp", "asa04_2.grp", "asa04_3.grp", "asa04_5.grp",
  "asa04_6.grp", "aya01_1.grp", "aya01_2.grp", "aya01_3.grp",
  "aya01_4.grp", "aya01_5.grp", "aya02_1.grp", "aya02_2.grp",
  "aya03_1.grp", "aya03_3.grp", "aya03_5.grp", "aya04_1.grp",
  "aya04_2.grp", "aya04_3.grp", "aya04_4.grp", "aya04_5.grp",
  "ban01_1.grp", "chi01_1.grp", "chi01_2.grp", "chi01_3.grp",
  "chi01_4.grp", "chi01_5.grp", "chi01_6.grp", "chi02_1.grp",
  "chi02_2.grp", "chi02_3.grp", "chi02_5.grp", "chi03_1.grp",
  "chi03_2.grp", "chi03_3.grp", "chi03_4.grp", "chi03_6.grp",
  "chi04_1.grp", "chi04_2.grp", "chi04_3.grp", "chi05_1.grp",
  "chi05_2.grp", "chi05_3.grp", "eim01_1.grp", "eim01_2.grp",
  "eim01_3.grp", "eim01_4.grp", "eim01_5.grp", "eim01_6.grp",
  "eim01_7.grp", "eim02_1.grp", "eim02_2.grp", "eim02_3.grp",
  "eim02_4.grp", "eim02_5.grp", "eim02_6.grp", "eim02_7.grp",
  "iku01_1.grp", "iku01_2.grp", "iku01_3.grp", "iku01_4.grp",
  "iku01_5.grp", "iku02_1.grp", "iku02_2.grp", "iku02_3.grp",
  "iku02_4.grp", "iku02_5.grp", "iku03_1.grp", "iku03_2.grp",
  "iku03_3.grp", "iku03_5.grp", "kuh01_1.grp", "kuh01_2.grp",
  "kuh01_3.grp", "kuh01_4.grp", "kuh02_1.grp", "kuh02_2.grp",
  "kuh02_3.grp", "kuh02_4.grp", "kuh03_1.grp", "kuh03_2.grp",
  "kuh04_1.grp", "kuh04_2.grp", "kuh04_3.grp", "kuh04_4.grp",
  "mak01_1.grp", "mak01_2.grp", "min01_1.grp", "min01_2.grp",
  "min01_3.grp", "min01_4.grp", "min01_5.grp", "min02_1.grp",
  "min02_2.grp", "min02_3.grp", "min02_5.grp", "min03_1.grp",
  "min03_2.grp", "min03_3.grp", "min03_4.grp", "min03_5.grp",
  "min04_1.grp", "min04_2.grp", "min04_3.grp", "min04_5.grp",
  "miz01_1.grp", "miz01_2.grp", "miz01_3.grp", "miz01_4.grp",
  "miz01_5.grp", "miz01_6.grp", "miz01_7.grp", "miz01_8.grp",
  "miz02_1.grp", "miz02_2.grp", "miz02_3.grp", "miz02_5.grp",
  "miz02_6.grp", "ona01_1.grp", "ona02_1.grp", "onb01_1.grp",
  "onb02_1.grp", "onc01_1.grp", "onc02_1.grp", "onn01_1.grp",
  "onn02_1.grp", "ota01_1.grp", "rei01_1.grp", "rei01_2.grp",
  "rei01_3.grp", "rei01_4.grp", "rei02_1.grp", "rei02_2.grp",
  "rei02_3.grp", "rei02_4.grp", "rei03_1.grp", "rei03_2.grp",
  "rei03_3.grp", "rei03_4.grp", "rei04_1.grp", "rei04_2.grp",
  "rei04_3.grp", "rei04_4.grp", "suz01_1.grp", "yu01_1.grp",
  "yu01_2.grp", "yu01_3.grp", "yu01_4.grp", "yu02_1.grp", "yu02_2.grp",
  "yu02_3.grp",
  
  /* ma_demo/data/Bck.pak (not supported yet) */
  /* ma_demo/data/Chr.pak (not supported yet) */
  /* ma_demo/data/Etc.pak (not supported yet) */
  /* ma_demo/data/Map.pak (not supported yet) */
  /* ma_demo/data/Pcm.pak (not supported yet) */
  /* ma_demo/data/Scn.pak (not supported yet) */
  /* ma_demo/data/Vis.pak (not supported yet) */

  /* night/Nightdat.pak (not supported yet) */
};

int plugin_query(int *num, char ***names)
{
  int i;
#define SYM_LEN 5
#define SYM_NUM 9

  *num = SYM_NUM;

  *names = (char **)calloc(*num, sizeof(char *));
  if (*names == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < *num; i++) {
    (*names)[i] = (char *)calloc(SYM_LEN, sizeof(char));
    if ((*names)[i] == NULL) {
      perror("calloc");
      exit(1);
    }
  }
  i = 0;
  strcpy((*names)[i++], "lfg");
  strcpy((*names)[i++], "lf2");
  strcpy((*names)[i++], "sgrp");
  strcpy((*names)[i++], "cgrp");
  strcpy((*names)[i++], "igrp");
  strcpy((*names)[i++], "wgrp");
  strcpy((*names)[i++], "gad");
  strcpy((*names)[i++], "psth");
  /* This is a generic GRP decoder. It should have low priority
     since it can't decode sgrp, cgrp, igrp, wgrp images.*/
  strcpy((*names)[i++], "grp");

  return 0;
}

/*
 * plugin_get_FOO functions
 */
int plugin_get_lf2(Image *img, unsigned char *data[], int *size, int *n)
{
  LF2 *lf2;
  int i;

  *n = 1;
  lf2 = read_lf2_from_data(data[0], size[0]);
  img[0].width = lf2->width;
  img[0].height = lf2->height;
  img[0].color_num = lf2->color_num;
  
  if (lf2->transparent == 0xff) {
    img[0].transparent = -1; /* transparent color isn't used */
  } else {
    img[0].transparent = lf2->transparent;
  }

  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < lf2->color_num; i++) {
    img[0].palette[i].r = lf2->palette[i][LF2_R];
    img[0].palette[i].g = lf2->palette[i][LF2_G];
    img[0].palette[i].b = lf2->palette[i][LF2_B];
  }

  img->image = lf2->image;
  return 0;
}

int plugin_get_lfg(Image *img, unsigned char *data[], int *size, int *n)
{
  LFG *lfg;
  int i;

  *n = 1;
  lfg = read_lfg_from_data(data[0], size[0]);

  img[0].width = lfg->width - lfg->xoffset;
  img[0].height = lfg->height - lfg->yoffset;
  img[0].color_num = 16;
  
  if (lfg->transparent == 0xff) {
    img[0].transparent = -1; /* transparent color isn't used */
  } else {
    img[0].transparent = lfg->transparent;
  }

  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < 16; i++) {
    img[0].palette[i].r = lfg->palette[i][LFG_R];
    img[0].palette[i].g = lfg->palette[i][LFG_G];
    img[0].palette[i].b = lfg->palette[i][LFG_B];
  }

  img[0].image = lfg->image;
  return 0;
}

int plugin_get_grp(Image *img, unsigned char *data[], int *size, int *n)
{
  GRP *grp;
  int i;

  *n = 1;
  grp = read_grp_from_data(data[1], size[1], data[0], size[0]);
  if (grp == NULL) {
    return -1;
  }

  img[0].width = grp->width;
  img[0].height = grp->height;
  img[0].color_num = grp->color_num;
  img[0].transparent = grp->transparent;
  
  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < grp->color_num; i++) {
    img[0].palette[i].r = grp->palette[i][GRP_R];
    img[0].palette[i].g = grp->palette[i][GRP_G];
    img[0].palette[i].b = grp->palette[i][GRP_B];
  }

  img[0].image = grp->image;

  return 0;
}

int plugin_get_gad(Image *img, unsigned char *data[], int *size, int *n)
{
  GAD *gad;
  int i, j;

  gad = read_gad_from_data(data[1], size[1], data[0], size[0]);
  if (gad == NULL) {
    return -1;
  }

  *n = gad->num;
  for (i = 0; i < gad->num; i++) {
    img[i].width = gad->width[i];
    img[i].height = gad->height[i];
    img[i].color_num = gad->color_num;
    img[i].transparent = gad->transparent;
    
    img[i].palette = (Color *)calloc(img[i].color_num, sizeof(Color));
    if (img[0].palette == NULL) {
      perror("calloc");
      exit(1);
    }
    for (j = 0; j < gad->color_num; j++) {
      img[i].palette[j].r = gad->palette[j][LF_R];
      img[i].palette[j].g = gad->palette[j][LF_G];
      img[i].palette[j].b = gad->palette[j][LF_B];
    }
    
    img[i].image = gad->image[i];
  }

  return 0;
}

int plugin_get_sgrp(Image *img, unsigned char *data[], int *size, int *n)
{
  GRP *grp;
  int i;

  *n = 1;
  grp = read_grp_from_data(data[1], size[1], data[0], size[0]);
  if (grp == NULL) {
    return -1;
  }

  img[0].width = grp->width;
  img[0].height = grp->height;
  img[0].color_num = grp->color_num;
  img[0].transparent = grp->transparent;
  
  img[0].palette = (Color *)calloc(img->color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < grp->color_num; i++) {
    /* color order is B-G-R rather than R-G-B(such as other games) */
    img[0].palette[i].r = grp->palette[i][GRP_B];
    img[0].palette[i].g = grp->palette[i][GRP_G];
    img[0].palette[i].b = grp->palette[i][GRP_R];
  }

  img[0].image = grp->image;

  return 0;
}

int plugin_get_wgrp(Image *img, unsigned char *data[], int *size, int *n)
{
  GRP *grp;
  int i;

  *n = 1;
  grp = read_wgrp_from_data(data[1], size[1], data[0], size[0]);
  if (grp == NULL) {
    return -1;
  }

  img[0].width = grp->width;
  img[0].height = grp->height;
  img[0].color_num = grp->color_num;
  img[0].transparent = grp->transparent;
  
  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < grp->color_num; i++) {
    img[0].palette[i].r = grp->palette[i][GRP_R];
    img[0].palette[i].g = grp->palette[i][GRP_G];
    img[0].palette[i].b = grp->palette[i][GRP_B];
  }

  img[0].image = grp->image;

  return 0;
}

int plugin_get_cgrp(Image *img, unsigned char *data[], int *size, int *n)
{
  GRP *grp;
  int i;

  *n = 1;
  grp = read_cgrp_from_data(data[1], size[1], data[0], size[0]);
  if (grp == NULL) {
    return -1;
  }

  img[0].width = grp->width;
  img[0].height = grp->height;
  img[0].color_num = grp->color_num;
  img[0].transparent = grp->transparent;
  
  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("calloc");
    exit(1);
  }
  for (i = 0; i < grp->color_num; i++) {
    img[0].palette[i].r = grp->palette[i][GRP_R];
    img[0].palette[i].g = grp->palette[i][GRP_G];
    img[0].palette[i].b = grp->palette[i][GRP_B];
  }

  img[0].image = grp->image;

  return 0;
}

int plugin_get_igrp(Image *img, unsigned char *data[], int *size, int *n)
{
  return plugin_get_cgrp(img, data, size, n);
}

int plugin_get_psth(Image *img, unsigned char *data[], int *size, int *n)
{
  PSTH_IMG *psth;
  int i;

#ifdef DEBUG
  fprintf(stderr, "getting PSTH...");
#endif

  *n = 1;
  psth = read_psth_from_data(data[0], size[0]);
  img[0].width = psth->width;
  img[0].height = psth->height;
  img[0].color_num = psth->palette_size;

  img[0].palette = (Color *)calloc(img[0].color_num, sizeof(Color));
  if (img[0].palette == NULL) {
    perror("plugin_get_psth: calloc");
    exit(1);
  }
  for (i = 0; i < psth->palette_size; i++) {
    img[0].palette[i].r = psth->palette[i * 3];
    img[0].palette[i].g = psth->palette[i * 3 + 1];
    img[0].palette[i].b = psth->palette[i * 3 + 2];
  }

  img[0].image = psth->image;


#ifdef DEBUG
  fprintf(stderr, "done.\n");
#endif
  return 0;
}

/*
 * plugin_is_FOO functions
 */
int plugin_is_lf2(unsigned char *data, int size, const char *fname)
{
  unsigned char buf[8];

  memcpy(buf, data, 7);
  buf[7] = '\0';
  if (!strcmp(buf, "LEAF256")) {
    return True;
  }
  return False;
}

int plugin_is_lfg(unsigned char *data, int size, const char *fname)
{
  unsigned char buf[9];

  memcpy(buf, data, 8);
  buf[8] = '\0';
  if (!strcmp(buf, "LEAFCODE")) {
    return True;
  }
  return False;
}

/*
 * check .grp images in `Saorin to issho!'
 */
int plugin_is_sgrp(unsigned char *data, int size, const char *fname)
{
  int i;

  if (!grp_header_check(data, size)) {
    return False;
  }

  for (i = 0; i < sizeof(fname_saorin) / sizeof(fname_saorin[0]); i++) {
    if (!strcasecmp(fname_saorin[i], fname)) {
      fprintf(stderr, "GRP(Saorin to Issho!)\n");
      return True;
    }
  }
  return False;
}

int plugin_is_grp(unsigned char *data, int size, const char *fname)
{
  char *ptr;

  ptr = strchr(fname, '.');
  if (ptr == NULL) return False;
  if (strcasecmp(ptr, ".grp")) return False;

  if (!grp_header_check(data, size)) {
    fprintf(stderr, "plugin_is_grp: This file has a suffix \".grp\", but has an invalid header.\n");
    return False;
  }

  fprintf(stderr, "GRP(Generic)\n");
  return True;
}

int plugin_is_wgrp(unsigned char *data, int size, const char *fname)
{
  int res = False;
  char *ptr;

  /* cull by a extention */
  ptr = strchr(fname, '.');
  if (ptr == NULL) return False;
  if (strcasecmp(ptr, ".grp")) return False;

  /* cull by a invalid header */
  if (!grp_header_check(data, size)) {
    fprintf(stderr, "plugin_is_wgrp: This file has a suffix \".grp\", but has an invalid header.\n");
    return False;
  }

  if (!strcmp("leaflogo.grp", fname)) res = True; /* LEAFLOGO.pak(logo)*/
  if (!strncmp("n2bg", fname, 4)) res = True; /* WABG.pak(background images)*/
  if (!strncmp("n2ca", fname, 4)) res = True; /* WACA.pak (calendar)*/
  if (!strncmp("n2cat", fname, 5)) res = True; /* WACAT.pak(casting in ending) */
  if (!strncmp("n2ch", fname, 4)) res = True; /* WACH.pak, characters */
  if (!strncmp("n2ed", fname, 4)) res = True; /* WAED.pak, ending images*/
  if (!strncmp("n2eg", fname, 4)) res = True; /* WAEG.pak, visuals */
  if (!strncmp("n2hg", fname, 4)) res = True; /* WAHG.pak, H visuals */
  if (!strncmp("n2op", fname, 4)) res = True; /* WAOP.pak, opening */
  if (!strncmp("n2stf", fname, 5)) res = True; /* WASTF.pak, staff */
  if (!strncmp("n2s2g", fname, 5)) res = True; /* WASYS2.pak, music mode */

  /* not complete, currently */
  if (!strcmp("n2moj000.grp", fname)) res = True;

  /* non-image data */
  if (!strncmp("n2dat", fname, 5)) res = True;

  if (res) {
    fprintf(stderr, "GRP(White Album)\n");
    return True;
  }
  return False;
}

int plugin_is_gad(unsigned char *data, int size, const char *fname)
{
  int res = False;
  char *ptr;

  /* cull by extention */
  ptr = strchr(fname, '.');
  if (ptr == NULL) return False;
  if (strcasecmp(ptr, ".gad")) return False;

  if (!strcmp("n2opa000.gad", fname)) res = True; /* WAOP.pak */

  if (!strncmp("n2mw", fname, 4)) res = True; /* WASYS1.pak */
  if (!strncmp("n2spn", fname, 5)) res = True; /* WASYS1.pak */
  if (!strncmp("n2tpn", fname, 5)) res = True; /* WASYS1.pak */
  if (!strncmp("n2tit", fname, 5)) res = True; /* WATIT.pak */

  /* where's the palette? */
  if (!strncmp("n2par", fname, 5)) res = True; /* WAPAR.pak */

  if (res) {
    fprintf(stderr, "GAD(White Album)\n");
    return True;
  }
  return False;
}

int plugin_is_cgrp(unsigned char *data, int size, const char *fname)
{
  int i;

  if (!grp_header_check(data, size)) {
    return False;
  }

  for (i = 0; i < sizeof(fname_comic) / sizeof(fname_comic[0]); i++) {
    if (!strcasecmp(fname_comic[i], fname)) {
      fprintf(stderr, "GRP(Comic Party)\n");
      return True;
    }
  }
  return False;
}

int plugin_is_igrp(unsigned char *data, int size, const char *fname)
{
  int i;

  if (!grp_header_check(data, size)) {
    return False;
  }

  for (i = 0; i < sizeof(fname_inagawa) / sizeof(fname_inagawa[0]); i++) {
    if (!strcasecmp(fname_inagawa[i], fname)) {
      fprintf(stderr, "GRP(Inagawa de Ikou!!)\n");
      return True;
    }
  }
  return False;
}


static int grp_header_check(unsigned char *data, int size)
{
  int len, elen;

  len = LONGWORD(data[0], data[1], data[2], data[3]);
  elen = LONGWORD(data[4], data[5], data[6], data[7]);
  
#ifdef DEBUG
  fprintf(stderr, "len: %d, elen: %d\n", len, elen);
#endif

  /* This kind of images is included in White Album's archive.
     (n2eg0[40, 41, 43].grp, ) */
  if (len == 0 || elen == 0) {
    return False;
  }

  /* This kind of images is included in White Album's archive.
     (n2eg0[44, 45].grp, ) */
  if (len != size) {
    return False;
  }

  return True;
}

int plugin_is_psth(unsigned char *data, int size, const char *fname)
{
  int *d;

  d = (int *)data;

  if (d[0] == 0x5053 && d[1] == 0x5448) {
#ifdef DEBUG
    fprintf(stderr, "find PSTH image.\n");
#endif
    return True;
  }

  return False;
}

/*
 * plugin_query_FOO functions
 */
int plugin_query_lf2(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  *n_flist = 0;

  return 0;
}

int plugin_query_lfg(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  *n_flist = 0;

  return 0;
}

int plugin_query_sgrp(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  return plugin_query_grp(fname, data, flist, n_flist);
}

int plugin_query_grp(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  char *dup, *dot;
  int i;
#define FNAME_LEN 13

  *n_flist = 1;

  *flist = (char **)calloc(*n_flist, sizeof(char *));
  for (i = 0; i < *n_flist; i++) {
    *flist[i] = (char *)calloc(FNAME_LEN, sizeof(char));
    if (*flist[i] == NULL) {
      perror("calloc");
      exit(1);
    }
  }

  dup = strdup(fname);
  if (dup == NULL) {
    perror("strdup");
    exit(1);
  }
  dot = strchr(dup, '.');
  *dot = '\0';
  sprintf(*flist[0], "%s.c16", dup);
  free(dup);
  
  return 0;
}

int plugin_query_wgrp(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  int res;

  res = plugin_query_grp(fname, data, flist, n_flist);
  if (*n_flist == 1) {
    if (!strncmp("n2cat0", (*flist)[0], 6)) {
      strcpy((*flist)[0], "n2cat000.c16");
    }
    if (!strncmp("n2stf", (*flist)[0], 5)) {
      strcpy((*flist)[0], "n2stf000.c16");
    }
    if (!strncmp("n2moj", (*flist)[0], 5)) {
      strcpy((*flist)[0], "n2mw000.c16");
    }
  }
  
  return res;
}

int plugin_query_gad(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  int res;

  res = plugin_query_grp(fname, data, flist, n_flist);
  if (*n_flist == 1) {
    if (!strncmp("n2spn0", (*flist)[0], 6)) {
      strcpy((*flist)[0], "n2spn000.c16");
    }
    if (!strncmp("n2tpn0", (*flist)[0], 5)) {
      strcpy((*flist)[0], "n2spn000.c16");
    }
  }
  
  return res;
}

int plugin_query_cgrp(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  return plugin_query_grp(fname, data, flist, n_flist);
}

int plugin_query_igrp(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{
  return plugin_query_grp(fname, data, flist, n_flist);
}

int plugin_query_psth(const char *fname, unsigned char *data, char ***flist, int *n_flist)
{

#ifdef DEBUG
  fprintf(stderr, "querying PSTH...");
#endif
  
  *n_flist = 0;

#ifdef DEBUG
  fprintf(stderr, "done\n");
#endif
  return 0;
}
