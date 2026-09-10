#import "VKMessage.h"
#import "VKAttachment.h"

@implementation VKMessage

+ (instancetype)messageFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKMessage *msg = [[VKMessage alloc] init];
    msg.messageId = [dict[@"id"] integerValue] ?: [dict[@"mid"] integerValue];
    
    NSInteger peerId = [dict[@"peer_id"] integerValue];
    if (peerId == 0) {
        if (dict[@"chat_id"]) {
            peerId = 2000000000 + [dict[@"chat_id"] integerValue];
        } else {
            peerId = [dict[@"user_id"] integerValue];
        }
    }
    msg.peerId = peerId;
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
    
    // Вложения
    NSMutableArray *atts = [NSMutableArray array];
    NSArray *rawAtts = dict[@"attachments"];
    if ([rawAtts isKindOfClass:[NSArray class]]) {
        for (NSDictionary *rawAtt in rawAtts) {
            VKAttachment *a = [VKAttachment attachmentFromDictionary:rawAtt];
            if (a) [atts addObject:a];
        }
    }
    msg.attachments = atts;
    
    // Пересланные сообщения
    NSArray *rawFwd = dict[@"fwd_messages"];
    if ([rawFwd isKindOfClass:[NSArray class]] && rawFwd.count > 0) {
        NSMutableArray *fwds = [NSMutableArray array];
        for (NSDictionary *fwdDict in rawFwd) {
            VKMessage *fwd = [VKMessage messageFromDictionary:fwdDict];
            if (fwd) [fwds addObject:fwd];
        }
        msg.fwdMessages = fwds;
    }
    
    // Ответ на сообщение
    NSDictionary *rawReply = dict[@"reply_message"];
    if ([rawReply isKindOfClass:[NSDictionary class]]) {
        msg.replyMessage = [VKMessage messageFromDictionary:rawReply];
    }
    
    // Сервисные действия в беседах
    id rawAction = dict[@"action"];
    if ([rawAction isKindOfClass:[NSDictionary class]]) {
        NSDictionary *actDict = (NSDictionary *)rawAction;
        msg.action = actDict[@"type"];
        msg.actionMid = [actDict[@"member_id"] integerValue];
        msg.actionText = actDict[@"text"];
        msg.actionEmail = actDict[@"email"];
    } else if ([rawAction isKindOfClass:[NSString class]]) {
        msg.action = (NSString *)rawAction;
        msg.actionMid = [dict[@"action_mid"] integerValue];
        msg.actionText = dict[@"action_text"];
        msg.actionEmail = dict[@"action_email"];
    }
    
    return msg;
}

- (BOOL)isServiceAction {
    return self.action.length > 0;
}

- (NSString *)serviceActionText {
    if (![self isServiceAction]) return @"";
    
    BOOL isFemale = (self.senderUser && self.senderUser.sex == 1);
    
    if ([self.action isEqualToString:@"chat_photo_update"]) {
        return isFemale ? @"обновила фотографию беседы" : @"обновил фотографию беседы";
    } else if ([self.action isEqualToString:@"chat_photo_remove"]) {
        return isFemale ? @"удалила фотографию беседы" : @"удалил фотографию беседы";
    } else if ([self.action isEqualToString:@"chat_create"]) {
        return [NSString stringWithFormat:isFemale ? @"создала беседу «%@»" : @"создал беседу «%@»", self.actionText ?: @""];
    } else if ([self.action isEqualToString:@"chat_title_update"]) {
        return [NSString stringWithFormat:isFemale ? @"изменила название беседы на «%@»" : @"изменил название беседы на «%@»", self.actionText ?: @""];
    } else if ([self.action isEqualToString:@"chat_invite_user"] || [self.action isEqualToString:@"chat_user_add"]) {
        if (self.actionMid != 0 && self.actionMid == self.fromId) {
            return isFemale ? @"вернулась в беседу" : @"вернулся в беседу";
        }
        return isFemale ? @"пригласила пользователя в беседу" : @"пригласил пользователя в беседу";
    } else if ([self.action isEqualToString:@"chat_kick_user"] || [self.action isEqualToString:@"chat_user_kick"]) {
        if (self.actionMid != 0 && self.actionMid == self.fromId) {
            return isFemale ? @"покинула беседу" : @"покинул беседу";
        }
        return isFemale ? @"исключила пользователя из беседы" : @"исключил пользователя из беседы";
    } else if ([self.action isEqualToString:@"chat_invite_user_by_link"]) {
        return isFemale ? @"присоединилась к беседе по ссылке" : @"присоединился к беседе по ссылке";
    } else if ([self.action isEqualToString:@"chat_pin_message"]) {
        return isFemale ? @"закрепила сообщение" : @"закрепил сообщение";
    } else if ([self.action isEqualToString:@"chat_unpin_message"]) {
        return isFemale ? @"открепила сообщение" : @"открепил сообщение";
    }
    return self.action;
}

