#import "VKAudioTrack.h"

@implementation VKAudioTrack

+ (instancetype)trackFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKAudioTrack *track = [[VKAudioTrack alloc] init];
    track.trackId = [dict[@"id"] ?: dict[@"aid"] integerValue];
    track.audioId = track.trackId;
    track.ownerId = [dict[@"owner_id"] ?: dict[@"ownerId"] integerValue];
    
    id rawArtist = dict[@"artist"];
    track.artist = [rawArtist isKindOfClass:[NSString class]] ? rawArtist : @"Неизвестный исполнитель";
    
    id rawTitle = dict[@"title"];
    track.title = [rawTitle isKindOfClass:[NSString class]] ? rawTitle : @"Аудиозапись";
    
    track.durationSeconds = [dict[@"duration"] integerValue];
    NSInteger m = track.durationSeconds / 60;
    NSInteger s = track.durationSeconds % 60;
    track.duration = [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
    
    id rawUrl = dict[@"url"] ?: dict[@"mp3"] ?: dict[@"stream_url"];
    if ([rawUrl isKindOfClass:[NSString class]] && [rawUrl length] > 0) {
        track.streamURL = rawUrl;
    }
    
    id rawCover = dict[@"thumb"] ?: dict[@"cover"] ?: dict[@"cover_url"] ?: dict[@"photo_300"] ?: dict[@"album"][@"thumb"] ?: dict[@"album"][@"cover"];
    if ([rawCover isKindOfClass:[NSString class]] && [rawCover length] > 0) {
        track.coverURL = rawCover;
    } else if ([rawCover isKindOfClass:[NSDictionary class]]) {
        NSString *url = rawCover[@"photo_600"] ?: rawCover[@"photo_300"] ?: rawCover[@"photo_135"] ?: rawCover[@"photo_68"] ?: rawCover[@"src"];
        if ([url isKindOfClass:[NSString class]] && [url length] > 0) {
            track.coverURL = url;
        }
    }
    
    return track;
}

@end
