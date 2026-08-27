#import <UIKit/UIKit.h>
#import "VKAudioPlayer.h"

typedef NS_ENUM(NSInteger, VKMiniPlayerMode) {
    VKMiniPlayerModeExpandedBar,
    VKMiniPlayerModeFloatingBubble,
    VKMiniPlayerModeHidden
};

@interface VKMiniPlayerBar : UIView

+ (instancetype)sharedBar;

@property (nonatomic, assign, readonly) VKMiniPlayerMode currentMode;
@property (nonatomic, assign, readonly) BOOL isCollapsed;
@property (nonatomic, assign, readonly) BOOL isDismissed;
@property (nonatomic, copy) void (^onTapBar)(void);

- (void)showInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset;
- (void)hideAnimated:(BOOL)animated;
- (void)updateLayoutWithBottomOffset:(CGFloat)bottomOffset;

- (void)collapseToFloatingBubbleAnimated:(BOOL)animated;
- (void)expandToBarAnimated:(BOOL)animated;
- (void)hideFullyAnimated:(BOOL)animated;
- (void)restoreIfPlayingInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset;

@end
