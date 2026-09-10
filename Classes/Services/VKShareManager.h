#import <UIKit/UIKit.h>
#import "VKPost.h"

@interface VKShareManager : NSObject <UIActionSheetDelegate, UIAlertViewDelegate>

+ (instancetype)sharedManager;

- (void)presentShareSheetForPost:(VKPost *)post
              fromViewController:(UIViewController *)viewController
                      completion:(void (^)(void))completion;

@end
