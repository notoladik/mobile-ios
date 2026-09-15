#import <UIKit/UIKit.h>
#import "VKUser.h"

@interface VKMessageViewersViewController : UITableViewController

@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, assign) NSInteger messageId;

- (instancetype)initWithPeerId:(NSInteger)peerId messageId:(NSInteger)messageId;
- (instancetype)initWithViewers:(NSArray<VKUser *> *)viewers;

@end
