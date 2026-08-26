#import <UIKit/UIKit.h>
#import "VKAudioPlayer.h"

@interface VKMiniPlayerBar : UIView

+ (instancetype)sharedBar;

@property (nonatomic, copy) void (^onTapBar)(void);

- (void)showInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset;
- (void)hideAnimated:(BOOL)animated;
- (void)updateLayoutWithBottomOffset:(CGFloat)bottomOffset;

@end
