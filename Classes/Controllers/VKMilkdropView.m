#import "VKMilkdropView.h"
#import <QuartzCore/QuartzCore.h>
#import "VKVisualizerEngine.h"

@interface VKMilkdropView ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) UILabel *presetBadgeLabel;
@end

@implementation VKMilkdropView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:10.0/255.0 green:12.0/255.0 blue:18.0/255.0 alpha:1.0];
        self.layer.cornerRadius = 6.0;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
        _isPlaying = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nextPreset)];
        [self addGestureRecognizer:tap];
        
        _presetBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 24)];
        _presetBadgeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _presetBadgeLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:220.0/255.0 blue:255.0/255.0 alpha:1.0];
        _presetBadgeLabel.font = [UIFont boldSystemFontOfSize:11];
        _presetBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _presetBadgeLabel.layer.cornerRadius = 4.0;
        _presetBadgeLabel.clipsToBounds = YES;
        _presetBadgeLabel.alpha = 0.0;
        [self addSubview:_presetBadgeLabel];
        
        [self startAnimation];
    }
    return self;
}

- (void)startAnimation {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame)];
    if ([self.displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        [self.displayLink setPreferredFramesPerSecond:60];
    }
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)dealloc {
    [self stopAnimation];
}

- (void)nextPreset {
    [[VKVisualizerEngine sharedEngine] nextPreset];
    [self showPresetBadge];
}

- (void)previousPreset {
    [[VKVisualizerEngine sharedEngine] previousPreset];
    [self showPresetBadge];
}

- (NSString *)currentPresetName {
    return [[VKVisualizerEngine sharedEngine] currentPresetTitle];
}

- (void)showPresetBadge {
    self.presetBadgeLabel.text = [self currentPresetName];
    [self.presetBadgeLabel sizeToFit];
    CGRect f = self.presetBadgeLabel.frame;
    f.size.width += 18.0;
    f.size.height = 24.0;
    f.origin.x = 10.0;
    f.origin.y = 10.0;
    self.presetBadgeLabel.frame = f;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.presetBadgeLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4 delay:1.8 options:0 animations:^{
            self.presetBadgeLabel.alpha = 0.0;
        } completion:nil];
    }];
}

- (void)renderFrame {
    [VKVisualizerEngine sharedEngine].isPlaying = self.isPlaying;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    
    [[VKVisualizerEngine sharedEngine] renderFrameInContext:ctx size:rect.size];
}

@end
