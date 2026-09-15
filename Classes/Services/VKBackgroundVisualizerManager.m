#import "VKBackgroundVisualizerManager.h"
#import "VKBackgroundVisualizerView.h"

static NSString *const kPrefEnabled      = @"openvk.bg_visualizer.enabled";
static NSString *const kPrefStyle        = @"openvk.bg_visualizer.style";
static NSString *const kPrefLayerMode    = @"openvk.bg_visualizer.layerMode";
static NSString *const kPrefOpacity      = @"openvk.bg_visualizer.opacity";
static NSString *const kPrefOnlyPlaying  = @"openvk.bg_visualizer.only_playing";

@interface VKBackgroundVisualizerManager ()
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic, strong, readwrite) VKBackgroundVisualizerView *visualizerView;
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
        _style = [ud objectForKey:kPrefStyle] ? (VKBackgroundVisualizerStyle)[ud integerForKey:kPrefStyle] : VKBackgroundVisualizerStyleWaves;
        _layerMode = [ud objectForKey:kPrefLayerMode] ? (VKBackgroundVisualizerLayerMode)[ud integerForKey:kPrefLayerMode] : VKBackgroundVisualizerLayerModeOverlay;
        _opacity = [ud objectForKey:kPrefOpacity] ? [ud floatForKey:kPrefOpacity] : 0.25f;
        _onlyWhenPlaying = [ud objectForKey:kPrefOnlyPlaying] ? [ud boolForKey:kPrefOnlyPlaying] : NO;
    }
    return self;
}

- (void)setupWithWindow:(UIWindow *)window {
    self.window = window;
    if (!self.visualizerView) {
        self.visualizerView = [[VKBackgroundVisualizerView alloc] initWithFrame:window.bounds];
        self.visualizerView.style = self.style;
        self.visualizerView.onlyWhenPlaying = self.onlyWhenPlaying;
        self.visualizerView.alpha = self.opacity;
    }
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
    self.visualizerView.style = style;
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
    if (self.visualizerView) {
        self.visualizerView.alpha = opacity;
    }
}

- (void)setOnlyWhenPlaying:(BOOL)onlyWhenPlaying {
    _onlyWhenPlaying = onlyWhenPlaying;
    [[NSUserDefaults standardUserDefaults] setBool:onlyWhenPlaying forKey:kPrefOnlyPlaying];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.visualizerView.onlyWhenPlaying = onlyWhenPlaying;
}

- (void)updateVisualizerState {
    if (!self.window) return;
    
    if (self.isEnabled) {
        if (!self.visualizerView) {
            self.visualizerView = [[VKBackgroundVisualizerView alloc] initWithFrame:self.window.bounds];
        }
        
        self.visualizerView.frame = self.window.bounds;
        self.visualizerView.alpha = self.opacity;
        self.visualizerView.style = self.style;
        self.visualizerView.onlyWhenPlaying = self.onlyWhenPlaying;
        self.visualizerView.hidden = NO;
        
        if (self.visualizerView.superview != self.window) {
            [self.visualizerView removeFromSuperview];
            if (self.layerMode == VKBackgroundVisualizerLayerModeOverlay) {
                [self.window addSubview:self.visualizerView];
            } else {
                [self.window insertSubview:self.visualizerView atIndex:0];
            }
        }
        
        if (self.layerMode == VKBackgroundVisualizerLayerModeOverlay) {
            [self.window bringSubviewToFront:self.visualizerView];
            self.visualizerView.layer.zPosition = 999;
        } else {
            [self.window sendSubviewToBack:self.visualizerView];
            self.visualizerView.layer.zPosition = -1;
        }
        
        [self.visualizerView start];
    } else {
        [self.visualizerView stop];
        self.visualizerView.hidden = YES;
        [self.visualizerView removeFromSuperview];
    }
}

- (NSString *)titleForStyle:(VKBackgroundVisualizerStyle)style {
    switch (style) {
        case VKBackgroundVisualizerStyleWaves: return @"🌊  Неоновые волны";
        case VKBackgroundVisualizerStyleEqualizer: return @"📊  Ретро-эквалайзер";
        case VKBackgroundVisualizerStyleAurora: return @"✨  Северное сияние";
        case VKBackgroundVisualizerStyleParticles: return @"🌌  Звёздная пыль";
    }
    return @"Неоновые волны";
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
