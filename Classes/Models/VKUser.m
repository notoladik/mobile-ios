#import "VKUser.h"
#import "NSNull+Safe.h"
#import "VKAuthService.h"

@implementation VKUser

+ (instancetype)userFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKUser *user = [[VKUser alloc] init];
    user.uid = [dict[@"id"] integerValue] ?: [dict[@"uid"] integerValue];
    user.username = dict[@"screen_name"] ?: (user.uid > 0 ? [NSString stringWithFormat:@"id%ld", (long)user.uid] : @"id");
    
    NSString *first = dict[@"first_name"] ?: @"";
    NSString *last = dict[@"last_name"] ?: @"";
    user.displayName = [[NSString stringWithFormat:@"%@ %@", first, last] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (user.displayName.length == 0) user.displayName = dict[@"name"] ?: user.username;
    
    user.avatarURL = dict[@"photo_100"] ?: dict[@"photo_200"] ?: dict[@"photo_50"] ?: dict[@"photo_max"];
    
    if ([dict[@"city"] isKindOfClass:[NSDictionary class]]) {
        user.city = dict[@"city"][@"title"];
    } else if ([dict[@"city"] isKindOfClass:[NSString class]]) {
        user.city = dict[@"city"];
    }
    
    user.isOnline = [dict[@"online"] integerValue] == 1;
    if ([dict[@"last_seen"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *ls = dict[@"last_seen"];
        NSInteger platform = [ls[@"platform"] integerValue];
        if (platform == 1 || platform == 2 || platform == 3) user.onlinePlatform = @"📱";
        else if (platform == 4) user.onlinePlatform = @"🤖";
        else if (platform == 7) user.onlinePlatform = @"💻";
    }
    if ([dict[@"online_mobile"] integerValue] == 1 && user.onlinePlatform.length == 0) {
        user.onlinePlatform = @"📱";
    }
    user.isOfficial = [dict[@"verified"] integerValue] == 1;
    user.status = dict[@"status"];
    user.about = dict[@"about"];
    user.site = dict[@"site"];
    user.deactivated = dict[@"deactivated"];
    user.banReason = dict[@"ban_reason"];
    user.isGroup = NO;
    user.isFriend = [dict[@"friend_status"] integerValue] == 3 || [dict[@"is_friend"] integerValue] == 1;
    user.sex = [dict[@"sex"] integerValue];
    user.canWriteOnWall = [dict[@"can_write_on_wall"] integerValue] == 1;
    user.canPost = [dict[@"can_post"] integerValue] == 1;
    
    if ([dict[@"counters"] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *c = dict[@"counters"];
        user.photoCount = [c[@"photos"] integerValue];
        user.friendsCount = [c[@"friends"] integerValue];
        user.followersCount = [c[@"followers"] integerValue];
        user.groupsCount = [c[@"groups"] integerValue] ?: [c[@"pages"] integerValue];
        user.videoCount = [c[@"videos"] integerValue];
        user.audioCount = [c[@"audios"] integerValue];
    }
    
    return user;
}

+ (instancetype)groupFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKUser *group = [[VKUser alloc] init];
    NSInteger rawId = [dict[@"id"] integerValue];
    group.uid = -labs(rawId);
    group.username = dict[@"screen_name"] ?: [NSString stringWithFormat:@"club%ld", (long)labs(rawId)];
    group.displayName = dict[@"name"] ?: group.username;
    group.avatarURL = dict[@"photo_100"] ?: dict[@"photo_200"] ?: dict[@"photo_50"];
    group.isGroup = YES;
    group.isOfficial = [dict[@"verified"] integerValue] == 1;
    group.status = dict[@"status"] ?: dict[@"description"];
    group.isAdmin = [dict[@"is_admin"] integerValue] == 1;
    group.canPost = [dict[@"can_post"] integerValue] == 1;
    group.canSuggest = [dict[@"can_suggest"] integerValue] == 1;
    
    return group;
}

- (BOOL)isCurrentUser {
    NSString *token = [[NSUserDefaults standardUserDefaults] stringForKey:@"openvk.token"];
    if (!token || token.length == 0) return NO;
    VKUser *curr = [VKAuthService sharedService].currentUserModel;
    return (curr && curr.uid == self.uid);
}

- (BOOL)canCreatePost {
    if ([self accessStatus] != VKProfileAccessStatusActive) return NO;
    if ([self isCurrentUser]) return YES;
    if (self.isGroup) return self.isAdmin || self.canPost || self.canSuggest;
    if (self.isClosed && !self.canAccessClosed) return NO;
    return self.canWriteOnWall || self.canPost;
}

- (VKProfileAccessStatus)accessStatus {
    if ([self.deactivated isEqualToString:@"deleted"]) return VKProfileAccessStatusDeleted;
    if ([self.deactivated isEqualToString:@"banned"]) return VKProfileAccessStatusBanned;
    if (self.isBlacklisted) return VKProfileAccessStatusBlacklistedByThem;
    if (self.isClosed && !self.canAccessClosed) return VKProfileAccessStatusPrivateProfile;
    if (self.isBlacklistedByMe) return VKProfileAccessStatusBlacklistedByMe;
    return VKProfileAccessStatusActive;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = @(self.uid);
    if (self.username) dict[@"screen_name"] = self.username;
    if (self.displayName) dict[@"name"] = self.displayName;
    if (self.avatarURL) dict[@"photo_100"] = self.avatarURL;
    if (self.city) dict[@"city"] = self.city;
    dict[@"online"] = @(self.isOnline ? 1 : 0);
    dict[@"verified"] = @(self.isOfficial ? 1 : 0);
    dict[@"is_group"] = @(self.isGroup ? 1 : 0);
    if (self.status) dict[@"status"] = self.status;
    if (self.about) dict[@"about"] = self.about;
    if (self.site) dict[@"site"] = self.site;
    return dict;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.uid forKey:@"uid"];
    [coder encodeObject:self.username forKey:@"username"];
    [coder encodeObject:self.displayName forKey:@"displayName"];
    [coder encodeObject:self.avatarURL forKey:@"avatarURL"];
    [coder encodeObject:self.city forKey:@"city"];
    [coder encodeBool:self.isOnline forKey:@"isOnline"];
    [coder encodeBool:self.isOfficial forKey:@"isOfficial"];
    [coder encodeBool:self.isGroup forKey:@"isGroup"];
    [coder encodeObject:self.status forKey:@"status"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.uid = [coder decodeIntegerForKey:@"uid"];
        self.username = [coder decodeObjectForKey:@"username"];
        self.displayName = [coder decodeObjectForKey:@"displayName"];
        self.avatarURL = [coder decodeObjectForKey:@"avatarURL"];
        self.city = [coder decodeObjectForKey:@"city"];
        self.isOnline = [coder decodeBoolForKey:@"isOnline"];
        self.isOfficial = [coder decodeBoolForKey:@"isOfficial"];
        self.isGroup = [coder decodeBoolForKey:@"isGroup"];
        self.status = [coder decodeObjectForKey:@"status"];
    }
    return self;
}

@end
