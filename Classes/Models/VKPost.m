#import "VKPost.h"
#import "NSNull+Safe.h"

@implementation VKPost

+ (instancetype)postFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKPost *post = [[VKPost alloc] init];
    post.vkID = [dict[@"id"] integerValue];
    
    NSInteger sourceId = [dict[@"from_id"] integerValue] ?: [dict[@"source_id"] integerValue] ?: 0;
    NSInteger ownerId = [dict[@"owner_id"] integerValue] ?: [dict[@"source_id"] integerValue] ?: [dict[@"from_id"] integerValue] ?: 0;
    post.ownerID = ownerId;
    
    // Автор
    if (sourceId > 0) {
        NSDictionary *p = profiles[@(sourceId)];
        post.author = [VKUser userFromDictionary:p] ?: [VKUser userFromDictionary:@{@"id": @(sourceId), @"first_name": @"Пользователь", @"last_name": @""}];
    } else if (sourceId < 0) {
        NSDictionary *g = groups[@(-sourceId)];
        post.author = [VKUser groupFromDictionary:g] ?: [VKUser groupFromDictionary:@{@"id": @(-sourceId), @"name": @"Сообщество"}];
    } else {
        post.author = [VKUser userFromDictionary:@{@"id": @0, @"first_name": @"Пользователь"}];
    }
    
    // Владелец стены (если пост на чужой стене)
    if (ownerId != 0 && ownerId != sourceId) {
        if (ownerId > 0) {
            NSDictionary *wp = profiles[@(ownerId)];
            post.wallOwner = [VKUser userFromDictionary:wp];
        } else {
            NSDictionary *wg = groups[@(-ownerId)];
            post.wallOwner = [VKUser groupFromDictionary:wg];
        }
    }
    
    // Платформа
    if ([dict[@"post_source"] isKindOfClass:[NSDictionary class]]) {
        post.platform = dict[@"post_source"][@"platform"];
    }
    
    // Дата
    double timestamp = [dict[@"date"] doubleValue];
    if (timestamp > 0) {
        post.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"d MMM в HH:mm"];
        post.timeAgo = [df stringFromDate:post.date];
    } else {
        post.timeAgo = @"сегодня";
    }
    
    id rawText = dict[@"text"];
    if ([rawText isKindOfClass:[NSString class]]) {
        post.text = rawText;
    } else if ([rawText isKindOfClass:[NSNumber class]]) {
        post.text = [(NSNumber *)rawText stringValue];
    } else {
        post.text = @"";
    }
    post.isExplicit = [dict[@"is_explicit"] boolValue] || [dict[@"nsfw"] boolValue];
    
    // Счетчики
    if ([dict[@"likes"] isKindOfClass:[NSDictionary class]]) {
        post.likesCount = [dict[@"likes"][@"count"] integerValue];
        post.isLiked = [dict[@"likes"][@"user_likes"] integerValue] == 1;
    }
    if ([dict[@"comments"] isKindOfClass:[NSDictionary class]]) {
        post.commentsCount = [dict[@"comments"][@"count"] integerValue];
    }
    if ([dict[@"reposts"] isKindOfClass:[NSDictionary class]]) {
        post.repostsCount = [dict[@"reposts"][@"count"] integerValue];
    }
    
    // Вложения
    NSMutableArray *atts = [NSMutableArray array];
    NSArray *rawAtts = dict[@"attachments"];
    if ([rawAtts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rawAtt in rawAtts) {
            VKAttachment *a = [VKAttachment attachmentFromDictionary:rawAtt];
            if (a) [atts addObject:a];
        }
    }
    post.attachments = atts;
    
    // Репосты (история)
    NSMutableArray *history = [NSMutableArray array];
    NSArray *rawHistory = dict[@"copy_history"];
    if ([rawHistory isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rawPost in rawHistory) {
            VKPost *reposted = [VKPost postFromDictionary:rawPost profiles:profiles groups:groups];
            if (reposted) [history addObject:reposted];
        }
    }
    post.repostHistory = history;
    
    // Источник (Copyright)
    if ([dict[@"copyright"] isKindOfClass:[NSDictionary class]]) {
        post.copyrightName = dict[@"copyright"][@"name"] ?: dict[@"copyright"][@"title"];
        post.copyrightLink = dict[@"copyright"][@"link"] ?: dict[@"copyright"][@"url"];
    }
    
    // Автор подписи (Signer)
    NSInteger signerId = [dict[@"signer_id"] integerValue];
    if (signerId > 0) {
        NSDictionary *sp = profiles[@(signerId)];
        post.signerUser = [VKUser userFromDictionary:sp];
    }
    
    return post;
}

- (BOOL)isOnAlienWall {
    return (self.wallOwner != nil);
}

- (BOOL)canRepost {
    return (self.vkID > 0 && self.ownerID != 0);
}

@end
