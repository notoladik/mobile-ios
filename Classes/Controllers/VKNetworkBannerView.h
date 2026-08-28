#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VKNetworkBannerState) {
    VKNetworkBannerStateHidden,
    VKNetworkBannerStateWaitingForNetwork,
    VKNetworkBannerStateConnecting,
    VKNetworkBannerStateServerUnavailable,
    VKNetworkBannerStateConnected
};

@interface VKNetworkBannerView : UIView

+ (instancetype)sharedBanner;

@property (nonatomic, assign, readonly) VKNetworkBannerState currentState;
@property (nonatomic, copy) void (^onRetryTapped)(void);

- (void)attachToWindow:(UIWindow *)window;
- (void)showState:(VKNetworkBannerState)state animated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;

@end
