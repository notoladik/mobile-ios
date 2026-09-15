#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VKBackgroundVisualizerStyle) {
    VKBackgroundVisualizerStyleWaves = 0,       // Неоновые звуковые волны
    VKBackgroundVisualizerStyleEqualizer = 1,   // Ретро-эквалайзер Winamp
    VKBackgroundVisualizerStyleAurora = 2,      // Северное сияние (Аура)
    VKBackgroundVisualizerStyleParticles = 3    // Звёздная пыль (Космос)
};

typedef NS_ENUM(NSInteger, VKBackgroundVisualizerLayerMode) {
    VKBackgroundVisualizerLayerModeOverlay = 0,     // Атмосферное наложение (поверх)
    VKBackgroundVisualizerLayerModeUnderlay = 1     // Подложка под контент (на заднем плане)
};

@class VKBackgroundVisualizerView;

@interface VKBackgroundVisualizerManager : NSObject

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) VKBackgroundVisualizerStyle style;
@property (nonatomic, assign) VKBackgroundVisualizerLayerMode layerMode;
@property (nonatomic, assign) CGFloat opacity; // 0.10 ... 1.0
@property (nonatomic, assign) BOOL onlyWhenPlaying;

@property (nonatomic, strong, readonly) VKBackgroundVisualizerView *visualizerView;

+ (instancetype)sharedManager;

- (void)setupWithWindow:(UIWindow *)window;
- (void)updateVisualizerState;

- (NSString *)titleForStyle:(VKBackgroundVisualizerStyle)style;
- (NSString *)titleForLayerMode:(VKBackgroundVisualizerLayerMode)mode;
- (NSString *)titleForOpacity:(CGFloat)opacity;

@end
