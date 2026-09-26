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
        NSInteger gId = labs(userId);
        NSDictionary *params = @{
            @"group_id": @(gId),
            @"group_ids": @(gId),
            @"fields": @"description,status,verified,site,members_count,can_post,can_suggest,is_admin,is_member,photo_50,photo_100,photo_200,photo_max_orig,counters"
        };
        [[VKAPIClient sharedClient] callMethod:@"groups.getById" parameters:params completionHandler:^(id response, NSError *error) {
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            id resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : response;
            if ([resp isKindOfClass:[NSArray class]] && [resp count] > 0) {
                VKUser *group = [VKUser groupFromDictionary:resp[0]];
                if (completion) completion(group, nil);
                return;
            } else if ([resp isKindOfClass:[NSDictionary class]]) {
                VKUser *group = [VKUser groupFromDictionary:resp];
                if (completion) completion(group, nil);
                return;
            }
            if (completion) completion(nil, nil);
        }];
    } else {
        // User profile
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
            @"fields": @"photo_100,photo_200,photo_max,photo_400_orig,photo_max_orig,city,online,verified,screen_name,status,about,site,sex,can_write_on_wall,can_post,friend_status,counters"
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
    [self fetchWallForOwnerId:ownerId offset:offset count:count filter:nil completion:completion];
}

- (void)fetchWallForOwnerId:(NSInteger)ownerId
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                     filter:(NSString *)filter
                 completion:(void (^)(NSArray *posts, NSInteger totalCount, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"owner_id": @(ownerId),
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1"
    }];
    if (filter.length > 0) {
        params[@"filter"] = filter;
    }
    
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
            
            BOOL isArchivedFilter = [filter isEqualToString:@"archived"];
            NSMutableArray *posts = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKPost *post = [VKPost postFromDictionary:item profiles:profiles groups:groups];
                if (post) {
                    if (isArchivedFilter) {
                        post.isArchived = YES;
                    }
                    [posts addObject:post];
                }
            }
            
            if (completion) completion(posts, total, nil);
            return;
        }
        
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)archivePost:(NSInteger)postId ownerId:(NSInteger)ownerId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId)
    };
    [[VKAPIClient sharedClient] callMethod:@"wall.archive" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)restorePost:(NSInteger)postId ownerId:(NSInteger)ownerId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId)
    };
    [[VKAPIClient sharedClient] callMethod:@"wall.reveal" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)deletePost:(NSInteger)postId ownerId:(NSInteger)ownerId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId)
    };
    [[VKAPIClient sharedClient] callMethod:@"wall.delete" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)pinPost:(NSInteger)postId ownerId:(NSInteger)ownerId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId)
    };
    [[VKAPIClient sharedClient] callMethod:@"wall.pin" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)unpinPost:(NSInteger)postId ownerId:(NSInteger)ownerId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId)
    };
    [[VKAPIClient sharedClient] callMethod:@"wall.unpin" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)fetchGroupMembersForGroupId:(NSInteger)groupId
                             offset:(NSInteger)offset
                              count:(NSInteger)count
                         completion:(void (^)(NSArray *members, NSInteger totalCount, NSError *error))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"group_id": @(labs(groupId)),
        @"offset": @(offset),
        @"count": @(count),
        @"fields": @"photo_100,photo_200,online,verified,screen_name"
    }];
    
    [[VKAPIClient sharedClient] callMethod:@"groups.getMembers" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSInteger total = [resp[@"count"] integerValue];
        NSArray *items = resp[@"items"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
        
        NSMutableArray *members = [NSMutableArray array];
        if ([items isKindOfClass:[NSArray class]]) {
            for (id item in items) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    VKUser *u = [VKUser userFromDictionary:item];
                    if (u) [members addObject:u];
                } else if ([item isKindOfClass:[NSNumber class]]) {
                    VKUser *u = [[VKUser alloc] init];
                    u.uid = [item integerValue];
                    u.displayName = [NSString stringWithFormat:@"id%ld", (long)u.uid];
                    [members addObject:u];
                }
            }
        }
        if (completion) completion(members, total > 0 ? total : members.count, nil);
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

- (void)fetchManagedGroupsWithCompletion:(void (^)(NSArray<VKUser *> *groups, NSError *error))completion {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"filter": @"admin,editor",
        @"extended": @"1",
        @"fields": @"photo_50,photo_100,photo_200,verified,screen_name,members_count,description",
        @"count": @(100)
    }];
    
    [[VKAPIClient sharedClient] callMethod:@"groups.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp && [resp isKindOfClass:[NSDictionary class]]) {
            NSArray *items = resp[@"items"] ?: resp[@"response"];
            NSMutableArray *groups = [NSMutableArray array];
            if ([items isKindOfClass:[NSArray class]]) {
                for (NSDictionary *item in items) {
                    if ([item isKindOfClass:[NSDictionary class]]) {
                        VKUser *g = [VKUser groupFromDictionary:item];
                        if (g) [groups addObject:g];
                    }
                }
            }
            if (completion) completion(groups, nil);
            return;
        }
        if (completion) completion(@[], nil);
    }];
}

@end
