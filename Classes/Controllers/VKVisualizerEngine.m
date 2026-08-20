#import "VKVisualizerEngine.h"

@implementation VKVisualizerEngine

+ (instancetype)sharedEngine {
    static VKVisualizerEngine *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[VKVisualizerEngine alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _presets = [VKMilkdropPreset defaultPresets];
        _currentPresetIndex = 0;
        _virtualMachine = [[VKEELVirtualMachine alloc] init];
        _isPlaying = YES;
        _time = 0.0;
    }
    return self;
}

- (void)nextPreset {
    self.currentPresetIndex = (self.currentPresetIndex + 1) % self.presets.count;
}

- (void)previousPreset {
    self.currentPresetIndex = (self.currentPresetIndex - 1 + self.presets.count) % self.presets.count;
}

- (NSString *)currentPresetTitle {
    if (self.presets.count == 0) return @"MilkDrop";
    return self.presets[self.currentPresetIndex].name;
}

#pragma mark - Render Loop (EEL VM + Mesh Warp & Audio Waveform)

- (void)renderFrameInContext:(CGContextRef)ctx size:(CGSize)size {
    if (!ctx || self.presets.count == 0) return;
    
    CGFloat w = size.width;
    CGFloat h = size.height;
    CGFloat cx = w / 2.0;
    CGFloat cy = h / 2.0;
    
    if (self.isPlaying) {
        self.time += 0.03;
    } else {
        self.time += 0.005;
    }
    
    CGFloat bass = self.isPlaying ? (0.8 + 0.4 * sin(self.time * 3.5) * cos(self.time * 2.1)) : 0.2;
    CGFloat mid = self.isPlaying ? (0.7 + 0.3 * cos(self.time * 2.8)) : 0.2;
    CGFloat treb = self.isPlaying ? (0.6 + 0.4 * sin(self.time * 4.5)) : 0.2;
    
    // Передаем системные переменные в виртуальную машину EEL
    [self.virtualMachine setVariable:@"time" value:self.time];
    [self.virtualMachine setVariable:@"bass" value:bass];
    [self.virtualMachine setVariable:@"mid" value:mid];
    [self.virtualMachine setVariable:@"treb" value:treb];
    
    // 1. Исполняем уравнения Per-Frame текущего пресета
    VKMilkdropPreset *currentPreset = self.presets[self.currentPresetIndex];
    [currentPreset executePerFrame:self.virtualMachine];
    
    CGFloat rot = [self.virtualMachine getVariable:@"rot"];
    CGFloat zoom = [self.virtualMachine getVariable:@"zoom"];
    CGFloat warp = [self.virtualMachine getVariable:@"warp"];
    CGFloat decay = [self.virtualMachine getVariable:@"decay"];
    
    // Очистка фона
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:10.0/255.0 green:12.0/255.0 blue:18.0/255.0 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
    
    // 2. Рендеринг деформированной сетки Milkdrop Warp Mesh (20x20)
    NSInteger gridX = 14;
    NSInteger gridY = 14;
    CGFloat stepX = w / (CGFloat)gridX;
    CGFloat stepY = h / (CGFloat)gridY;
    
    CGContextSetLineWidth(ctx, 1.5);
    
    for (NSInteger y = 0; y <= gridY; y++) {
        CGContextBeginPath(ctx);
        for (NSInteger x = 0; x <= gridX; x++) {
            CGFloat px = x * stepX;
            CGFloat py = y * stepY;
            
            CGFloat normX = (px - cx) / cx;
            CGFloat normY = (py - cy) / cy;
            CGFloat rad = sqrt(normX * normX + normY * normY);
            CGFloat ang = atan2(normY, normX);
            
            // Исполняем уравнения Per-Pixel / Per-Vertex для каждой точки
            [currentPreset executePerPixel:self.virtualMachine x:normX y:normY rad:rad ang:ang];
            
            CGFloat pointRot = [self.virtualMachine getVariable:@"rot"];
            CGFloat pointZoom = [self.virtualMachine getVariable:@"zoom"];
            
            CGFloat warpedAng = ang + pointRot + sin(rad * 6.0 + self.time * 2.0) * warp;
            CGFloat warpedRad = rad * pointZoom;
            
            CGFloat finalX = cx + cos(warpedAng) * warpedRad * cx;
            CGFloat finalY = cy + sin(warpedAng) * warpedRad * cy;
            
            if (x == 0) CGContextMoveToPoint(ctx, finalX, finalY);
            else CGContextAddLineToPoint(ctx, finalX, finalY);
        }
        
        CGFloat hue = fmod((self.time * 0.08) + ((CGFloat)y / (CGFloat)gridY) * 0.6, 1.0);
        UIColor *lineCol = [UIColor colorWithHue:hue saturation:0.9 brightness:0.9 alpha:0.65 * decay];
        CGContextSetStrokeColorWithColor(ctx, lineCol.CGColor);
        CGContextStrokePath(ctx);
    }
    
    // 3. Рендеринг звуковой волны (Milkdrop Waveform)
    NSInteger wavePoints = 120;
    CGContextSetLineWidth(ctx, 3.0);
    CGFloat waveHue = fmod(self.time * 0.15, 1.0);
    UIColor *waveColor = [UIColor colorWithHue:waveHue saturation:0.85 brightness:1.0 alpha:0.9];
    CGContextSetStrokeColorWithColor(ctx, waveColor.CGColor);
    
    CGContextBeginPath(ctx);
    for (NSInteger i = 0; i <= wavePoints; i++) {
        CGFloat norm = (CGFloat)i / (CGFloat)wavePoints;
        CGFloat x = norm * w;
        CGFloat amp = (self.isPlaying ? bass : 0.05) * 32.0;
        CGFloat y = cy + sin(norm * 14.0 + self.time * 4.0) * cos(norm * 8.0 - self.time * 2.0) * amp;
        
        if (i == 0) CGContextMoveToPoint(ctx, x, y);
        else CGContextAddLineToPoint(ctx, x, y);
    }
    CGContextStrokePath(ctx);
}

@end
