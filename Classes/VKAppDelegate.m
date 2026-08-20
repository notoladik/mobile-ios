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

@implementation VKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [VKCrashLogger log:@"[VKAppDelegate] App launched."];
    
    // Инициализация темы оформления
    [[VKThemeManager sharedManager] applyTheme:[[VKThemeManager sharedManager] currentTheme]];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    if ([self.window respondsToSelector:@selector(setTintColor:)]) {
        self.window.tintColor = [[VKThemeManager sharedManager] accentColor];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authStatusChanged:) name:VKAuthStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(countersUpdated:) name:VKCountersDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sideMenuStateChanged:) name:VKSideMenuStateDidChangeNotification object:nil];
    
    [self updateRootViewController];
    [[VKSideMenuManager sharedManager] setupWithRootWindow:self.window];
    [self updateTabBarVisibility];
    
    [self.window makeKeyAndVisible];
    return YES;
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
        [self updateRootViewController];
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
    if ([[VKAuthService sharedService] isAuthenticated]) {
        BOOL isSideEnabled = [[VKSideMenuManager sharedManager] isSideMenuEnabled];
        
        if (isSideEnabled) {
            // Режим бокового меню: чистый полноэкранный стек без таббара
            self.tabBarController = nil;
            VKFeedViewController *feedVC = [[VKFeedViewController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:feedVC];
            self.window.rootViewController = nav;
        } else {
            // Режим вкладок: классический таббар
            self.tabBarController = [[UITabBarController alloc] init];
            
            VKFeedViewController *feedVC = [[VKFeedViewController alloc] init];
            UINavigationController *feedNav = [[UINavigationController alloc] initWithRootViewController:feedVC];
            feedNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Лента" image:[self tabBarIconForIndex:0] tag:0];
            
            VKSearchViewController *searchVC = [[VKSearchViewController alloc] init];
            UINavigationController *searchNav = [[UINavigationController alloc] initWithRootViewController:searchVC];
            searchNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Поиск" image:[self tabBarIconForIndex:1] tag:1];
            
            VKMessagesViewController *msgVC = [[VKMessagesViewController alloc] init];
            UINavigationController *msgNav = [[UINavigationController alloc] initWithRootViewController:msgVC];
            msgNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Сообщения" image:[self tabBarIconForIndex:2] tag:2];
            
            NSInteger msgCount = [[VKAuthService sharedService] messagesCount];
            if (msgCount > 0) {
                msgNav.tabBarItem.badgeValue = [NSString stringWithFormat:@"%ld", (long)msgCount];
            }
            
            VKMoreViewController *moreVC = [[VKMoreViewController alloc] initWithStyle:UITableViewStyleGrouped];
            UINavigationController *moreNav = [[UINavigationController alloc] initWithRootViewController:moreVC];
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
        UINavigationController *loginNav = [[UINavigationController alloc] initWithRootViewController:loginVC];
        self.window.rootViewController = loginNav;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
