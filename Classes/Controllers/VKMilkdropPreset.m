#import "VKMilkdropPreset.h"

@implementation VKMilkdropPreset

- (instancetype)init {
    self = [super init];
    if (self) {
        _decay = 0.97;
        _waveAlpha = 0.8;
        _waveScale = 1.0;
        _zoom = 1.0;
        _rot = 0.0;
        _warp = 0.0;
        _dx = 0.0;
        _dy = 0.0;
        _cx = 0.5;
        _cy = 0.5;
        _perFrameEquations = [NSMutableArray array];
        _perPixelEquations = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)presetFromString:(NSString *)milkContent name:(NSString *)name {
    VKMilkdropPreset *p = [[VKMilkdropPreset alloc] init];
    p.name = name ?: @"MilkDrop Preset";
    
    NSArray *lines = [milkContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0 || [trimmed hasPrefix:@"#"] || [trimmed hasPrefix:@"//"]) continue;
        
        NSRange eq = [trimmed rangeOfString:@"="];
        if (eq.location == NSNotFound) continue;
        
        NSString *key = [[trimmed substringToIndex:eq.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *val = [[trimmed substringFromIndex:eq.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if ([key isEqualToString:@"fDecay"]) p.decay = [val doubleValue];
        else if ([key isEqualToString:@"fZoom"]) p.zoom = [val doubleValue];
        else if ([key isEqualToString:@"fRot"]) p.rot = [val doubleValue];
        else if ([key isEqualToString:@"fWarp"]) p.warp = [val doubleValue];
        else if ([key isEqualToString:@"fWaveAlpha"]) p.waveAlpha = [val doubleValue];
        else if ([key hasPrefix:@"per_frame_"]) [p.perFrameEquations addObject:val];
        else if ([key hasPrefix:@"per_pixel_"]) [p.perPixelEquations addObject:val];
    }
    return p;
}

+ (NSArray<VKMilkdropPreset *> *)defaultPresets {
    NSMutableArray *list = [NSMutableArray array];
    
    // 1. Geiss - Cosmic Vortex
    VKMilkdropPreset *p1 = [[VKMilkdropPreset alloc] init];
    p1.name = @"Geiss - Cosmic Feedback Vortex";
    p1.author = @"Ryan Geiss";
    p1.decay = 0.97;
    p1.zoom = 0.985;
    [p1.perFrameEquations addObject:@"rot = rot + 0.02 * sin(time * 1.5);"];
    [p1.perFrameEquations addObject:@"zoom = 0.98 + 0.015 * sin(time * 2.2);"];
    [p1.perFrameEquations addObject:@"warp = 0.04 * bass;"];
    [p1.perPixelEquations addObject:@"rot = rot + sin(rad * 6.0 + time * 2.0) * 0.02;"];
    [list addObject:p1];
    
    // 2. Rovastar - Hyperspace Tunnel
    VKMilkdropPreset *p2 = [[VKMilkdropPreset alloc] init];
    p2.name = @"Rovastar - Hyperspace Wormhole";
    p2.author = @"Rovastar";
    p2.decay = 0.955;
    p2.zoom = 0.96;
    [p2.perFrameEquations addObject:@"rot = rot + 0.035 * cos(time * 1.8);"];
    [p2.perFrameEquations addObject:@"warp = 0.06 * treb;"];
    [p2.perPixelEquations addObject:@"zoom = 0.95 + 0.05 * sin(ang * 4.0 + time * 3.0);"];
    [list addObject:p2];
    
    // 3. Unchained - Acid Mandala
    VKMilkdropPreset *p3 = [[VKMilkdropPreset alloc] init];
    p3.name = @"Unchained - Acid Mandala Bloom";
    p3.author = @"Unchained";
    p3.decay = 0.975;
    p3.zoom = 1.01;
    [p3.perFrameEquations addObject:@"rot = 0.03 * sin(time * 2.5);"];
    [p3.perFrameEquations addObject:@"warp = 0.08 * mid;"];
    [p3.perPixelEquations addObject:@"rot = rot + cos(rad * 8.0 - time * 2.0) * 0.03;"];
    [list addObject:p3];
    
    // 4. Zylot - Neon Pulse Matrix
    VKMilkdropPreset *p4 = [[VKMilkdropPreset alloc] init];
    p4.name = @"Zylot - Neon Pulse Matrix";
    p4.author = @"Zylot";
    p4.decay = 0.965;
    p4.zoom = 0.99;
    [p4.perFrameEquations addObject:@"rot = 0.015;"];
    [p4.perFrameEquations addObject:@"warp = 0.05 * bass;"];
    [p4.perPixelEquations addObject:@"zoom = 0.98 + 0.03 * cos(rad * 10.0 + time * 4.0);"];
    [list addObject:p4];
    
    return list;
}

- (void)executePerFrame:(VKEELVirtualMachine *)vm {
    // Устанавливаем базовые параметры
    [vm setVariable:@"decay" value:self.decay];
    [vm setVariable:@"zoom" value:self.zoom];
    [vm setVariable:@"rot" value:self.rot];
    [vm setVariable:@"warp" value:self.warp];
    [vm setVariable:@"dx" value:self.dx];
    [vm setVariable:@"dy" value:self.dy];
    [vm setVariable:@"cx" value:self.cx];
    [vm setVariable:@"cy" value:self.cy];
    
    // Исполняем уравнения Per-Frame
    for (NSString *eq in self.perFrameEquations) {
        [vm evaluateScript:eq];
    }
}

- (void)executePerPixel:(VKEELVirtualMachine *)vm x:(CGFloat)x y:(CGFloat)y rad:(CGFloat)rad ang:(CGFloat)ang {
    [vm setVariable:@"x" value:x];
    [vm setVariable:@"y" value:y];
    [vm setVariable:@"rad" value:rad];
    [vm setVariable:@"ang" value:ang];
    
    for (NSString *eq in self.perPixelEquations) {
        [vm evaluateScript:eq];
    }
}

@end
