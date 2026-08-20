#import "VKFeedService.h"
#import "VKAPIClient.h"

@implementation VKFeedService

+ (instancetype)sharedService {
    static VKFeedService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)fetchFeedIsGlobal:(BOOL)isGlobal
                startFrom:(NSString *)startFrom
               completion:(void (^)(NSArray *posts, NSString *nextFrom, NSError *error))completion {
    
    NSString *method = isGlobal ? @"newsfeed.getGlobal" : @"newsfeed.get";
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"count": @"20",
        @"extended": @"1",
        @"with_alien_wall_posts": @"1",
        @"filters": @"post"
    }];
    if (startFrom && startFrom.length > 0) {
        params[@"start_from"] = startFrom;
    }
    
    [[VKAPIClient sharedClient] callMethod:method parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSArray *rawItems = resp[@"items"] ?: @[];
            NSArray *rawProfiles = resp[@"profiles"] ?: @[];
            NSArray *rawGroups = resp[@"groups"] ?: @[];
            
            id rawNext = resp[@"next_from"] ?: resp[@"nextFrom"];
            NSString *next = nil;
            if ([rawNext isKindOfClass:[NSString class]]) {
                next = (NSString *)rawNext;
            } else if ([rawNext isKindOfClass:[NSNumber class]]) {
                next = [(NSNumber *)rawNext stringValue];
            }
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in rawProfiles) {
                id pid = p[@"id"] ?: p[@"uid"];
                if (pid) {
                    profiles[pid] = p;
                    profiles[[pid description]] = p;
                    profiles[@([pid integerValue])] = p;
                }
            }
            
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in rawGroups) {
                id gid = g[@"id"] ?: g[@"gid"];
                if (gid) {
                    groups[gid] = g;
                    groups[[gid description]] = g;
                    groups[@([gid integerValue])] = g;
                }
            }
            
            NSMutableArray *posts = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKPost *post = [VKPost postFromDictionary:item profiles:profiles groups:groups];
                if (post) [posts addObject:post];
            }
            
            if (completion) completion(posts, next, nil);
            return;
        }
        
        if (completion) completion(@[], nil, nil);
    }];
}

- (void)likePost:(VKPost *)post completion:(void (^)(VKPost *updatedPost, NSError *error))completion {
    if (!post || post.vkID == 0) {
        if (completion) completion(post, nil);
        return;
    }
    
    NSString *method = post.isLiked ? @"likes.delete" : @"likes.add";
    NSDictionary *params = @{
        @"type": @"post",
        @"owner_id": @(post.ownerID),
        @"item_id": @(post.vkID)
    };
    
    [[VKAPIClient sharedClient] callMethod:method parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(post, error);
            return;
        }
        
        post.isLiked = !post.isLiked;
        if (post.isLiked) {
            post.likesCount += 1;
        } else {
            post.likesCount = MAX(0, post.likesCount - 1);
        }
        
        if (completion) completion(post, nil);
    }];
}

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion {
    [self createPostWithText:text ownerId:ownerId attachments:nil explicit:NO fromGroup:fromGroup completion:completion];
}

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
               attachments:(NSString *)attachments
                  explicit:(BOOL)explicit
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"owner_id": @(ownerId),
        @"message": text ?: @""
    }];
    if (attachments.length > 0) {
        params[@"attachments"] = attachments;
    }
    if (explicit) {
        params[@"explicit"] = @"1";
    }
    if (ownerId < 0 && fromGroup) {
        params[@"from_group"] = @"1";
    }
    
    [[VKAPIClient sharedClient] callMethod:@"wall.post" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

- (void)repostPost:(VKPost *)post
           message:(NSString *)message
           groupId:(NSInteger)groupId
        completion:(void (^)(BOOL success, NSError *error))completion {
    
    if (!post || post.vkID == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    
    NSString *object = [NSString stringWithFormat:@"wall%ld_%ld", (long)post.ownerID, (long)post.vkID];
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"object": object
    }];
    if (message.length > 0) {
        params[@"message"] = message;
    }
    if (groupId > 0) {
        params[@"group_id"] = @(groupId);
        params[@"as_group"] = @"1";
    }
    
    [[VKAPIClient sharedClient] callMethod:@"wall.repost" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, error);
            return;
        }
        if (completion) completion(YES, nil);
    }];
}

@end
