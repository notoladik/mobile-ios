#import <Foundation/Foundation.h>
#import "VKNotification.h"

@interface VKNotificationsService : NSObject

+ (instancetype)sharedService;

- (void)fetchNotificationsWithArchived:(BOOL)archived
                                offset:(NSInteger)offset
                                 count:(NSInteger)count
                            completion:(void (^)(NSArray *notifications, NSError *error))completion;

- (void)markAsReadWithCompletion:(void (^)(BOOL success))completion;

@end
