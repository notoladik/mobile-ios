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

@interface VKNavigationController : UINavigationController <UIGestureRecognizerDelegate>
- (void)updateNavBarTheme;
@end

@implementation VKNavigationController
- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.delegate = self;
    }
    [self updateNavBarTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNavBarTheme) name:VKThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateNavBarTheme];
}

- (void)updateNavBarTheme {
    VKThemeManager *tm = [VKThemeManager sharedManager];
    UINavigationBar *bar = self.navigationBar;
    if (!bar) return;
    
    BOOL hasBarTintColor = [bar respondsToSelector:@selector(setBarTintColor:)];
    if ([tm isSkeuomorphic]) {
        bar.barStyle = UIBarStyleBlack;
        UIImage *navImg = [tm navBarBackgroundImageForHeight:64.0];
        [bar setBackgroundImage:navImg forBarMetrics:UIBarMetricsDefault];
        bar.tintColor = [UIColor whiteColor];
        
        NSShadow *navShadow = [[NSShadow alloc] init];
        navShadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        navShadow.shadowOffset = CGSizeMake(0, -1);
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18],
            NSShadowAttributeName: navShadow
        };
    } else if ([tm isClassicFlat]) {
        bar.barStyle = UIBarStyleDefault;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            bar.barTintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            bar.tintColor = [UIColor whiteColor];
        } else {
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        }
        if ([bar respondsToSelector:@selector(setTranslucent:)]) {
            bar.translucent = NO;
        }
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    } else {
        // Modern Swift
        bar.barStyle = UIBarStyleDefault;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            bar.barTintColor = [UIColor whiteColor];
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        } else {
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        }
        if ([bar respondsToSelector:@selector(setTranslucent:)]) {
            bar.translucent = NO;
        }
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    return self.viewControllers.count > 1;
}
@end

@implementation VKAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [VKCrashLogger log:@"[VKAppDelegate] App launched."];
    
    // Мониторинг сети
    [[VKNetworkStatusManager sharedManager] startMonitoring];
    
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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerStateChanged:) name:VKAudioPlayerStateDidChangeNotification object:nil];
    
    [self updateRootViewController];
    [[VKSideMenuManager sharedManager] setupWithRootWindow:self.window];
    [self updateTabBarVisibility];
    
    [[VKNetworkBannerView sharedBanner] attachToWindow:self.window];
    
    [self.window makeKeyAndVisible];
    return YES;
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
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
