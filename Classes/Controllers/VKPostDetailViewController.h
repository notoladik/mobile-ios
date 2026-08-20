#import <UIKit/UIKit.h>
#import "VKPost.h"

@interface VKPostDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, strong) VKPost *post;

- (instancetype)initWithPost:(VKPost *)post;

@end
