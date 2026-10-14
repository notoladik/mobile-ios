#import "VKKateTheme.h"
#import "VKThemeManager.h"

NSString *const VKKateThemeDidChangeNotification = @"VKKateThemeDidChangeNotification";
static NSString *const kKateThemePrefKey = @"key_theme";

static inline UIColor *VKColorHex(UInt32 hex, CGFloat alpha) {
    return [UIColor colorWithRed:((CGFloat)((hex >> 16) & 0xFF)) / 255.0
                           green:((CGFloat)((hex >> 8) & 0xFF)) / 255.0
                            blue:((CGFloat)(hex & 0xFF)) / 255.0
                           alpha:alpha];
}

@interface VKKateTheme ()

@property (nonatomic, assign, readwrite) VKKateThemeId themeId;
@property (nonatomic, copy, readwrite) NSString *name;
@property (nonatomic, assign, readwrite) BOOL isDark;

@property (nonatomic, strong, readwrite) UIColor *headerColor;
@property (nonatomic, strong, readwrite) UIColor *headerTitleColor;
@property (nonatomic, strong, readwrite) UIColor *headerSubtitleColor;

@property (nonatomic, strong, readwrite) UIColor *tabsBackgroundColor;
@property (nonatomic, strong, readwrite) UIColor *tabTextSelectedColor;
@property (nonatomic, strong, readwrite) UIColor *tabTextNormalColor;
@property (nonatomic, strong, readwrite) UIColor *tabIndicatorColor;
@property (nonatomic, strong, readwrite) UIColor *tabDividerColor;

@property (nonatomic, strong, readwrite) UIColor *backgroundColor;
@property (nonatomic, strong, readwrite) UIColor *cardBackgroundColor;
@property (nonatomic, strong, readwrite) UIColor *cardBorderColor;

@property (nonatomic, strong, readwrite) UIColor *primaryTextColor;
@property (nonatomic, strong, readwrite) UIColor *secondaryTextColor;
@property (nonatomic, strong, readwrite) UIColor *postLinkColor;

@property (nonatomic, strong, readwrite) UIColor *unreadItemBackgroundColor;
@property (nonatomic, strong, readwrite) UIColor *unreadBadgeColor;
@property (nonatomic, strong, readwrite) UIColor *unreadBadgeTextColor;

@property (nonatomic, strong, readwrite) UIColor *incomingBubbleColor;
@property (nonatomic, strong, readwrite) UIColor *incomingBubbleTextColor;
@property (nonatomic, strong, readwrite) UIColor *incomingBubbleTimeColor;

@property (nonatomic, strong, readwrite) UIColor *outgoingBubbleColor;
@property (nonatomic, strong, readwrite) UIColor *outgoingBubbleTextColor;
@property (nonatomic, strong, readwrite) UIColor *outgoingBubbleTimeColor;

@property (nonatomic, strong, readwrite) UIColor *pinnedBannerBackgroundColor;
@property (nonatomic, strong, readwrite) UIColor *pinnedAccentColor;

@property (nonatomic, strong, readwrite) UIColor *profileButtonBackgroundColor;
@property (nonatomic, strong, readwrite) UIColor *profileButtonTextColor;
@property (nonatomic, strong, readwrite) UIColor *separatorColor;

@end

@implementation VKKateTheme

+ (NSArray<NSNumber *> *)allThemeIds {
    return @[
        @(VKKateThemeIndigo),        // 10
        @(VKKateThemeMaterialDark),  // 11
        @(VKKateThemeTransparent),   // 12
        @(VKKateThemeLight),         // 0
        @(VKKateThemeHolo),          // 8
        @(VKKateThemeBlack),         // 1
        @(VKKateThemePink),          // 2
        @(VKKateThemeOrange),        // 5
        @(VKKateThemeMetal),         // 6
        @(VKKateThemeCoffee),        // 7
        @(VKKateThemeOldLight),      // 9
        @(VKKateThemeLightGreen),    // 4
        @(VKKateThemeGreen)          // 3
    ];
}

