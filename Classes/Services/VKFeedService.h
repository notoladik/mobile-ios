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
                 copyright:(NSString *)copyright
                  explicit:(BOOL)explicit
                 fromGroup:(BOOL)fromGroup
                completion:(void (^)(BOOL success, NSError *error))completion;

- (void)uploadWallPhoto:(UIImage *)image
                ownerId:(NSInteger)ownerId
             completion:(void (^)(NSString *attachmentString, NSError *error))completion;

- (void)createPollWithQuestion:(NSString *)question
                       answers:(NSArray<NSString *> *)answers
                   isAnonymous:(BOOL)isAnonymous
                       ownerId:(NSInteger)ownerId
                    completion:(void (^)(NSString *attachmentString, NSError *error))completion;

- (void)repostPost:(VKPost *)post
           message:(NSString *)message
           groupId:(NSInteger)groupId
        completion:(void (^)(BOOL success, NSError *error))completion;

@end
