#import <Foundation/Foundation.h>
#import "VKAudioTrack.h"

@interface VKAudioService : NSObject

+ (instancetype)sharedService;

- (void)fetchAudiosWithUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion;

- (void)addAudioWithAudioId:(NSInteger)audioId
                    ownerId:(NSInteger)ownerId
                 completion:(void (^)(BOOL success, NSError *error))completion;

@end
