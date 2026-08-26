#import <UIKit/UIKit.h>
#import "VKPost.h"

@interface VKPostDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) VKPost *post;
@property (nonatomic, assign) BOOL focusCommentInputOnAppear;

- (instancetype)initWithPost:(VKPost *)post;

@end
