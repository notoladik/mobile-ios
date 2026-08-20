#import "VKSideMenuManager.h"
#import "VKSideMenuViewController.h"
#import "VKAuthService.h"
#import "VKProfileViewController.h"
#import "VKFriendsListViewController.h"
#import "VKGroupsListViewController.h"
#import "VKNotificationsViewController.h"
#import "VKSettingsViewController.h"
#import "VKFeedViewController.h"
#import "VKSearchViewController.h"
#import "VKMessagesViewController.h"
#import "VKAlbumsListViewController.h"
#import "VKVideosListViewController.h"
#import "VKAudioListViewController.h"
#import "VKMoreViewController.h"

NSString *const VKSideMenuStateDidChangeNotification = @"VKSideMenuStateDidChangeNotification";
static NSString *const kSideMenuEnabledKey = @"openvk.side_menu_enabled";

@interface VKSideMenuManager () <UIGestureRecognizerDelegate>
@property (nonatomic, strong, readwrite) VKSideMenuViewController *sideMenuViewController;
@property (nonatomic, weak) UIWindow *rootWindow;
@property (nonatomic, strong) UIView *dimmingOverlayView;
@property (nonatomic, assign, readwrite) BOOL isMenuOpen;
@property (nonatomic, assign) CGFloat menuWidth;
@end

@implementation VKSideMenuManager

+ (instancetype)sharedManager {
    static VKSideMenuManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _menuWidth = 270.0;
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kSideMenuEnabledKey] != nil) {
            _isSideMenuEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kSideMenuEnabledKey];
        } else {
            _isSideMenuEnabled = YES; // По умолчанию включено
        }
        _sideMenuViewController = [[VKSideMenuViewController alloc] init];
    }
    return self;
}

- (void)setIsSideMenuEnabled:(BOOL)isSideMenuEnabled {
    _isSideMenuEnabled = isSideMenuEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:isSideMenuEnabled forKey:kSideMenuEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:VKSideMenuStateDidChangeNotification object:nil];
}

- (void)setupWithRootWindow:(UIWindow *)window {
    self.rootWindow = window;
    CGFloat winW = window.bounds.size.width;
    CGFloat winH = window.bounds.size.height;
    CGFloat menuW = MIN(270.0, winW * 0.8);
    
    if (!self.sideMenuViewController.view.superview) {
        self.sideMenuViewController.view.frame = CGRectMake(0, 0, menuW, winH);
        self.sideMenuViewController.view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    }
}

- (void)toggleMenu {
    if (!self.isSideMenuEnabled) return;
    if (self.isMenuOpen) {
        [self closeMenuAnimated:YES completion:nil];
    } else {
        [self openMenu];
    }
}

- (void)openMenu {
    if (!self.isSideMenuEnabled || !self.rootWindow) return;
    UIViewController *rootVC = self.rootWindow.rootViewController;
    if (!rootVC) return;
    
    [self.sideMenuViewController reloadData];
    
    CGFloat winW = self.rootWindow.bounds.size.width;
    CGFloat winH = self.rootWindow.bounds.size.height;
    CGFloat menuW = MIN(270.0, winW * 0.8);
    
    self.sideMenuViewController.view.frame = CGRectMake(0, 0, menuW, winH);
    
    if (!self.sideMenuViewController.view.superview) {
        [self.rootWindow insertSubview:self.sideMenuViewController.view atIndex:0];
    }
    
    if (!self.dimmingOverlayView) {
        self.dimmingOverlayView = [[UIView alloc] initWithFrame:self.rootWindow.bounds];
        self.dimmingOverlayView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.dimmingOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.dimmingOverlayView.alpha = 0.0;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimmingTapped)];
        [self.dimmingOverlayView addGestureRecognizer:tap];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.dimmingOverlayView addGestureRecognizer:pan];
    }
    self.dimmingOverlayView.frame = self.rootWindow.bounds;
    
    if (!self.dimmingOverlayView.superview) {
        [rootVC.view addSubview:self.dimmingOverlayView];
    }
    
    self.isMenuOpen = YES;
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        rootVC.view.frame = CGRectMake(menuW, 0, winW, winH);
        self.dimmingOverlayView.alpha = 1.0;
    } completion:nil];
}

- (void)closeMenuAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if (!self.rootWindow) return;
    UIViewController *rootVC = self.rootWindow.rootViewController;
    if (!rootVC) return;
    
    self.isMenuOpen = NO;
    CGRect windowBounds = self.rootWindow.bounds;
    void (^actions)(void) = ^{
        rootVC.view.frame = windowBounds;
        self.dimmingOverlayView.alpha = 0.0;
    };
    
    void (^finish)(BOOL) = ^(BOOL finished) {
        rootVC.view.frame = windowBounds;
        [self.dimmingOverlayView removeFromSuperview];
        [self.sideMenuViewController.view removeFromSuperview];
        [rootVC.view setNeedsLayout];
        [rootVC.view layoutIfNeeded];
        if (completion) completion();
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:actions completion:finish];
    } else {
        actions();
        finish(YES);
    }
}

- (void)dimmingTapped {
    [self closeMenuAnimated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self closeMenuAnimated:YES completion:nil];
    }
}

