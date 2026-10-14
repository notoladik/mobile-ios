#import "VKAppDelegate.h"
#import "VKAuthService.h"
#import "VKLoginViewController.h"
#import "VKFeedViewController.h"
#import "VKSearchViewController.h"
#import "VKMessagesViewController.h"
#import "VKMoreViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import "VKMiniPlayerBar.h"
#import "VKAudioPlayer.h"
#import "VKNetworkStatusManager.h"
#import "VKNetworkBannerView.h"
#import "VKLongPollService.h"
#import "VKBackgroundVisualizerManager.h"
#import "VKPresetManager.h"
#import "VKKateSettings.h"
#import "VKKateMainViewController.h"
#import "VKNavigationController.h"

@interface VKAppDelegate ()
@property (nonatomic, assign) VKThemeType renderedRootTheme;
@end

@implementation VKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [VKCrashLogger log:@"[VKAppDelegate] App launched."];
    
    // Мониторинг сети
    [[VKNetworkStatusManager sharedManager] startMonitoring];
    
    // Инициализация темы оформления
    [[VKThemeManager sharedManager] applyTheme:[[VKThemeManager sharedManager] currentTheme]];
    
    // Синхронизация невидимки Kate Mobile
    if ([VKKateSettings isUnlocked] && [VKKateSettings isOfflineModeEnabled]) {
        [VKKateSettings sendSetOfflineIfEnabled];
    }
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    if ([self.window respondsToSelector:@selector(setTintColor:)]) {
        self.window.tintColor = [[VKThemeManager sharedManager] accentColor];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authStatusChanged:) name:VKAuthStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(countersUpdated:) name:VKCountersDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sideMenuStateChanged:) name:VKSideMenuStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerStateChanged:) name:VKAudioPlayerStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(longPollUnreadCountChanged:) name:VKLongPollUnreadCountDidChangeNotification object:nil];
    
    [self updateRootViewController];
    [[VKSideMenuManager sharedManager] setupWithRootWindow:self.window];
    [self updateTabBarVisibility];
    
    [[VKNetworkBannerView sharedBanner] attachToWindow:self.window];
    [[VKBackgroundVisualizerManager sharedManager] setupWithWindow:self.window];
    
    if ([[VKAuthService sharedService] isAuthenticated]) {
        [[VKLongPollService sharedService] start];
    }
    
    [self.window makeKeyAndVisible];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    return YES;
}

- (void)longPollUnreadCountChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger count = [note.userInfo[@"count"] integerValue];
        if (self.tabBarController && self.tabBarController.viewControllers.count >= 3) {
            UINavigationController *msgNav = self.tabBarController.viewControllers[2];
            msgNav.tabBarItem.badgeValue = (count > 0) ? [NSString stringWithFormat:@"%ld", (long)count] : nil;
        }
    });
}

- (void)audioPlayerStateChanged:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([VKAudioPlayer sharedPlayer].currentTrack != nil) {
            CGFloat offset = (self.tabBarController != nil) ? 49.0 : 0.0;
            [[VKMiniPlayerBar sharedBar] showInView:self.window bottomOffset:offset];
        } else {
            [[VKMiniPlayerBar sharedBar] hideAnimated:YES];
        }
    });
}

- (void)sideMenuStateChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRootViewController];
    });
}

- (void)updateTabBarVisibility {
    // Больше не требуется грязных хаков, rootViewController обновляется нативно
}

- (void)themeChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.window.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
        if ([self.window respondsToSelector:@selector(setTintColor:)]) {
            self.window.tintColor = [[VKThemeManager sharedManager] accentColor];
        }
        if (self.renderedRootTheme != [VKThemeManager sharedManager].currentTheme) [self updateRootViewController];
    });
}

- (void)authStatusChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateRootViewController];
    });
}

- (void)countersUpdated:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.tabBarController && self.tabBarController.viewControllers.count >= 4) {
            NSInteger msgCount = [[VKAuthService sharedService] messagesCount];
            UINavigationController *msgNav = self.tabBarController.viewControllers[2];
            msgNav.tabBarItem.badgeValue = (msgCount > 0) ? [NSString stringWithFormat:@"%ld", (long)msgCount] : nil;
            
            NSInteger notifCount = [[VKAuthService sharedService] notificationsCount];
            NSInteger friendsCount = [[VKAuthService sharedService] friendsCount];
            NSInteger totalMore = notifCount;
            UINavigationController *moreNav = self.tabBarController.viewControllers[3];
            moreNav.tabBarItem.badgeValue = (totalMore > 0) ? [NSString stringWithFormat:@"%ld", (long)totalMore] : nil;
        }
    });
}

