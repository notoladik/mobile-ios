#import <Foundation/Foundation.h>
#import "VKUser.h"
#import "VKAttachment.h"

@interface VKComment : NSObject

@property (nonatomic, assign) NSInteger commentId;
@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, assign) NSInteger fromId;
@property (nonatomic, strong) VKUser *author;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *timeAgo;
@property (nonatomic, strong) NSArray *attachments;
@property (nonatomic, assign) NSInteger likesCount;
@property (nonatomic, assign) BOOL isLiked;

// Ветки и ответы
@property (nonatomic, assign) NSInteger replyToComment;
@property (nonatomic, assign) NSInteger replyToUser;
@property (nonatomic, strong) VKUser *replyToAuthor;
@property (nonatomic, assign) NSInteger threadLevel;
@property (nonatomic, weak) VKComment *parentComment;

+ (instancetype)commentFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups;

@end
