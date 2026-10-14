#import "VKChatBackgroundView.h"
#import "VKChatAppearance.h"
#import "VKAVSGLView.h"
#import "VKProjectMGLView.h"
#import "VKAudioPlayer.h"
#import "VKThemeManager.h"
#import "VKBackgroundVisualizerManager.h"

@interface VKChatBackgroundView ()
@property (nonatomic, strong) UIImageView *photoView;
@property (nonatomic, strong) VKAVSGLView *avsView;
@property (nonatomic, strong) VKProjectMGLView *milkdropView;
@property (nonatomic, assign, readwrite) BOOL hasCustomBackground;
@end

@implementation VKChatBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAnimation) name:VKAudioPlayerStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAnimation) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateAnimation) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [VKBackgroundVisualizerManager sharedManager].chatBackgroundActive = NO;
    if (self.avsView) {
        [self.avsView stopAnimation];
    }
    if (self.milkdropView) {
        [self.milkdropView stopAnimation];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setPeerId:(NSInteger)peerId {
    _peerId = peerId;
    [self refreshAppearance];
}

- (void)setActive:(BOOL)active {
    _active = active;
    [self updateAnimation];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updateAnimation];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.photoView) self.photoView.frame = self.bounds;
    if (self.avsView) self.avsView.frame = self.bounds;
    if (self.milkdropView) self.milkdropView.frame = self.bounds;
}

- (void)refreshAppearance {
    NSDictionary *settings = [VKChatAppearance effectiveSettingsForPeerId:self.peerId];
    VKChatBackgroundMode mode = [settings[@"mode"] integerValue];
    self.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    if (mode == VKChatBackgroundModePhoto) {
        if (!self.photoView) {
            self.photoView = [[UIImageView alloc] initWithFrame:self.bounds];
            self.photoView.contentMode = UIViewContentModeScaleAspectFill;
            self.photoView.clipsToBounds = YES;
            self.photoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:self.photoView];
        }
        self.photoView.image = [VKChatAppearance wallpaperForPeerId:self.peerId];
        self.photoView.hidden = NO;
    } else {
        self.photoView.image = nil;
        self.photoView.hidden = YES;
    }
    
    if (mode == VKChatBackgroundModeVisualizer) {
        VKBackgroundVisualizerStyle style = (VKBackgroundVisualizerStyle)[settings[@"style"] integerValue];
        CGFloat opacity = [settings[@"opacity"] floatValue];
        if (opacity <= 0.01f) opacity = 0.25f;
        
        if (style == VKBackgroundVisualizerStyleMilkdrop) {
            if (self.avsView) {
                [self.avsView stopAnimation];
                [self.avsView removeFromSuperview];
                self.avsView = nil;
            }
            if (!self.milkdropView) {
                self.milkdropView = [[VKProjectMGLView alloc] initWithFrame:self.bounds];
                self.milkdropView.userInteractionEnabled = NO;
                self.milkdropView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [self insertSubview:self.milkdropView atIndex:0];
            }
            self.milkdropView.alpha = opacity;
        } else {
            // AVS
            if (self.milkdropView) {
                [self.milkdropView stopAnimation];
                [self.milkdropView removeFromSuperview];
                self.milkdropView = nil;
            }
            if (!self.avsView) {
                self.avsView = [[VKAVSGLView alloc] initWithFrame:self.bounds];
                self.avsView.userInteractionEnabled = NO;
                self.avsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [self insertSubview:self.avsView atIndex:0];
            }
            self.avsView.alpha = opacity;
        }
    } else {
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
    }
    
    self.hasCustomBackground = (mode == VKChatBackgroundModeVisualizer) || (self.photoView.image != nil);
    [self updateAnimation];
}

- (void)updateAnimation {
    NSDictionary *settings = [VKChatAppearance effectiveSettingsForPeerId:self.peerId];
    VKChatBackgroundMode mode = [settings[@"mode"] integerValue];
    BOOL isVisMode = (mode == VKChatBackgroundModeVisualizer);
    
    [VKBackgroundVisualizerManager sharedManager].chatBackgroundActive = (self.active && isVisMode);
    
    BOOL canAnimate = self.active && self.window && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground;
    BOOL onlyPlaying = [settings[@"onlyPlaying"] boolValue];
    BOOL hasMusic = [VKAudioPlayer sharedPlayer].isPlaying;
    BOOL shouldAnimate = canAnimate && isVisMode && (!onlyPlaying || hasMusic);
    
    if (self.avsView) {
        self.avsView.hidden = !shouldAnimate;
        if (shouldAnimate) [self.avsView startAnimation];
        else [self.avsView stopAnimation];
    }
    if (self.milkdropView) {
        self.milkdropView.hidden = !shouldAnimate;
        if (shouldAnimate) [self.milkdropView startAnimation];
        else [self.milkdropView stopAnimation];
    }
}

@end
