#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "VKAudioTrack.h"

extern NSString *const VKAudioPlayerStateDidChangeNotification;
extern NSString *const VKAudioPlayerProgressNotification;

@interface VKAudioPlayer : NSObject

@property (nonatomic, strong, readonly) VKAudioTrack *currentTrack;
@property (nonatomic, strong, readonly) NSArray<VKAudioTrack *> *playlist;
@property (nonatomic, assign, readonly) NSInteger currentIndex;
@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign) BOOL isShuffleEnabled;
@property (nonatomic, assign) NSInteger repeatMode; // 0: None, 1: Repeat All, 2: Repeat One

+ (instancetype)sharedPlayer;

- (void)playPlaylist:(NSArray<VKAudioTrack *> *)tracks startIndex:(NSInteger)index;
- (void)playTrack:(VKAudioTrack *)track;
- (void)togglePlayPause;
- (void)play;
- (void)pause;
- (void)stop;
- (void)nextTrack;
- (void)previousTrack;
- (void)seekToTime:(NSTimeInterval)time;

@end
