#import <UIKit/UIKit.h>
#import "VKPost.h"

@interface VKShareDialogPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) VKPost *post;
@property (nonatomic, copy) void (^onPostShared)(void);

- (instancetype)initWithPost:(VKPost *)post;

@end
