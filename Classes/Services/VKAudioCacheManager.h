#import <Foundation/Foundation.h>
#import "VKAudioTrack.h"

@interface VKAudioCacheManager : NSObject

+ (instancetype)sharedManager;

- (BOOL)isTrackCached:(VKAudioTrack *)track;
- (NSString *)cachedFilePathForTrack:(VKAudioTrack *)track;
- (NSURL *)playbackURLForTrack:(VKAudioTrack *)track;

- (void)cacheTrack:(VKAudioTrack *)track completion:(void (^)(BOOL success, NSString *filePath))completion;
- (void)removeCachedTrack:(VKAudioTrack *)track;
- (NSArray<VKAudioTrack *> *)allCachedTracks;
- (unsigned long long)totalCacheSizeBytes;
- (void)clearAllCache;

@end
