#import "VKAudioPlayer.h"
#import "VKAudioCacheManager.h"
#import <MediaToolbox/MediaToolbox.h>
#import <AudioToolbox/AudioToolbox.h>

NSString *const VKAudioPlayerStateDidChangeNotification = @"VKAudioPlayerStateDidChangeNotification";
NSString *const VKAudioPlayerProgressNotification = @"VKAudioPlayerProgressNotification";

@interface VKAudioPlayer () {
    float _pcmRingBuffer[1024];
    NSUInteger _pcmRingWriteIndex;
    BOOL _hasCapturedRealPCM;
    NSTimeInterval _lastPCMTime;
}
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong, readwrite) VKAudioTrack *currentTrack;
@property (nonatomic, strong, readwrite) NSArray<VKAudioTrack *> *playlist;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, strong) id timeObserver;

- (void)handleAudioBufferList:(AudioBufferList *)bufferList frames:(CMItemCount)frames;
@end

static void tap_Init(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void tap_Finalize(MTAudioProcessingTapRef tap) {
}

static void tap_Prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
}

static void tap_Unprepare(MTAudioProcessingTapRef tap) {
}

static void tap_Process(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status == noErr && numberFramesOut && *numberFramesOut > 0) {
        VKAudioPlayer *player = (__bridge VKAudioPlayer *)MTAudioProcessingTapGetStorage(tap);
        if (player) {
            [player handleAudioBufferList:bufferListInOut frames:*numberFramesOut];
        }
    }
}

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
        _pcmRingWriteIndex = 0;
        _hasCapturedRealPCM = NO;
        _lastPCMTime = 0;
        
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

- (void)handleAudioBufferList:(AudioBufferList *)bufferList frames:(CMItemCount)frames {
    if (!bufferList || bufferList->mNumberBuffers == 0 || frames == 0) return;
    
    @synchronized (self) {
        float *src = (float *)bufferList->mBuffers[0].mData;
        if (!src) return;
        
        NSUInteger toCopy = MIN((NSUInteger)frames, (NSUInteger)512);
        for (NSUInteger i = 0; i < toCopy; i++) {
            _pcmRingBuffer[(_pcmRingWriteIndex + i) % 1024] = src[i];
        }
        _pcmRingWriteIndex = (_pcmRingWriteIndex + toCopy) % 1024;
        _hasCapturedRealPCM = YES;
        _lastPCMTime = [NSDate timeIntervalSinceReferenceDate];
    }
}

- (void)getLatestPCMData:(float *)outBuffer count:(NSUInteger)count {
    if (!outBuffer || count == 0) return;
    
    if (!self.isPlaying) {
        memset(outBuffer, 0, count * sizeof(float));
        return;
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    @synchronized (self) {
        if (_hasCapturedRealPCM && (now - _lastPCMTime < 0.5)) {
            // Читаем из захваченного кольцевого буфера
            NSUInteger startIdx = (_pcmRingWriteIndex + 1024 - count) % 1024;
            for (NSUInteger i = 0; i < count; i++) {
                outBuffer[i] = _pcmRingBuffer[(startIdx + i) % 1024];
            }
            return;
        }
    }
    
    // Синхронизированный непрерывный живой гармонический спектр по монотонному времени
    static NSTimeInterval baseTime = 0.0;
    if (baseTime == 0.0) baseTime = now;
    double elapsed = now - baseTime;
    
    // Динамический ритм (126 BPM с суб-басом, киком, снейром и хай-хэтом)
    double beatPos = fmod(elapsed * (126.0 / 60.0), 1.0);
    float kick = (beatPos < 0.14) ? (1.0f - (float)beatPos / 0.14f) * 1.8f : 0.0f;
    float snare = (beatPos > 0.48 && beatPos < 0.62) ? (1.0f - ((float)beatPos - 0.48f) / 0.14f) * 1.3f : 0.0f;
    float hihat = (fmod(elapsed * (126.0 * 2.0 / 60.0), 1.0) < 0.08) ? 0.7f : 0.0f;
    
    for (NSUInteger i = 0; i < count; i++) {
        double t = elapsed * 3.5 + (double)i * 0.04;
        float sub = sinf(t * 1.2f) * (0.6f + kick * 0.9f);
        float bass = sinf(t * 2.5f + sinf(t * 0.4f)) * 0.5f;
        float mid = sinf(t * 9.8f) * (0.35f + snare * 0.6f);
        float treb = sinf(t * 32.4f) * (0.2f + hihat * 0.5f);
        outBuffer[i] = (sub + bass + mid + treb) * 0.75f;
    }
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
    self.duration = (track.durationSeconds > 0) ? (NSTimeInterval)track.durationSeconds : 180.0;
    
    if (self.player) {
        [self.player pause];
        if (self.timeObserver) {
            [self.player removeTimeObserver:self.timeObserver];
            self.timeObserver = nil;
        }
        self.player = nil;
    }
    
    NSURL *url = [[VKAudioCacheManager sharedManager] playbackURLForTrack:track];
    if (!url && track.streamURL.length > 0) {
        url = [NSURL URLWithString:track.streamURL];
    }
    if (!url && track.url.length > 0) {
        url = [NSURL URLWithString:track.url];
    }
    
    if (url) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
        AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
        
        __weak typeof(self) weakSelf = self;
        void (^attachTap)(AVAssetTrack *) = ^(AVAssetTrack *trackObj) {
            if (!trackObj) return;
            AVMutableAudioMixInputParameters *inputParams = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:trackObj];
            
            MTAudioProcessingTapCallbacks callbacks;
            callbacks.version = 1;
            callbacks.clientInfo = (__bridge void *)(weakSelf);
            callbacks.init = tap_Init;
            callbacks.finalize = tap_Finalize;
            callbacks.prepare = tap_Prepare;
            callbacks.unprepare = tap_Unprepare;
            callbacks.process = tap_Process;
            
            MTAudioProcessingTapRef tap = NULL;
            OSStatus err = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap);
            if (err == noErr && tap) {
                inputParams.audioTapProcessor = tap;
                CFRelease(tap);
                
                AVMutableAudioMix *audioMix = [AVMutableAudioMix audioMix];
                audioMix.inputParameters = @[inputParams];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (weakSelf && weakSelf.player && weakSelf.player.currentItem) {
                        weakSelf.player.currentItem.audioMix = audioMix;
                    }
                });
            }
        };
        
        NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        if (audioTracks.count > 0) {
            attachTap(audioTracks[0]);
        } else {
            [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
                NSArray *tracksAsync = [asset tracksWithMediaType:AVMediaTypeAudio];
                if (tracksAsync.count > 0) {
                    attachTap(tracksAsync[0]);
                }
            }];
        }
        
        self.player = [AVPlayer playerWithPlayerItem:item];
        [self.player play];
        self.isPlaying = YES;
        
        self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                                      queue:dispatch_get_main_queue()
                                                                 usingBlock:^(CMTime time) {
            if (weakSelf) {
                weakSelf.currentTime = CMTimeGetSeconds(time);
                [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerProgressNotification object:nil];
            }
        }];
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
