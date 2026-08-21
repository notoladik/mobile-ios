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
    [self createPostWithText:text ownerId:ownerId attachments:nil copyright:nil explicit:NO fromGroup:fromGroup completion:completion];
}

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
               attachments:(NSString *)attachments
                  explicit:(BOOL)explicit
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion {
    [self createPostWithText:text ownerId:ownerId attachments:attachments copyright:nil explicit:explicit fromGroup:fromGroup completion:completion];
}

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
               attachments:(NSString *)attachments
                 copyright:(NSString *)copyright
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
    if (copyright.length > 0) {
        params[@"copyright"] = copyright;
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

- (void)uploadWallPhoto:(UIImage *)image
                ownerId:(NSInteger)ownerId
             completion:(void (^)(NSString *attachmentString, NSError *error))completion {
    
    if (!image) {
        if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No image data"}]);
        return;
    }
    
    NSMutableDictionary *serverParams = [NSMutableDictionary dictionary];
    if (ownerId < 0) {
        serverParams[@"group_id"] = @(-ownerId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"photos.getWallUploadServer" parameters:serverParams completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSString *uploadUrl = resp[@"upload_url"];
        if (!uploadUrl || uploadUrl.length == 0) {
            if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"No upload_url received"}]);
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
                if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid upload response"}]);
                return;
            }
            
            NSMutableDictionary *saveParams = [NSMutableDictionary dictionary];
            if (uDict[@"server"]) saveParams[@"server"] = uDict[@"server"];
            if (uDict[@"photo"]) saveParams[@"photo"] = uDict[@"photo"];
            if (uDict[@"hash"]) saveParams[@"hash"] = uDict[@"hash"];
            if (ownerId < 0) {
                saveParams[@"group_id"] = @(-ownerId);
            } else if (ownerId > 0) {
                saveParams[@"user_id"] = @(ownerId);
            }
            
            [[VKAPIClient sharedClient] callMethod:@"photos.saveWallPhoto" parameters:saveParams completionHandler:^(id saveResp, NSError *saveErr) {
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
                
                if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save wall photo"}]);
            }];
        }];
    }];
}

- (void)createPollWithQuestion:(NSString *)question
                       answers:(NSArray<NSString *> *)answers
                   isAnonymous:(BOOL)isAnonymous
                       ownerId:(NSInteger)ownerId
                    completion:(void (^)(NSString *attachmentString, NSError *error))completion {
    
    if (question.length == 0 || answers.count < 2) {
        if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Invalid poll parameters"}]);
        return;
    }
    
    NSData *answersJsonData = [NSJSONSerialization dataWithJSONObject:answers options:0 error:nil];
    NSString *answersJsonString = [[NSString alloc] initWithData:answersJsonData encoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:@{
        @"question": question,
        @"answers": answersJsonString ?: @"[]",
        @"is_anonymous": isAnonymous ? @"1" : @"0"
    }];
    if (ownerId < 0) {
        params[@"owner_id"] = @(ownerId);
    }
    
    [[VKAPIClient sharedClient] callMethod:@"polls.create" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger pollId = [resp[@"id"] integerValue];
            NSInteger pollOwner = [resp[@"owner_id"] integerValue] ?: ownerId;
            if (pollId != 0) {
                NSString *attStr = [NSString stringWithFormat:@"poll%ld_%ld", (long)pollOwner, (long)pollId];
                if (completion) completion(attStr, nil);
                return;
            }
        }
        
        if (completion) completion(nil, [NSError errorWithDomain:@"VKFeedService" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create poll"}]);
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
