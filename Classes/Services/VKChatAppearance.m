#import "VKChatAppearance.h"
#import "VKAppConfig.h"
#import "VKAuthService.h"
#import "VKUser.h"
#import <CommonCrypto/CommonDigest.h>
#import <math.h>

NSString *const VKChatAppearanceDidChangeNotification = @"VKChatAppearanceDidChangeNotification";

@implementation VKChatAppearance
+ (NSString *)namespace {
    NSString *identity = [NSString stringWithFormat:@"%@|%ld", [VKAppConfig currentHost], (long)[[VKAuthService sharedService] currentUserModel].uid];
    NSData *data = [identity dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(digest); ++i) [result appendFormat:@"%02x", digest[i]];
    return result;
}
+ (NSString *)keyForPeerId:(NSInteger)peerId {
    return [NSString stringWithFormat:@"openvk.chat.appearance.%@.%ld", [self namespace], (long)peerId];
}
+ (NSString *)wallpaperPathForPeerId:(NSInteger)peerId {
    NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"ChatWallpapers"];
    return [root stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%ld.jpg", [self namespace], (long)peerId]];
}
+ (void)notifyChange:(NSInteger)peerId {
    [[NSNotificationCenter defaultCenter] postNotificationName:VKChatAppearanceDidChangeNotification object:nil userInfo:@{@"peerId": @(peerId)}];
}
+ (void)migrateLegacyWallpaper {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    /* One migration, not one per account: do not copy an old account's photo
       into every subsequently logged-in account. Leave the original intact. */
    NSString *marker = @"openvk.chat.appearance.legacyMigrated";
    if ([ud boolForKey:marker]) return;
    NSString *oldPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"chat_wallpaper.jpg"];
    if (![ud objectForKey:[self keyForPeerId:0]]) {
        NSData *data = [NSData dataWithContentsOfFile:oldPath];
        if (data && [UIImage imageWithData:data]) {
            NSString *path = [self wallpaperPathForPeerId:0];
            if (![[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil]) return;
            if (![data writeToFile:path atomically:YES]) return;
            [ud setObject:@{@"mode": @(VKChatBackgroundModePhoto), @"style": @(VKBackgroundVisualizerStyleAVS), @"opacity": @0.25, @"onlyPlaying": @YES} forKey:[self keyForPeerId:0]];
        }
    }
    [ud setBool:YES forKey:marker];
}
+ (NSDictionary *)settingsForPeerId:(NSInteger)peerId {
    [self migrateLegacyWallpaper];
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForPeerId:peerId]];
    NSMutableDictionary *s = [@{@"mode": @(VKChatBackgroundModeDefault), @"style": @(VKBackgroundVisualizerStyleAVS), @"opacity": @0.25, @"onlyPlaying": @YES} mutableCopy];
    if ([stored isKindOfClass:[NSDictionary class]]) [s addEntriesFromDictionary:stored];
    NSInteger mode = [s[@"mode"] integerValue];
    if (mode < 0 || mode > VKChatBackgroundModeVisualizer) s[@"mode"] = @(VKChatBackgroundModeDefault);
    NSInteger style = [s[@"style"] integerValue];
    if (style != VKBackgroundVisualizerStyleAVS && style != VKBackgroundVisualizerStyleMilkdrop) {
        s[@"style"] = @(VKBackgroundVisualizerStyleAVS);
    }
    CGFloat opacity = [s[@"opacity"] floatValue];
    s[@"opacity"] = @(isfinite(opacity) ? MAX(0.05, MIN(0.6, opacity)) : 0.25);
    return s;
}
+ (NSDictionary *)effectiveSettingsForPeerId:(NSInteger)peerId {
    NSDictionary *settings = [self settingsForPeerId:peerId];
    if (peerId != 0 && [settings[@"mode"] integerValue] == VKChatBackgroundModeDefault) return [self settingsForPeerId:0];
    return settings;
}
+ (void)setValue:(id)value forSetting:(NSString *)key peerId:(NSInteger)peerId {
    if (![@[@"mode", @"style", @"opacity", @"onlyPlaying"] containsObject:key] || !value) return;
    NSMutableDictionary *settings = [[self settingsForPeerId:peerId] mutableCopy];
    settings[key] = value;
    [[NSUserDefaults standardUserDefaults] setObject:settings forKey:[self keyForPeerId:peerId]];
    [self notifyChange:peerId];
}
+ (void)resetPeerId:(NSInteger)peerId {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self keyForPeerId:peerId]];
    [[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPathForPeerId:peerId] error:nil];
    [self notifyChange:peerId];
}
+ (BOOL)hasOwnWallpaperForPeerId:(NSInteger)peerId {
    [self migrateLegacyWallpaper];
    return [[NSFileManager defaultManager] fileExistsAtPath:[self wallpaperPathForPeerId:peerId]];
}
+ (UIImage *)wallpaperForPeerId:(NSInteger)peerId {
    NSDictionary *raw = [self settingsForPeerId:peerId];
    NSDictionary *effective = [self effectiveSettingsForPeerId:peerId];
    if ([effective[@"mode"] integerValue] != VKChatBackgroundModePhoto) return nil;
    NSInteger source = peerId != 0 && [raw[@"mode"] integerValue] == VKChatBackgroundModeDefault ? 0 : peerId;
    return [UIImage imageWithContentsOfFile:[self wallpaperPathForPeerId:source]];
}
+ (BOOL)saveWallpaper:(UIImage *)image peerId:(NSInteger)peerId error:(NSError **)error {
    if (!image || image.size.width <= 0 || image.size.height <= 0) {
        if (error) *error = [NSError errorWithDomain:@"VKChatAppearance" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Не удалось прочитать изображение"}];
        return NO;
    }
    /* Bound memory and disk usage, flatten orientation at scale 1. */
    CGFloat scale = MIN(1.0, 1600.0 / MAX(image.size.width, image.size.height));
    CGSize size = CGSizeMake(MAX(1, floor(image.size.width * scale)), MAX(1, floor(image.size.height * scale)));
    UIGraphicsBeginImageContextWithOptions(size, YES, 1.0);
    [[UIColor whiteColor] setFill];
    UIRectFill((CGRect){CGPointZero, size});
    [image drawInRect:(CGRect){CGPointZero, size}];
    UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *jpeg = scaled ? UIImageJPEGRepresentation(scaled, 0.85) : nil;
    if (!jpeg) {
        if (error) *error = [NSError errorWithDomain:@"VKChatAppearance" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Не удалось подготовить обои"}];
        return NO;
    }
    NSString *path = [self wallpaperPathForPeerId:peerId];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    if (![jpeg writeToFile:path options:NSDataWritingAtomic error:error]) return NO;
    [self setValue:@(VKChatBackgroundModePhoto) forSetting:@"mode" peerId:peerId];
    return YES;
}
+ (void)removeWallpaperForPeerId:(NSInteger)peerId {
    [[NSFileManager defaultManager] removeItemAtPath:[self wallpaperPathForPeerId:peerId] error:nil];
    [self setValue:@(VKChatBackgroundModeNone) forSetting:@"mode" peerId:peerId];
}
@end
