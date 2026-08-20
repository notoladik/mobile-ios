#import "VKComment.h"

@implementation VKComment

+ (instancetype)commentFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKComment *c = [[VKComment alloc] init];
    c.commentId = [dict[@"id"] integerValue];
    c.fromId = [dict[@"from_id"] integerValue];
    
    if (c.fromId > 0) {
        NSDictionary *p = profiles[@(c.fromId)];
        c.author = [VKUser userFromDictionary:p] ?: [VKUser userFromDictionary:@{@"id": @(c.fromId), @"first_name": @"Пользователь"}];
    } else if (c.fromId < 0) {
        NSDictionary *g = groups[@(-c.fromId)];
        c.author = [VKUser groupFromDictionary:g] ?: [VKUser groupFromDictionary:@{@"id": @(-c.fromId), @"name": @"Сообщество"}];
    }
    
    c.text = dict[@"text"] ?: @"";
    
    double timestamp = [dict[@"date"] doubleValue];
    if (timestamp > 0) {
        c.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"d MMM в HH:mm"];
        c.timeAgo = [df stringFromDate:c.date];
    } else {
        c.timeAgo = @"сегодня";
    }
    
    if ([dict[@"likes"] isKindOfClass:[NSDictionary class]]) {
        c.likesCount = [dict[@"likes"][@"count"] integerValue];
        c.isLiked = [dict[@"likes"][@"user_likes"] integerValue] == 1;
    }
    
    NSMutableArray *atts = [NSMutableArray array];
    NSArray *rawAtts = dict[@"attachments"];
    if ([rawAtts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rawAtt in rawAtts) {
            VKAttachment *a = [VKAttachment attachmentFromDictionary:rawAtt];
            if (a) [atts addObject:a];
        }
    }
    c.attachments = atts;
    
    return c;
}

@end
