#import <Foundation/Foundation.h>
#import "VKEELVirtualMachine.h"

@interface VKMilkdropPreset : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *author;

// Базовые параметры Milkdrop
@property (nonatomic, assign) CGFloat decay;
@property (nonatomic, assign) CGFloat waveAlpha;
@property (nonatomic, assign) CGFloat waveScale;
@property (nonatomic, assign) CGFloat zoom;
@property (nonatomic, assign) CGFloat rot;
@property (nonatomic, assign) CGFloat warp;
@property (nonatomic, assign) CGFloat dx;
@property (nonatomic, assign) CGFloat dy;
@property (nonatomic, assign) CGFloat cx;
@property (nonatomic, assign) CGFloat cy;

// EEL Скрипты
@property (nonatomic, strong) NSMutableArray<NSString *> *perFrameEquations;
@property (nonatomic, strong) NSMutableArray<NSString *> *perPixelEquations;

+ (instancetype)presetFromString:(NSString *)milkContent name:(NSString *)name;
+ (NSArray<VKMilkdropPreset *> *)defaultPresets;

- (void)executePerFrame:(VKEELVirtualMachine *)vm;
- (void)executePerPixel:(VKEELVirtualMachine *)vm x:(CGFloat)x y:(CGFloat)y rad:(CGFloat)rad ang:(CGFloat)ang;

@end
