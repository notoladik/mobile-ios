#import <UIKit/UIKit.h>

@interface VKOfflinePlaceholderView : UIView

@property (nonatomic, copy) NSString *iconText;
@property (nonatomic, copy) NSString *titleText;
@property (nonatomic, copy) NSString *messageText;
@property (nonatomic, copy) NSString *buttonTitle;
@property (nonatomic, copy) void (^onRetryTapped)(void);

+ (instancetype)offlinePlaceholderWithFrame:(CGRect)frame onRetry:(void(^)(void))onRetry;
+ (instancetype)serverErrorPlaceholderWithFrame:(CGRect)frame onRetry:(void(^)(void))onRetry;

- (void)setLoading:(BOOL)loading;

@end
