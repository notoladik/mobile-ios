#import "VKMessagesService.h"
#import "VKAPIClient.h"
#import "VKAuthService.h"

@implementation VKMessagesService

+ (instancetype)sharedService {
    static VKMessagesService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)fetchConversationsWithOffset:(NSInteger)offset
                               count:(NSInteger)count
                          completion:(void (^)(NSArray *conversations, NSInteger unreadCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1",
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified,screen_name"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getConversations" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            // Fallback на messages.getDialogs
            NSDictionary *dParams = @{
                @"offset": @(offset),
                @"count": @(count),
                @"extended": @"1",
                @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified,screen_name"
            };
            [[VKAPIClient sharedClient] callMethod:@"messages.getDialogs" parameters:dParams completionHandler:^(id dResp, NSError *dErr) {
                if (dErr) {
                    if (completion) completion(nil, 0, dErr);
                    return;
                }
                
                NSDictionary *dDict = [dResp isKindOfClass:[NSDictionary class]] ? (dResp[@"response"] ?: dResp) : nil;
                if (dDict) {
                    NSArray *items = dDict[@"items"] ?: @[];
                    NSArray *rawProfiles = dDict[@"profiles"] ?: dDict[@"users"] ?: @[];
                    NSArray *rawGroups = dDict[@"groups"] ?: @[];
                    
                    NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
                    for (NSDictionary *p in rawProfiles) {
                        if (p[@"id"] || p[@"uid"]) {
                            NSInteger uid = [p[@"id"] integerValue] ?: [p[@"uid"] integerValue];
                            profiles[@(uid)] = p;
                            profiles[[NSString stringWithFormat:@"%ld", (long)uid]] = p;
                        }
                    }
                    
                    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
                    for (NSDictionary *g in rawGroups) {
                        if (g[@"id"] || g[@"gid"]) {
                            NSInteger gid = [g[@"id"] integerValue] ?: [g[@"gid"] integerValue];
                            groups[@(gid)] = g;
                            groups[[NSString stringWithFormat:@"%ld", (long)gid]] = g;
                        }
                    }
                    
                    NSMutableArray *convs = [NSMutableArray array];
                    for (id item in items) {
                        if ([item isKindOfClass:[NSDictionary class]]) {
                            VKConversation *c = [VKConversation conversationFromDictionary:item profiles:profiles groups:groups];
                            if (c) [convs addObject:c];
                        }
                    }
                    if (completion) completion(convs, 0, nil);
                    return;
                }
                if (completion) completion(@[], 0, nil);
            }];
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSArray *rawItems = resp[@"items"] ?: @[];
            NSArray *rawProfiles = resp[@"profiles"] ?: @[];
            NSArray *rawGroups = resp[@"groups"] ?: @[];
            NSInteger unreadTotal = [resp[@"unread_count"] integerValue];
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in rawProfiles) {
                if (p[@"id"] || p[@"uid"]) {
                    NSInteger uid = [p[@"id"] integerValue] ?: [p[@"uid"] integerValue];
                    profiles[@(uid)] = p;
                    profiles[[NSString stringWithFormat:@"%ld", (long)uid]] = p;
                }
            }
            
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in rawGroups) {
                if (g[@"id"] || g[@"gid"]) {
                    NSInteger gid = [g[@"id"] integerValue] ?: [g[@"gid"] integerValue];
                    groups[@(gid)] = g;
                    groups[[NSString stringWithFormat:@"%ld", (long)gid]] = g;
                }
            }
            
            NSMutableArray *convs = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKConversation *c = [VKConversation conversationFromDictionary:item profiles:profiles groups:groups];
                if (c) [convs addObject:c];
            }
            
            if (completion) completion(convs, unreadTotal, nil);
            return;
        }
        
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)fetchHistoryForPeerId:(NSInteger)peerId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *messages, NSError *error))completion {
    
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1",
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getHistory" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSArray *rawItems = resp[@"items"] ?: @[];
            NSArray *rawProfiles = resp[@"profiles"] ?: @[];
            NSArray *rawGroups = resp[@"groups"] ?: @[];
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in rawProfiles) {
                NSInteger uid = [p[@"id"] integerValue] ?: [p[@"uid"] integerValue];
                if (uid != 0) {
                    profiles[@(uid)] = [VKUser userFromDictionary:p];
                }
            }
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in rawGroups) {
                NSInteger gid = [g[@"id"] integerValue] ?: [g[@"gid"] integerValue];
                if (gid != 0) {
                    groups[@(gid)] = [VKUser groupFromDictionary:g];
                }
            }
            
            NSMutableArray *msgs = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKMessage *m = [VKMessage messageFromDictionary:item];
                if (m) {
                    if (m.fromId > 0) {
                        m.senderUser = profiles[@(m.fromId)];
                    } else if (m.fromId < 0) {
                        m.senderUser = groups[@(-m.fromId)];
                    }
                    [msgs addObject:m];
                }
            }
            if (completion) completion(msgs, nil);
            return;
        }
        
        if (completion) completion(@[], nil);
    }];
}

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion {
    [self sendMessageToPeerId:peerId text:text attachment:nil completion:completion];
}

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 attachment:(NSString *)attachment
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion {
    [self sendMessageToPeerId:peerId text:text attachment:attachment replyTo:0 forwardMsgs:nil completion:completion];
}

