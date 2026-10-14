#import "VKClientDesign.h"
#import "VKClientDesignGeometry.h"

NSString *const VKClientDesignDidChangeNotification = @"VKClientDesignDidChangeNotification";
NSString *const VKClientRoundAvatarsOption = @"roundAvatars";
NSString *const VKClientChatAvatarsOption = @"chatAvatars";
NSString *const VKClientTwoLinePreviewsOption = @"twoLinePreviews";
NSString *const VKClientProfileMenuOption = @"profileMenu";

@implementation VKClientDesign
+ (BOOL)isAndroidClientDesign {
    VKThemeType t = [VKThemeManager sharedManager].currentTheme;
    return t == VKThemeTypeKateMobile || t == VKThemeTypeAndroid;
}
+ (NSString *)keyForOption:(NSString *)option theme:(VKThemeType)theme {
    return [NSString stringWithFormat:@"openvk.clientDesign.%ld.%@", (long)theme, option];
}
+ (BOOL)boolForOption:(NSString *)option theme:(VKThemeType)theme {
    if (theme != VKThemeTypeKateMobile && theme != VKThemeTypeAndroid) return NO;
    id stored = [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForOption:option theme:theme]];
    if (stored) return [stored boolValue];
    if ([option isEqualToString:VKClientRoundAvatarsOption]) return YES;
    if ([option isEqualToString:VKClientProfileMenuOption]) {
        // Preserve an existing user's choice from the old Kate settings screen.
        id old = [[NSUserDefaults standardUserDefaults] objectForKey:@"kOpenVKKateProfileHubKey"];
        return theme == VKThemeTypeKateMobile && (!old || [old boolValue]);
    }
    return theme == VKThemeTypeKateMobile;
}
+ (void)notifyTheme:(VKThemeType)theme {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKClientDesignDidChangeNotification object:nil
        userInfo:@{@"theme": @(theme)}];
}
+ (void)setBool:(BOOL)value forOption:(NSString *)option theme:(VKThemeType)theme {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:[self keyForOption:option theme:theme]];
    [self notifyTheme:theme];
}
+ (BOOL)roundAvatars { return [self boolForOption:VKClientRoundAvatarsOption theme:[VKThemeManager sharedManager].currentTheme]; }
+ (BOOL)chatAvatars { return [self boolForOption:VKClientChatAvatarsOption theme:[VKThemeManager sharedManager].currentTheme]; }
+ (BOOL)twoLinePreviews { return [self boolForOption:VKClientTwoLinePreviewsOption theme:[VKThemeManager sharedManager].currentTheme]; }
+ (BOOL)profileMenu { return [self boolForOption:VKClientProfileMenuOption theme:[VKThemeManager sharedManager].currentTheme]; }
+ (CGFloat)messageFontSizeForTheme:(VKThemeType)theme {
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForOption:@"messageFontSize" theme:theme]];
    return (CGFloat)VKClientValidMessageFont(n ? n.doubleValue : 15.0);
}
+ (CGFloat)messageFontSize { return [self isAndroidClientDesign] ? [self messageFontSizeForTheme:[VKThemeManager sharedManager].currentTheme] : 15.0; }
+ (void)setMessageFontSize:(CGFloat)size theme:(VKThemeType)theme {
    [[NSUserDefaults standardUserDefaults] setDouble:VKClientValidMessageFont(size) forKey:[self keyForOption:@"messageFontSize" theme:theme]];
    [self notifyTheme:theme];
}
+ (NSInteger)firstTab {
    NSNumber *n = [[NSUserDefaults standardUserDefaults] objectForKey:[self keyForOption:@"firstTab" theme:VKThemeTypeKateMobile]];
    return VKClientValidFirstTab(n ? n.intValue : 0);
}
+ (void)setFirstTab:(NSInteger)index {
    [[NSUserDefaults standardUserDefaults] setInteger:VKClientValidFirstTab((int)index) forKey:[self keyForOption:@"firstTab" theme:VKThemeTypeKateMobile]];
    [self notifyTheme:VKThemeTypeKateMobile];
}
+ (void)resetTheme:(VKThemeType)theme {
    for (NSString *option in @[VKClientRoundAvatarsOption, VKClientChatAvatarsOption, VKClientTwoLinePreviewsOption,
                              VKClientProfileMenuOption, @"messageFontSize", @"firstTab"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[self keyForOption:option theme:theme]];
    }
    if (theme == VKThemeTypeKateMobile) [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"kOpenVKKateProfileHubKey"];
    [self notifyTheme:theme];
}
+ (UIImage *)iconNamed:(NSString *)name color:(UIColor *)color {
    UIImage *image = [UIImage imageNamed:name];
    if (!image || !color) return image;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [color setFill];
    UIRectFill(CGRectMake(0, 0, image.size.width, image.size.height));
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height) blendMode:kCGBlendModeDestinationIn alpha:1.0];
    UIImage *tinted = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tinted;
}
@end
