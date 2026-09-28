#import "MOXAudio.h"

@implementation MOXAudio

/**
 * コールバック処理。
 * バッファに対して値を設定する処理を記述する必要がある
 * buffer[play] に対して、最大 buffer_size までのデータを設定する。
 */
- (void)callback { /* virtual */ }

/**
 * 内部コールバック処理
 * 演奏処理と登録されたコールバックの処理を行う
 */
- (void)base_callback
{
	if (!opened)
		return;

	// 再生処理実行
	{
		SndCommand cmd;
		header.samplePtr = buffer[play];
		cmd.cmd    = bufferCmd;
		cmd.param1 = 0;
		cmd.param2 = (long)&header;
		SndDoCommand(channel, &cmd, 0);
	}
	
	// バッファ切り替え
	play = 1 - play;

	// 新バッファ消去
	memset(buffer[play], 0, buffer_size);

	// バッファ更新処理
	if (!paused) {
		[lock lock];
		[self callback];
		[lock unlock];
	}

	// 次のコールバック
	if (opened) {
		SndCommand cmd;
		cmd.cmd    = callBackCmd;
		SndDoCommand(channel, &cmd, 0);
	}
}

// コールバック用プロシージャ
static void 
callbackProc(SndChannel *ch, SndCommand *cmd)
{
	[(MOXAudio*)ch->userInfo base_callback];
}

/**
 * イニシャライザ
 * 初期化後直ちに演奏処理が開始されてポーズ状態になる
 *
 * @param format   種別
 * @param freq     周波数設定
 * @param channels チャンネル数
 * @param samples  サンプルデータ数
 */
- (int)init:(AudioFormat)format freq:(int)freq channels:(int)channels samples:(int)samples 
{
	int i;

	// 再オープンの場合はいったん終了処理
	if (opened) {
		[self stop];
	}

	// ロック生成
	lock = [[NSLock alloc] init];

	header.numChannels = channels;
    header.sampleSize  = (format & 0xff) * 8;
    header.sampleRate  = freq << 16;
    header.numFrames   = samples;
    header.encode      = cmpSH;

    // コンバータ設定 
	// デフォルトは MSB らしい
    switch (format) {
	case AUDIO_S16LSB:
        header.compressionID = fixedCompression;
        header.format = k16BitLittleEndianFormat;
		break;
	default:
		header.compressionID = notCompressed;
    }

    // 再生バッファ生成
	buffer_size = (format & 0xff) * samples * channels;
	for (i=0; i<2; i++) {
		if ((buffer[i] = malloc (sizeof(buffer[0]) * buffer_size)) == NULL) {
			goto errend;
		}
		memset(buffer[i], 0, buffer_size);
	}

	// チャンネル生成
	if ((channel = malloc(sizeof *channel)) == NULL) {
		goto errend;
	}

    channel->userInfo = (long)self;
    channel->qLength  = 128;
    if (SndNewChannel(&channel, 
					  sampledSynth, 
					  (channels >= 2) ? initStereo : initMono,
					  NewSndCallBackUPP(callbackProc)) != noErr) {
        fprintf(stderr, "failed to create audio channel");
        goto errend;
    }

	opened = YES;
	paused = YES;

   	// コールバック処理開始
	{
		SndCommand cmd;
		cmd.cmd = callBackCmd;
		SndDoCommand(channel, &cmd, 0);
	}

	return 0;
	
 errend:
	for (i=0;i<2;i++)
		free(buffer[i]);
	free(channel);
	return -1;
}

/**
 * バッファ更新処理をロックする
 */
- (void)lock
{
	[lock lock];
}

/**
 * バッファ更新処理のロックを解除する
 */
- (void)unlock
{
	[lock unlock];
}

/**
 * 演奏状態を返す
 */
- (AudioStatus)status
{
	return opened ? (paused ? AUDIO_PAUSED :  AUDIO_PLAYING) : AUDIO_STOPPED;
}

/**
 * 演奏を一時停止する
 */
- (void)pause:(BOOL)on
{
	paused = on;
}

/**
 * 演奏を停止する。
 */
- (void)stop
{
	if (opened) {
		int i;
		opened = NO;
		
		// チャンネル破棄
		SndDisposeChannel(channel, true);
		channel = NULL;
		
		// バッファ破棄
		for (i=0; i<2; i++) {
			free(buffer[i]);
			buffer[i] = NULL;
		}

		// ロック破棄
		[lock release];
	}
}

/**
 * デストラクタ
 */
- (void)dealloc 
{
	if (opened) 
		[self stop];
	[super dealloc];
}

@end
