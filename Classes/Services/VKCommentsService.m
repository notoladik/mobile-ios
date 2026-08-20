#import "VKCommentsService.h"
#import "VKAPIClient.h"

@implementation VKCommentsService

+ (instancetype)sharedService {
    static VKCommentsService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)fetchCommentsForOwnerId:(NSInteger)ownerId
                         postId:(NSInteger)postId
                         offset:(NSInteger)offset
                          count:(NSInteger)count
                     completion:(void (^)(NSArray *comments, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"post_id": @(postId),
        @"offset": @(offset),
        @"count": @(count),
        @"extended": @"1",
        @"need_likes": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"wall.getComments" parameters:params completionHandler:^(id response, NSError *error) {
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
            
            NSMutableArray *comments = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKComment *c = [VKComment commentFromDictionary:item profiles:profiles groups:groups];
                if (c) [comments addObject:c];
            }
            
            if (completion) completion(comments, total, nil);
            return;
        }
        
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)addCommentForOwnerId:(NSInteger)ownerId
                      postId:(NSInteger)postId
                     message:(NSString *)message
                  replyToCid:(NSInteger)replyToCid
                  completion:(void (^)(BOOL success, NSInteger commentId, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"owner_id": @(ownerId),
        @"post_id": @(postId),
        @"text": message ?: @""
    }];
    if (replyToCid > 0) {
        params[@"reply_to_comment"] = @(replyToCid);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"wall.createComment" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, 0, error);
            return;
        }
        
        NSInteger cid = 0;
        if ([response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            cid = [response[@"response"][@"comment_id"] integerValue] ?: [response[@"response"] integerValue];
        }
        if (completion) completion(YES, cid, nil);
    }];
}

- (void)likeCommentId:(NSInteger)commentId
              ownerId:(NSInteger)ownerId
               isLike:(BOOL)isLike
           completion:(void (^)(BOOL success))completion {
    
    NSString *method = isLike ? @"likes.add" : @"likes.delete";
    NSDictionary *params = @{
        @"type": @"comment",
        @"owner_id": @(ownerId),
        @"item_id": @(commentId)
    };
    
    [[VKAPIClient sharedClient] callMethod:method parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) completion(error == nil);
    }];
}

- (void)editCommentForOwnerId:(NSInteger)ownerId
                    commentId:(NSInteger)commentId
                      message:(NSString *)message
                   completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"comment_id": @(commentId),
        @"message": message ?: @""
    };
    
    [[VKAPIClient sharedClient] callMethod:@"wall.editComment" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)deleteCommentForOwnerId:(NSInteger)ownerId
                      commentId:(NSInteger)commentId
                     completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSDictionary *params = @{
        @"owner_id": @(ownerId),
        @"comment_id": @(commentId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"wall.deleteComment" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

@end
