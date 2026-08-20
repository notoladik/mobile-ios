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

- (void)fetchAudiosWithUserId:(NSInteger)userId
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray<VKAudioTrack *> *tracks, NSError *error))completion {
    
    NSDictionary *params = @{
        @"owner_id": @(userId),
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 40),
        @"need_user": @"0"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"audio.get" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            // Если метод не поддерживается сервером или вернул ошибку, возвращаем демо-треки
            if (completion) completion([self demoTracks], nil);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSArray *items = resp[@"items"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
        
        if (items && items.count > 0) {
            NSMutableArray *tracks = [NSMutableArray array];
            for (NSDictionary *d in items) {
                VKAudioTrack *t = [VKAudioTrack trackFromDictionary:d];
                if (t) [tracks addObject:t];
            }
            if (completion) completion(tracks, nil);
        } else {
            if (completion) completion([self demoTracks], nil);
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

@end
