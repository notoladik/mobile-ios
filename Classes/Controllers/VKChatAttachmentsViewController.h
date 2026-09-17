#import <UIKit/UIKit.h>

@interface VKChatAttachmentsViewController : UIViewController

@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, copy) NSString *chatTitle;

- (instancetype)initWithPeerId:(NSInteger)peerId chatTitle:(NSString *)chatTitle;

@end
