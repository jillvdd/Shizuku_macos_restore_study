/**
 * MacOS X AUDIO ストリームクラス
 * Carbon による PCMストリーム処理 抽象クラス
 * 実際に使う場合にはこれを継承してコールバック処理を実装する必要がある
 */
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

typedef enum {
	AUDIO_U8       = 0x0001,
	AUDIO_S16LSB   = 0x0002,
	AUDIO_S16MSB   = 0x0102
} AudioFormat;
 
typedef enum {
	AUDIO_STOPPED,
	AUDIO_PAUSED,
	AUDIO_PLAYING
} AudioStatus;

@interface MOXAudio : NSObject 
{
	CmpSoundHeader header;     // 再生用ヘッダ
	SndChannelPtr channel;     // チャンネル情報 

	size_t buffer_size;        // バッファサイズ
 	unsigned char *buffer[2];  // バッファ
	int play;                  // 切り替えバッファ番号
	
	volatile BOOL opened;      // 有効状態
	volatile BOOL paused;      // ポーズ中

	NSLock *lock;              // コールバックのロック用
}

- (int)init:(AudioFormat)format freq:(int)freq channels:(int)channels samples:(int)samples;
- (void)pause:(BOOL)on;
- (void)lock;
- (void)unlock;
- (AudioStatus)status;
- (void)stop;

- (void)callback;

@end
