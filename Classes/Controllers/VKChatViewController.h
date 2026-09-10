#import <UIKit/UIKit.h>
#import "VKMessage.h"
#import "VKUser.h"

@interface VKChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>

@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, strong) VKUser *peerUser;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *chatPhotoURL;
@property (nonatomic, assign) NSInteger membersCount;
@property (nonatomic, assign) NSInteger adminId;

- (instancetype)initWithPeerId:(NSInteger)peerId peerUser:(VKUser *)peerUser title:(NSString *)title;

@end
