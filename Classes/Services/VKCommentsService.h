#import <Foundation/Foundation.h>
#import "VKComment.h"

@interface VKCommentsService : NSObject

+ (instancetype)sharedService;

- (void)fetchCommentsForOwnerId:(NSInteger)ownerId
                         postId:(NSInteger)postId
                         offset:(NSInteger)offset
                          count:(NSInteger)count
                     completion:(void (^)(NSArray *comments, NSInteger totalCount, NSError *error))completion;

- (void)addCommentForOwnerId:(NSInteger)ownerId
                      postId:(NSInteger)postId
                     message:(NSString *)message
                  replyToCid:(NSInteger)replyToCid
                  completion:(void (^)(BOOL success, NSInteger commentId, NSError *error))completion;

- (void)likeCommentId:(NSInteger)commentId
              ownerId:(NSInteger)ownerId
               isLike:(BOOL)isLike
           completion:(void (^)(BOOL success))completion;

- (void)editCommentForOwnerId:(NSInteger)ownerId
                    commentId:(NSInteger)commentId
                      message:(NSString *)message
                   completion:(void (^)(BOOL success, NSError *error))completion;

- (void)deleteCommentForOwnerId:(NSInteger)ownerId
                      commentId:(NSInteger)commentId
                     completion:(void (^)(BOOL success, NSError *error))completion;

@end
