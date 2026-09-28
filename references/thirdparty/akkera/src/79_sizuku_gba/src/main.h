
#ifndef MAIN_H
#define MAIN_H
#ifdef __cplusplus
extern "C" {
#endif


//---------------------------------------------------------------------------
//ÉvÉçÉOÉâÉÄÇÃèÛë‘
enum {
	STATE_INIT  = 0x01,
	STATE_RESET,
	STATE_JINGLE,
	STATE_OPENING,
	STATE_TITLE,
	STATE_SCRIPT,
};

//---------------------------------------------------------------------------
EWRAM_CODE void StateInit(); 
EWRAM_CODE void StateReset();
EWRAM_CODE void StateJingle();
EWRAM_CODE void StateOpening();
EWRAM_CODE void StateTitle();
EWRAM_CODE void StateScript();


EWRAM_CODE void InitWS();
EWRAM_CODE void InitLib();
EWRAM_CODE void InitKey();
EWRAM_CODE void InitIRQ();
EWRAM_CODE void InitFont();
EWRAM_CODE void InitSprite();
EWRAM_CODE void InitGBFS();


EWRAM_CODE void ErrorMessage(char* msg1, char* msg2);


#ifdef __cplusplus
}
#endif
#endif
