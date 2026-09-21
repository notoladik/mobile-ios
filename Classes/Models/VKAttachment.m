#import "VKAttachment.h"
#import "NSNull+Safe.h"
#import "VKStickersService.h"

@implementation VKPollOption
@end

@implementation VKAttachment

+ (instancetype)attachmentFromDictionary:(NSDictionary *)dict {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    NSString *typeStr = dict[@"type"];
    if (!typeStr) return nil;
    
    VKAttachment *att = [[VKAttachment alloc] init];
    
    if ([typeStr isEqualToString:@"photo"]) {
        att.type = VKAttachmentTypePhoto;
        NSDictionary *p = dict[@"photo"];
        att.photoId = [p[@"id"] integerValue];
        att.ownerId = [p[@"owner_id"] integerValue];
        
        NSArray *sizes = p[@"sizes"];
        NSString *lowURL = nil;
        NSString *fullURL = nil;
        CGFloat lowW = 0, lowH = 0;
        CGFloat fullW = 0, fullH = 0;
        
        if ([sizes isKindOfClass:[NSArray class]] && sizes.count > 0) {
            NSDictionary *lowDict = nil;
            NSDictionary *fullDict = [sizes lastObject];
            
            for (NSDictionary *s in sizes) {
                NSString *st = s[@"type"];
                if ([st isEqualToString:@"m"] || [st isEqualToString:@"x"]) {
                    lowDict = s;
                    break;
                }
            }
            if (!lowDict) lowDict = sizes[0];
            
            for (NSDictionary *s in sizes) {
                NSString *st = s[@"type"];
                if ([st isEqualToString:@"w"] || [st isEqualToString:@"z"] || [st isEqualToString:@"y"]) {
                    fullDict = s;
                    break;
                }
            }
            
            lowURL = lowDict[@"url"] ?: lowDict[@"src"];
            lowW = [lowDict[@"width"] floatValue];
            lowH = [lowDict[@"height"] floatValue];
            
            fullURL = fullDict[@"url"] ?: fullDict[@"src"];
            fullW = [fullDict[@"width"] floatValue];
            fullH = [fullDict[@"height"] floatValue];
        } else {
            lowURL = p[@"photo_130"] ?: p[@"photo_604"] ?: p[@"photo_75"];
            fullURL = p[@"photo_1280"] ?: p[@"photo_807"] ?: p[@"photo_604"] ?: p[@"photo_130"];
            lowW = 320; lowH = 240;
            fullW = 800; fullH = 600;
        }
        
        att.photoURLLow = lowURL ?: fullURL;
        att.photoURLFull = fullURL ?: lowURL;
        
        NSInteger qualityPref = [[NSUserDefaults standardUserDefaults] integerForKey:@"VKPhotoQualityPreference"];
        if (qualityPref == 1) { // High quality
            att.photoURL = att.photoURLFull;
            att.photoWidth = (fullW > 0) ? fullW : (lowW > 0 ? lowW : 320);
            att.photoHeight = (fullH > 0) ? fullH : (lowH > 0 ? lowH : 240);
        } else { // Low quality (traffic saver) - default 0
            att.photoURL = att.photoURLLow;
            att.photoWidth = (lowW > 0) ? lowW : (fullW > 0 ? fullW : 320);
            att.photoHeight = (lowH > 0) ? lowH : (fullH > 0 ? fullH : 240);
        }
        
        att.photoLikes = [p[@"likes"][@"count"] integerValue];
        att.photoIsLiked = [p[@"likes"][@"user_likes"] integerValue] == 1;
        return att;
    }
    
    if ([typeStr isEqualToString:@"video"]) {
        att.type = VKAttachmentTypeVideo;
        NSDictionary *v = dict[@"video"];
        att.videoId = [v[@"id"] integerValue];
        att.videoTitle = v[@"title"] ?: @"Видеозапись";
        NSInteger sec = [v[@"duration"] integerValue];
        att.videoDuration = [NSString stringWithFormat:@"%ld:%02ld", (long)(sec / 60), (long)(sec % 60)];
        
        NSArray *imgs = v[@"image"];
        if ([imgs isKindOfClass:[NSArray class]] && imgs.count > 0) {
            att.videoImageURL = [imgs lastObject][@"url"];
        }
        
        NSDictionary *files = v[@"files"];
        if ([files isKindOfClass:[NSDictionary class]]) {
            att.videoURL = files[@"mp4_720"] ?: files[@"mp4_480"] ?: files[@"mp4_360"] ?: files[@"mp4_240"];
        }
        if (!att.videoURL) att.videoURL = v[@"player"];
        return att;
    }
    
    if ([typeStr isEqualToString:@"audio"]) {
        att.type = VKAttachmentTypeAudio;
        NSDictionary *a = dict[@"audio"];
        att.audioId = [a[@"id"] integerValue];
        att.audioOwnerId = [a[@"owner_id"] integerValue];
        att.audioArtist = a[@"artist"] ?: @"";
        att.audioTitle = a[@"title"] ?: @"";
        att.audioURL = a[@"url"] ?: a[@"stream_url"] ?: a[@"link"];
        NSInteger sec = [a[@"duration"] integerValue];
        att.audioDuration = [NSString stringWithFormat:@"%ld:%02ld", (long)(sec / 60), (long)(sec % 60)];
        return att;
    }
    
    if ([typeStr isEqualToString:@"doc"]) {
        NSDictionary *d = dict[@"doc"];
        NSString *ext = [d[@"ext"] lowercaseString];
        NSInteger docType = [d[@"type"] integerValue];
        
        if ([ext isEqualToString:@"gif"] || docType == 3 || d[@"preview"] != nil) {
            att.type = VKAttachmentTypeGif;
            att.docTitle = d[@"title"] ?: @"GIF";
            att.docURL = d[@"url"];
            
            // Превью гифки
            NSDictionary *prev = d[@"preview"];
            if ([prev isKindOfClass:[NSDictionary class]]) {
                NSDictionary *photo = prev[@"photo"];
                NSArray *sizes = photo[@"sizes"];
                if ([sizes isKindOfClass:[NSArray class]] && sizes.count > 0) {
                    NSDictionary *best = [sizes lastObject];
                    att.gifPreviewURL = best[@"src"] ?: best[@"url"];
                    att.gifWidth = [best[@"width"] floatValue];
                    att.gifHeight = [best[@"height"] floatValue];
                }
                NSDictionary *video = prev[@"video"];
                if ([video isKindOfClass:[NSDictionary class]] && video[@"src"]) {
                    att.docURL = video[@"src"];
                }
            }
            if (!att.gifPreviewURL) {
                att.gifPreviewURL = att.docURL;
            }
        } else {
            att.type = VKAttachmentTypeDoc;
            att.docTitle = d[@"title"] ?: @"Документ";
            att.docExt = ext.uppercaseString;
            att.docURL = d[@"url"];
            NSInteger bytes = [d[@"size"] integerValue];
            if (bytes < 1024 * 1024) {
                att.docSize = [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
            } else {
                att.docSize = [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
            }
        }
        return att;
    }
    
    if ([typeStr isEqualToString:@"link"]) {
        att.type = VKAttachmentTypeLink;
        NSDictionary *l = dict[@"link"];
        att.linkURL = l[@"url"];
        att.linkTitle = l[@"title"] ?: @"Ссылка";
        att.linkDescription = l[@"description"] ?: l[@"caption"] ?: @"";
        
        NSDictionary *p = l[@"photo"];
        if ([p isKindOfClass:[NSDictionary class]]) {
            NSArray *sizes = p[@"sizes"];
            if ([sizes isKindOfClass:[NSArray class]] && sizes.count > 0) {
                att.linkImageURL = [sizes lastObject][@"url"] ?: [sizes lastObject][@"src"];
            } else {
                att.linkImageURL = p[@"photo_604"] ?: p[@"photo_130"];
            }
        }
        if (!att.linkImageURL) {
            att.linkImageURL = l[@"image_src"] ?: l[@"preview_url"];
        }
        return att;
    }
    
    if ([typeStr isEqualToString:@"poll"]) {
        att.type = VKAttachmentTypePoll;
        NSDictionary *p = dict[@"poll"];
        att.pollId = [p[@"id"] integerValue];
        att.pollOwnerId = [p[@"owner_id"] integerValue];
        att.pollQuestion = p[@"question"] ?: @"Опрос";
        att.pollTotalVotes = [p[@"votes"] integerValue];
        
        NSMutableArray *opts = [NSMutableArray array];
        NSArray *answers = p[@"answers"];
        if ([answers isKindOfClass:[NSArray class]]) {
            for (NSDictionary *ans in answers) {
                VKPollOption *opt = [[VKPollOption alloc] init];
                opt.optionId = [ans[@"id"] integerValue];
                opt.text = ans[@"text"] ?: @"";
                opt.votes = [ans[@"votes"] integerValue];
                [opts addObject:opt];
            }
        }
        att.pollOptions = opts;
        return att;
    }
    
    if ([typeStr isEqualToString:@"sticker"]) {
        att.type = VKAttachmentTypeSticker;
        NSDictionary *s = dict[@"sticker"];
        att.stickerId = [s[@"sticker_id"] integerValue] ?: [s[@"id"] integerValue];
        
        NSArray *images = s[@"images"];
        if ([images isKindOfClass:[NSArray class]] && images.count > 0) {
            NSDictionary *best = [images lastObject];
            att.stickerURL = best[@"url"];
        } else {
            att.stickerURL = s[@"photo_352"] ?: s[@"photo_256"] ?: s[@"photo_128"] ?: s[@"photo_512"];
        }
        if ((!att.stickerURL || att.stickerURL.length == 0) && att.stickerId > 0) {
            att.stickerURL = [[VKStickersService sharedService] stickerURLForId:att.stickerId];
        }
        att.stickerURL = [[VKStickersService sharedService] normalizeURL:att.stickerURL];
        return att;
    }
    
    if ([typeStr isEqualToString:@"audio_message"]) {
        att.type = VKAttachmentTypeAudioMessage;
        NSDictionary *am = dict[@"audio_message"];
        att.audioMessageId = [am[@"id"] integerValue];
        att.audioMessageURL = am[@"link_mp3"] ?: am[@"link_ogg"];
        att.audioMessageDuration = [am[@"duration"] integerValue];
        return att;
    }
    
    if ([typeStr isEqualToString:@"wall"]) {
        att.type = VKAttachmentTypeWall;
        NSDictionary *w = dict[@"wall"];
        att.wallPostId = [w[@"id"] integerValue];
        att.wallOwnerId = [w[@"to_id"] integerValue] ?: [w[@"owner_id"] integerValue] ?: [w[@"from_id"] integerValue];
        att.wallText = w[@"text"] ?: @"";
        return att;
    }
    
    return nil;
}

@end
