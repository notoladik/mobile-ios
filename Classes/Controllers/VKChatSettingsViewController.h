#import <UIKit/UIKit.h>
#import "VKUser.h"

@interface VKChatSettingsViewController : UITableViewController

@property (nonatomic, assign) NSInteger chatId;
@property (nonatomic, assign) NSInteger adminId;
@property (nonatomic, copy) NSString *chatTitle;
@property (nonatomic, copy) NSString *chatPhotoURL;
@property (nonatomic, assign) NSInteger membersCount;
@property (nonatomic, assign) BOOL isMember;

@property (nonatomic, copy) void (^onChatUpdated)(NSString *newTitle, NSString *newPhoto, BOOL isMember);

- (instancetype)initWithChatId:(NSInteger)chatId
                       adminId:(NSInteger)adminId
                         title:(NSString *)title
                      photoURL:(NSString *)photoURL
                  membersCount:(NSInteger)membersCount
                      isMember:(BOOL)isMember;

@end
