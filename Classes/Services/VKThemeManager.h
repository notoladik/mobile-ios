#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VKThemeType) {
    VKThemeTypeModernSwift = 0,    // Эпоха Modern SwiftUI / iOS 16-18 (виджетные карточки 14pt, SF rounded, мягкие тени)
    VKThemeTypeClassicUIKit = 1,   // Эпоха iOS 7-10 Flat (культовый синий навбар VK #4A76A8, сплошная плоская лента)
    VKThemeTypeiOS6Legacy = 2      // Эпоха iOS 5-6 Скевоморфизм (глянец, льняной фон, квадратные аватары, рельеф)
};

extern NSString *const VKThemeDidChangeNotification;

@interface VKThemeManager : NSObject

@property (nonatomic, assign) VKThemeType currentTheme;

+ (instancetype)sharedManager;

- (NSString *)nameForTheme:(VKThemeType)type;
- (NSString *)eraDescriptionForTheme:(VKThemeType)type;
- (void)applyTheme:(VKThemeType)type;

// Цвета
- (UIColor *)accentColor;
- (UIColor *)backgroundColor;
- (UIColor *)cardBackgroundColor;
- (UIColor *)cardBorderColor;
- (UIColor *)navBarBackgroundColor;
- (UIColor *)navBarTitleColor;
- (UIColor *)navBarTintColor;
- (UIColor *)tabBarTintColor;
- (UIColor *)secondaryTextColor;
- (UIColor *)separatorColor;

// Метрики и геометрия
- (CGFloat)cardCornerRadius;
- (CGFloat)cardHorizontalMargin;
- (CGFloat)avatarCornerRadiusForSize:(CGFloat)size;
- (CGFloat)avatarBorderWidth;
- (UIColor *)avatarBorderColor;
- (BOOL)isSkeuomorphic;
- (BOOL)isClassicFlat;
- (BOOL)isModern;

// Шрифты и тени
- (UIFont *)titleFontOfSize:(CGFloat)size;
- (UIFont *)bodyFontOfSize:(CGFloat)size;
- (UIColor *)textShadowColor;
- (CGSize)textShadowOffset;

// Генерация визуальных элементов эпох
- (UIImage *)stripedLinenPatternImage;
- (UIImage *)navBarBackgroundImageForHeight:(CGFloat)height;
- (UIImage *)tabBarBackgroundImage;
- (UIImage *)tabBarIconForIndex:(NSInteger)index;
- (UIImage *)skeuomorphicButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted;
- (UIImage *)skeuomorphicNavBarButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted;
- (UIImage *)skeuomorphicBackBarButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted;

// Навигационные кнопки
- (UIBarButtonItem *)barButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action isBack:(BOOL)isBack;
- (UIBarButtonItem *)navBarMenuBarButtonItemWithTarget:(id)target action:(SEL)action;
- (UIBarButtonItem *)navBarComposeBarButtonItemWithTarget:(id)target action:(SEL)action;
- (UIBarButtonItem *)navBarRefreshBarButtonItemWithTarget:(id)target action:(SEL)action;

// Векторные иконки реакций кнопок постов (без эмодзи!)
- (UIImage *)reactionCommentIconWithColor:(UIColor *)color;
- (UIImage *)reactionMegaphoneIconWithColor:(UIColor *)color;
- (UIImage *)reactionHeartIconWithColor:(UIColor *)color filled:(BOOL)filled;

@end
