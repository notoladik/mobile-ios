#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VKBackgroundVisualizerStyle) {
    VKBackgroundVisualizerStyleAVS = 0,         // Winamp AVS (Nullsoft 2D)
    VKBackgroundVisualizerStyleMilkdrop = 1,    // Milkdrop 2 (projectM 3D)
    VKBackgroundVisualizerStyleWaves = 2,       // Неоновые звуковые волны (2D)
    VKBackgroundVisualizerStyleEqualizer = 3,   // Ретро-эквалайзер Winamp (2D)
    VKBackgroundVisualizerStyleAurora = 4,      // Северное сияние (2D)
    VKBackgroundVisualizerStyleParticles = 5    // Звёздная пыль (2D)
};

typedef NS_ENUM(NSInteger, VKBackgroundVisualizerLayerMode) {
    VKBackgroundVisualizerLayerModeOverlay = 0,     // Атмосферное наложение (поверх)
    VKBackgroundVisualizerLayerModeUnderlay = 1     // Подложка под контент (на заднем плане)
};

@interface VKBackgroundVisualizerManager : NSObject

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) VKBackgroundVisualizerStyle style;
@property (nonatomic, assign) VKBackgroundVisualizerLayerMode layerMode;
@property (nonatomic, assign) CGFloat opacity; // 0.10 ... 1.0
@property (nonatomic, assign) BOOL onlyWhenPlaying;

@property (nonatomic, strong, readonly) UIView *activeVisualizerView;

+ (instancetype)sharedManager;

- (void)setupWithWindow:(UIWindow *)window;
- (void)updateVisualizerState;

- (NSString *)titleForStyle:(VKBackgroundVisualizerStyle)style;
- (NSString *)titleForLayerMode:(VKBackgroundVisualizerLayerMode)mode;
- (NSString *)titleForOpacity:(CGFloat)opacity;

@end
