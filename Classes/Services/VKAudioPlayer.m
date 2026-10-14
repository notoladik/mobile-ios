#import "VKAudioPlayer.h"
#import "VKAudioCacheManager.h"
#import <MediaToolbox/MediaToolbox.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import <stdint.h>
#import <QuartzCore/QuartzCore.h>
#import "VKPCMBuffer.h"

NSString *const VKAudioPlayerStateDidChangeNotification = @"VKAudioPlayerStateDidChangeNotification";
NSString *const VKAudioPlayerProgressNotification = @"VKAudioPlayerProgressNotification";

typedef struct {
    __unsafe_unretained VKAudioPlayer *player;
    VKPCMFormat format;
    double sampleRate;
    unsigned generation;
    BOOL supported;
} VKAudioTapStorage;

@interface VKAudioPlayer () {
    VKPCMBuffer _pcm;
    unsigned _playbackGeneration;
}
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong, readwrite) VKAudioTrack *currentTrack;
@property (nonatomic, strong, readwrite) NSArray<VKAudioTrack *> *playlist;
@property (nonatomic, assign, readwrite) NSInteger currentIndex;
@property (nonatomic, assign, readwrite) BOOL isPlaying;
@property (nonatomic, assign, readwrite) NSTimeInterval currentTime;
@property (nonatomic, assign, readwrite) NSTimeInterval duration;
@property (nonatomic, strong) id timeObserver;

@property (nonatomic, copy) NSString *tapStatus;
- (void)resetPCMBuffer;
- (unsigned)pcmGeneration;
- (void)handleAudioBufferList:(AudioBufferList *)buffers frames:(CMItemCount)frames storage:(VKAudioTapStorage *)storage;
@end

static void tap_Init(MTAudioProcessingTapRef tap, void *clientInfo, void **storageOut) {
    VKAudioPlayer *player = (__bridge VKAudioPlayer *)clientInfo;
    VKAudioTapStorage *storage = calloc(1, sizeof(*storage));
    if (storage) {
        storage->player = player;
        storage->generation = [player pcmGeneration];
    }
    *storageOut = storage;
}
static void tap_Finalize(MTAudioProcessingTapRef tap) {
    free(MTAudioProcessingTapGetStorage(tap));
}
static void tap_Prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *asbd) {
    VKAudioTapStorage *s = MTAudioProcessingTapGetStorage(tap);
    if (!s || !asbd) return;
    unsigned channelsInBuffer = (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) ? 1 : asbd->mChannelsPerFrame;
    s->format = (VKPCMFormat){
        channelsInBuffer ? asbd->mBytesPerFrame / channelsInBuffer : 0,
        asbd->mBitsPerChannel, asbd->mBytesPerFrame,
        (asbd->mFormatFlags & kAudioFormatFlagIsFloat) != 0,
        (asbd->mFormatFlags & kAudioFormatFlagIsBigEndian) != 0,
        (asbd->mFormatFlags & kAudioFormatFlagIsAlignedHigh) != 0
    };
    s->sampleRate = asbd->mSampleRate;
    s->supported = asbd->mFormatID == kAudioFormatLinearPCM &&
        ((asbd->mFormatFlags & kAudioFormatFlagIsFloat) || (asbd->mFormatFlags & kAudioFormatFlagIsSignedInteger)) &&
        VKPCMFormatSupported(s->format);
}
static void tap_Unprepare(MTAudioProcessingTapRef tap) {
    VKAudioTapStorage *s = MTAudioProcessingTapGetStorage(tap);
    if (s) s->supported = NO;
}
static void tap_Process(MTAudioProcessingTapRef tap, CMItemCount frames, MTAudioProcessingTapFlags flags,
                        AudioBufferList *buffers, CMItemCount *framesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, frames, buffers, flagsOut, NULL, framesOut);
    VKAudioTapStorage *s = MTAudioProcessingTapGetStorage(tap);
    if (status == noErr && s && s->supported && framesOut && *framesOut > 0)
        [s->player handleAudioBufferList:buffers frames:*framesOut storage:s];
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
        VKPCMInit(&_pcm);
        [self resetPCMBuffer];
        // Настройка фонового воспроизведения в iOS
        NSError *categoryError = nil;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(itemDidFinishPlaying:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioSessionInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
    }
    return self;
}

