#import <UIKit/UIKit.h>
@interface VKChatAppearanceViewController : UITableViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
- (instancetype)initWithPeerId:(NSInteger)peerId;
@end
