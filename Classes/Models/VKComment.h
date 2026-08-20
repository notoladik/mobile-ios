#import <Foundation/Foundation.h>
#import "VKUser.h"
#import "VKAttachment.h"

@interface VKComment : NSObject

@property (nonatomic, assign) NSInteger commentId;
@property (nonatomic, assign) NSInteger fromId;
@property (nonatomic, strong) VKUser *author;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *timeAgo;
@property (nonatomic, strong) NSArray *attachments;
@property (nonatomic, assign) NSInteger likesCount;
@property (nonatomic, assign) BOOL isLiked;

+ (instancetype)commentFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups;

@end
