#import "VKAudioCacheManager.h"
#import "VKCrashLogger.h"

@interface VKAudioCacheManager ()
@property (nonatomic, copy) NSString *cacheDirectory;
@property (nonatomic, copy) NSString *indexFilePath;
@property (nonatomic, strong) NSMutableDictionary *metadataIndex;
@end

@implementation VKAudioCacheManager

+ (instancetype)sharedManager {
    static VKAudioCacheManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = paths.firstObject;
        _cacheDirectory = [docDir stringByAppendingPathComponent:@"AudioCache"];
        _indexFilePath = [_cacheDirectory stringByAppendingPathComponent:@"cache_index.json"];
        
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_cacheDirectory isDirectory:&isDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_cacheDirectory withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        [self loadIndex];
    }
    return self;
}

- (void)loadIndex {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.indexFilePath]) {
        NSData *data = [NSData dataWithContentsOfFile:self.indexFilePath];
        if (data) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                self.metadataIndex = [dict mutableCopy];
                return;
            }
        }
    }
    self.metadataIndex = [NSMutableDictionary dictionary];
}

- (void)saveIndex {
    @synchronized (self) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:self.metadataIndex options:NSJSONWritingPrettyPrinted error:nil];
        [data writeToFile:self.indexFilePath atomically:YES];
    }
}

- (NSString *)keyForTrack:(VKAudioTrack *)track {
    if (!track) return @"";
    return [NSString stringWithFormat:@"%ld_%ld", (long)track.ownerID, (long)track.vkID];
}

- (NSString *)cachedFilePathForTrack:(VKAudioTrack *)track {
    if (!track) return nil;
    NSString *fileName = [NSString stringWithFormat:@"audio_%ld_%ld.mp3", (long)track.ownerID, (long)track.vkID];
    return [self.cacheDirectory stringByAppendingPathComponent:fileName];
}

- (BOOL)isTrackCached:(VKAudioTrack *)track {
    if (!track) return NO;
    NSString *path = [self cachedFilePathForTrack:track];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSURL *)playbackURLForTrack:(VKAudioTrack *)track {
    if (!track) return nil;
    if ([self isTrackCached:track]) {
        NSString *path = [self cachedFilePathForTrack:track];
        return [NSURL fileURLWithPath:path];
    }
    if (track.url.length > 0) {
        return [NSURL URLWithString:track.url];
    }
    return nil;
}

- (void)cacheTrack:(VKAudioTrack *)track completion:(void (^)(BOOL success, NSString *filePath))completion {
    if (!track || track.url.length == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    
    NSString *destPath = [self cachedFilePathForTrack:track];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
        if (completion) completion(YES, destPath);
        return;
    }
    
    [VKCrashLogger log:@"[VKAudioCacheManager] Caching track %@ - %@...", track.artist, track.title];
    
    NSURL *downloadURL = [NSURL URLWithString:track.url];
    NSURLRequest *req = [NSURLRequest requestWithURL:downloadURL];
    
    if (NSClassFromString(@"NSURLSession")) {
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:req completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error || !location) {
                [VKCrashLogger log:@"[VKAudioCacheManager] Download error: %@", error];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO, nil);
                    });
                }
                return;
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:destPath error:nil];
            NSError *moveErr = nil;
            [[NSFileManager defaultManager] moveItemAtPath:[location path] toPath:destPath error:&moveErr];
            
            if (!moveErr) {
                @synchronized (self) {
                    self.metadataIndex[[self keyForTrack:track]] = @{
                        @"id": @(track.vkID),
                        @"owner_id": @(track.ownerID),
                        @"artist": track.artist ?: @"",
                        @"title": track.title ?: @"",
                        @"duration": @(track.durationSeconds),
                        @"cached_at": @([[NSDate date] timeIntervalSince1970])
                    };
                    [self saveIndex];
                }
                [VKCrashLogger log:@"[VKAudioCacheManager] Track cached successfully to %@", destPath];
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(YES, destPath);
                    });
                }
            } else {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO, nil);
                    });
                }
            }
        }];
        [task resume];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:downloadURL];
            if (data && data.length > 0) {
                [data writeToFile:destPath atomically:YES];
                @synchronized (self) {
                    self.metadataIndex[[self keyForTrack:track]] = @{
                        @"id": @(track.vkID),
                        @"owner_id": @(track.ownerID),
                        @"artist": track.artist ?: @"",
                        @"title": track.title ?: @"",
                        @"duration": @(track.durationSeconds),
                        @"cached_at": @([[NSDate date] timeIntervalSince1970])
                    };
                    [self saveIndex];
                }
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(YES, destPath);
                    });
                }
            } else {
                if (completion) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(NO, nil);
                    });
                }
            }
        });
    }
}

- (void)removeCachedTrack:(VKAudioTrack *)track {
    if (!track) return;
    NSString *path = [self cachedFilePathForTrack:track];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    @synchronized (self) {
        [self.metadataIndex removeObjectForKey:[self keyForTrack:track]];
        [self saveIndex];
    }
}

- (NSArray<VKAudioTrack *> *)allCachedTracks {
    NSMutableArray *res = [NSMutableArray array];
    @synchronized (self) {
        for (NSString *key in self.metadataIndex) {
            NSDictionary *d = self.metadataIndex[key];
            VKAudioTrack *t = [VKAudioTrack trackFromDictionary:d];
            if (t && [self isTrackCached:t]) {
                [res addObject:t];
            }
        }
    }
    return res;
}

- (unsigned long long)totalCacheSizeBytes {
    unsigned long long total = 0;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDirectory error:nil];
    for (NSString *f in files) {
        NSString *fp = [self.cacheDirectory stringByAppendingPathComponent:f];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fp error:nil];
        total += [attrs fileSize];
    }
    return total;
}

- (void)clearAllCache {
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cacheDirectory error:nil];
    for (NSString *f in files) {
        NSString *fp = [self.cacheDirectory stringByAppendingPathComponent:f];
        [[NSFileManager defaultManager] removeItemAtPath:fp error:nil];
    }
    @synchronized (self) {
        [self.metadataIndex removeAllObjects];
        [self saveIndex];
    }
}

@end
