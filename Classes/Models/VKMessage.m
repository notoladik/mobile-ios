#import "VKMessage.h"
#import "VKAttachment.h"

@implementation VKMessage

+ (instancetype)messageFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKMessage *msg = [[VKMessage alloc] init];
    msg.messageId = [dict[@"id"] integerValue];
    msg.peerId = [dict[@"peer_id"] integerValue] ?: [dict[@"user_id"] integerValue];
    msg.fromId = [dict[@"from_id"] integerValue] ?: [dict[@"user_id"] integerValue];
    msg.text = dict[@"text"] ?: dict[@"body"] ?: @"";
    msg.isOutgoing = [dict[@"out"] integerValue] == 1;
    msg.isRead = [dict[@"read_state"] integerValue] == 1;
    
    double timestamp = [dict[@"date"] doubleValue];
    if (timestamp > 0) {
        msg.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"HH:mm"];
        msg.timeString = [df stringFromDate:msg.date];
    }
    
    NSMutableArray *atts = [NSMutableArray array];
    NSArray *rawAtts = dict[@"attachments"];
    if ([rawAtts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rawAtt in rawAtts) {
            VKAttachment *a = [VKAttachment attachmentFromDictionary:rawAtt];
            if (a) [atts addObject:a];
        }
    }
    msg.attachments = atts;
    
    return msg;
}

@end

@implementation VKConversation

+ (instancetype)conversationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKConversation *conv = [[VKConversation alloc] init];
    NSDictionary *c = dict[@"conversation"] ?: dict;
    
    NSInteger peerId = [c[@"peer"][@"id"] integerValue] ?: [dict[@"user_id"] integerValue];
    conv.peerId = peerId;
    conv.unreadCount = [c[@"unread_count"] integerValue];
    
    if (peerId > 0) {
        NSDictionary *p = profiles[@(peerId)];
        conv.peerUser = [VKUser userFromDictionary:p] ?: [VKUser userFromDictionary:@{@"id": @(peerId), @"first_name": @"Пользователь", @"last_name": @""}];
    } else if (peerId < 0) {
        NSDictionary *g = groups[@(-peerId)];
        conv.peerUser = [VKUser groupFromDictionary:g] ?: [VKUser groupFromDictionary:@{@"id": @(-peerId), @"name": @"Сообщество"}];
    }
    
    conv.title = c[@"chat_settings"][@"title"] ?: conv.peerUser.displayName;
    
    NSDictionary *lastMsgDict = dict[@"last_message"] ?: dict[@"message"];
    if (lastMsgDict) {
        conv.lastMessage = [VKMessage messageFromDictionary:lastMsgDict];
    }
    
    return conv;
}

@end
