#import <UIKit/UIKit.h>
#import "VKThemeManager.h"

extern NSString *const VKClientDesignDidChangeNotification;
extern NSString *const VKClientRoundAvatarsOption;
extern NSString *const VKClientChatAvatarsOption;
extern NSString *const VKClientTwoLinePreviewsOption;
extern NSString *const VKClientProfileMenuOption;

@interface VKClientDesign : NSObject
+ (BOOL)isAndroidClientDesign;
+ (BOOL)boolForOption:(NSString *)option theme:(VKThemeType)theme;
+ (void)setBool:(BOOL)value forOption:(NSString *)option theme:(VKThemeType)theme;
+ (BOOL)roundAvatars;
+ (BOOL)chatAvatars;
+ (BOOL)twoLinePreviews;
+ (BOOL)profileMenu;
+ (CGFloat)messageFontSize;
+ (CGFloat)messageFontSizeForTheme:(VKThemeType)theme;
+ (void)setMessageFontSize:(CGFloat)size theme:(VKThemeType)theme;
+ (NSInteger)firstTab;
+ (void)setFirstTab:(NSInteger)index;
+ (void)resetTheme:(VKThemeType)theme;
/* Alpha-mask tinting also works on iOS 6, unlike UIImageRenderingMode. */
+ (UIImage *)iconNamed:(NSString *)name color:(UIColor *)color;
@end
