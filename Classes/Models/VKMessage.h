#import <Foundation/Foundation.h>
#import "VKUser.h"

@interface VKMessage : NSObject

@property (nonatomic, assign) NSInteger messageId;
@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, assign) NSInteger fromId;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, copy) NSString *timeString;
@property (nonatomic, assign) BOOL isOutgoing;
@property (nonatomic, assign) BOOL isRead;
@property (nonatomic, strong) NSArray *attachments;

+ (instancetype)messageFromDictionary:(NSDictionary *)dict;

@end

@interface VKConversation : NSObject

@property (nonatomic, strong) VKUser *peerUser;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) VKMessage *lastMessage;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, assign) BOOL canWrite;

+ (instancetype)conversationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups;

@end
