#import <Foundation/Foundation.h>
#import "VKUser.h"

typedef NS_ENUM(NSInteger, VKNotificationType) {
    VKNotificationTypeLike = 0,
    VKNotificationTypeComment,
    VKNotificationTypeFriendRequest,
    VKNotificationTypeRepost,
    VKNotificationTypeMention,
    VKNotificationTypeWallPost,
    VKNotificationTypeGift,
    VKNotificationTypeVoicesTransfer,
    VKNotificationTypeRatingUp,
    VKNotificationTypeMakeAdmin
};

@interface VKNotification : NSObject

@property (nonatomic, copy) NSString *notificationId;
@property (nonatomic, assign) VKNotificationType type;
@property (nonatomic, strong) VKUser *user;
@property (nonatomic, copy) NSString *textPreview;
@property (nonatomic, copy) NSString *timeAgo;
@property (nonatomic, assign) BOOL isRead;
@property (nonatomic, copy) NSString *ratingValue;
@property (nonatomic, copy) NSString *giftImageURL;
@property (nonatomic, assign) NSInteger targetPostID;
@property (nonatomic, assign) NSInteger targetPostOwnerID;

+ (instancetype)notificationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups isArchived:(BOOL)isArchived;

@end
