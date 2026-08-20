#import <UIKit/UIKit.h>

@interface VKFriendsListViewController : UITableViewController <UISearchBarDelegate>

@property (nonatomic, assign) NSInteger userId;

- (instancetype)initWithUserId:(NSInteger)userId;

@end
