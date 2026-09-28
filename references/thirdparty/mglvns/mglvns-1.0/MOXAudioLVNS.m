#import "MOXAudioLVNS.h"

@implementation MOXAudioLVNS

/**
 * コールバック処理。
 * バッファに対して値を設定する処理を記述する必要がある
 * buffer[play] に対して、最大 buffer_size までのデータを設定する。
 */
- (void)callback 
{
	size_t len;
        if (pos >= sound_len)
            [self pause:YES];
        else {
            len = sound_len - pos;
            len = (len < buffer_size)? len: buffer_size;
            memcpy(buffer[play], sound_data+pos, len);
            pos += len;
        }
}

/**
 * デストラクタ
 */
- (void)dealloc 
{
	free(sound_data);
	[super dealloc];
}

/* -------------------------------------------------------- */

/**
 * LVNS向けインターフェース 
 * C言語による呼び出しラッパー
 */

/**
 * サウンド初期化
 */
static void
OpenSound(void *dep) 
{
	// nothing to do
}

/**
 * サウンド終了
 */
static void
CloseSound(void *dep)
{
	MOXAudioLVNS *self = dep;
	[self stop];
	[self release];
}

/**
 * データのロード
 */
static void
LoadSound(void *dep, const char *name) 
{
	MOXAudioLVNS *self = dep;
	[self lock];
	self->sound_data = LvnsLoadData(self->lvns, name, &self->sound_len);
	self->pos = 0;
	[self unlock];
}

/**
 * 再生開始
 */
static void
StartSound(void *dep)
{
	MOXAudioLVNS *self = dep;
	if (!self->opened)
		[self init:AUDIO_S16LSB freq:11025 channels:2 samples:1024];
	self->pos = 0;
	[self pause:NO];
}

/**
 * 停止
 */
static void
StopSound(void *dep)
{
	MOXAudioLVNS *self = dep;
	[self stop];
}

/**
 * 演奏中チェック
 */
static int
GetSoundState(void *dep)
{
	MOXAudioLVNS *self = dep;
	return [self status] == AUDIO_PLAYING ? 1 : 0;
}

/**
 * LVNS用効果音再生情報を返す
 */
+ (Sound*)getSound:(Lvns*)_lvns
{
	Sound *s;
	if ((s = malloc(sizeof *s)) != NULL) {
		MOXAudioLVNS *audio = [MOXAudioLVNS alloc];
		audio->lvns = _lvns;
		s->depend   = audio;
		s->open     = OpenSound;
		s->close    = CloseSound;
		s->load     = LoadSound;
		s->start    = StartSound;
		s->stop     = StopSound;
		s->getState = GetSoundState;
	}
	return s;
}

@end
