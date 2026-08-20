#import <Foundation/Foundation.h>

@interface VKSupporter : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *nick;
@property (nonatomic, copy) NSString *iconURL;
@property (nonatomic, copy) NSString *amount;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, strong) NSArray *profiles;
- (NSString *)displayName;
@end

@interface VKSupportersService : NSObject

@property (nonatomic, strong, readonly) NSArray<VKSupporter *> *testers;
@property (nonatomic, strong, readonly) NSArray<VKSupporter *> *donors;

+ (instancetype)sharedService;

- (void)fetchSupportersIfNeeded;
- (NSString *)badgeIconURLForScreenName:(NSString *)screenName;
- (VKSupporter *)supporterForScreenName:(NSString *)screenName;

@end
