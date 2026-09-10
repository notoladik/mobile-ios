#import <UIKit/UIKit.h>
#import "VKUser.h"

@interface VKChatMembersViewController : UITableViewController

@property (nonatomic, assign) NSInteger chatId;
@property (nonatomic, assign) NSInteger adminId;

- (instancetype)initWithChatId:(NSInteger)chatId adminId:(NSInteger)adminId;

@end
