#import <Cocoa/Cocoa.h>
#import "MOXAudio.h"

#include "Lvns.h"
#include "Sound.h"

@interface MOXAudioLVNS : MOXAudio
{
	/* LVNS 情報構造体 */
    Lvns *lvns;
	unsigned char *sound_data; 	// 再生用データ
	long sound_len;             // データサイズ
	long pos;                   // 再生ポイント
}

+(Sound*)getSound:(Lvns*)lvns;

@end


