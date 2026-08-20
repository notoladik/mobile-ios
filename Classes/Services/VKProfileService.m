#import "VKProfileService.h"
#import "VKAPIClient.h"

@implementation VKProfileService

+ (instancetype)sharedService {
    static VKProfileService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)fetchProfileForUserId:(NSInteger)userId completion:(void (^)(VKUser *user, NSError *error))completion {
    if (userId < 0) {
        // Group profile
        NSDictionary *params = @{
            @"group_id": @(labs(userId)),
            @"fields": @"description,status,verified,site,members_count,can_post,can_suggest,is_admin,is_member"
        };
        [[VKAPIClient sharedClient] callMethod:@"groups.getById" parameters:params completionHandler:^(id response, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            if ([response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
                NSArray *items = response[@"response"];
                if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                    VKUser *group = [VKUser groupFromDictionary:items[0]];
                    if (completion) completion(group, nil);
                    return;
                }
            }
            if (completion) completion(nil, nil);
        }];
    } else {
        // User profile
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
            @"fields": @"photo_100,photo_200,city,online,verified,screen_name,status,about,site,sex,can_write_on_wall,can_post,friend_status,counters"
        }];
        if (userId > 0) {
            params[@"user_ids"] = @(userId);
        }
        
        [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:params completionHandler:^(id response, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            id items = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
            if ([items isKindOfClass:[NSArray class]] && [items count] > 0) {
                VKUser *user = [VKUser userFromDictionary:items[0]];
                if (completion) completion(user, nil);
                return;
            } else if ([items isKindOfClass:[NSDictionary class]]) {
                VKUser *user = [VKUser userFromDictionary:items];
                if (completion) completion(user, nil);
                return;
            }
            if (completion) completion(nil, nil);
        }];
    }
}

- (void)fetchWallForOwnerId:(NSInteger)ownerId
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *posts, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"wall.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *rawItems = resp[@"items"] ?: @[];
            NSArray *rawProfiles = resp[@"profiles"] ?: @[];
            NSArray *rawGroups = resp[@"groups"] ?: @[];
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in rawProfiles) {
                if (p[@"id"]) profiles[p[@"id"]] = p;
            }
            
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in rawGroups) {
                if (g[@"id"]) groups[g[@"id"]] = g;
            }
            
            NSMutableArray *posts = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKPost *post = [VKPost postFromDictionary:item profiles:profiles groups:groups];
                if (post) [posts addObject:post];
            }
            
            if (completion) completion(posts, total, nil);
            return;
        }
        
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)fetchFriendsForUserId:(NSInteger)userId
                   completion:(void (^)(NSArray *friends, NSError *error))completion {
    [self fetchFriendsForUserId:userId offset:0 count:100 completion:^(NSArray *friends, NSInteger totalCount, NSError *error) {
        if (completion) completion(friends, error);
    }];
}

- (void)fetchFriendsForUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *friends, NSInteger totalCount, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"offset": @(offset),
        @"count": @(count),
        @"fields": @"photo_100,online,verified,screen_name"
    }];
    if (userId > 0) {
        params[@"user_id"] = @(userId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"friends.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        if ([response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            NSDictionary *resp = response[@"response"];
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: resp;
            
            NSMutableArray *friends = [NSMutableArray array];
            if ([items isKindOfClass:[NSArray class]]) {
                for (NSDictionary *item in items) {
                    VKUser *u = [VKUser userFromDictionary:item];
                    if (u) [friends addObject:u];
                }
            }
            if (completion) completion(friends, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)fetchGroupsForUserId:(NSInteger)userId
                   completion:(void (^)(NSArray *groups, NSError *error))completion {
    [self fetchGroupsForUserId:userId offset:0 count:100 completion:^(NSArray *groups, NSInteger totalCount, NSError *error) {
        if (completion) completion(groups, error);
    }];
}

- (void)fetchGroupsForUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *groups, NSInteger totalCount, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1",
        @"fields": @"photo_100,verified,screen_name,members_count,description"
    }];
    if (userId > 0) {
        params[@"user_id"] = @(userId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"groups.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        if ([response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            NSDictionary *resp = response[@"response"];
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: resp;
            
            NSMutableArray *groups = [NSMutableArray array];
            if ([items isKindOfClass:[NSArray class]]) {
                for (NSDictionary *item in items) {
                    VKUser *g = [VKUser groupFromDictionary:item];
                    if (g) [groups addObject:g];
                }
            }
            if (completion) completion(groups, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)joinGroup:(NSInteger)groupId completion:(void (^)(BOOL success, NSError *error))completion {
    [[VKAPIClient sharedClient] callMethod:@"groups.join" parameters:@{@"group_id": @(labs(groupId))} completionHandler:^(id response, NSError *error) {
        if (completion) completion(!error, error);
    }];
}

- (void)leaveGroup:(NSInteger)groupId completion:(void (^)(BOOL success, NSError *error))completion {
    [[VKAPIClient sharedClient] callMethod:@"groups.leave" parameters:@{@"group_id": @(labs(groupId))} completionHandler:^(id response, NSError *error) {
        if (completion) completion(!error, error);
    }];
}

- (void)addFriend:(NSInteger)userId completion:(void (^)(BOOL success, NSError *error))completion {
    [[VKAPIClient sharedClient] callMethod:@"friends.add" parameters:@{@"user_id": @(userId)} completionHandler:^(id response, NSError *error) {
        if (completion) completion(!error, error);
    }];
}

- (void)deleteFriend:(NSInteger)userId completion:(void (^)(BOOL success, NSError *error))completion {
    [[VKAPIClient sharedClient] callMethod:@"friends.delete" parameters:@{@"user_id": @(userId)} completionHandler:^(id response, NSError *error) {
        if (completion) completion(!error, error);
    }];
}

- (void)fetchFriendRequestsWithCompletion:(void (^)(NSArray<VKUser *> *requests, NSInteger totalCount, NSError *error))completion {
    NSDictionary *params = @{
        @"extended": @"1",
        @"need_mutual": @"1",
        @"count": @(50)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"friends.getRequests" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(@[], 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: @[];
            NSMutableArray *users = [NSMutableArray array];
            for (id item in items) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    VKUser *u = [VKUser userFromDictionary:item];
                    if (u) [users addObject:u];
                } else if ([item isKindOfClass:[NSNumber class]]) {
                    VKUser *u = [[VKUser alloc] init];
                    u.uid = [item integerValue];
                    u.displayName = [NSString stringWithFormat:@"Пользователь %ld", (long)u.uid];
                    [users addObject:u];
                }
            }
            if (completion) completion(users, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

@end
