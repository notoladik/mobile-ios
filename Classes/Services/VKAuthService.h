#import <Foundation/Foundation.h>
#import "VKUser.h"

extern NSString *const VKAuthStatusDidChangeNotification;
extern NSString *const VKCountersDidUpdateNotification;

@interface VKAuthAccount : NSObject
@property (nonatomic, strong) VKUser *user;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *instanceHost;
@end

@interface VKAuthService : NSObject

@property (nonatomic, copy, readonly) NSString *accessToken;
@property (nonatomic, strong, readonly) VKUser *currentUserModel;
@property (nonatomic, strong, readonly) NSArray *accounts; // NSArray of VKAuthAccount
@property (nonatomic, assign, readonly) BOOL isAuthenticated;
@property (nonatomic, assign, readonly) BOOL requiresTwoFactor;

// Counters
@property (nonatomic, assign) NSInteger friendsCount;
@property (nonatomic, assign) NSInteger notificationsCount;
@property (nonatomic, assign) NSInteger messagesCount;
@property (nonatomic, assign) NSInteger balanceVotes;

+ (instancetype)sharedService;

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                     code:(NSString *)code
               completion:(void (^)(BOOL success, NSString *errorMsg, BOOL need2FA))completion;

- (void)switchToAccount:(VKAuthAccount *)account;
- (void)removeAccountWithUsername:(NSString *)username;
- (void)logout;
- (void)fetchCurrentUser:(void (^)(BOOL success))completion;
- (void)fetchCounters;
- (void)fetchBalance;
- (NSInteger)currentUserId;

@end
