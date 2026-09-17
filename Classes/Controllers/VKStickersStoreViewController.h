#import <UIKit/UIKit.h>

@interface VKStickersStoreViewController : UIViewController

@property (nonatomic, copy) void (^onPacksUpdated)(void);

@end
