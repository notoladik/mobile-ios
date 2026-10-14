#import <UIKit/UIKit.h>

@interface VKKateMainViewController : UIViewController <UIScrollViewDelegate, UIActionSheetDelegate>

@property (nonatomic, assign) NSInteger currentTabIndex;

- (void)switchToTab:(NSInteger)index animated:(BOOL)animated;
- (void)updateUnreadCounters;

@end
