#import <UIKit/UIKit.h>
#import "VKPost.h"
#import "VKUser.h"

@interface VKShareGroupPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) VKPost *post;
@property (nonatomic, strong) NSArray<VKUser *> *groups;
@property (nonatomic, copy) void (^onPostShared)(void);

- (instancetype)initWithPost:(VKPost *)post groups:(NSArray<VKUser *> *)groups;

@end
