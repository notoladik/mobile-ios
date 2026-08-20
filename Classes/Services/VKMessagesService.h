#import <Foundation/Foundation.h>
#import "VKMessage.h"

@interface VKMessagesService : NSObject

+ (instancetype)sharedService;

- (void)fetchConversationsWithOffset:(NSInteger)offset
                               count:(NSInteger)count
                          completion:(void (^)(NSArray *conversations, NSInteger unreadCount, NSError *error))completion;

- (void)fetchHistoryForPeerId:(NSInteger)peerId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *messages, NSError *error))completion;

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion;

- (void)markAsReadForPeerId:(NSInteger)peerId
                  messageId:(NSInteger)messageId
                 completion:(void (^)(BOOL success))completion;

@end
