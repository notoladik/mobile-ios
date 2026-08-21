#import "VKAudioAlbum.h"

@implementation VKAudioAlbum

+ (instancetype)albumFromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    VKAudioAlbum *album = [[VKAudioAlbum alloc] init];
    album.albumId = [dict[@"id"] ?: dict[@"album_id"] integerValue];
    album.ownerId = [dict[@"owner_id"] integerValue];
    
    id rawTitle = dict[@"title"];
    album.title = [rawTitle isKindOfClass:[NSString class]] ? rawTitle : @"Без названия";
    
    album.trackCount = [dict[@"count"] ?: dict[@"size"] ?: dict[@"tracks_count"] integerValue];
    
    id rawThumb = dict[@"thumb"] ?: dict[@"photo"] ?: dict[@"cover"];
    if ([rawThumb isKindOfClass:[NSString class]] && [rawThumb length] > 0) {
        album.thumbURL = rawThumb;
    } else if ([rawThumb isKindOfClass:[NSDictionary class]]) {
        NSString *url = rawThumb[@"photo_600"] ?: rawThumb[@"photo_300"] ?: rawThumb[@"photo_135"] ?: rawThumb[@"src"];
        if ([url isKindOfClass:[NSString class]]) {
            album.thumbURL = url;
        }
    }
    
    return album;
}

@end
