#import <UIKit/UIKit.h>
#import "VKUser.h"

@interface VKProfileViewController : UITableViewController

@property (nonatomic, strong) VKUser *user;
@property (nonatomic, assign) BOOL isFullProfileMode;

- (instancetype)initWithUser:(VKUser *)user;
- (void)refreshProfile;

@end
