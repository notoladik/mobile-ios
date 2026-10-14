#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 13 аутентичных тем из decompiled FreeKate (res/values/arrays.xml)
typedef NS_ENUM(NSInteger, VKKateThemeId) {
    VKKateThemeIndigo = 10,         // Индиго (по умолчанию светлая)
    VKKateThemeMaterialDark = 11,   // Индиго тёмная (по умолчанию тёмная / на скриншотах)
    VKKateThemeTransparent = 12,    // Прозрачная
    VKKateThemeLight = 0,           // Светлая Holo
    VKKateThemeHolo = 8,            // Тёмная Holo
    VKKateThemeBlack = 1,           // Чёрная
    VKKateThemePink = 2,            // Розовая
    VKKateThemeOrange = 5,          // Оранжевая
    VKKateThemeMetal = 6,           // Металл
    VKKateThemeCoffee = 7,          // Кофе
    VKKateThemeOldLight = 9,        // Старая светлая
    VKKateThemeLightGreen = 4,      // Зелёная
    VKKateThemeGreen = 3            // Тёмно-зелёная
};

extern NSString *const VKKateThemeDidChangeNotification;

@interface VKKateTheme : NSObject

@property (nonatomic, assign, readonly) VKKateThemeId themeId;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) BOOL isDark;

// 1. Навбар / Шапка приложения (attr_header_bg, colorPrimary / colorPrimaryDark)
@property (nonatomic, strong, readonly) UIColor *headerColor;
@property (nonatomic, strong, readonly) UIColor *headerTitleColor;
@property (nonatomic, strong, readonly) UIColor *headerSubtitleColor;

// 2. Вкладки (attr_tab_bg, attr_tab_text_color, colorAccent)
@property (nonatomic, strong, readonly) UIColor *tabsBackgroundColor;
@property (nonatomic, strong, readonly) UIColor *tabTextSelectedColor;
@property (nonatomic, strong, readonly) UIColor *tabTextNormalColor;
@property (nonatomic, strong, readonly) UIColor *tabIndicatorColor;
@property (nonatomic, strong, readonly) UIColor *tabDividerColor;

// 3. Основные фоны и карточки (activity_background, attr_item_bg)
@property (nonatomic, strong, readonly) UIColor *backgroundColor;
@property (nonatomic, strong, readonly) UIColor *cardBackgroundColor;
@property (nonatomic, strong, readonly) UIColor *cardBorderColor;

// 4. Тексты (attr_item_text_color, attr_item_ago_color, attr_item_link_color)
@property (nonatomic, strong, readonly) UIColor *primaryTextColor;
@property (nonatomic, strong, readonly) UIColor *secondaryTextColor;
@property (nonatomic, strong, readonly) UIColor *postLinkColor;

// 5. Непрочитанные элементы (attr_item_bg_unread, attr_count_bg)
@property (nonatomic, strong, readonly) UIColor *unreadItemBackgroundColor;
@property (nonatomic, strong, readonly) UIColor *unreadBadgeColor;
@property (nonatomic, strong, readonly) UIColor *unreadBadgeTextColor;

// 6. Диалоги и сообщения (attr_bg_bubble)
@property (nonatomic, strong, readonly) UIColor *incomingBubbleColor;
@property (nonatomic, strong, readonly) UIColor *incomingBubbleTextColor;
@property (nonatomic, strong, readonly) UIColor *incomingBubbleTimeColor;

@property (nonatomic, strong, readonly) UIColor *outgoingBubbleColor;
@property (nonatomic, strong, readonly) UIColor *outgoingBubbleTextColor;
@property (nonatomic, strong, readonly) UIColor *outgoingBubbleTimeColor;

// 7. Закрепленное сообщение / баннеры
@property (nonatomic, strong, readonly) UIColor *pinnedBannerBackgroundColor;
@property (nonatomic, strong, readonly) UIColor *pinnedAccentColor;

// 8. Кнопки и разделители
@property (nonatomic, strong, readonly) UIColor *profileButtonBackgroundColor;
@property (nonatomic, strong, readonly) UIColor *profileButtonTextColor;
@property (nonatomic, strong, readonly) UIColor *separatorColor;

// Управление активной темой
+ (instancetype)currentTheme;
+ (VKKateThemeId)currentThemeId;
+ (void)setCurrentThemeId:(VKKateThemeId)themeId;

+ (instancetype)themeWithId:(VKKateThemeId)themeId;
+ (NSArray<NSNumber *> *)allThemeIds;
+ (NSString *)nameForThemeId:(VKKateThemeId)themeId;
+ (BOOL)isDarkThemeId:(VKKateThemeId)themeId;

@end
