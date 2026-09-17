#import "VKBackgroundVisualizerManager.h"
#import "VKBackgroundVisualizerView.h"
#import "VKAVSGLView.h"
#import "VKProjectMGLView.h"
#import "VKAudioPlayer.h"

static NSString *const kPrefEnabled      = @"openvk.bg_visualizer.enabled";
static NSString *const kPrefStyle        = @"openvk.bg_visualizer.style";
static NSString *const kPrefLayerMode    = @"openvk.bg_visualizer.layerMode";
static NSString *const kPrefOpacity      = @"openvk.bg_visualizer.opacity";
static NSString *const kPrefOnlyPlaying  = @"openvk.bg_visualizer.only_playing";

@interface VKBackgroundVisualizerManager ()
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong, readwrite) UIView *activeVisualizerView;
@property (nonatomic, strong) VKAVSGLView *avsView;
@property (nonatomic, strong) VKProjectMGLView *milkdropView;
@property (nonatomic, strong) VKBackgroundVisualizerView *legacy2DView;
@end

@implementation VKBackgroundVisualizerManager

+ (instancetype)sharedManager {
    static VKBackgroundVisualizerManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[VKBackgroundVisualizerManager alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        _isEnabled = [ud objectForKey:kPrefEnabled] ? [ud boolForKey:kPrefEnabled] : NO;
        _style = [ud objectForKey:kPrefStyle] ? (VKBackgroundVisualizerStyle)[ud integerForKey:kPrefStyle] : VKBackgroundVisualizerStyleAVS;
        _layerMode = [ud objectForKey:kPrefLayerMode] ? (VKBackgroundVisualizerLayerMode)[ud integerForKey:kPrefLayerMode] : VKBackgroundVisualizerLayerModeOverlay;
        _opacity = [ud objectForKey:kPrefOpacity] ? [ud floatForKey:kPrefOpacity] : 0.25f;
        _onlyWhenPlaying = [ud objectForKey:kPrefOnlyPlaying] ? [ud boolForKey:kPrefOnlyPlaying] : NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioPlayerStateChanged:)
                                                     name:VKAudioPlayerStateDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupWithWindow:(UIWindow *)window {
    self.window = window;
    [self updateVisualizerState];
}

- (void)setIsEnabled:(BOOL)isEnabled {
    _isEnabled = isEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:isEnabled forKey:kPrefEnabled];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateVisualizerState];
}

- (void)setStyle:(VKBackgroundVisualizerStyle)style {
    _style = style;
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)style forKey:kPrefStyle];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateVisualizerState];
}

- (void)setLayerMode:(VKBackgroundVisualizerLayerMode)layerMode {
    _layerMode = layerMode;
    [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)layerMode forKey:kPrefLayerMode];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateVisualizerState];
}

- (void)setOpacity:(CGFloat)opacity {
    _opacity = opacity;
    [[NSUserDefaults standardUserDefaults] setFloat:(float)opacity forKey:kPrefOpacity];
    [[NSUserDefaults standardUserDefaults] synchronize];
    if (self.activeVisualizerView) {
        self.activeVisualizerView.alpha = opacity;
    }
}

- (void)setOnlyWhenPlaying:(BOOL)onlyWhenPlaying {
    _onlyWhenPlaying = onlyWhenPlaying;
    [[NSUserDefaults standardUserDefaults] setBool:onlyWhenPlaying forKey:kPrefOnlyPlaying];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateVisualizerState];
}

- (void)audioPlayerStateChanged:(NSNotification *)note {
    if (self.isEnabled && self.onlyWhenPlaying) {
        [self updateVisualizerState];
    }
}

- (void)appDidEnterBackground:(NSNotification *)note {
    if (self.avsView) {
        [self.avsView stopAnimation];
    }
    if (self.milkdropView) {
        [self.milkdropView stopAnimation];
    }
    if (self.legacy2DView) {
        [self.legacy2DView stop];
    }
}

- (void)appWillEnterForeground:(NSNotification *)note {
    if (self.isEnabled) {
        [self updateVisualizerState];
    }
}

