#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
#import "VKMilkdropPreset.h"
#import "VKEELVirtualMachine.h"

@interface VKVisualizerEngine : NSObject

@property (nonatomic, strong) NSArray<VKMilkdropPreset *> *presets;
@property (nonatomic, assign) NSInteger currentPresetIndex;
@property (nonatomic, strong) VKEELVirtualMachine *virtualMachine;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) CGFloat time;

+ (instancetype)sharedEngine;

- (void)nextPreset;
- (void)previousPreset;
- (NSString *)currentPresetTitle;

// Рендеринг кадра через EEL Virtual Machine и уравнения пресета
- (void)renderFrameInContext:(CGContextRef)ctx size:(CGSize)size;

@end
