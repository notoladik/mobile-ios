#import "VKMessagesService.h"
#import "VKAPIClient.h"

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
            NSMutableArray *msgs = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKMessage *m = [VKMessage messageFromDictionary:item];
                if (m) [msgs addObject:m];
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
    
    NSInteger randomId = arc4random_uniform(1000000000);
    NSDictionary *params = @{
        @"peer_id": @(peerId),
        @"message": text ?: @"",
        @"random_id": @(randomId)
    };
    
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

@end