+ (NSString *)nameForThemeId:(VKKateThemeId)themeId {
    switch (themeId) {
        case VKKateThemeIndigo: return @"Индиго";
        case VKKateThemeMaterialDark: return @"Индиго тёмная";
        case VKKateThemeTransparent: return @"Прозрачная";
        case VKKateThemeLight: return @"Светлая Holo";
        case VKKateThemeHolo: return @"Тёмная Holo";
        case VKKateThemeBlack: return @"Чёрная";
        case VKKateThemePink: return @"Розовая";
        case VKKateThemeOrange: return @"Оранжевая";
        case VKKateThemeMetal: return @"Металл";
        case VKKateThemeCoffee: return @"Кофе";
        case VKKateThemeOldLight: return @"Старая светлая";
        case VKKateThemeLightGreen: return @"Зелёная";
        case VKKateThemeGreen: return @"Тёмно-зелёная";
    }
}

+ (BOOL)isDarkThemeId:(VKKateThemeId)themeId {
    switch (themeId) {
        case VKKateThemeMaterialDark:
        case VKKateThemeBlack:
        case VKKateThemeHolo:
        case VKKateThemeMetal:
        case VKKateThemeCoffee:
        case VKKateThemeLightGreen:
        case VKKateThemeGreen:
        case VKKateThemeTransparent:
            return YES;
        default:
            return NO;
    }
}

+ (VKKateThemeId)currentThemeId {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id val = [ud objectForKey:kKateThemePrefKey];
    if (!val) {
        // По умолчанию тёмная Индиго (как на скриншотах пользователя)
        return VKKateThemeMaterialDark;
    }
    return (VKKateThemeId)[val integerValue];
}

+ (void)setCurrentThemeId:(VKKateThemeId)themeId {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:themeId forKey:kKateThemePrefKey];
    [ud synchronize];
    
    // Оповещаем систему
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VKKateThemeDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:VKThemeDidChangeNotification object:nil];
    });
}

+ (instancetype)currentTheme {
    return [self themeWithId:[self currentThemeId]];
}

