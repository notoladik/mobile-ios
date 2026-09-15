#import "VKBackgroundVisualizerView.h"
#import "VKAudioPlayer.h"
#import <QuartzCore/QuartzCore.h>

static const int kNumWaves = 4;
static const int kNumBars = 24;
static const int kNumParticles = 36;
static const int kNumBlobs = 3;

typedef struct {
    CGPoint position;
    CGPoint velocity;
    CGFloat size;
    CGFloat baseAlpha;
} VKParticle;

@interface VKBackgroundVisualizerView () {
    CADisplayLink *_displayLink;
    CGFloat _phase;
    float _smoothedRMS;
    
    // Слой волн
    CAShapeLayer *_waveLayers[kNumWaves];
    
    // Слой эквалайзера
    CALayer *_barLayers[kNumBars];
    CALayer *_capLayers[kNumBars];
    CGFloat _barPeakHeights[kNumBars];
    
    // Слой Аура / Сияние
    CAGradientLayer *_auroraLayers[kNumBlobs];
    
    // Слой частиц
    CALayer *_particleLayers[kNumParticles];
    VKParticle _particles[kNumParticles];
}

@property (nonatomic, assign) BOOL isAnimating;
@end

@implementation VKBackgroundVisualizerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        _smoothedRMS = 0.1f;
        _phase = 0.0f;
        _style = VKBackgroundVisualizerStyleWaves;
        
        [self setupStyleLayers];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stop];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil;
}

- (void)appDidEnterBackground {
    [self stop];
}

- (void)appWillEnterForeground {
    if (self.superview && !self.hidden) {
        [self start];
    }
}

- (void)setStyle:(VKBackgroundVisualizerStyle)style {
    if (_style != style) {
        _style = style;
        [self refreshStyle];
    }
}

- (void)refreshStyle {
    [self clearAllLayers];
    [self setupStyleLayers];
}

- (void)clearAllLayers {
    NSArray *sublayers = [self.layer.sublayers copy];
    for (CALayer *l in sublayers) {
        [l removeFromSuperlayer];
    }
    for (int i = 0; i < kNumWaves; i++) _waveLayers[i] = nil;
    for (int i = 0; i < kNumBars; i++) {
        _barLayers[i] = nil;
        _capLayers[i] = nil;
        _barPeakHeights[i] = 0;
    }
    for (int i = 0; i < kNumBlobs; i++) _auroraLayers[i] = nil;
    for (int i = 0; i < kNumParticles; i++) _particleLayers[i] = nil;
}

- (void)setupStyleLayers {
    switch (_style) {
        case VKBackgroundVisualizerStyleWaves:
            [self setupWavesLayers];
            break;
        case VKBackgroundVisualizerStyleEqualizer:
            [self setupEqualizerLayers];
            break;
        case VKBackgroundVisualizerStyleAurora:
            [self setupAuroraLayers];
            break;
        case VKBackgroundVisualizerStyleParticles:
            [self setupParticlesLayers];
            break;
    }
}

#pragma mark - Setup Layer Styles

- (void)setupWavesLayers {
    UIColor *colors[kNumWaves] = {
        [UIColor colorWithRed:0.0 green:0.75 blue:1.0 alpha:0.35],
        [UIColor colorWithRed:0.25 green:0.45 blue:0.95 alpha:0.40],
        [UIColor colorWithRed:0.85 green:0.20 blue:0.95 alpha:0.35],
        [UIColor colorWithRed:0.05 green:0.90 blue:0.65 alpha:0.30]
    };
    
    for (int i = 0; i < kNumWaves; i++) {
        CAShapeLayer *sl = [CAShapeLayer layer];
        sl.fillColor = colors[i].CGColor;
        sl.strokeColor = [UIColor clearColor].CGColor;
        sl.lineWidth = 0.0;
        sl.actions = @{@"path": [NSNull null]};
        [self.layer addSublayer:sl];
        _waveLayers[i] = sl;
    }
}

- (void)setupEqualizerLayers {
    for (int i = 0; i < kNumBars; i++) {
        CALayer *bar = [CALayer layer];
        float ratio = (float)i / (float)kNumBars;
        UIColor *col = [UIColor colorWithRed:(0.1 + 0.8 * ratio)
                                       green:(0.8 - 0.4 * ratio)
                                        blue:(0.9 - 0.3 * ratio)
                                       alpha:0.65];
        bar.backgroundColor = col.CGColor;
        bar.cornerRadius = 2.0;
        bar.actions = @{@"bounds": [NSNull null], @"position": [NSNull null], @"frame": [NSNull null]};
        [self.layer addSublayer:bar];
        _barLayers[i] = bar;
        
        CALayer *cap = [CALayer layer];
        cap.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
        cap.cornerRadius = 1.0;
        cap.actions = @{@"bounds": [NSNull null], @"position": [NSNull null], @"frame": [NSNull null]};
        [self.layer addSublayer:cap];
        _capLayers[i] = cap;
        _barPeakHeights[i] = 0;
    }
}

