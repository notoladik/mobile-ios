#import "VKSearchService.h"
#import "VKAPIClient.h"

@implementation VKSearchService

+ (instancetype)sharedService {
    static VKSearchService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)searchUsersWithQuery:(NSString *)query
                      offset:(NSInteger)offset
                       count:(NSInteger)count
                  completion:(void (^)(NSArray *users, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"q": query ?: @"",
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30),
        @"fields": @"photo_100,photo_200,online,verified,screen_name,city,status"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"users.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: ([resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[]);
            
            NSMutableArray *users = [NSMutableArray array];
            for (NSDictionary *item in items) {
                VKUser *u = [VKUser userFromDictionary:item];
                if (u) [users addObject:u];
            }
            if (completion) completion(users, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchGroupsWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *groups, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"q": query ?: @"",
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30),
        @"fields": @"photo_100,verified,screen_name,members_count,activity"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"groups.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: ([resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[]);
            
            NSMutableArray *groups = [NSMutableArray array];
            for (NSDictionary *item in items) {
                VKUser *g = [VKUser groupFromDictionary:item];
                if (g) [groups addObject:g];
            }
            if (completion) completion(groups, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchNewsWithQuery:(NSString *)query
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *posts, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"q": query ?: @"",
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30),
        @"extended": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"newsfeed.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *rawItems = resp[@"items"] ?: @[];
            NSArray *rawProfiles = resp[@"profiles"] ?: @[];
            NSArray *rawGroups = resp[@"groups"] ?: @[];
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in rawProfiles) {
                if (p[@"id"]) profiles[p[@"id"]] = p;
            }
            
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in rawGroups) {
                if (g[@"id"]) groups[g[@"id"]] = g;
            }
            
            NSMutableArray *posts = [NSMutableArray array];
            for (NSDictionary *item in rawItems) {
                VKPost *post = [VKPost postFromDictionary:item profiles:profiles groups:groups];
                if (post) [posts addObject:post];
            }
            
            if (completion) completion(posts, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchVideosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *videos, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"q": query ?: @"",
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 20),
        @"extended": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"video.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: @[];
            
            NSMutableArray *videos = [NSMutableArray array];
            for (NSDictionary *item in items) {
                VKAttachment *att = [[VKAttachment alloc] init];
                att.type = VKAttachmentTypeVideo;
                att.videoId = [item[@"id"] integerValue];
                att.ownerId = [item[@"owner_id"] integerValue];
                att.videoTitle = item[@"title"] ?: @"Видеозапись";
                att.videoImageURL = item[@"photo_320"] ?: item[@"photo_130"] ?: item[@"image"];
                att.videoURL = item[@"player"] ?: item[@"files"][@"mp4_720"] ?: item[@"files"][@"mp4_480"] ?: item[@"files"][@"mp4_360"] ?: item[@"files"][@"mp4_240"];
                
                NSInteger dur = [item[@"duration"] integerValue];
                if (dur > 0) {
                    att.videoDuration = [NSString stringWithFormat:@"%ld:%02ld", (long)(dur / 60), (long)(dur % 60)];
                } else {
                    att.videoDuration = @"0:00";
                }
                [videos addObject:att];
            }
            if (completion) completion(videos, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchAudiosWithQuery:(NSString *)query
                       offset:(NSInteger)offset
                        count:(NSInteger)count
                   completion:(void (^)(NSArray *audios, NSInteger totalCount, NSError *error))completion {
    
    NSString *method = (query.length > 0) ? @"audio.search" : @"audio.getPopular";
    NSDictionary *params = (query.length > 0) ? @{
        @"q": query,
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30)
    } : @{
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30)
    };
    
    [[VKAPIClient sharedClient] callMethod:method parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: ([resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[]);
            
            NSMutableArray *audios = [NSMutableArray array];
            for (NSDictionary *item in items) {
                VKAttachment *att = [[VKAttachment alloc] init];
                att.type = VKAttachmentTypeAudio;
                att.ownerId = [item[@"owner_id"] integerValue];
                att.audioArtist = item[@"artist"] ?: @"Исполнитель";
                att.audioTitle = item[@"title"] ?: @"Аудиозапись";
                att.docURL = item[@"url"]; // Ссылка на MP3
                
                NSInteger dur = [item[@"duration"] integerValue];
                if (dur > 0) {
                    att.audioDuration = [NSString stringWithFormat:@"%ld:%02ld", (long)(dur / 60), (long)(dur % 60)];
                } else {
                    att.audioDuration = @"3:00";
                }
                [audios addObject:att];
            }
            if (completion) completion(audios, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchDocsWithQuery:(NSString *)query
                     offset:(NSInteger)offset
                      count:(NSInteger)count
                 completion:(void (^)(NSArray *docs, NSInteger totalCount, NSError *error))completion {
    
    NSDictionary *params = @{
        @"q": query ?: @"",
        @"offset": @(offset),
        @"count": @(count > 0 ? count : 30)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"docs.search" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(nil, 0, error);
            return;
        }
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (resp) {
            NSInteger total = [resp[@"count"] integerValue];
            NSArray *items = resp[@"items"] ?: @[];
            
            NSMutableArray *docs = [NSMutableArray array];
            for (NSDictionary *item in items) {
                VKAttachment *att = [[VKAttachment alloc] init];
                att.type = VKAttachmentTypeDoc;
                att.docTitle = item[@"title"] ?: @"Документ";
                att.docExt = item[@"ext"] ?: @"doc";
                att.docURL = item[@"url"];
                NSInteger size = [item[@"size"] integerValue];
                if (size > 1024 * 1024) {
                    att.docSize = [NSString stringWithFormat:@"%.1f МБ", (float)size / (1024.0 * 1024.0)];
                } else {
                    att.docSize = [NSString stringWithFormat:@"%ld КБ", (long)(size / 1024)];
                }
                [docs addObject:att];
            }
            if (completion) completion(docs, total, nil);
            return;
        }
        if (completion) completion(@[], 0, nil);
    }];
}

- (void)searchAllWithQuery:(NSString *)query
                completion:(void (^)(NSArray *videos, NSArray *posts, NSArray *users, NSArray *groups, NSArray *audios))completion {
    
    __block NSArray *foundVideos = @[];
    __block NSArray *foundPosts = @[];
    __block NSArray *foundUsers = @[];
    __block NSArray *foundGroups = @[];
    __block NSArray *foundAudios = @[];
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);
    [self searchVideosWithQuery:query offset:0 count:4 completion:^(NSArray *videos, NSInteger totalCount, NSError *error) {
        if (videos) foundVideos = videos;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [self searchNewsWithQuery:query offset:0 count:10 completion:^(NSArray *posts, NSInteger totalCount, NSError *error) {
        if (posts) foundPosts = posts;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [self searchUsersWithQuery:query offset:0 count:5 completion:^(NSArray *users, NSInteger totalCount, NSError *error) {
        if (users) foundUsers = users;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [self searchGroupsWithQuery:query offset:0 count:5 completion:^(NSArray *groups, NSInteger totalCount, NSError *error) {
        if (groups) foundGroups = groups;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [self searchAudiosWithQuery:query offset:0 count:5 completion:^(NSArray *audios, NSInteger totalCount, NSError *error) {
        if (audios) foundAudios = audios;
        dispatch_group_leave(group);
    }];
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion) {
            completion(foundVideos, foundPosts, foundUsers, foundGroups, foundAudios);
        }
    });
}

@end