- (UIImage *)tabBarIconForIndex:(NSInteger)index {
    return [[VKThemeManager sharedManager] tabBarIconForIndex:index];
}

- (void)updateRootViewController {
    self.renderedRootTheme = [VKThemeManager sharedManager].currentTheme;
    if ([[VKAuthService sharedService] isAuthenticated]) {
        BOOL isKate = [[VKThemeManager sharedManager] isKateTheme];
        BOOL isSideEnabled = [[VKSideMenuManager sharedManager] isSideMenuEnabled];
        
        if (isKate) {
            // Режим Kate Mobile: аутентичные верхние вкладки (Профиль | Новости | Сообщения) + Kate Action Bar
            self.tabBarController = nil;
            VKKateMainViewController *kateMainVC = [[VKKateMainViewController alloc] init];
            VKNavigationController *nav = [[VKNavigationController alloc] initWithRootViewController:kateMainVC];
            self.window.rootViewController = nav;
        } else if (isSideEnabled) {
            // Режим бокового меню: чистый полноэкранный стек без таббара
            self.tabBarController = nil;
            VKFeedViewController *feedVC = [[VKFeedViewController alloc] init];
            VKNavigationController *nav = [[VKNavigationController alloc] initWithRootViewController:feedVC];
            self.window.rootViewController = nav;
        } else {
            // Режим вкладок: классический таббар
            self.tabBarController = [[UITabBarController alloc] init];
            
            VKFeedViewController *feedVC = [[VKFeedViewController alloc] init];
            VKNavigationController *feedNav = [[VKNavigationController alloc] initWithRootViewController:feedVC];
            feedNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Лента" image:[self tabBarIconForIndex:0] tag:0];
            
            VKSearchViewController *searchVC = [[VKSearchViewController alloc] init];
            VKNavigationController *searchNav = [[VKNavigationController alloc] initWithRootViewController:searchVC];
            searchNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Поиск" image:[self tabBarIconForIndex:1] tag:1];
            
            VKMessagesViewController *msgVC = [[VKMessagesViewController alloc] init];
            VKNavigationController *msgNav = [[VKNavigationController alloc] initWithRootViewController:msgVC];
            msgNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Сообщения" image:[self tabBarIconForIndex:2] tag:2];
            
            NSInteger msgCount = [[VKAuthService sharedService] messagesCount];
            if (msgCount > 0) {
                msgNav.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld", (long)msgCount];
            }
            
            VKMoreViewController *moreVC = [[VKMoreViewController alloc] initWithStyle:UITableViewStyleGrouped];
            VKNavigationController *moreNav = [[VKNavigationController alloc] initWithRootViewController:moreVC];
            moreNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Прочее" image:[self tabBarIconForIndex:3] tag:3];
            
            NSInteger notifCount = [[VKAuthService sharedService] notificationsCount];
            if (notifCount > 0) {
                moreNav.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld", (long)notifCount];
            }
            
            self.tabBarController.viewControllers = @[feedNav, searchNav, msgNav, moreNav];
            self.window.rootViewController = self.tabBarController;
        }
    } else {
        self.tabBarController = nil;
        VKLoginViewController *loginVC = [[VKLoginViewController alloc] init];
        VKNavigationController *loginNav = [[VKNavigationController alloc] initWithRootViewController:loginVC];
        self.window.rootViewController = loginNav;
    }
    
    [[VKBackgroundVisualizerManager sharedManager] updateVisualizerState];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type == UIEventTypeRemoteControl) {
        [[VKAudioPlayer sharedPlayer] handleRemoteControlEvent:event];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Open URL (Document Import)

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if (!url) return NO;
    
    NSString *ext = [[url pathExtension] lowercaseString];
    if ([ext isEqualToString:@"milk"] || [ext isEqualToString:@"avs"]) {
        NSError *error = nil;
        BOOL ok = [VKPresetManager importPresetFromURL:url error:&error];
        if (ok) {
            NSString *name = [url lastPathComponent];
            NSString *msg = [NSString stringWithFormat:@"Пресет «%@» успешно импортирован!", name];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Импорт пресета"
                                                            message:msg
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return YES;
        } else {
            NSString *errDesc = error.localizedDescription ?: @"Не удалось импортировать файл пресета.";
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка импорта"
                                                            message:errDesc
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return NO;
        }
    }
    return NO;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [self application:app openURL:url sourceApplication:@"" annotation:@{}];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if ([VKKateSettings isUnlocked] && [VKKateSettings isOfflineModeEnabled]) {
        [VKKateSettings sendSetOfflineIfEnabled];
    }
}

@end