- (void)sendMessageToPeerId:(NSInteger)peerId
                       text:(NSString *)text
                 attachment:(NSString *)attachment
                    replyTo:(NSInteger)replyTo
                forwardMsgs:(NSString *)forwardMsgs
                 completion:(void (^)(BOOL success, NSInteger messageId, NSError *error))completion {
    
    NSInteger randomId = arc4random_uniform(1000000000);
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"peer_id": @(peerId),
        @"message": text ?: @"",
        @"random_id": @(randomId)
    }];
    if (attachment.length > 0) {
        params[@"attachment"] = attachment;
    }
    if (replyTo > 0) {
        params[@"reply_to"] = @(replyTo);
    }
    if (forwardMsgs.length > 0) {
        params[@"forward_messages"] = forwardMsgs;
    }
    
    [[VKAPIClient sharedClient] callMethod:@"messages.send" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, 0, error);
            return;
        }
        
        NSInteger msgId = 0;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            msgId = [response[@"response"] integerValue];
        }
        if (completion) completion(YES, msgId, nil);
    }];
}

- (void)uploadMessagePhoto:(UIImage *)image
                    peerId:(NSInteger)peerId
                completion:(void (^)(NSString *attachmentString, NSError *error))completion {
    if (!image) {
        if (completion) completion(nil, [NSError errorWithDomain:@"VKMessagesService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No image"}]);
        return;
    }
    
    NSMutableDictionary *serverParams = [NSMutableDictionary dictionary];
    if (peerId != 0) {
        serverParams[@"peer_id"] = @(peerId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"photos.getMessagesUploadServer" parameters:serverParams completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSString *uploadUrl = resp[@"upload_url"];
        if (!uploadUrl || uploadUrl.length == 0) {
            if (completion) completion(nil, [NSError errorWithDomain:@"VKMessagesService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No upload_url"}]);
            return;
        }
        
        NSData *jpegData = UIImageJPEGRepresentation(image, 0.85);
        [[VKAPIClient sharedClient] uploadFileWithURL:uploadUrl fieldName:@"photo" fileName:@"photo.jpg" mimeType:@"image/jpeg" fileData:jpegData completionHandler:^(id uploadResp, NSError *upErr) {
            if (upErr) {
                if (completion) completion(nil, upErr);
                return;
            }
            
            NSDictionary *uDict = [uploadResp isKindOfClass:[NSDictionary class]] ? uploadResp : nil;
            if (!uDict) {
                if (completion) completion(nil, [NSError errorWithDomain:@"VKMessagesService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid upload response"}]);
                return;
            }
            
            NSMutableDictionary *saveParams = [NSMutableDictionary dictionary];
            if (uDict[@"server"]) saveParams[@"server"] = uDict[@"server"];
            if (uDict[@"photo"]) saveParams[@"photo"] = uDict[@"photo"];
            if (uDict[@"hash"]) saveParams[@"hash"] = uDict[@"hash"];
            
            [[VKAPIClient sharedClient] callMethod:@"photos.saveMessagesPhoto" parameters:saveParams completionHandler:^(id saveResp, NSError *saveErr) {
                if (saveErr) {
                    if (completion) completion(nil, saveErr);
                    return;
                }
                
                NSArray *items = [saveResp isKindOfClass:[NSDictionary class]] ? (saveResp[@"response"] ?: @[]) : @[];
                if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                    NSDictionary *photoItem = items[0];
                    NSInteger photoId = [photoItem[@"id"] integerValue] ?: [photoItem[@"pid"] integerValue];
                    NSInteger photoOwner = [photoItem[@"owner_id"] integerValue];
                    if (photoId != 0) {
                        NSString *attStr = [NSString stringWithFormat:@"photo%ld_%ld", (long)photoOwner, (long)photoId];
                        if (completion) completion(attStr, nil);
                        return;
                    }
                }
                
                if (completion) completion(nil, [NSError errorWithDomain:@"VKMessagesService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save message photo"}]);
            }];
        }];
    }];
}

