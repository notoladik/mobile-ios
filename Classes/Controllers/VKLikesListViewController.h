#import <UIKit/UIKit.h>

@interface VKLikesListViewController : UITableViewController

// type: @"post" или @"comment"
- (instancetype)initWithType:(NSString *)type
                     ownerId:(NSInteger)ownerId
                      itemId:(NSInteger)itemId
               initialFilter:(NSInteger)initialFilter; // 0 = лайки, 1 = репосты

@end
