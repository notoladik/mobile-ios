#import "VKKateSettings.h"
#import "VKChatAppearance.h"
#import "VKClientDesign.h"
#import "VKAPIClient.h"
#import "VKAuthService.h"
#import <AudioToolbox/AudioToolbox.h>

NSString *const VKKateSettingsDidChangeNotification = @"VKKateSettingsDidChangeNotification";

static NSString *const kKateUnlockedKey = @"kOpenVKKateUnlockedKey";
static NSString *const kKateOfflineKey = @"kOpenVKKateOfflineKey";
static NSString *const kKateCloseUnreadKey = @"kOpenVKKateCloseUnreadKey";
static NSString *const kKateHideTypingKey = @"kOpenVKKateHideTypingKey";
static NSString *const kKateBubblesKey = @"kOpenVKKateBubblesKey";
static NSString *const kKateProfileHubKey = @"kOpenVKKateProfileHubKey";

@implementation VKKateSettings

+ (instancetype)sharedSettings {
    static VKKateSettings *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

+ (BOOL)isUnlocked {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKateUnlockedKey];
}

+ (void)setUnlocked:(BOOL)unlocked {
    [[NSUserDefaults standardUserDefaults] setBool:unlocked forKey:kKateUnlockedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
}

+ (void)unlockWithAlertFromViewController:(UIViewController *)vc {
    [self setUnlocked:YES];
    
    // Легкий виброотклик
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    NSString *msg = @"🐱 Мяу! Секретный режим Kate Mobile успешно активирован!\n\n"
                    @"Вам стали доступны:\n"
                    @"• Фирменная тема Kate Mobile (Indigo)\n"
                    @"• Невидимка (оффлайн-режим)\n"
                    @"• Нечиталка сообщений\n"
                    @"• Скрытие набора текста (неписалка)\n"
                    @"• Прямоугольные облачка сообщений\n\n"
                    @"Новый раздел настроек появился в меню!";
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Секрет разблокирован!"
                                                    message:msg
                                                   delegate:nil
                                          cancelButtonTitle:@"Ура! 🎉"
                                          otherButtonTitles:nil];
    [alert show];
}

+ (BOOL)isOfflineModeEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKateOfflineKey];
}

+ (void)setOfflineModeEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kKateOfflineKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
    
    if (enabled) {
        [self sendSetOfflineIfEnabled];
    } else {
        if ([[VKAuthService sharedService] isAuthenticated]) {
            [[VKAPIClient sharedClient] callMethod:@"account.setOnline" parameters:@{} completionHandler:nil];
        }
    }
}

+ (void)sendSetOfflineIfEnabled {
    if (![self isOfflineModeEnabled]) return;
    if (![[VKAuthService sharedService] isAuthenticated]) return;
    
    [[VKAPIClient sharedClient] callMethod:@"account.setOffline" parameters:@{} completionHandler:^(id response, NSError *error) {
        if (!error) {
            NSLog(@"[VKKateSettings] account.setOffline successful");
        } else {
            NSLog(@"[VKKateSettings] account.setOffline failed: %@", error);
        }
    }];
}

+ (BOOL)isCloseUnreadEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKateCloseUnreadKey];
}

+ (void)setCloseUnreadEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kKateCloseUnreadKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
}

+ (BOOL)isTypingStatusHidden {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKateHideTypingKey];
}

+ (void)setTypingStatusHidden:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kKateHideTypingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
}

+ (BOOL)isKateBubblesEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kKateBubblesKey];
}

+ (void)setKateBubblesEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kKateBubblesKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
}

+ (UIImage *)chatWallpaperImage { return [VKChatAppearance wallpaperForPeerId:0]; }
+ (BOOL)hasChatWallpaper { return [self chatWallpaperImage] != nil; }

+ (BOOL)isProfileHubModeEnabled {
    return [VKClientDesign boolForOption:VKClientProfileMenuOption theme:VKThemeTypeKateMobile];
}
+ (void)setProfileHubModeEnabled:(BOOL)enabled {
    [VKClientDesign setBool:enabled forOption:VKClientProfileMenuOption theme:VKThemeTypeKateMobile];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKKateSettingsDidChangeNotification object:nil];
}

@end