+ (instancetype)themeWithId:(VKKateThemeId)themeId {
    VKKateTheme *t = [[VKKateTheme alloc] init];
    t.themeId = themeId;
    t.name = [self nameForThemeId:themeId];
    t.isDark = [self isDarkThemeId:themeId];
    
    // Общие цвета по умолчанию
    t.headerTitleColor = [UIColor whiteColor];
    t.headerSubtitleColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    t.unreadBadgeTextColor = [UIColor whiteColor];
    t.profileButtonTextColor = [UIColor whiteColor];
    
    switch (themeId) {
        case VKKateThemeMaterialDark: {
            // @style/KateMaterialDark (ID 11): Indigo header, Material Dark background
            t.headerColor = VKColorHex(0x1976D2, 1.0); // @color/indigo_dark
            t.tabsBackgroundColor = VKColorHex(0x1976D2, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.72];
            t.tabIndicatorColor = VKColorHex(0xFF4081, 1.0); // @color/indigo_accent
            t.tabDividerColor = VKColorHex(0x1565C0, 1.0);
            
            t.backgroundColor = VKColorHex(0x212121, 1.0); // @color/material_dark_bg
            t.cardBackgroundColor = VKColorHex(0x262626, 1.0); // @drawable/ds_item_bg_material_dark
            t.cardBorderColor = VKColorHex(0x303030, 1.0);
            
            t.primaryTextColor = VKColorHex(0xF3F3F3, 1.0); // @color/text_color_holo
            t.secondaryTextColor = VKColorHex(0xA8A8A8, 1.0); // @color/solid_item_ago_holo
            t.postLinkColor = VKColorHex(0x80CBC4, 1.0); // @color/material_deep_teal_200
            
            t.unreadItemBackgroundColor = VKColorHex(0x277693, 0.45); // @drawable/d_item_bg_unread_holo #75277693
            t.unreadBadgeColor = VKColorHex(0x1976D2, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x2B2E35, 1.0);
            t.incomingBubbleTextColor = [UIColor whiteColor];
            t.incomingBubbleTimeColor = [UIColor colorWithWhite:0.65 alpha:1.0];
            
            t.outgoingBubbleColor = VKColorHex(0x1A416B, 1.0);
            t.outgoingBubbleTextColor = [UIColor whiteColor];
            t.outgoingBubbleTimeColor = VKColorHex(0x64B5F6, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x1E1E1E, 0.98);
            t.pinnedAccentColor = VKColorHex(0xFF4081, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x1E88E5, 1.0);
            t.separatorColor = VKColorHex(0x333333, 1.0);
            break;
        }
            
        case VKKateThemeIndigo: {
            // @style/KateIndigo (ID 10): Indigo light theme
            t.headerColor = VKColorHex(0x1976D2, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x1976D2, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            t.tabIndicatorColor = VKColorHex(0xFF4081, 1.0);
            t.tabDividerColor = VKColorHex(0x1565C0, 1.0);
            
            t.backgroundColor = VKColorHex(0xF0F2F5, 1.0);
            t.cardBackgroundColor = [UIColor whiteColor];
            t.cardBorderColor = VKColorHex(0xD9DCE1, 1.0);
            
            t.primaryTextColor = VKColorHex(0x222222, 1.0);
            t.secondaryTextColor = VKColorHex(0x8A8A8A, 1.0);
            t.postLinkColor = VKColorHex(0x2B587A, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x6A8AAB, 0.18); // @drawable/d_item_bg_unread
            t.unreadBadgeColor = VKColorHex(0x1976D2, 1.0);
            
            t.incomingBubbleColor = [UIColor whiteColor];
            t.incomingBubbleTextColor = VKColorHex(0x1E1E1E, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x8E8E93, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0xE3F2FD, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0x1E1E1E, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0x1976D2, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0xF5F7FA, 0.98);
            t.pinnedAccentColor = VKColorHex(0xFF4081, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x1E88E5, 1.0);
            t.separatorColor = VKColorHex(0xD6D6D6, 1.0);
            break;
        }
            
        case VKKateThemeBlack: {
            // @style/KateDark (ID 1): Pure dark / Black
            t.headerColor = VKColorHex(0x181818, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x181818, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.60];
            t.tabIndicatorColor = [UIColor whiteColor];
            t.tabDividerColor = VKColorHex(0x2A2A2A, 1.0);
            
            t.backgroundColor = VKColorHex(0x000000, 1.0);
            t.cardBackgroundColor = VKColorHex(0x141414, 1.0);
            t.cardBorderColor = VKColorHex(0x222222, 1.0);
            
            t.primaryTextColor = [UIColor whiteColor];
            t.secondaryTextColor = VKColorHex(0x888888, 1.0);
            t.postLinkColor = VKColorHex(0x80B1DE, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x425E7D, 0.40);
            t.unreadBadgeColor = VKColorHex(0x425E7D, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x1E1E1E, 1.0);
            t.incomingBubbleTextColor = [UIColor whiteColor];
            t.incomingBubbleTimeColor = VKColorHex(0x777777, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x2C3E50, 1.0);
            t.outgoingBubbleTextColor = [UIColor whiteColor];
            t.outgoingBubbleTimeColor = VKColorHex(0x80B1DE, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x141414, 0.98);
            t.pinnedAccentColor = [UIColor whiteColor];
            
            t.profileButtonBackgroundColor = VKColorHex(0x333333, 1.0);
            t.separatorColor = VKColorHex(0x222222, 1.0);
            break;
        }
            
        case VKKateThemeHolo: {
            // @style/KateHolo (ID 8): Dark Holo Blue
            t.headerColor = VKColorHex(0x020202, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x020202, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            t.tabIndicatorColor = VKColorHex(0x33B5E5, 1.0); // Holo Blue
            t.tabDividerColor = VKColorHex(0x33B5E5, 0.6);
            
            t.backgroundColor = VKColorHex(0x1F2020, 1.0);
            t.cardBackgroundColor = VKColorHex(0x262626, 1.0);
            t.cardBorderColor = VKColorHex(0x333333, 1.0);
            
            t.primaryTextColor = VKColorHex(0xF3F3F3, 1.0);
            t.secondaryTextColor = VKColorHex(0xA8A8A8, 1.0);
            t.postLinkColor = VKColorHex(0x33B5E5, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x277693, 0.45);
            t.unreadBadgeColor = VKColorHex(0x33B5E5, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x272727, 1.0);
            t.incomingBubbleTextColor = [UIColor whiteColor];
            t.incomingBubbleTimeColor = VKColorHex(0x888888, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x1B3C4B, 1.0);
            t.outgoingBubbleTextColor = [UIColor whiteColor];
            t.outgoingBubbleTimeColor = VKColorHex(0x33B5E5, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x181818, 0.98);
            t.pinnedAccentColor = VKColorHex(0x33B5E5, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x277693, 1.0);
            t.separatorColor = VKColorHex(0x333333, 1.0);
            break;
        }
            
        case VKKateThemeLight: {
            // @style/KateLight (ID 0): Light Holo Blue
            t.headerColor = VKColorHex(0x3F9FE0, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x3F9FE0, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            t.tabIndicatorColor = VKColorHex(0x33B5E5, 1.0);
            t.tabDividerColor = VKColorHex(0x2A8ACB, 1.0);
            
            t.backgroundColor = VKColorHex(0xF4F4F4, 1.0);
            t.cardBackgroundColor = [UIColor whiteColor];
            t.cardBorderColor = VKColorHex(0xD9DCE1, 1.0);
            
            t.primaryTextColor = VKColorHex(0x222222, 1.0);
            t.secondaryTextColor = VKColorHex(0x999999, 1.0);
            t.postLinkColor = VKColorHex(0x2B587A, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x6A8AAB, 0.18);
            t.unreadBadgeColor = VKColorHex(0x3F9FE0, 1.0);
            
            t.incomingBubbleColor = [UIColor whiteColor];
            t.incomingBubbleTextColor = VKColorHex(0x1E1E1E, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x8E8E93, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0xE1F5FE, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0x1E1E1E, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0x0288D1, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0xF0F4F8, 0.98);
            t.pinnedAccentColor = VKColorHex(0x33B5E5, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x3F9FE0, 1.0);
            t.separatorColor = VKColorHex(0xD6D6D6, 1.0);
            break;
        }
            
        case VKKateThemePink: {
            // @style/KatePink (ID 2): Pink
            t.headerColor = VKColorHex(0xFF6CBB, 1.0);
            t.tabsBackgroundColor = VKColorHex(0xFF6CBB, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            t.tabIndicatorColor = VKColorHex(0xFF6CBB, 1.0);
            t.tabDividerColor = VKColorHex(0xE556A3, 1.0);
            
            t.backgroundColor = VKColorHex(0xF2E5EC, 1.0);
            t.cardBackgroundColor = [UIColor whiteColor];
            t.cardBorderColor = VKColorHex(0xE5D2DF, 1.0);
            
            t.primaryTextColor = VKColorHex(0x4E3141, 1.0);
            t.secondaryTextColor = VKColorHex(0x782344, 1.0);
            t.postLinkColor = VKColorHex(0xC2185B, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0xF8BBD0, 0.45);
            t.unreadBadgeColor = VKColorHex(0xFF6CBB, 1.0);
            
            t.incomingBubbleColor = [UIColor whiteColor];
            t.incomingBubbleTextColor = VKColorHex(0x4E3141, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x782344, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0xFCE4EC, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0x4E3141, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0xC2185B, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0xFBF1F6, 0.98);
            t.pinnedAccentColor = VKColorHex(0xFF6CBB, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0xFF6CBB, 1.0);
            t.separatorColor = VKColorHex(0xE0CFD9, 1.0);
            break;
        }
            
        case VKKateThemeOrange: {
            // @style/KateOrange (ID 5): Orange
            t.headerColor = VKColorHex(0xFF7400, 1.0);
            t.tabsBackgroundColor = VKColorHex(0xFF7400, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            t.tabIndicatorColor = VKColorHex(0xFF7400, 1.0);
            t.tabDividerColor = VKColorHex(0xE06600, 1.0);
            
            t.backgroundColor = VKColorHex(0xFEF6F2, 1.0);
            t.cardBackgroundColor = [UIColor whiteColor];
            t.cardBorderColor = VKColorHex(0xF0DFD5, 1.0);
            
            t.primaryTextColor = VKColorHex(0x222222, 1.0);
            t.secondaryTextColor = VKColorHex(0x8D8A8A, 1.0);
            t.postLinkColor = VKColorHex(0xD26A1D, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0xE4D1C3, 0.45);
            t.unreadBadgeColor = VKColorHex(0xFF7400, 1.0);
            
            t.incomingBubbleColor = [UIColor whiteColor];
            t.incomingBubbleTextColor = VKColorHex(0x222222, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x888888, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0xFFF3E0, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0x222222, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0xEF6C00, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0xFFF8F4, 0.98);
            t.pinnedAccentColor = VKColorHex(0xFF7400, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0xFF7400, 1.0);
            t.separatorColor = VKColorHex(0xE8D5CA, 1.0);
            break;
        }
            
        case VKKateThemeMetal: {
            // @style/KateMetal (ID 6): Gun Metal
            t.headerColor = VKColorHex(0x465864, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x465864, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            t.tabIndicatorColor = VKColorHex(0x818B8C, 1.0);
            t.tabDividerColor = VKColorHex(0x3B4A54, 1.0);
            
            t.backgroundColor = VKColorHex(0x313E40, 1.0);
            t.cardBackgroundColor = VKColorHex(0x3E4A4E, 1.0);
            t.cardBorderColor = VKColorHex(0x4E5C62, 1.0);
            
            t.primaryTextColor = [UIColor whiteColor];
            t.secondaryTextColor = VKColorHex(0xABB5BB, 1.0);
            t.postLinkColor = VKColorHex(0x90CAF9, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x919B9C, 0.45);
            t.unreadBadgeColor = VKColorHex(0x607D8B, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x384347, 1.0);
            t.incomingBubbleTextColor = [UIColor whiteColor];
            t.incomingBubbleTimeColor = VKColorHex(0xABB5BB, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x4E616C, 1.0);
            t.outgoingBubbleTextColor = [UIColor whiteColor];
            t.outgoingBubbleTimeColor = VKColorHex(0xB0BEC5, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x2C3739, 0.98);
            t.pinnedAccentColor = VKColorHex(0x90A4AE, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x465864, 1.0);
            t.separatorColor = VKColorHex(0x465358, 1.0);
            break;
        }
            
        case VKKateThemeCoffee: {
            // @style/KateCoffee (ID 7): Coffee Dark Brown
            t.headerColor = VKColorHex(0x331709, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x331709, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            t.tabIndicatorColor = VKColorHex(0xD9AB82, 1.0);
            t.tabDividerColor = VKColorHex(0x261106, 1.0);
            
            t.backgroundColor = VKColorHex(0x170606, 1.0);
            t.cardBackgroundColor = VKColorHex(0x241818, 1.0);
            t.cardBorderColor = VKColorHex(0x362424, 1.0);
            
            t.primaryTextColor = VKColorHex(0xF9E8E8, 1.0);
            t.secondaryTextColor = VKColorHex(0x998888, 1.0);
            t.postLinkColor = VKColorHex(0xD9AB82, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x764726, 0.45);
            t.unreadBadgeColor = VKColorHex(0x764726, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x2C1E1E, 1.0);
            t.incomingBubbleTextColor = VKColorHex(0xF9E8E8, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x998888, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x4A2A1A, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0xF9E8E8, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0xD9AB82, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x1F1010, 0.98);
            t.pinnedAccentColor = VKColorHex(0xD9AB82, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x54311C, 1.0);
            t.separatorColor = VKColorHex(0x331F1F, 1.0);
            break;
        }
            
        case VKKateThemeOldLight: {
            // @style/KateOldLight (ID 9): Classic VK Light Blue
            t.headerColor = VKColorHex(0x43678E, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x43678E, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            t.tabIndicatorColor = VKColorHex(0x6283A7, 1.0);
            t.tabDividerColor = VKColorHex(0x355475, 1.0);
            
            t.backgroundColor = VKColorHex(0xEEEEEE, 1.0);
            t.cardBackgroundColor = [UIColor whiteColor];
            t.cardBorderColor = VKColorHex(0xD3D9DE, 1.0);
            
            t.primaryTextColor = VKColorHex(0x222222, 1.0);
            t.secondaryTextColor = VKColorHex(0x999999, 1.0);
            t.postLinkColor = VKColorHex(0x2B587A, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0xC5DDF7, 0.50);
            t.unreadBadgeColor = VKColorHex(0x43678E, 1.0);
            
            t.incomingBubbleColor = [UIColor whiteColor];
            t.incomingBubbleTextColor = VKColorHex(0x222222, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x888888, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0xE6EDF5, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0x222222, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0x43678E, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0xF0F3F7, 0.98);
            t.pinnedAccentColor = VKColorHex(0x43678E, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x43678E, 1.0);
            t.separatorColor = VKColorHex(0xD0D7DE, 1.0);
            break;
        }
            
        case VKKateThemeLightGreen: {
            // @style/KateLightGreen (ID 4): Green
            t.headerColor = VKColorHex(0x037103, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x037103, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            t.tabIndicatorColor = VKColorHex(0x7AAC5D, 1.0);
            t.tabDividerColor = VKColorHex(0x025902, 1.0);
            
            t.backgroundColor = VKColorHex(0x051405, 1.0);
            t.cardBackgroundColor = VKColorHex(0x142414, 1.0);
            t.cardBorderColor = VKColorHex(0x1D361D, 1.0);
            
            t.primaryTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.secondaryTextColor = VKColorHex(0x807D7D, 1.0);
            t.postLinkColor = VKColorHex(0x7AAC5D, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x3A4733, 0.50);
            t.unreadBadgeColor = VKColorHex(0x367934, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x182C18, 1.0);
            t.incomingBubbleTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x807D7D, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x224822, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0x7AAC5D, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x0F1E0F, 0.98);
            t.pinnedAccentColor = VKColorHex(0x7AAC5D, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x205E20, 1.0);
            t.separatorColor = VKColorHex(0x1C301C, 1.0);
            break;
        }
            
        case VKKateThemeGreen: {
            // @style/KateGreen (ID 3): Dark Green
            t.headerColor = VKColorHex(0x0B160B, 1.0);
            t.tabsBackgroundColor = VKColorHex(0x0B160B, 1.0);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.60];
            t.tabIndicatorColor = VKColorHex(0x9E7956, 1.0);
            t.tabDividerColor = VKColorHex(0x060D06, 1.0);
            
            t.backgroundColor = VKColorHex(0x0E1002, 1.0);
            t.cardBackgroundColor = VKColorHex(0x181F14, 1.0);
            t.cardBorderColor = VKColorHex(0x232C1E, 1.0);
            
            t.primaryTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.secondaryTextColor = VKColorHex(0x655B52, 1.0);
            t.postLinkColor = VKColorHex(0x9E7956, 1.0);
            
            t.unreadItemBackgroundColor = VKColorHex(0x3A4733, 0.50);
            t.unreadBadgeColor = VKColorHex(0x202A16, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x192015, 1.0);
            t.incomingBubbleTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.incomingBubbleTimeColor = VKColorHex(0x655B52, 1.0);
            
            t.outgoingBubbleColor = VKColorHex(0x253320, 1.0);
            t.outgoingBubbleTextColor = VKColorHex(0xEFEFEF, 1.0);
            t.outgoingBubbleTimeColor = VKColorHex(0x9E7956, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x12160E, 0.98);
            t.pinnedAccentColor = VKColorHex(0x9E7956, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x2C3A24, 1.0);
            t.separatorColor = VKColorHex(0x232C1E, 1.0);
            break;
        }
            
        case VKKateThemeTransparent: {
            // @style/KateTransparent (ID 12): Semi-transparent dark
            t.headerColor = VKColorHex(0x1E1E1E, 0.95);
            t.tabsBackgroundColor = VKColorHex(0x1E1E1E, 0.95);
            t.tabTextSelectedColor = [UIColor whiteColor];
            t.tabTextNormalColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            t.tabIndicatorColor = VKColorHex(0xFF4081, 1.0);
            t.tabDividerColor = VKColorHex(0x333333, 1.0);
            
            t.backgroundColor = VKColorHex(0x181818, 1.0);
            t.cardBackgroundColor = VKColorHex(0x242424, 0.92);
            t.cardBorderColor = VKColorHex(0x333333, 1.0);
            
            t.primaryTextColor = [UIColor whiteColor];
            t.secondaryTextColor = VKColorHex(0xA8A8A8, 1.0);
            t.postLinkColor = VKColorHex(0x64B5F6, 1.0);
            
            t.unreadItemBackgroundColor = [UIColor colorWithWhite:0.35 alpha:0.45];
            t.unreadBadgeColor = VKColorHex(0x1976D2, 1.0);
            
            t.incomingBubbleColor = VKColorHex(0x262626, 0.95);
            t.incomingBubbleTextColor = [UIColor whiteColor];
            t.incomingBubbleTimeColor = [UIColor colorWithWhite:0.65 alpha:1.0];
            
            t.outgoingBubbleColor = VKColorHex(0x1E3A5F, 0.95);
            t.outgoingBubbleTextColor = [UIColor whiteColor];
            t.outgoingBubbleTimeColor = VKColorHex(0x64B5F6, 1.0);
            
            t.pinnedBannerBackgroundColor = VKColorHex(0x1E1E1E, 0.98);
            t.pinnedAccentColor = VKColorHex(0xFF4081, 1.0);
            
            t.profileButtonBackgroundColor = VKColorHex(0x1E88E5, 1.0);
            t.separatorColor = VKColorHex(0x333333, 1.0);
            break;
        }
    }
    
    return t;
}

@end
