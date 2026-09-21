#import <UIKit/UIKit.h>
#import "VKPost.h"
#import "VKMessage.h"

@interface VKShareDialogPickerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) VKPost *post;
@property (nonatomic, strong) NSArray<VKMessage *> *forwardMessages;
@property (nonatomic, copy) void (^onPostShared)(void);

- (instancetype)initWithPost:(VKPost *)post;
- (instancetype)initWithForwardMessages:(NSArray<VKMessage *> *)forwardMessages;

@end