- (void)pinMessageWithPeerId:(NSInteger)peerId
                   messageId:(NSInteger)messageId
                  completion:(void (^)(BOOL success, NSError *error))completion {
    if (messageId <= 0) {
        if (completion) completion(NO, nil);
        return;
    }
    
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"message_id": @(messageId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.pin" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)unpinMessageWithPeerId:(NSInteger)peerId
                    completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"peer_id": @(peerId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.unpin" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)fetchConversationWithPeerId:(NSInteger)peerId
                         completion:(void (^)(VKConversation *conversation, VKMessage *pinnedMessage, NSError *error))completion {
    NSDictionary *params = @{
        @"peer_ids": [NSString stringWithFormat:@"%ld", (long)peerId],
        @"extended": @"1",
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getConversationsById" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (!resp) {
            if (completion) completion(nil, nil, nil);
            return;
        }
        
        NSArray *items = resp[@"items"] ?: @[];
        NSArray *rawProfiles = resp[@"profiles"] ?: @[];
        NSArray *rawGroups = resp[@"groups"] ?: @[];
        
        NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
        for (NSDictionary *p in rawProfiles) {
            NSInteger uid = [p[@"id"] integerValue] ?: [p[@"uid"] integerValue];
            if (uid != 0) profiles[@(uid)] = p;
        }
        NSMutableDictionary *groups = [NSMutableDictionary dictionary];
        for (NSDictionary *g in rawGroups) {
            NSInteger gid = [g[@"id"] integerValue] ?: [g[@"gid"] integerValue];
            if (gid != 0) groups[@(gid)] = g;
        }
        
        VKConversation *conversation = nil;
        VKMessage *pinned = nil;
        if (items.count > 0) {
            NSDictionary *firstItem = items[0];
            conversation = [VKConversation conversationFromDictionary:firstItem profiles:profiles groups:groups];
            
            NSDictionary *convDict = [firstItem isKindOfClass:[NSDictionary class]] ? (firstItem[@"conversation"] ?: firstItem) : nil;
            NSDictionary *chatSettings = convDict[@"chat_settings"];
            NSDictionary *pinnedDict = [chatSettings isKindOfClass:[NSDictionary class]] ? chatSettings[@"pinned_message"] : convDict[@"pinned_message"];
            if ([pinnedDict isKindOfClass:[NSDictionary class]]) {
                pinned = [VKMessage messageFromDictionary:pinnedDict];
                if (pinned && pinned.fromId > 0 && profiles[@(pinned.fromId)]) {
                    pinned.senderUser = [VKUser userFromDictionary:profiles[@(pinned.fromId)]];
                }
            }
        }
        
        if (completion) completion(conversation, pinned, nil);
    }];
}

- (void)markAsReadForPeerId:(NSInteger)peerId
                  messageId:(NSInteger)messageId
                 completion:(void (^)(BOOL success))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"peer_id": @(peerId)
    }];
    if (messageId > 0) {
        params[@"start_message_id"] = @(messageId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"messages.markAsRead" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) completion(error == nil);
    }];
}