- (unsigned)pcmGeneration {
    pthread_mutex_lock(&_pcm.lock);
    unsigned generation = _pcm.generation;
    pthread_mutex_unlock(&_pcm.lock);
    return generation;
}
- (void)handleAudioBufferList:(AudioBufferList *)buffers frames:(CMItemCount)frames storage:(VKAudioTapStorage *)storage {
    if (!buffers || frames <= 0 || buffers->mNumberBuffers > VK_PCM_MAX_BUFFERS) return;
    VKPCMSamples samples[VK_PCM_MAX_BUFFERS];
    for (unsigned i = 0; i < buffers->mNumberBuffers; ++i)
        samples[i] = (VKPCMSamples){buffers->mBuffers[i].mData, buffers->mBuffers[i].mDataByteSize, buffers->mBuffers[i].mNumberChannels};
    VKPCMPush(&_pcm, storage->generation, storage->format, samples, buffers->mNumberBuffers,
              (size_t)frames, storage->sampleRate, CACurrentMediaTime());
}
- (void)resetPCMBuffer {
    _playbackGeneration = VKPCMReset(&_pcm);
    self.tapStatus = @"Ожидание аудиодорожки";
}
- (void)getLatestPCMData:(float *)outBuffer count:(NSUInteger)count {
    if (!outBuffer || !count) return;
    if (!self.isPlaying) { memset(outBuffer, 0, sizeof(float) * count); return; }
    VKPCMRead(&_pcm, outBuffer, count, CACurrentMediaTime());
}
- (NSString *)pcmDiagnosticText {
    pthread_mutex_lock(&_pcm.lock);
    uint64_t captured = _pcm.framesCaptured;
    double rate = _pcm.sampleRate;
    BOOL fresh = _pcm.validCount && CACurrentMediaTime() - _pcm.lastTime <= 0.5;
    pthread_mutex_unlock(&_pcm.lock);
    if (!self.currentTrack) return @"Нет воспроизводимой музыки";
    if (!self.player) return self.tapStatus ?: @"Нет доступного аудиофайла";
    if (!self.isPlaying) return @"Пауза — PCM не выводится";
    if (captured) return [NSString stringWithFormat:@"PCM %@ · %.0f Гц · %llu кадров", fresh ? @"поступает" : @"ожидается", rate, (unsigned long long)captured];
    return self.tapStatus ?: @"PCM пока не поступает";
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
    if (self.player.currentItem) self.player.currentItem.audioMix = nil;
    [self resetPCMBuffer];
    unsigned generation = _playbackGeneration;
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
        
        // Install an audio tap only after async track loading succeeds.
        // AVPlayer can play network assets before their tracks are synchronously visible.
        self.player = [AVPlayer playerWithPlayerItem:item];
        self.isPlaying = YES; // Playback intent; pause during loading is respected below.
        __weak typeof(self) weakSelf = self;
        __weak typeof(self) weakPlayer = self;
        [item.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
            NSError *error = nil;
            AVKeyValueStatus status = [item.asset statusOfValueForKey:@"tracks" error:&error];
            dispatch_async(dispatch_get_main_queue(), ^{
                VKAudioPlayer *strongSelf = weakPlayer;
                if (!strongSelf || strongSelf->_playbackGeneration != generation || strongSelf.player.currentItem != item) return;
                if (status != AVKeyValueStatusLoaded) {
                    strongSelf.tapStatus = @"Не удалось загрузить аудиодорожку для PCM";
                    NSLog(@"[VKAudioPlayer] Audio tracks unavailable: %@", error);
                    if (strongSelf.isPlaying) [strongSelf.player play];
                    return;
                }
                NSArray *tracks = [item.asset tracksWithMediaType:AVMediaTypeAudio];
                if (!tracks.count) {
                    strongSelf.tapStatus = @"Поток не предоставляет audio tap; попробуйте сохранённый трек";
                    NSLog(@"[VKAudioPlayer] No audio track for PCM tap");
                    if (strongSelf.isPlaying) [strongSelf.player play];
                    return;
                }
                MTAudioProcessingTapCallbacks callbacks = {0};
                // The SDK explicitly requires version 0, not literal 1.
                callbacks.version = kMTAudioProcessingTapCallbacksVersion_0;
                callbacks.clientInfo = (__bridge void *)strongSelf;
                callbacks.init = tap_Init;
                callbacks.finalize = tap_Finalize;
                callbacks.prepare = tap_Prepare;
                callbacks.unprepare = tap_Unprepare;
                callbacks.process = tap_Process;
                MTAudioProcessingTapRef tap = NULL;
                OSStatus tapStatus = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PreEffects, &tap);
                if (tapStatus != noErr || !tap) {
                    strongSelf.tapStatus = [NSString stringWithFormat:@"Не удалось создать audio tap (%d)", (int)tapStatus];
                    NSLog(@"[VKAudioPlayer] Audio tap creation failed: %d", (int)tapStatus);
                    if (strongSelf.isPlaying) [strongSelf.player play];
                    return;
                }
                AVMutableAudioMixInputParameters *parameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:tracks.firstObject];
                parameters.audioTapProcessor = tap;
                AVMutableAudioMix *mix = [AVMutableAudioMix audioMix];
                mix.inputParameters = @[parameters];
                item.audioMix = mix;
                CFRelease(tap);
                strongSelf.tapStatus = @"Audio tap подключён; ожидание PCM";
                if (strongSelf.isPlaying) [strongSelf.player play];
            });
        }];

        self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                                      queue:dispatch_get_main_queue()
                                                                 usingBlock:^(CMTime time) {
            if (weakSelf) {
                weakSelf.currentTime = CMTimeGetSeconds(time);
                [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerProgressNotification object:nil];
            }
        }];
    } else {
        self.isPlaying = NO;
        self.tapStatus = @"У трека нет доступного аудиофайла";
    }
    
    [self updateNowPlayingInfo];
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
    if (!self.player) return;
    if (self.player) {
        [self.player play];
    }
    self.isPlaying = YES;
    [self updateNowPlayingInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)pause {
    if (self.player) {
        [self.player pause];
    }
    self.isPlaying = NO;
    [self updateNowPlayingInfo];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKAudioPlayerStateDidChangeNotification object:nil];
}

