#import <Foundation/Foundation.h>
#import "VKAudioTrack.h"

@interface VKAudioService : NSObject

+ (instancetype)sharedService;

- (void)fetchAudiosWithUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion;

- (void)searchAudiosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion;

- (void)fetchPopularAudiosWithOffset:(NSInteger)offset
                               count:(NSInteger)count
                          completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion;

- (void)fetchRecommendationsWithOffset:(NSInteger)offset
                                 count:(NSInteger)count
                            completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion;

- (void)addAudioWithAudioId:(NSInteger)audioId
                    ownerId:(NSInteger)ownerId
                 completion:(void (^)(BOOL success, NSError *error))completion;

- (void)deleteAudioWithAudioId:(NSInteger)audioId
                       ownerId:(NSInteger)ownerId
                    completion:(void (^)(BOOL success, NSError *error))completion;

- (void)getLyricsWithLyricsId:(NSInteger)lyricsId
                   completion:(void (^)(NSString *lyricsText, NSError *error))completion;

- (void)setBroadcastAudio:(NSString *)audioIdString
               completion:(void (^)(BOOL success, NSError *error))completion;

@end
