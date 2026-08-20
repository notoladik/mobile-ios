#import <Foundation/Foundation.h>
#import "VKUser.h"
#import "VKPost.h"

@interface VKProfileService : NSObject

+ (instancetype)sharedService;

- (void)fetchProfileForUserId:(NSInteger)userId
                   completion:(void (^)(VKUser *user, NSError *error))completion;

- (void)fetchWallForOwnerId:(NSInteger)ownerId
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *posts, NSInteger totalCount, NSError *error))completion;

- (void)fetchFriendsForUserId:(NSInteger)userId
                   completion:(void (^)(NSArray *friends, NSError *error))completion;

- (void)fetchFriendsForUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *friends, NSInteger totalCount, NSError *error))completion;

- (void)fetchGroupsForUserId:(NSInteger)userId
                   completion:(void (^)(NSArray *groups, NSError *error))completion;

- (void)fetchGroupsForUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *groups, NSInteger totalCount, NSError *error))completion;

- (void)joinGroup:(NSInteger)groupId completion:(void (^)(BOOL success, NSError *error))completion;
- (void)leaveGroup:(NSInteger)groupId completion:(void (^)(BOOL success, NSError *error))completion;

- (void)addFriend:(NSInteger)userId completion:(void (^)(BOOL success, NSError *error))completion;
- (void)deleteFriend:(NSInteger)userId completion:(void (^)(BOOL success, NSError *error))completion;
- (void)fetchFriendRequestsWithCompletion:(void (^)(NSArray<VKUser *> *requests, NSInteger totalCount, NSError *error))completion;

@end
