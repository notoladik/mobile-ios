#import <Foundation/Foundation.h>
#import "VKMessage.h"

extern NSString *const VKLongPollDidReceiveNewMessageNotification;
extern NSString *const VKLongPollDidReadMessagesNotification;
extern NSString *const VKLongPollUserTypingNotification;
extern NSString *const VKLongPollUnreadCountDidChangeNotification;

@interface VKLongPollService : NSObject

+ (instancetype)sharedService;

@property (nonatomic, assign, readonly) BOOL isRunning;
@property (nonatomic, copy, readonly) NSString *server;
@property (nonatomic, assign, readonly) NSInteger currentTS;

- (void)start;
- (void)stop;
- (void)restart;

@end
