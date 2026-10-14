#import <UIKit/UIKit.h>
@interface VKChatBackgroundView : UIView
@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, assign, getter=isActive) BOOL active;
@property (nonatomic, assign, readonly) BOOL hasCustomBackground;
- (void)refreshAppearance;
@end
