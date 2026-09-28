#import <Cocoa/Cocoa.h>
#import "NSLvnsImage.h"

#include <sys/time.h>
#include "Lvns.h"

@interface LvnsController : NSView
{
	/* 描画対象ウインドウ */
    IBOutlet id mainWindow;

	/* LVNS 情報構造体 */
    Lvns *lvns;
	
	/* Flip 処理用 */
	NSTimeInterval wait_clock;
	NSTimeInterval wait_count;

	/* 内部描画バッファ用 */
	NSLvnsImage *image;

	/* タイマ保持用 */
    struct timeval timer[10];

	/* サウンド処理用 */
	Sound sound_info;
	NSSound *sound;
	u_char *sound_data;
	size_t sound_len;

	/* BGM処理用 */
	Music music_info;
	NSMovie *movie;
}	

- (IBAction) Select              : (id) sender;
- (IBAction) Cancel              : (id) sender; 
- (IBAction) ImageMode           : (id) sender;
- (IBAction) SkipTillSelect      : (id) sender ;
- (IBAction) SkipTillSelectForce : (id) sender;
- (IBAction) CursorUp            : (id) sender;
- (IBAction) CursorDown          : (id) sender;


@end