- (void)setupAuroraLayers {
    NSArray *colorPairs = @[
        @[ (id)[UIColor colorWithRed:0.1 green:0.5 blue:0.95 alpha:0.45].CGColor, (id)[UIColor clearColor].CGColor ],
        @[ (id)[UIColor colorWithRed:0.85 green:0.15 blue:0.65 alpha:0.40].CGColor, (id)[UIColor clearColor].CGColor ],
        @[ (id)[UIColor colorWithRed:0.0 green:0.85 blue:0.6 alpha:0.35].CGColor, (id)[UIColor clearColor].CGColor ]
    ];
    
    for (int i = 0; i < kNumBlobs; i++) {
        CAGradientLayer *g = [CAGradientLayer layer];
        if ([g respondsToSelector:@selector(setType:)]) {
            g.type = kCAGradientLayerRadial;
        }
        g.colors = colorPairs[i % colorPairs.count];
        g.startPoint = CGPointMake(0.5, 0.5);
        g.endPoint = CGPointMake(1.0, 1.0);
        g.cornerRadius = 120.0;
        g.actions = @{@"bounds": [NSNull null], @"position": [NSNull null], @"transform": [NSNull null]};
        [self.layer addSublayer:g];
        _auroraLayers[i] = g;
    }
}

- (void)setupParticlesLayers {
    CGSize sz = self.bounds.size;
    if (sz.width < 10) sz = [UIScreen mainScreen].bounds.size;
    
    for (int i = 0; i < kNumParticles; i++) {
        CALayer *p = [CALayer layer];
        CGFloat s = 2.0 + (arc4random() % 6);
        p.frame = CGRectMake(0, 0, s, s);
        p.cornerRadius = s / 2.0;
        
        float r = 0.5 + ((arc4random() % 50) / 100.0);
        float g = 0.7 + ((arc4random() % 30) / 100.0);
        float b = 1.0;
        p.backgroundColor = [UIColor colorWithRed:r green:g blue:b alpha:0.75].CGColor;
        p.actions = @{@"position": [NSNull null], @"opacity": [NSNull null], @"transform": [NSNull null]};
        [self.layer addSublayer:p];
        _particleLayers[i] = p;
        
        _particles[i].position = CGPointMake(arc4random() % (int)sz.width, arc4random() % (int)sz.height);
        _particles[i].velocity = CGPointMake(((int)(arc4random() % 40) - 20) / 20.0, -0.8 - ((arc4random() % 20) / 10.0));
        _particles[i].size = s;
        _particles[i].baseAlpha = 0.3 + ((arc4random() % 50) / 100.0);
    }
}

#pragma mark - Animation Control

