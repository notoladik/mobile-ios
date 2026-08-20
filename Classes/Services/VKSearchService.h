#import <Foundation/Foundation.h>
#import "VKUser.h"
#import "VKPost.h"
#import "VKAttachment.h"

@interface VKSearchService : NSObject

+ (instancetype)sharedService;

- (void)searchUsersWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       count:(NSInteger)count
                  completion:(void (^)(NSArray *users, NSInteger totalCount, NSError *error))completion;

- (void)searchGroupsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *groups, NSInteger totalCount, NSError *error))completion;

- (void)searchNewsWithQuery:(NSString *)query
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *posts, NSInteger totalCount, NSError *error))completion;

- (void)searchVideosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *videos, NSInteger totalCount, NSError *error))completion;

- (void)searchAudiosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *audios, NSInteger totalCount, NSError *error))completion;

- (void)searchDocsWithQuery:(NSString *)query
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *docs, NSInteger totalCount, NSError *error))completion;

- (void)searchAllWithQuery:(NSString *)query
                completion:(void (^)(NSArray *videos, NSArray *posts, NSArray *users, NSArray *groups, NSArray *audios))completion;

@end