- (NSString *)displayText {
    if ([self isServiceAction]) {
        return [self serviceActionText];
    }
    if (self.text.length > 0) {
        return self.text;
    }
    if (self.attachments.count > 0) {
        VKAttachment *first = self.attachments[0];
        switch (first.type) {
            case VKAttachmentTypePhoto: return @"[Фотография]";
            case VKAttachmentTypeSticker: return @"[Стикер]";
            case VKAttachmentTypeAudioMessage: return @"[Голосовое сообщение]";
            case VKAttachmentTypeWall: return [NSString stringWithFormat:@"[Запись на стене%@]", first.wallText.length > 0 ? [NSString stringWithFormat:@": %@", first.wallText] : @""];
            case VKAttachmentTypeAudio: return @"[Аудиозапись]";
            case VKAttachmentTypeVideo: return @"[Видеозапись]";
            case VKAttachmentTypeDoc: return @"[Документ]";
            case VKAttachmentTypeGif: return @"[GIF]";
            case VKAttachmentTypeLink: return @"[Ссылка]";
            case VKAttachmentTypePoll: return @"[Опрос]";
            default: return @"[Вложение]";
        }
    }
    if (self.fwdMessages.count > 0) {
        return [NSString stringWithFormat:@"[%ld пересл. сообщ.]", (long)self.fwdMessages.count];
    }
    if (self.replyMessage) {
        return @"[Ответ]";
    }
    return @"";
}

@end

@implementation VKConversation

+ (instancetype)conversationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKConversation *conv = [[VKConversation alloc] init];
    NSDictionary *c = dict[@"conversation"] ?: dict;
    
    NSInteger peerId = [c[@"peer"][@"id"] integerValue];
    if (peerId == 0) {
        if (dict[@"chat_id"]) {
            peerId = 2000000000 + [dict[@"chat_id"] integerValue];
        } else {
            peerId = [dict[@"user_id"] integerValue];
        }
    }
    conv.peerId = peerId;
    conv.unreadCount = [c[@"unread_count"] integerValue];
    conv.canWrite = YES;
    if (c[@"can_write"] && [c[@"can_write"] isKindOfClass:[NSDictionary class]]) {
        conv.canWrite = [c[@"can_write"][@"allowed"] boolValue];
    }
    
    // Определение типа диалога: беседа / группа / пользователь
    conv.isChat = (peerId > 2000000000 || [c[@"peer"][@"type"] isEqualToString:@"chat"] || dict[@"chat_id"] != nil);
    conv.isGroup = (peerId < 0 || [c[@"peer"][@"type"] isEqualToString:@"group"]);
    
    if (conv.isChat) {
        conv.chatId = (peerId > 2000000000) ? (peerId - 2000000000) : [dict[@"chat_id"] integerValue];
        NSDictionary *settings = c[@"chat_settings"];
        conv.title = settings[@"title"] ?: dict[@"title"] ?: [NSString stringWithFormat:@"Беседа #%ld", (long)conv.chatId];
        
        NSDictionary *photo = settings[@"photo"];
        conv.chatPhotoURL = photo[@"photo_100"] ?: photo[@"photo_50"] ?: dict[@"photo_100"] ?: dict[@"photo_50"];
        conv.membersCount = [settings[@"members_count"] integerValue] ?: [dict[@"users_count"] integerValue];
        conv.adminId = [settings[@"admin_id"] integerValue] ?: [dict[@"admin_id"] integerValue];
        conv.activeMemberIds = settings[@"active_ids"] ?: dict[@"chat_active"];
    } else if (conv.isGroup) {
        NSInteger gid = -peerId;
        NSDictionary *g = groups[@(gid)] ?: groups[[NSString stringWithFormat:@"%ld", (long)gid]];
        conv.peerUser = [VKUser groupFromDictionary:g] ?: [VKUser groupFromDictionary:@{@"id": @(gid), @"name": @"Сообщество"}];
        conv.title = conv.peerUser.displayName;
    } else {
        // Личный диалог с пользователем
        NSDictionary *p = profiles[@(peerId)] ?: profiles[[NSString stringWithFormat:@"%ld", (long)peerId]];
        conv.peerUser = [VKUser userFromDictionary:p] ?: [VKUser userFromDictionary:@{@"id": @(peerId), @"first_name": @"Пользователь", @"last_name": @""}];
        conv.title = conv.peerUser.displayName;
    }
    
    NSDictionary *lastMsgDict = dict[@"last_message"] ?: dict[@"message"];
    if (lastMsgDict) {
        conv.lastMessage = [VKMessage messageFromDictionary:lastMsgDict];
    }
    
    return conv;
}

- (NSString *)displayTitle {
    if (self.title.length > 0) return self.title;
    if (self.peerUser.displayName.length > 0) return self.peerUser.displayName;
    return self.isChat ? [NSString stringWithFormat:@"Беседа #%ld", (long)self.chatId] : @"Диалог";
}

- (NSString *)displayAvatarURL {
    if (self.isChat && self.chatPhotoURL.length > 0) {
        return self.chatPhotoURL;
    }
    return self.peerUser.avatarURL;
}

- (NSString *)previewText {
    if (!self.lastMessage) return @"";
    NSString *prefix = self.lastMessage.isOutgoing ? @"Вы: " : @"";
    return [NSString stringWithFormat:@"%@%@", prefix, [self.lastMessage displayText]];
}

@end