- (void)navigateToIndex:(NSInteger)index {
    [self closeMenuAnimated:YES completion:^{
        UIViewController *root = self.rootWindow.rootViewController;
        UINavigationController *nav = [root isKindOfClass:[UINavigationController class]] ? (UINavigationController *)root : nil;
        UITabBarController *tabBar = [root isKindOfClass:[UITabBarController class]] ? (UITabBarController *)root : nil;
        VKUser *cur = [[VKAuthService sharedService] currentUserModel];
        
        if (nav) {
            // Режим одного полноэкранного UINavigationController
            switch (index) {
                case 0: { // Профиль
                    if (cur) {
                        VKProfileViewController *prof = [[VKProfileViewController alloc] initWithUser:cur];
                        [nav setViewControllers:@[prof] animated:NO];
                    }
                    break;
                }
                case 1: { // Новости
                    VKFeedViewController *feed = [[VKFeedViewController alloc] init];
                    [nav setViewControllers:@[feed] animated:NO];
                    break;
                }
                case 2: { // Ответы
                    VKNotificationsViewController *notif = [[VKNotificationsViewController alloc] init];
                    [nav setViewControllers:@[notif] animated:NO];
                    break;
                }
                case 3: { // Сообщения
                    VKMessagesViewController *msg = [[VKMessagesViewController alloc] init];
                    [nav setViewControllers:@[msg] animated:NO];
                    break;
                }
                case 4: { // Друзья
                    VKFriendsListViewController *friends = [[VKFriendsListViewController alloc] initWithUserId:cur.uid];
                    [nav setViewControllers:@[friends] animated:NO];
                    break;
                }
                case 5: { // Группы
                    VKGroupsListViewController *groups = [[VKGroupsListViewController alloc] initWithUserId:cur.uid];
                    [nav setViewControllers:@[groups] animated:NO];
                    break;
                }
                case 6: { // Фотографии
                    VKAlbumsListViewController *albums = [[VKAlbumsListViewController alloc] initWithUserId:cur.uid];
                    [nav setViewControllers:@[albums] animated:NO];
                    break;
                }
                case 7: { // Видеозаписи
                    VKVideosListViewController *videos = [[VKVideosListViewController alloc] initWithUserId:cur.uid];
                    [nav setViewControllers:@[videos] animated:NO];
                    break;
                }
                case 8: { // Музыка
                    VKAudioListViewController *audio = [[VKAudioListViewController alloc] initWithUserId:cur.uid];
                    [nav setViewControllers:@[audio] animated:NO];
                    break;
                }
                case 10: { // Поиск
                    VKSearchViewController *search = [[VKSearchViewController alloc] init];
                    [nav setViewControllers:@[search] animated:NO];
                    break;
                }
                case 11: { // Настройки
                    VKSettingsViewController *settings = [[VKSettingsViewController alloc] init];
                    [nav setViewControllers:@[settings] animated:NO];
                    break;
                }
                default: { // Прочее
                    VKMoreViewController *more = [[VKMoreViewController alloc] initWithStyle:UITableViewStyleGrouped];
                    [nav setViewControllers:@[more] animated:NO];
                    break;
                }
            }
        } else if (tabBar) {
            // Режим таббара
            switch (index) {
                case 0: {
                    if (cur && tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKProfileViewController *prof = [[VKProfileViewController alloc] initWithUser:cur];
                        [tNav pushViewController:prof animated:YES];
                    }
                    break;
                }
                case 1: {
                    tabBar.selectedIndex = 0;
                    break;
                }
                case 2: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKNotificationsViewController *notif = [[VKNotificationsViewController alloc] init];
                        [tNav pushViewController:notif animated:YES];
                    }
                    break;
                }
                case 3: {
                    tabBar.selectedIndex = 2;
                    break;
                }
                case 4: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKFriendsListViewController *friends = [[VKFriendsListViewController alloc] initWithUserId:cur.uid];
                        [tNav pushViewController:friends animated:YES];
                    }
                    break;
                }
                case 5: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKGroupsListViewController *groups = [[VKGroupsListViewController alloc] initWithUserId:cur.uid];
                        [tNav pushViewController:groups animated:YES];
                    }
                    break;
                }
                case 6: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKAlbumsListViewController *albums = [[VKAlbumsListViewController alloc] initWithUserId:cur.uid];
                        [tNav pushViewController:albums animated:YES];
                    }
                    break;
                }
                case 7: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKVideosListViewController *videos = [[VKVideosListViewController alloc] initWithUserId:cur.uid];
                        [tNav pushViewController:videos animated:YES];
                    }
                    break;
                }
                case 8: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKAudioListViewController *audio = [[VKAudioListViewController alloc] initWithUserId:cur.uid];
                        [tNav pushViewController:audio animated:YES];
                    }
                    break;
                }
                case 10: {
                    tabBar.selectedIndex = 1;
                    break;
                }
                case 11: {
                    if (tabBar.selectedViewController) {
                        UINavigationController *tNav = (UINavigationController *)tabBar.selectedViewController;
                        VKSettingsViewController *settings = [[VKSettingsViewController alloc] init];
                        [tNav pushViewController:settings animated:YES];
                    }
                    break;
                }
                default: {
                    tabBar.selectedIndex = 3;
                    break;
                }
            }
        }
    }];
}

@end