- (void)leaveChatWithChatId:(NSInteger)chatId
                 completion:(void (^)(BOOL success, NSError *error))completion {
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    [self removeChatUserWithUserId:myId chatId:chatId completion:completion];
}

- (void)returnToChatWithChatId:(NSInteger)chatId
                    completion:(void (^)(BOOL success, NSError *error))completion {
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    [self addChatUserWithUserId:myId chatId:chatId completion:completion];
}

- (void)addChatUserWithUserId:(NSInteger)userId
                       chatId:(NSInteger)chatId
                   completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"chat_id": @(chatId),
        @"user_id": @(userId),
        @"peer_id": @(2000000000 + chatId)
    };
    [[VKAPIClient sharedClient] callMethod:@"messages.addChatUser" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)removeChatUserWithUserId:(NSInteger)userId
                          chatId:(NSInteger)chatId
                      completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"chat_id": @(chatId),
        @"user_id": @(userId),
        @"peer_id": @(2000000000 + chatId)
    };
    [[VKAPIClient sharedClient] callMethod:@"messages.removeChatUser" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)editMessageWithPeerId:(NSInteger)peerId
                    messageId:(NSInteger)messageId
                         text:(NSString *)text
                   completion:(void (^)(BOOL success, NSError *error))completion {
    if (messageId <= 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"VKMessagesService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid messageId"}]);
        return;
    }
    
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"message_id": @(messageId),
        @"message": text ?: @""
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.edit" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)deleteMessagesWithIds:(NSArray<NSNumber *> *)messageIds
                 deleteForAll:(BOOL)deleteForAll
                       peerId:(NSInteger)peerId
                   completion:(void (^)(BOOL success, NSError *error))completion {
    if (messageIds.count == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    
    NSMutableArray *strIds = [NSMutableArray array];
    for (NSNumber *mid in messageIds) {
        [strIds addObject:[mid description]];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"message_ids": [strIds componentsJoinedByString:@","],
        @"delete_for_all": deleteForAll ? @"1" : @"0"
    }];
    if (peerId != 0) {
        params[@"peer_id"] = @(peerId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"messages.delete" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)fetchMessageViewersWithPeerId:(NSInteger)peerId
                            messageId:(NSInteger)messageId
                           completion:(void (^)(NSArray<VKUser *> *viewers, NSError *error))completion {
    if (messageId <= 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"message_id": @(messageId),
        @"extended": @"1",
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getMessageViewers" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSDictionary *dict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSArray *rawProfiles = dict[@"profiles"];
        NSMutableArray *viewers = [NSMutableArray array];
        if ([rawProfiles isKindOfClass:[NSArray class]]) {
            for (NSDictionary *p in rawProfiles) {
                VKUser *u = [VKUser userFromDictionary:p];
                if (u) [viewers addObject:u];
            }
        }
        if (completion) completion(viewers, nil);
    }];
}

- (void)setSilenceModeForPeerId:(NSInteger)peerId
                           time:(NSInteger)time
                     completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"time": @(time),
        @"sound": (time == 0 ? @1 : @0)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"account.setSilenceMode" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)setMemberRoleWithPeerId:(NSInteger)peerId
                         userId:(NSInteger)userId
                           role:(NSString *)role
                     completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"user_id": @(userId),
        @"role": role ?: @"member"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.setMemberRole" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

@end
