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
@property (nonatomic, strong) NSArray<VKMessage *> *fwdMessages;
@property (nonatomic, strong) VKMessage *replyMessage;

// Сервисные действия в беседах
@property (nonatomic, copy) NSString *action;
@property (nonatomic, assign) NSInteger actionMid;
@property (nonatomic, copy) NSString *actionText;
@property (nonatomic, copy) NSString *actionEmail;
@property (nonatomic, strong) VKUser *senderUser;

+ (instancetype)messageFromDictionary:(NSDictionary *)dict;

- (BOOL)isServiceAction;
- (NSString *)serviceActionText;
- (NSString *)displayText;

@end

@interface VKConversation : NSObject

@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) VKUser *peerUser;
@property (nonatomic, strong) VKMessage *lastMessage;
@property (nonatomic, assign) NSInteger unreadCount;
@property (nonatomic, assign) BOOL canWrite;

// Поля бесед и сообществ
@property (nonatomic, assign) BOOL isChat;
@property (nonatomic, assign) BOOL isGroup;
@property (nonatomic, assign) NSInteger chatId;
@property (nonatomic, copy) NSString *chatPhotoURL;
@property (nonatomic, assign) NSInteger membersCount;
@property (nonatomic, assign) NSInteger adminId;
@property (nonatomic, strong) NSArray *activeMemberIds;

+ (instancetype)conversationFromDictionary:(NSDictionary *)dict profiles:(NSDictionary *)profiles groups:(NSDictionary *)groups;

- (NSString *)displayTitle;
- (NSString *)displayAvatarURL;
- (NSString *)previewText;

@end