- (void)stop {
    if (self.player) {
        [self.player pause];
    }
    self.player.currentItem.audioMix = nil;
    [self resetPCMBuffer];
    if (self.player && self.timeObserver) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    self.player = nil;
    self.isPlaying = NO;
    self.currentTrack = nil;
    [self updateNowPlayingInfo];
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
    [self updateNowPlayingInfo];
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

- (void)handleAudioSessionInterruption:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    AVAudioSessionInterruptionType type = [userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan) {
        if (self.isPlaying) {
            [self pause];
        }
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        AVAudioSessionInterruptionOptions options = [userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options & AVAudioSessionInterruptionOptionShouldResume) {
            [self play];
        }
    }
}

- (void)handleRemoteControlEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) return;
    
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay:
            [self play];
            break;
        case UIEventSubtypeRemoteControlPause:
            [self pause];
            break;
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [self togglePlayPause];
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [self nextTrack];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [self previousTrack];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingBackward:
        case UIEventSubtypeRemoteControlBeginSeekingForward:
        case UIEventSubtypeRemoteControlEndSeekingBackward:
        case UIEventSubtypeRemoteControlEndSeekingForward:
            break;
        default:
            break;
    }
}

- (void)updateNowPlayingInfo {
    if (!self.currentTrack) {
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
        return;
    }
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (self.currentTrack.title.length > 0) {
        info[MPMediaItemPropertyTitle] = self.currentTrack.title;
    } else {
        info[MPMediaItemPropertyTitle] = @"Аудиозапись";
    }
    
    if (self.currentTrack.artist.length > 0) {
        info[MPMediaItemPropertyArtist] = self.currentTrack.artist;
    } else {
        info[MPMediaItemPropertyArtist] = @"OpenVK";
    }
    
    if (self.duration > 0) {
        info[MPMediaItemPropertyPlaybackDuration] = @(self.duration);
    }
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(self.currentTime);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.isPlaying ? 1.0 : 0.0);
    
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
}

@end
