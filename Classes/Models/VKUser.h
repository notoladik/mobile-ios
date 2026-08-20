#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, VKProfileAccessStatus) {
    VKProfileAccessStatusActive = 0,
    VKProfileAccessStatusDeleted,
    VKProfileAccessStatusBanned,
    VKProfileAccessStatusBlacklistedByThem,
    VKProfileAccessStatusBlacklistedByMe,
    VKProfileAccessStatusPrivateProfile
};

@interface VKUser : NSObject <NSCoding>

@property (nonatomic, assign) NSInteger uid;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *avatarURL;
@property (nonatomic, copy) NSString *city;
@property (nonatomic, assign) BOOL isOnline;
@property (nonatomic, copy) NSString *onlinePlatform;
@property (nonatomic, copy) NSString *lastSeen;
@property (nonatomic, assign) BOOL isGroup;
@property (nonatomic, assign) BOOL isFriend;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) NSInteger photoCount;
@property (nonatomic, assign) NSInteger friendsCount;
@property (nonatomic, assign) NSInteger followersCount;
@property (nonatomic, assign) NSInteger groupsCount;
@property (nonatomic, assign) NSInteger videoCount;
@property (nonatomic, assign) NSInteger audioCount;
@property (nonatomic, copy) NSString *about;
@property (nonatomic, copy) NSString *site;
@property (nonatomic, assign) BOOL isOfficial;
@property (nonatomic, copy) NSString *deactivated;
@property (nonatomic, copy) NSString *banReason;
@property (nonatomic, assign) BOOL isClosed;
@property (nonatomic, assign) BOOL canAccessClosed;
@property (nonatomic, assign) BOOL isBlacklisted;
@property (nonatomic, assign) BOOL isBlacklistedByMe;
@property (nonatomic, assign) NSInteger sex;
@property (nonatomic, assign) BOOL isAdmin;
@property (nonatomic, assign) BOOL canPost;
@property (nonatomic, assign) BOOL canSuggest;
@property (nonatomic, assign) BOOL canWriteOnWall;

+ (instancetype)userFromDictionary:(NSDictionary *)dict;
+ (instancetype)groupFromDictionary:(NSDictionary *)dict;

- (BOOL)isCurrentUser;
- (BOOL)canCreatePost;
- (VKProfileAccessStatus)accessStatus;
- (NSDictionary *)dictionaryRepresentation;

@end