- (void)updateVisualizerState {
    if (!self.window) return;
    
    if (!self.isEnabled) {
        if (self.avsView) {
            [self.avsView stopAnimation];
            [self.avsView removeFromSuperview];
            self.avsView = nil;
        }
        if (self.milkdropView) {
            [self.milkdropView stopAnimation];
            [self.milkdropView removeFromSuperview];
            self.milkdropView = nil;
        }
        if (self.legacy2DView) {
            [self.legacy2DView stop];
            [self.legacy2DView removeFromSuperview];
            self.legacy2DView = nil;
        }
        self.activeVisualizerView = nil;
        return;
    }
    
    // Включение нужного визуализатора
    if (self.style == VKBackgroundVisualizerStyleAVS) {
        if (self.milkdropView) {
            [self.milkdropView stopAnimation];
            [self.milkdropView removeFromSuperview];
            self.milkdropView = nil;
        }
        if (self.legacy2DView) {
            [self.legacy2DView stop];
            [self.legacy2DView removeFromSuperview];
            self.legacy2DView = nil;
        }
        
        if (!self.avsView) {
            self.avsView = [[VKAVSGLView alloc] initWithFrame:self.window.bounds];
            self.avsView.userInteractionEnabled = NO;
            self.avsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        self.activeVisualizerView = self.avsView;
        
    } else if (self.style == VKBackgroundVisualizerStyleMilkdrop) {
        if (self.avsView) {
            [self.avsView stopAnimation];
            [self.avsView removeFromSuperview];
            self.avsView = nil;
        }
        if (self.legacy2DView) {
            [self.legacy2DView stop];
            [self.legacy2DView removeFromSuperview];
            self.legacy2DView = nil;
        }
        
        if (!self.milkdropView) {
            self.milkdropView = [[VKProjectMGLView alloc] initWithFrame:self.window.bounds];
            self.milkdropView.userInteractionEnabled = NO;
            self.milkdropView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        self.activeVisualizerView = self.milkdropView;
        
    } else {
        // 2D эффекты (Волны, Эквалайзер, Аура, Частицы)
        if (self.avsView) {
            [self.avsView stopAnimation];
            [self.avsView removeFromSuperview];
            self.avsView = nil;
        }
        if (self.milkdropView) {
            [self.milkdropView stopAnimation];
            [self.milkdropView removeFromSuperview];
            self.milkdropView = nil;
        }
        
        if (!self.legacy2DView) {
            self.legacy2DView = [[VKBackgroundVisualizerView alloc] initWithFrame:self.window.bounds];
            self.legacy2DView.userInteractionEnabled = NO;
            self.legacy2DView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        self.legacy2DView.style = self.style;
        self.legacy2DView.onlyWhenPlaying = self.onlyWhenPlaying;
        self.activeVisualizerView = self.legacy2DView;
    }
    
    if (self.activeVisualizerView) {
        self.activeVisualizerView.frame = self.window.bounds;
        self.activeVisualizerView.alpha = self.opacity;
        
        if (self.activeVisualizerView.superview != self.window) {
            [self.activeVisualizerView removeFromSuperview];
            if (self.layerMode == VKBackgroundVisualizerLayerModeOverlay) {
                [self.window addSubview:self.activeVisualizerView];
            } else {
                [self.window insertSubview:self.activeVisualizerView atIndex:0];
            }
        }
        
        if (self.layerMode == VKBackgroundVisualizerLayerModeOverlay) {
            [self.window bringSubviewToFront:self.activeVisualizerView];
            self.activeVisualizerView.layer.zPosition = 999;
        } else {
            [self.window sendSubviewToBack:self.activeVisualizerView];
            self.activeVisualizerView.layer.zPosition = -1;
        }
        
        // Управление воспроизведением анимации
        BOOL shouldAnimate = YES;
        if (self.onlyWhenPlaying) {
            shouldAnimate = [[VKAudioPlayer sharedPlayer] isPlaying];
        }
        
        if (shouldAnimate) {
            self.activeVisualizerView.hidden = NO;
            if (self.avsView) {
                [self.avsView startAnimation];
            } else if (self.milkdropView) {
                [self.milkdropView startAnimation];
            } else if (self.legacy2DView) {
                [self.legacy2DView start];
            }
        } else {
            self.activeVisualizerView.hidden = YES;
            if (self.avsView) {
                [self.avsView stopAnimation];
            } else if (self.milkdropView) {
                [self.milkdropView stopAnimation];
            } else if (self.legacy2DView) {
                [self.legacy2DView stop];
            }
        }
    }
}

- (NSString *)titleForStyle:(VKBackgroundVisualizerStyle)style {
    switch (style) {
        case VKBackgroundVisualizerStyleAVS: return @"⚡  Winamp AVS (2D)";
        case VKBackgroundVisualizerStyleMilkdrop: return @"🌌  Milkdrop 2 (3D)";
        case VKBackgroundVisualizerStyleWaves: return @"🌊  Неоновые волны (2D)";
        case VKBackgroundVisualizerStyleEqualizer: return @"📊  Ретро-эквалайзер (2D)";
        case VKBackgroundVisualizerStyleAurora: return @"✨  Северное сияние (2D)";
        case VKBackgroundVisualizerStyleParticles: return @"🪐  Звёздная пыль (2D)";
    }
    return @"Winamp AVS";
}

- (NSString *)titleForLayerMode:(VKBackgroundVisualizerLayerMode)mode {
    switch (mode) {
        case VKBackgroundVisualizerLayerModeOverlay: return @"Поверх контента";
        case VKBackgroundVisualizerLayerModeUnderlay: return @"Подложка под контент";
    }
    return @"Поверх контента";
}

- (NSString *)titleForOpacity:(CGFloat)opacity {
    int pct = (int)roundf(opacity * 100.0f);
    return [NSString stringWithFormat:@"%d%%", pct];
}

@end
