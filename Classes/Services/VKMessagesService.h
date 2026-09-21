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

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 attachment:(NSString *)attachment
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion;

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 attachment:(NSString *)attachment
                    replyTo:(NSInteger)replyTo
                forwardMsgs:(NSString *)forwardMsgs
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion;

- (void)uploadMessagePhoto:(UIImage *)image
                    peerId:(NSInteger)peerId
                completion:(void (^)(NSString *attachmentString, NSError *error))completion;

- (void)pinMessageWithPeerId:(NSInteger)peerId
                   messageId:(NSInteger)messageId
                  completion:(void (^)(BOOL success, NSError *error))completion;

- (void)unpinMessageWithPeerId:(NSInteger)peerId
                    completion:(void (^)(BOOL success, NSError *error))completion;

- (void)fetchConversationWithPeerId:(NSInteger)peerId
                         completion:(void (^)(VKConversation *conversation, VKMessage *pinnedMessage, NSError *error))completion;

- (void)markAsReadForPeerId:(NSInteger)peerId
                  messageId:(NSInteger)messageId
                 completion:(void (^)(BOOL success))completion;

- (void)leaveChatWithChatId:(NSInteger)chatId
                 completion:(void (^)(BOOL success, NSError *error))completion;

- (void)returnToChatWithChatId:(NSInteger)chatId
                    completion:(void (^)(BOOL success, NSError *error))completion;

- (void)addChatUserWithUserId:(NSInteger)userId
                       chatId:(NSInteger)chatId
                   completion:(void (^)(BOOL success, NSError *error))completion;

- (void)removeChatUserWithUserId:(NSInteger)userId
                          chatId:(NSInteger)chatId
                      completion:(void (^)(BOOL success, NSError *error))completion;

- (void)editMessageWithPeerId:(NSInteger)peerId
                    messageId:(NSInteger)messageId
                         text:(NSString *)text
                   completion:(void (^)(BOOL success, NSError *error))completion;

- (void)deleteMessagesWithIds:(NSArray<NSNumber *> *)messageIds
                 deleteForAll:(BOOL)deleteForAll
                       peerId:(NSInteger)peerId
                   completion:(void (^)(BOOL success, NSError *error))completion;

- (void)fetchMessageViewersWithPeerId:(NSInteger)peerId
                            messageId:(NSInteger)messageId
                           completion:(void (^)(NSArray<VKUser *> *viewers, NSError *error))completion;

- (void)setSilenceModeForPeerId:(NSInteger)peerId
                           time:(NSInteger)time
                     completion:(void (^)(BOOL success, NSError *error))completion;

- (void)setMemberRoleWithPeerId:(NSInteger)peerId
                         userId:(NSInteger)userId
                           role:(NSString *)role
                     completion:(void (^)(BOOL success, NSError *error))completion;

- (void)getHistoryAttachmentsForPeerId:(NSInteger)peerId
                             mediaType:(NSString *)mediaType
                             startFrom:(NSString *)startFrom
                                 count:(NSInteger)count
                            completion:(void (^)(NSArray *items, NSString *nextFrom, NSDictionary<NSNumber *, VKUser *> *profiles, NSError *error))completion;

- (void)sendSticker:(NSInteger)stickerId
             peerId:(NSInteger)peerId
         completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion;

- (void)setTypingForPeerId:(NSInteger)peerId
                completion:(void (^)(BOOL success, NSError *error))completion;

- (void)markAsReadForPeerId:(NSInteger)peerId
             startMessageId:(NSInteger)startMessageId
                 completion:(void (^)(BOOL success))completion;

@end
