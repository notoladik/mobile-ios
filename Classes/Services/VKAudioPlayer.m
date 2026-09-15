#import "VKAudioPlayer.h"
#import "VKAudioCacheManager.h"
#import <MediaToolbox/MediaToolbox.h>
#import <AudioToolbox/AudioToolbox.h>
#import <stdint.h>

NSString *const VKAudioPlayerStateDidChangeNotification = @"VKAudioPlayerStateDidChangeNotification";
NSString *const VKAudioPlayerProgressNotification = @"VKAudioPlayerProgressNotification";

@interface VKAudioPlayer () {
    float _pcmRingBuffer[4096];
    NSUInteger _pcmRingWriteIndex;
    BOOL _hasCapturedRealPCM;
    NSTimeInterval _lastPCMTime;
    AudioStreamBasicDescription _processingFormat;
    BOOL _hasProcessingFormat;
    NSUInteger _tapProcessCount;
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
- (void)configureProcessingFormat:(const AudioStreamBasicDescription *)format;
- (void)resetPCMBuffer;
- (void)recordTapProcess;
@end

static void tap_Init(MTAudioProcessingTapRef tap, void *clientInfo, void **tapStorageOut) {
    *tapStorageOut = clientInfo;
}

static void tap_Finalize(MTAudioProcessingTapRef tap) {
}

static void tap_Prepare(MTAudioProcessingTapRef tap, CMItemCount maxFrames, const AudioStreamBasicDescription *processingFormat) {
    VKAudioPlayer *player = (__bridge VKAudioPlayer *)MTAudioProcessingTapGetStorage(tap);
    [player configureProcessingFormat:processingFormat];
    if (processingFormat) {
        NSLog(@"[VKAudioPlayer] PCM tap prepared: %.0f Hz, %u channel(s), flags=0x%X",
              processingFormat->mSampleRate,
              (unsigned int)processingFormat->mChannelsPerFrame,
              (unsigned int)processingFormat->mFormatFlags);
    }
}

static void tap_Unprepare(MTAudioProcessingTapRef tap) {
}

static void tap_Process(MTAudioProcessingTapRef tap, CMItemCount numberFrames, MTAudioProcessingTapFlags flags, AudioBufferList *bufferListInOut, CMItemCount *numberFramesOut, MTAudioProcessingTapFlags *flagsOut) {
    OSStatus status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, NULL, numberFramesOut);
    if (status == noErr && numberFramesOut && *numberFramesOut > 0) {
        VKAudioPlayer *player = (__bridge VKAudioPlayer *)MTAudioProcessingTapGetStorage(tap);
        if (player) {
            [player recordTapProcess];
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
        _hasProcessingFormat = NO;
        _tapProcessCount = 0;
        
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
        NSUInteger toCopy = MIN((NSUInteger)frames, (NSUInteger)512);
        NSUInteger channels = _hasProcessingFormat ? _processingFormat.mChannelsPerFrame : bufferList->mNumberBuffers;
        if (channels == 0) channels = 1;
        BOOL nonInterleaved = bufferList->mNumberBuffers > 1;
        BOOL isFloat = !_hasProcessingFormat || (_processingFormat.mFormatFlags & kAudioFormatFlagIsFloat) != 0;
        NSUInteger bytesPerSample = _hasProcessingFormat ? (_processingFormat.mBitsPerChannel / 8) : sizeof(float);

        for (NSUInteger frame = 0; frame < toCopy; frame++) {
            double sample = 0.0;
            NSUInteger samplesRead = 0;
            if (nonInterleaved) {
                NSUInteger bufferCount = MIN((NSUInteger)bufferList->mNumberBuffers, channels);
                for (NSUInteger channel = 0; channel < bufferCount; channel++) {
                    uint8_t *base = (uint8_t *)bufferList->mBuffers[channel].mData;
                    if (!base) continue;
                    if (isFloat && bytesPerSample >= sizeof(float)) {
                        sample += ((float *)base)[frame];
                    } else if (bytesPerSample == sizeof(int16_t)) {
                        sample += ((int16_t *)base)[frame] / 32768.0;
                    } else {
                        continue;
                    }
                    samplesRead += 1;
                }
            } else {
                uint8_t *base = (uint8_t *)bufferList->mBuffers[0].mData;
                if (base) {
                    NSUInteger sampleIndex = frame * channels;
                    for (NSUInteger channel = 0; channel < channels; channel++) {
                        if (isFloat && bytesPerSample >= sizeof(float)) {
                            sample += ((float *)base)[sampleIndex + channel];
                        } else if (bytesPerSample == sizeof(int16_t)) {
                            sample += ((int16_t *)base)[sampleIndex + channel] / 32768.0;
                        } else {
                            continue;
                        }
                        samplesRead += 1;
                    }
                }
            }
            _pcmRingBuffer[(_pcmRingWriteIndex + frame) % 4096] = samplesRead > 0 ? (float)(sample / samplesRead) : 0.0f;
        }
        _pcmRingWriteIndex = (_pcmRingWriteIndex + toCopy) % 4096;
        _hasCapturedRealPCM = YES;
        _lastPCMTime = [NSDate timeIntervalSinceReferenceDate];
    }
}

- (void)configureProcessingFormat:(const AudioStreamBasicDescription *)format {
    if (!format) return;
    @synchronized (self) {
        _processingFormat = *format;
        _hasProcessingFormat = YES;
    }
}

- (void)recordTapProcess {
    @synchronized (self) {
        _tapProcessCount += 1;
        if (_tapProcessCount == 1) {
            NSLog(@"[VKAudioPlayer] First PCM buffer received from tap");
        }
    }
}

- (void)resetPCMBuffer {
    @synchronized (self) {
        memset(_pcmRingBuffer, 0, sizeof(_pcmRingBuffer));
        _pcmRingWriteIndex = 0;
        _hasCapturedRealPCM = NO;
        _lastPCMTime = 0;
        _hasProcessingFormat = NO;
        _tapProcessCount = 0;
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
            NSUInteger readCount = MIN(count, (NSUInteger)4096);
            NSUInteger startIdx = (_pcmRingWriteIndex + 4096 - readCount) % 4096;
            if (readCount < count) {
                memset(outBuffer, 0, (count - readCount) * sizeof(float));
            }
            for (NSUInteger i = 0; i < readCount; i++) {
                outBuffer[count - readCount + i] = _pcmRingBuffer[(startIdx + i) % 4096];
            }
            return;
        }
    }
    // No tap data means silence. Do not invent a beat: projectM should react
    // to the actual track or remain still while the stream is unavailable.
    memset(outBuffer, 0, count * sizeof(float));
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
    [self resetPCMBuffer];
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
            callbacks.clientInfo = (__bridge void *)(self);
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
                // Attach to the exact item captured above. Previously this block
                // ran before self.player was assigned and silently skipped the tap.
                item.audioMix = audioMix;
                NSLog(@"[VKAudioPlayer] PCM tap attached to audio item");
            } else {
                NSLog(@"[VKAudioPlayer] Could not create PCM tap (status=%d)", (int)err);
            }
        };

        // Create the player before loading tracks asynchronously. The tap is
        // still attached to `item`, never to whichever currentItem happens to
        // be installed when the callback returns.
        self.player = [AVPlayer playerWithPlayerItem:item];
        
        NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
        if (audioTracks.count > 0) {
            attachTap(audioTracks[0]);
            [self.player play];
            self.isPlaying = YES;
        } else {
            [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
                NSArray *tracksAsync = [asset tracksWithMediaType:AVMediaTypeAudio];
                if (tracksAsync.count > 0) {
                    attachTap(tracksAsync[0]);
                    // For remote assets the audio track appears asynchronously.
                    // Start playback only after the mix is installed, otherwise
                    // old AVPlayer implementations may never invoke the tap.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (weakSelf && weakSelf.player.currentItem == item) {
                            [weakSelf.player play];
                            weakSelf.isPlaying = YES;
                        }
                    });
                } else {
                    NSLog(@"[VKAudioPlayer] Audio track was not found in asset");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (weakSelf && weakSelf.player.currentItem == item) {
                            [weakSelf.player play];
                            weakSelf.isPlaying = YES;
                        }
                    });
                }
            }];
        }
        
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
