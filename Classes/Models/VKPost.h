#import <Foundation/Foundation.h>
#import "VKUser.h"
#import "VKAttachment.h"

@interface VKPost : NSObject

@property (nonatomic, assign) NSInteger vkID;
@property (nonatomic, assign) NSInteger ownerID;
@property (nonatomic, strong) VKUser *author;
@property (nonatomic, strong) VKUser *wallOwner;
@property (nonatomic, copy) NSString *platform;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *timeAgo;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSArray *attachments;
@property (nonatomic, assign) NSInteger likesCount;
@property (nonatomic, assign) NSInteger commentsCount;
@property (nonatomic, assign) NSInteger repostsCount;
@property (nonatomic, assign) BOOL isLiked;
@property (nonatomic, strong) NSArray *repostHistory;
@property (nonatomic, assign) BOOL isExplicit;
@property (nonatomic, copy) NSString *copyrightName;
@property (nonatomic, copy) NSString *copyrightLink;
@property (nonatomic, strong) VKUser *signerUser;

+ (instancetype)postFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups;
- (BOOL)isOnAlienWall;
- (BOOL)canRepost;

@end