- (void)start {
    if (self.isAnimating) return;
    self.isAnimating = YES;
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    if ([_displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        _displayLink.preferredFramesPerSecond = 30;
    } else if ([_displayLink respondsToSelector:@selector(setFrameInterval:)]) {
        _displayLink.frameInterval = 2;
    }
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stop {
    if (!self.isAnimating) return;
    self.isAnimating = NO;
    [_displayLink invalidate];
    _displayLink = nil;
}

#pragma mark - Display Loop Tick

- (void)tick:(CADisplayLink *)link {
    float pcm[256];
    memset(pcm, 0, sizeof(pcm));
    [[VKAudioPlayer sharedPlayer] getLatestPCMData:pcm count:256];
    BOOL isPlaying = [VKAudioPlayer sharedPlayer].isPlaying;
    
    if (!isPlaying && self.onlyWhenPlaying) {
        self.layer.opacity = 0.0;
        return;
    } else {
        self.layer.opacity = 1.0;
    }
    
    float sum = 0.0f;
    for (int i = 0; i < 256; i++) {
        sum += pcm[i] * pcm[i];
    }
    float rawRMS = sqrtf(sum / 256.0f);
    
    if (isPlaying) {
        _smoothedRMS = _smoothedRMS * 0.82f + rawRMS * 0.18f;
        _phase += 0.07f + _smoothedRMS * 0.15f;
    } else {
        float idleAmp = 0.12f + 0.05f * sinf(_phase * 0.8f);
        _smoothedRMS = _smoothedRMS * 0.90f + idleAmp * 0.10f;
        _phase += 0.04f;
    }
    
    CGSize sz = self.bounds.size;
    if (sz.width < 10 || sz.height < 10) return;
    
    switch (_style) {
        case VKBackgroundVisualizerStyleWaves:
            [self renderWavesWithSize:sz pcm:pcm isPlaying:isPlaying];
            break;
        case VKBackgroundVisualizerStyleEqualizer:
            [self renderEqualizerWithSize:sz pcm:pcm isPlaying:isPlaying];
            break;
        case VKBackgroundVisualizerStyleAurora:
            [self renderAuroraWithSize:sz isPlaying:isPlaying];
            break;
        case VKBackgroundVisualizerStyleParticles:
            [self renderParticlesWithSize:sz isPlaying:isPlaying];
            break;
    }
}

#pragma mark - Renderers

- (void)renderWavesWithSize:(CGSize)sz pcm:(float *)pcm isPlaying:(BOOL)isPlaying {
    CGFloat w = sz.width;
    CGFloat h = sz.height;
    
    CGFloat waveHeights[kNumWaves] = { 0.72 * h, 0.78 * h, 0.83 * h, 0.88 * h };
    CGFloat waveFreqs[kNumWaves]   = { 0.007, 0.010, 0.013, 0.008 };
    CGFloat waveSpeeds[kNumWaves]  = { 1.0, 1.3, -1.1, 0.8 };
    CGFloat ampFactors[kNumWaves]  = { 1.2, 0.9, 1.1, 0.8 };
    
    for (int i = 0; i < kNumWaves; i++) {
        CAShapeLayer *sl = _waveLayers[i];
        if (!sl) continue;
        
        CGFloat baseH = waveHeights[i];
        CGFloat freq = waveFreqs[i];
        CGFloat spd = waveSpeeds[i];
        CGFloat amp = (24.0 + _smoothedRMS * 130.0) * ampFactors[i];
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(0, baseH)];
        
        CGFloat step = 10.0;
        for (CGFloat x = 0; x <= w + step; x += step) {
            CGFloat y = baseH + amp * sinf(x * freq + _phase * spd);
            [path addLineToPoint:CGPointMake(x, y)];
        }
        
        [path addLineToPoint:CGPointMake(w, h)];
        [path addLineToPoint:CGPointMake(0, h)];
        [path closePath];
        
        sl.path = path.CGPath;
    }
}

- (void)renderEqualizerWithSize:(CGSize)sz pcm:(float *)pcm isPlaying:(BOOL)isPlaying {
    CGFloat w = sz.width;
    CGFloat h = sz.height;
    
    CGFloat spacing = 4.0;
    CGFloat barW = (w - spacing * (kNumBars + 1)) / kNumBars;
    CGFloat maxH = h * 0.45;
    
    for (int i = 0; i < kNumBars; i++) {
        CALayer *bar = _barLayers[i];
        CALayer *cap = _capLayers[i];
        if (!bar || !cap) continue;
        
        float val = 0.0f;
        if (isPlaying) {
            int pcmIndex = (i * 10) % 256;
            val = fabsf(pcm[pcmIndex]) * 2.2f;
            val = MIN(val, 1.0f);
        } else {
            val = 0.12f + 0.08f * sinf(_phase * 1.5f + i * 0.4f);
        }
        
        CGFloat targetH = MAX(6.0, val * maxH);
        CGFloat x = spacing + i * (barW + spacing);
        CGFloat y = h - targetH;
        
        bar.frame = CGRectMake(x, y, barW, targetH);
        
        if (targetH >= _barPeakHeights[i]) {
            _barPeakHeights[i] = targetH;
        } else {
            _barPeakHeights[i] = MAX(6.0, _barPeakHeights[i] - 1.8);
        }
        
        CGFloat capY = h - _barPeakHeights[i] - 3.0;
        cap.frame = CGRectMake(x, capY, barW, 2.0);
    }
}

- (void)renderAuroraWithSize:(CGSize)sz isPlaying:(BOOL)isPlaying {
    CGFloat w = sz.width;
    CGFloat h = sz.height;
    CGFloat baseSize = MIN(w, h) * 0.85;
    
    for (int i = 0; i < kNumBlobs; i++) {
        CAGradientLayer *g = _auroraLayers[i];
        if (!g) continue;
        
        CGFloat cx = w * 0.5 + cosf(_phase * 0.6f + i * 2.0f) * (w * 0.32f);
        CGFloat cy = h * 0.5 + sinf(_phase * 0.4f + i * 1.6f) * (h * 0.28f);
        CGFloat pulse = 1.0 + _smoothedRMS * 1.2;
        CGFloat s = baseSize * pulse;
        
        g.frame = CGRectMake(cx - s / 2.0, cy - s / 2.0, s, s);
        g.cornerRadius = s / 2.0;
    }
}

- (void)renderParticlesWithSize:(CGSize)sz isPlaying:(BOOL)isPlaying {
    CGFloat w = sz.width;
    CGFloat h = sz.height;
    CGFloat speedMult = isPlaying ? (1.0 + _smoothedRMS * 3.5) : 1.0;
    
    for (int i = 0; i < kNumParticles; i++) {
        CALayer *p = _particleLayers[i];
        if (!p) continue;
        
        _particles[i].position.x += _particles[i].velocity.x * speedMult;
        _particles[i].position.y += _particles[i].velocity.y * speedMult;
        
        if (_particles[i].position.y < -10) {
            _particles[i].position.y = h + 10;
            _particles[i].position.x = arc4random() % (int)w;
        }
        if (_particles[i].position.x < -10) _particles[i].position.x = w + 10;
        if (_particles[i].position.x > w + 10) _particles[i].position.x = -10;
        
        CGFloat s = _particles[i].size * (1.0 + _smoothedRMS * 0.8);
        p.frame = CGRectMake(_particles[i].position.x - s / 2.0, _particles[i].position.y - s / 2.0, s, s);
        p.opacity = MIN(1.0, _particles[i].baseAlpha + _smoothedRMS * 0.5);
    }
}

@end
