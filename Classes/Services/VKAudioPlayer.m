#import "VKAudioPlayer.h"

NSString *const VKAudioPlayerStateDidChangeNotification = @"VKAudioPlayerStateDidChangeNotification";
NSString *const VKAudioPlayerProgressNotification = @"VKAudioPlayerProgressNotification";

@interface VKAudioPlayer ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong, readwrite) VKAudioTrack *currentTrack;
@property (nonatomic, strong, readwrite) NSArray<VKAudioTrack *> *playlist;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, strong) id timeObserver;
@end

@implementation VKAudioPlayer

+ (instancetype)sharedPlayer {
    static VKAudioPlayer *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _playlist = @[];
        _currentIndex = -1;
        
        // Настройка фонового воспроизведения в iOS
        NSError *categoryError = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(itemDidFinishPlaying:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
    }
    return self;
}

- (void)playPlaylist:(NSArray<VKAudioTrack *> *)tracks startIndex:(NSInteger)index {
    if (!tracks || tracks.count == 0) return;
    self.playlist = [tracks copy];
    self.currentIndex = (index >= 0 && index < (NSInteger)tracks.count) ? index : 0;
    [self playTrackInternal:self.playlist[self.currentIndex]];
}

- (void)playTrack:(VKAudioTrack *)track {
    if (!track) return;
    self.playlist = @[track];
    self.currentIndex = 0;
    [self playTrackInternal:track];
}

- (void)playTrackInternal:(VKAudioTrack *)track {
    self.currentTrack = track;
    self.currentTime = 0;
    self.duration = (track.durationSeconds > 0) ? track.durationSeconds : 180.0;
    
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    
    if (track.streamURL && track.streamURL.length > 0) {
        NSURL *url = [NSURL URLWithString:track.streamURL];
        if (url) {
            AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
            self.player = [AVPlayer playerWithPlayerItem:item];
            [self.player play];
            self.isPlaying = YES;
            
            __weak typeof(self) weakSelf = self;
            self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                                          queue:dispatch_get_main_queue()
                                                                     usingBlock:^(CMTime time) {
                if (weakSelf) {
                    weakSelf.currentTime = CMTimeGetSeconds(time);
                    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerProgressNotification object:nil];
                }
            }];
        }
    } else {
        // Симуляция воспроизведения для демо/треков без прямого потока
        self.isPlaying = YES;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)togglePlayPause {
    if (self.isPlaying) {
        [self pause];
    } else {
        [self play];
    }
}

- (void)play {
    if (self.player) {
        [self.player play];
    }
    self.isPlaying = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)pause {
    if (self.player) {
        [self.player pause];
    }
    self.isPlaying = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)stop {
    if (self.player) {
        [self.player pause];
    }
    self.isPlaying = NO;
    self.currentTrack = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)nextTrack {
    if (self.playlist.count == 0) return;
    if (self.isShuffleEnabled && self.playlist.count > 1) {
        NSInteger nextIdx = arc4random_uniform((u_int32_t)self.playlist.count);
        if (nextIdx == self.currentIndex) nextIdx = (nextIdx + 1) % self.playlist.count;
        self.currentIndex = nextIdx;
    } else {
        self.currentIndex = (self.currentIndex + 1) % self.playlist.count;
    }
    [self playTrackInternal:self.playlist[self.currentIndex]];
}

- (void)previousTrack {
    if (self.playlist.count == 0) return;
    self.currentIndex = (self.currentIndex - 1 + self.playlist.count) % self.playlist.count;
    [self playTrackInternal:self.playlist[self.currentIndex]];
}

- (void)seekToTime:(NSTimeInterval)time {
    self.currentTime = time;
    if (self.player) {
        [self.player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerProgressNotification object:nil];
}

- (void)itemDidFinishPlaying:(NSNotification *)notification {
    if (self.repeatMode == 2) {
        // Повтор одного трека
        [self seekToTime:0];
        [self play];
    } else if (self.repeatMode == 1 || self.currentIndex < (NSInteger)self.playlist.count - 1) {
        [self nextTrack];
    } else {
        [self pause];
    }
}

@end
