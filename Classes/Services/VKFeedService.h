#import <Foundation/Foundation.h>
#import "VKPost.h"

@interface VKFeedService : NSObject

+ (instancetype)sharedService;

- (void)fetchFeedIsGlobal:(BOOL)isGlobal
                startFrom:(NSString *)startFrom
               completion:(void (^)(NSArray *posts, NSString *nextFrom, NSError *error))completion;

- (void)likePost:(VKPost *)post
      completion:(void (^)(VKPost *updatedPost, NSError *error))completion;

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion;

- (void)createPostWithText:(NSString *)text
                   ownerId:(NSInteger)ownerId
               attachments:(NSString *)attachments
                  explicit:(BOOL)explicit
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion;

- (void)repostPost:(VKPost *)post
           message:(NSString *)message
           groupId:(NSInteger)groupId
        completion:(void (^)(BOOL success, NSError *error))completion;

@end
