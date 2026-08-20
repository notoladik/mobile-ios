#import <UIKit/UIKit.h>
#import "VKMessage.h"
#import "VKUser.h"

@interface VKChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, strong) VKUser *peerUser;
@property (nonatomic, copy) NSString *chatTitle;

- (instancetype)initWithPeerId:(NSInteger)peerId peerUser:(VKUser *)peerUser title:(NSString *)title;

@end
