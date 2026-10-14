#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const VKKateSettingsDidChangeNotification;

@interface VKKateSettings : NSObject

+ (instancetype)sharedSettings;

// Секретная пасхалка / статус разблокировки
+ (BOOL)isUnlocked;
+ (void)setUnlocked:(BOOL)unlocked;
+ (void)unlockWithAlertFromViewController:(UIViewController *)vc;

// Невидимка ("По возможности быть оффлайн" из Kate Mobile)
+ (BOOL)isOfflineModeEnabled;
+ (void)setOfflineModeEnabled:(BOOL)enabled;
+ (void)sendSetOfflineIfEnabled;

// Нечиталка ("Закрыть непрочитанным" / не отправлять markAsRead автоматически)
+ (BOOL)isCloseUnreadEnabled;
+ (void)setCloseUnreadEnabled:(BOOL)enabled;

// Неписалка ("Набор текста" / не отправлять typing status)
+ (BOOL)isTypingStatusHidden;
+ (void)setTypingStatusHidden:(BOOL)enabled;

// Стиль пузырей диалогов Kate (прямоугольные компактные облачка)
+ (BOOL)isKateBubblesEnabled;
+ (void)setKateBubblesEnabled:(BOOL)enabled;

// Обои в чатах
+ (UIImage *)chatWallpaperImage;
+ (BOOL)hasChatWallpaper;

// Стиль профиля (Навигационное меню разделов или Полная страница)
+ (BOOL)isProfileHubModeEnabled;
+ (void)setProfileHubModeEnabled:(BOOL)enabled;

@end
