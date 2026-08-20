#import "VKNotification.h"

@implementation VKNotification

+ (instancetype)notificationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups isArchived:(BOOL)isArchived {
    VKNotification *notif = [[VKNotification alloc] init];
    notif.isRead = isArchived;
    
    NSString *typeStr = dict[@"type"];
    if ([typeStr isEqualToString:@"like_post"] || [typeStr isEqualToString:@"like_comment"] || [typeStr isEqualToString:@"like_photo"] || [typeStr isEqualToString:@"like_video"]) {
        notif.type = VKNotificationTypeLike;
    } else if ([typeStr isEqualToString:@"copy_post"]) {
        notif.type = VKNotificationTypeRepost;
    } else if ([typeStr isEqualToString:@"friendRequest"] || [typeStr isEqualToString:@"follow"]) {
        notif.type = VKNotificationTypeFriendRequest;
    } else if ([typeStr isEqualToString:@"mention"] || [typeStr hasPrefix:@"mention_"]) {
        notif.type = VKNotificationTypeMention;
    } else if ([typeStr isEqualToString:@"wall"]) {
        notif.type = VKNotificationTypeWallPost;
    } else if ([typeStr isEqualToString:@"sent_gift"]) {
        notif.type = VKNotificationTypeGift;
    } else if ([typeStr isEqualToString:@"voices_transfer"]) {
        notif.type = VKNotificationTypeVoicesTransfer;
    } else if ([typeStr isEqualToString:@"up_rating"]) {
        notif.type = VKNotificationTypeRatingUp;
    } else if ([typeStr isEqualToString:@"make_you_admin"]) {
        notif.type = VKNotificationTypeMakeAdmin;
    } else {
        notif.type = VKNotificationTypeComment;
    }
    
    NSDictionary *feedback = dict[@"feedback"];
    NSDictionary *parent = dict[@"parent"];
    
    NSInteger sourceId = 0;
    if ([feedback isKindOfClass:[NSDictionary class]]) {
        if (feedback[@"from_id"]) sourceId = [feedback[@"from_id"] integerValue];
        else if (feedback[@"id"]) sourceId = [feedback[@"id"] integerValue];
        else if ([feedback[@"items"] isKindOfClass:[NSArray class]] && [feedback[@"items"] count] > 0) {
            sourceId = [feedback[@"items"][0][@"from_id"] integerValue];
        }
    }
    if (sourceId == 0 && [parent isKindOfClass:[NSDictionary class]]) {
        sourceId = [parent[@"id"] integerValue];
    }
    
    if (sourceId > 0 && profiles[@(sourceId)]) {
        notif.user = profiles[@(sourceId)];
    } else if (sourceId < 0 && groups[@(labs(sourceId))]) {
        notif.user = groups[@(labs(sourceId))];
    } else {
        VKUser *u = [[VKUser alloc] init];
        u.uid = sourceId;
        u.displayName = @"Пользователь";
        notif.user = u;
    }
    
    if ([parent isKindOfClass:[NSDictionary class]]) {
        notif.textPreview = parent[@"text"] ?: parent[@"title"];
        notif.targetPostID = [parent[@"id"] integerValue];
        notif.targetPostOwnerID = [parent[@"to_id"] integerValue] ?: [parent[@"owner_id"] integerValue] ?: [parent[@"from_id"] integerValue];
    } else if ([feedback isKindOfClass:[NSDictionary class]]) {
        notif.textPreview = feedback[@"text"];
        notif.targetPostID = [feedback[@"id"] integerValue];
        notif.targetPostOwnerID = [feedback[@"to_id"] integerValue] ?: [feedback[@"owner_id"] integerValue] ?: [feedback[@"from_id"] integerValue];
    }
    
    NSTimeInterval timestamp = [dict[@"date"] doubleValue];
    if (timestamp > 0) {
        NSDate *d = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:d];
        if (diff < 60) notif.timeAgo = @"только что";
        else if (diff < 3600) notif.timeAgo = [NSString stringWithFormat:@"%d мин. назад", (int)(diff / 60)];
        else if (diff < 86400) notif.timeAgo = [NSString stringWithFormat:@"%d ч. назад", (int)(diff / 3600)];
        else {
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"d MMM в HH:mm"];
            notif.timeAgo = [df stringFromDate:d];
        }
    } else {
        notif.timeAgo = @"недавно";
    }
    
    return notif;
}

@end
