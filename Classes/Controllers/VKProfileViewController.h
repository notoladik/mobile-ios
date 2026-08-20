#import <UIKit/UIKit.h>
#import "VKUser.h"

@interface VKProfileViewController : UITableViewController

@property (nonatomic, strong) VKUser *user;

- (instancetype)initWithUser:(VKUser *)user;

@end
