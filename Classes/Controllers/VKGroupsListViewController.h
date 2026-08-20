#import <UIKit/UIKit.h>

@interface VKGroupsListViewController : UITableViewController <UISearchBarDelegate>

@property (nonatomic, assign) NSInteger userId;

- (instancetype)initWithUserId:(NSInteger)userId;

@end
