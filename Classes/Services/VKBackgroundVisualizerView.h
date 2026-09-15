#import <UIKit/UIKit.h>
#import "VKBackgroundVisualizerManager.h"

@interface VKBackgroundVisualizerView : UIView

@property (nonatomic, assign) VKBackgroundVisualizerStyle style;
@property (nonatomic, assign) BOOL onlyWhenPlaying;

- (void)start;
- (void)stop;
- (void)refreshStyle;

@end
