#import "VKAudioService.h"
#import "VKAPIClient.h"

@implementation VKAudioService

+ (instancetype)sharedService {
    static VKAudioService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (NSArray<VKAudioTrack *> *)parseTracksFromResponse:(id)response {
    if (!response) return @[];
    
    NSDictionary *respDict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
    id rawItems = respDict[@"items"] ?: respDict[@"audios"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
    
    NSMutableArray *tracks = [NSMutableArray array];
    if ([rawItems isKindOfClass:[NSArray class]]) {
        for (id item in rawItems) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                VKAudioTrack *t = [VKAudioTrack trackFromDictionary:item];
                if (t) [tracks addObject:t];
            }
        }
    }
    return tracks;
}

- (void)fetchAudiosWithUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    [self fetchAudiosWithUserId:userId albumId:0 offset:offset count:count completion:completion];
}

- (void)fetchAudiosWithUserId:(NSInteger)userId
                      albumId:(NSInteger)albumId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId != 0) {
        params[@"owner_id"] = @(userId);
    }
    if (albumId != 0) {
        params[@"album_id"] = @(albumId);
    }
    params[@"offset"] = @(offset);
    params[@"count"] = @(count > 0 ? count : 50);
    params[@"need_user"] = @"0";
    
    [[VKAPIClient sharedClient] callMethod:@"audio.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (offset == 0) {
                if (completion) completion([self demoTracks], error);
            } else {
                if (completion) completion(@[], error);
            }
            return;
        }
        
        NSArray<VKAudioTrack *> *tracks = [self parseTracksFromResponse:response];
        if (tracks.count > 0) {
            if (completion) completion(tracks, nil);
        } else {
            if (offset == 0) {
                if (completion) completion([self demoTracks], nil);
            } else {
                if (completion) completion(@[], nil);
            }
        }
    }];
}

- (void)fetchAlbumsWithUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioAlbum *> *albums, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (userId != 0) {
        params[@"owner_id"] = @(userId);
    }
    params[@"offset"] = @(offset);
    params[@"count"] = @(count > 0 ? count : 50);
    
    [[VKAPIClient sharedClient] callMethod:@"audio.getAlbums" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSDictionary *respDict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        id rawItems = respDict[@"items"] ?: respDict[@"albums"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
        
        NSMutableArray *albums = [NSMutableArray array];
        if ([rawItems isKindOfClass:[NSArray class]]) {
            for (id item in rawItems) {
                if ([item isKindOfClass:[NSDictionary class]]) {
                    VKAudioAlbum *a = [VKAudioAlbum albumFromDictionary:item];
                    if (a) [albums addObject:a];
                }
            }
        }
        if (completion) completion(albums, nil);
    }];
}

- (void)searchAudiosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    
    if (query.length == 0) {
        if (completion) completion(@[], nil);
        return;
    }
    
    NSDictionary *params = @{
        @"q": query,
        @"auto_complete": @"1",
        @"sort": @"2", // по популярности / релевантности
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 40)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(@[], error);
            return;
        }
        
        NSArray<VKAudioTrack *> *tracks = [self parseTracksFromResponse:response];
        if (completion) completion(tracks, nil);
    }];
}

- (void)fetchPopularAudiosWithOffset:(NSInteger)offset
                               count:(NSInteger)count
                          completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    
    NSDictionary *params = @{
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 40)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.getPopular" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion([self demoTracks], error);
            return;
        }
        
        NSArray<VKAudioTrack *> *tracks = [self parseTracksFromResponse:response];
        if (completion) completion(tracks.count > 0 ? tracks : [self demoTracks], nil);
    }];
}

- (void)fetchRecommendationsWithOffset:(NSInteger)offset
                                 count:(NSInteger)count
                            completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    
    NSDictionary *params = @{
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 40)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.getRecommendations" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion([self demoTracks], error);
            return;
        }
        
        NSArray<VKAudioTrack *> *tracks = [self parseTracksFromResponse:response];
        if (completion) completion(tracks.count > 0 ? tracks : [self demoTracks], nil);
    }];
}

- (void)addAudioWithAudioId:(NSInteger)audioId
                    ownerId:(NSInteger)ownerId
                 completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSDictionary *params = @{
        @"audio_id": @(audioId),
        @"owner_id": @(ownerId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.add" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)deleteAudioWithAudioId:(NSInteger)audioId
                       ownerId:(NSInteger)ownerId
                    completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSDictionary *params = @{
        @"audio_id": @(audioId),
        @"owner_id": @(ownerId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.delete" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)getLyricsWithLyricsId:(NSInteger)lyricsId
                   completion:(void (^)(NSString *lyricsText, NSError *error))completion {
    
    NSDictionary *params = @{
        @"lyrics_id": @(lyricsId)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.getLyrics" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSString *text = resp[@"text"] ?: ([response isKindOfClass:[NSString class]] ? response : nil);
        if (completion) completion(text, nil);
    }];
}

- (void)setBroadcastAudio:(NSString *)audioIdString
               completion:(void (^)(BOOL success, NSError *error))completion {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (audioIdString.length > 0) {
        params[@"audio"] = audioIdString;
    }
    
    [[VKAPIClient sharedClient] callMethod:@"audio.setBroadcast" parameters:params completionHandler:^(id response, NSError *error) {
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (NSArray<VKAudioTrack *> *)demoTracks {
    NSArray *demoData = @[
        @{@"title": @"Я волна (DJ Smash Remix)", @"artist": @"DJ Smash feat. Fast Food", @"duration": @(248), @"url": @"https://files.nikanikoo.com/demo1.mp3"},
        @{@"title": @"Районы-кварталы", @"artist": @"Звери", @"duration": @(203), @"url": @"https://files.nikanikoo.com/demo2.mp3"},
        @{@"title": @"WWW Ленинград", @"artist": @"Ленинград", @"duration": @(170), @"url": @""},
        @{@"title": @"Седьмой лепесток", @"artist": @"Hi-Fi", @"duration": @(212), @"url": @""},
        @{@"title": @"Chop Suey!", @"artist": @"System of a Down", @"duration": @(210), @"url": @""},
        @{@"title": @"In the End", @"artist": @"Linkin Park", @"duration": @(216), @"url": @""},
        @{@"title": @"Белая стрекоза любви", @"artist": @"Quest Pistols", @"duration": @(185), @"url": @""},
        @{@"title": @"Мой рок-н-ролл", @"artist": @"Би-2 feat. Чичерина", @"duration": @(384), @"url": @""}
    ];
    
    NSMutableArray *res = [NSMutableArray array];
    for (NSDictionary *d in demoData) {
        VKAudioTrack *t = [VKAudioTrack trackFromDictionary:d];
        if (t) [res addObject:t];
    }
    return res;
}

@end
