#import "VKKateMainViewController.h"
#import "VKProfileViewController.h"
#import "VKFeedViewController.h"
#import "VKMessagesViewController.h"
#import "VKSearchViewController.h"
#import "VKNewPostViewController.h"
#import "VKFriendsListViewController.h"
#import "VKNotificationsViewController.h"
#import "VKAudioListViewController.h"
#import "VKKateSettingsViewController.h"
#import "VKSettingsViewController.h"
#import "VKLoginViewController.h"
#import "VKAuthService.h"
#import "VKThemeManager.h"
#import "VKClientDesign.h"
#import "VKClientDesignGeometry.h"
#import "VKClientDesignSettingsViewController.h"
#import "VKKateSettings.h"
#import "VKLongPollService.h"
#import "VKNavigationController.h"
#import "VKKateTheme.h"

@interface VKKateMainViewController ()

@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *refreshButton;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UIButton *composeButton;
@property (nonatomic, strong) UIButton *overflowButton;

@property (nonatomic, strong) UIView *tabsContainerView;
@property (nonatomic, strong) UIButton *profileTabButton;
@property (nonatomic, strong) UIButton *newsTabButton;
@property (nonatomic, strong) UIButton *messagesTabButton;
@property (nonatomic, strong) UILabel *messagesBadgeLabel;
@property (nonatomic, strong) UIView *tabIndicatorView;
@property (nonatomic, strong) UIView *horDividerView;

@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic, strong) VKProfileViewController *profileVC;
@property (nonatomic, strong) VKFeedViewController *feedVC;
@property (nonatomic, strong) VKMessagesViewController *messagesVC;

@property (nonatomic, assign) BOOL isInitialLayoutDone;

@end

@implementation VKKateMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    VKKateTheme *kt = [VKKateTheme currentTheme];
    self.view.backgroundColor = kt.headerColor;
    
    [self setupHeaderAndTabs];
    [self setupScrollViewAndControllers];
    [self themeDidChange];
    [self updateUnreadCounters];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUnreadCounters) name:VKCountersDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUnreadCounters) name:VKLongPollUnreadCountDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange) name:VKKateThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [self updateUnreadCounters];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (CGFloat)topStatusBarInset {
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) return 0.0;
    if ([self.view respondsToSelector:@selector(safeAreaInsets)] && self.view.safeAreaInsets.top > 0.0) return self.view.safeAreaInsets.top;
    CGRect status = [UIApplication sharedApplication].statusBarFrame;
    return MIN(status.size.width, status.size.height);
}

- (void)setupHeaderAndTabs {
    CGFloat screenW = self.view.bounds.size.width;
    CGFloat statusH = [self topStatusBarInset];
    CGFloat headerH = 44.0;
    CGFloat tabH = 38.0; // @dimen/tab_height in Kate Mobile
    
    VKKateTheme *kt = [VKKateTheme currentTheme];
    
    // 1. Верхний Action Bar
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, statusH + headerH)];
    self.headerView.backgroundColor = kt.headerColor;
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.headerView];
    
    // Заголовок "Kate Mobile"
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, statusH + 7, 160, 30)];
    self.titleLabel.text = @"OpenVK";
    self.titleLabel.accessibilityLabel = @"OpenVK, оформление Kate Mobile";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textColor = kt.headerTitleColor;
    self.titleLabel.backgroundColor = [UIColor clearColor];
    [self.headerView addSubview:self.titleLabel];
    
    // Кнопка Overflow (⋮)
    self.overflowButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.overflowButton.frame = CGRectMake(screenW - 38, statusH + 4, 36, 36);
    self.overflowButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImage *overflowImg = [UIImage imageNamed:@"kate_overflow"];
    if (overflowImg) {
        [self.overflowButton setImage:overflowImg forState:UIControlStateNormal];
    } else {
        [self.overflowButton setTitle:@"⋮" forState:UIControlStateNormal];
        [self.overflowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.overflowButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    }
    [self.overflowButton addTarget:self action:@selector(overflowAction) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.overflowButton];
    
    // Кнопка Создать (✏️)
    self.composeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.composeButton.frame = CGRectMake(screenW - 74, statusH + 4, 36, 36);
    self.composeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImage *composeImg = [UIImage imageNamed:@"kate_compose"];
    if (composeImg) {
        [self.composeButton setImage:composeImg forState:UIControlStateNormal];
    } else {
        [self.composeButton setTitle:@"✏️" forState:UIControlStateNormal];
        self.composeButton.titleLabel.font = [UIFont systemFontOfSize:17];
    }
    [self.composeButton addTarget:self action:@selector(composeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.composeButton];
    
    // Кнопка Поиск (🔍)
    self.searchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.searchButton.frame = CGRectMake(screenW - 110, statusH + 4, 36, 36);
    self.searchButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImage *searchImg = [UIImage imageNamed:@"kate_search"];
    if (searchImg) {
        [self.searchButton setImage:searchImg forState:UIControlStateNormal];
    } else {
        [self.searchButton setTitle:@"🔍" forState:UIControlStateNormal];
        self.searchButton.titleLabel.font = [UIFont systemFontOfSize:17];
    }
    [self.searchButton addTarget:self action:@selector(searchAction) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.searchButton];
    
    // Кнопка Обновить (🔄)
    self.refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.refreshButton.hidden = YES;
    self.refreshButton.frame = CGRectMake(screenW - 146, statusH + 4, 36, 36);
    self.refreshButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImage *refreshImg = [UIImage imageNamed:@"kate_refresh"];
    if (refreshImg) {
        [self.refreshButton setImage:refreshImg forState:UIControlStateNormal];
    } else {
        [self.refreshButton setTitle:@"🔄" forState:UIControlStateNormal];
        self.refreshButton.titleLabel.font = [UIFont systemFontOfSize:17];
    }
    [self.refreshButton addTarget:self action:@selector(refreshCurrentTabAction) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.refreshButton];
    
    // 2. Вкладки (Профиль | Новости | Сообщения)
    self.tabsContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, statusH + headerH, screenW, tabH)];
    self.tabsContainerView.backgroundColor = kt.tabsBackgroundColor;
    self.tabsContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.tabsContainerView];
    
    CGFloat tabW = floorf(screenW / 3.0);
    
    // Вкладка 0: ПРОФИЛЬ
    self.profileTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.profileTabButton.frame = CGRectMake(0, 0, tabW, tabH);
    [self.profileTabButton setTitle:@"Профиль" forState:UIControlStateNormal];
    self.profileTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.profileTabButton setTitleColor:kt.tabTextNormalColor forState:UIControlStateNormal];
    [self.profileTabButton addTarget:self action:@selector(profileTabTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.tabsContainerView addSubview:self.profileTabButton];
    
    // Вкладка 1: НОВОСТИ
    self.newsTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.newsTabButton.frame = CGRectMake(tabW, 0, tabW, tabH);
    [self.newsTabButton setTitle:@"Новости" forState:UIControlStateNormal];
    self.newsTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.newsTabButton setTitleColor:kt.tabTextSelectedColor forState:UIControlStateNormal];
    [self.newsTabButton addTarget:self action:@selector(newsTabTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.tabsContainerView addSubview:self.newsTabButton];
    
    // Вкладка 2: СООБЩЕНИЯ
    self.messagesTabButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.messagesTabButton.frame = CGRectMake(tabW * 2, 0, screenW - tabW * 2, tabH);
    [self.messagesTabButton setTitle:@"Сообщения" forState:UIControlStateNormal];
    self.messagesTabButton.titleLabel.font = [UIFont systemFontOfSize:13];
    [self.messagesTabButton setTitleColor:kt.tabTextNormalColor forState:UIControlStateNormal];
    [self.messagesTabButton addTarget:self action:@selector(messagesTabTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.tabsContainerView addSubview:self.messagesTabButton];
    
    // Бейдж непрочитанных сообщений на вкладке Сообщения
    self.messagesBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(tabW * 3 - 22, 9, 18, 18)];
    self.messagesBadgeLabel.backgroundColor = kt.unreadBadgeColor;
    self.messagesBadgeLabel.textColor = kt.unreadBadgeTextColor;
    self.messagesBadgeLabel.font = [UIFont boldSystemFontOfSize:10.5];
    self.messagesBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.messagesBadgeLabel.layer.cornerRadius = 9.0;
    self.messagesBadgeLabel.clipsToBounds = YES;
    self.messagesBadgeLabel.hidden = YES;
    [self.tabsContainerView addSubview:self.messagesBadgeLabel];
    
    // Полоса-индикатор активной вкладки
    self.tabIndicatorView = [[UIView alloc] initWithFrame:CGRectMake(tabW, tabH - 3.0, tabW, 3.0)];
    self.tabIndicatorView.backgroundColor = kt.tabIndicatorColor;
    [self.tabsContainerView addSubview:self.tabIndicatorView];
    
    // 3. Тонкий горизонтальный разделитель снизу вкладок
    self.horDividerView = [[UIView alloc] initWithFrame:CGRectMake(0, statusH + headerH + tabH, screenW, 1.0)];
    self.horDividerView.backgroundColor = kt.tabDividerColor;
    self.horDividerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.horDividerView];
}

- (void)setupScrollViewAndControllers {
    CGFloat screenW = self.view.bounds.size.width;
    CGFloat screenH = self.view.bounds.size.height;
    CGFloat statusH = [self topStatusBarInset];
    CGFloat topBarH = statusH + 44.0 + 38.0 + 1.0;
    CGFloat scrollH = screenH - topBarH;
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, topBarH, screenW, scrollH)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.pagingEnabled = YES;
    self.scrollView.scrollsToTop = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.bounces = NO;
    self.scrollView.delegate = self;
    self.scrollView.contentSize = CGSizeMake(screenW * 3, scrollH);
    [self.view addSubview:self.scrollView];
    
    // 1. Профиль (Page 0)
    self.profileVC = [[VKProfileViewController alloc] initWithUser:[[VKAuthService sharedService] currentUserModel]];
    [self addChildViewController:self.profileVC];
    self.profileVC.view.frame = CGRectMake(0, 0, screenW, scrollH);
    self.profileVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:self.profileVC.view];
    [self.profileVC didMoveToParentViewController:self];
    
    // 2. Новости (Page 1)
    self.feedVC = [[VKFeedViewController alloc] init];
    [self addChildViewController:self.feedVC];
    self.feedVC.view.frame = CGRectMake(screenW, 0, screenW, scrollH);
    self.feedVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:self.feedVC.view];
    [self.feedVC didMoveToParentViewController:self];
    
    // 3. Сообщения (Page 2)
    self.messagesVC = [[VKMessagesViewController alloc] init];
    [self addChildViewController:self.messagesVC];
    self.messagesVC.view.frame = CGRectMake(screenW * 2, 0, screenW, scrollH);
    self.messagesVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.scrollView addSubview:self.messagesVC.view];
    [self.messagesVC didMoveToParentViewController:self];
    
    // Стартуем на вкладке "Новости" (как в Kate Mobile)
    _currentTabIndex = [VKClientDesign firstTab];
    [self.scrollView setContentOffset:CGPointMake(_currentTabIndex * screenW, 0) animated:NO];
    [self updateTabHighlightForIndex:_currentTabIndex];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    CGFloat status = [self topStatusBarInset], header = 44.0, tabs = 38.0;
    self.headerView.frame = CGRectMake(0, 0, w, status + header);
    self.titleLabel.frame = CGRectMake(14, status + 7, VKClientHeaderTitleWidth(w), 30);
    self.overflowButton.frame = CGRectMake(w - 44, status, 44, 44);
    self.composeButton.frame = CGRectMake(w - 88, status, 44, 44);
    self.searchButton.frame = CGRectMake(w - 132, status, 44, 44);
    self.overflowButton.accessibilityLabel = @"Меню";
    self.searchButton.accessibilityLabel = @"Поиск";
    self.composeButton.accessibilityLabel = self.currentTabIndex == 2 ? @"Написать сообщение" : @"Новая запись";
    self.tabsContainerView.frame = CGRectMake(0, status + header, w, tabs);
    NSArray *buttons = @[self.profileTabButton, self.newsTabButton, self.messagesTabButton];
    for (NSUInteger i = 0; i < buttons.count; ++i) [(UIButton *)buttons[i] setFrame:CGRectMake(i * w / 3.0, 0, w / 3.0, tabs)];
    self.messagesBadgeLabel.frame = CGRectMake(w - 22, (tabs - 18) / 2.0, 18, 18);
    CGFloat top = status + header + tabs + 1.0;
    self.horDividerView.frame = CGRectMake(0, top - 1, w, 1);
    CGRect pageFrame = CGRectMake(0, top, w, MAX(0, h - top));
    BOOL sizeChanged = !CGRectEqualToRect(self.scrollView.frame, pageFrame);
    self.scrollView.frame = pageFrame;
    self.scrollView.contentSize = CGSizeMake(w * 3, self.scrollView.bounds.size.height);
    NSArray *children = @[self.profileVC, self.feedVC, self.messagesVC];
    for (NSUInteger i = 0; i < children.count; ++i) {
        UIViewController *child = children[i];
        child.view.frame = CGRectMake(i * w, 0, w, self.scrollView.bounds.size.height);
    }
    if (sizeChanged) self.scrollView.contentOffset = CGPointMake(self.currentTabIndex * w, 0);
    CGFloat page = w > 0 ? self.scrollView.contentOffset.x / w : self.currentTabIndex;
    self.tabIndicatorView.frame = CGRectMake(page * w / 3.0, tabs - 3, w / 3.0, 3);
}

#pragma mark - Tab Switching

- (void)profileTabTapped {
    [self switchToTab:0 animated:YES];
}

- (void)newsTabTapped {
    [self switchToTab:1 animated:YES];
}

- (void)messagesTabTapped {
    [self switchToTab:2 animated:YES];
}

- (void)switchToTab:(NSInteger)index animated:(BOOL)animated {
    if (index < 0 || index > 2) return;
    _currentTabIndex = index;
    CGFloat screenW = self.scrollView.bounds.size.width;
    [self.scrollView setContentOffset:CGPointMake(index * screenW, 0) animated:animated];
    [self updateTabHighlightForIndex:index];
}

- (void)updateTabHighlightForIndex:(NSInteger)index {
    if (index < 0 || index > 2) return;
    _currentTabIndex = index;
    
    self.profileVC.tableView.scrollsToTop = index == 0;
    self.feedVC.tableView.scrollsToTop = index == 1;
    self.messagesVC.tableView.scrollsToTop = index == 2;
    VKKateTheme *kt = [VKKateTheme currentTheme];
    UIColor *activeColor = kt.tabTextSelectedColor;
    UIColor *inactiveColor = kt.tabTextNormalColor;
    
    [self.profileTabButton setTitleColor:(index == 0 ? activeColor : inactiveColor) forState:UIControlStateNormal];
    [self.newsTabButton setTitleColor:(index == 1 ? activeColor : inactiveColor) forState:UIControlStateNormal];
    [self.messagesTabButton setTitleColor:(index == 2 ? activeColor : inactiveColor) forState:UIControlStateNormal];
    
    [self.composeButton setTitle:nil forState:UIControlStateNormal];
    self.composeButton.accessibilityLabel = index == 2 ? @"Написать сообщение" : @"Новая запись";
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.scrollView && scrollView.bounds.size.width > 0) {
        CGFloat pageOffset = scrollView.contentOffset.x / scrollView.bounds.size.width;
        CGFloat tabW = self.tabsContainerView.bounds.size.width / 3.0;
        
        CGRect f = self.tabIndicatorView.frame;
        f.origin.x = pageOffset * tabW;
        self.tabIndicatorView.frame = f;
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.scrollView && scrollView.bounds.size.width > 0) {
        NSInteger page = (NSInteger)roundf(scrollView.contentOffset.x / scrollView.bounds.size.width);
        [self updateTabHighlightForIndex:page];
    }
}

#pragma mark - Actions

- (void)refreshCurrentTabAction {
    if (_currentTabIndex == 0) {
        [self.profileVC refreshProfile];
    } else if (_currentTabIndex == 1) {
        [self.feedVC refreshFeed];
    } else if (_currentTabIndex == 2) {
        [self.messagesVC loadDialogs];
    }
}

- (void)searchAction {
    VKSearchViewController *searchVC = [[VKSearchViewController alloc] init];
    [self.navigationController pushViewController:searchVC animated:YES];
}

- (void)composeAction {
    if (self.currentTabIndex == 2) {
        // Написать новое сообщение -> выбор из списка друзей
        NSInteger myId = [[VKAuthService sharedService] currentUserId];
        VKFriendsListViewController *friendsVC = [[VKFriendsListViewController alloc] initWithUserId:myId];
        [self.navigationController pushViewController:friendsVC animated:YES];
    } else {
        // Создать новую запись на стену
        VKNewPostViewController *newPostVC = [[VKNewPostViewController alloc] init];
        VKNavigationController *nav = [[VKNavigationController alloc] initWithRootViewController:newPostVC];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)overflowAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"OpenVK" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    sheet.tag = 1001;
    for (NSString *title in @[@"Учётные записи", @"Ответы", @"Моя музыка", @"Настройки этой темы", @"Настройки OpenVK", @"Обновить"]) [sheet addButtonWithTitle:title];
    if ([VKKateSettings isUnlocked]) [sheet addButtonWithTitle:@"Дополнительные функции Kate"];
    [sheet addButtonWithTitle:@"Выход"];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 1001) {
        if (buttonIndex < 0 || buttonIndex == actionSheet.cancelButtonIndex) return;
        if (buttonIndex == 0) [self showAccountsMenu];
        else if (buttonIndex == 1) [self.navigationController pushViewController:[[VKNotificationsViewController alloc] init] animated:YES];
        else if (buttonIndex == 2) [self.navigationController pushViewController:[[VKAudioListViewController alloc] init] animated:YES];
        else if (buttonIndex == 3) [self.navigationController pushViewController:[[VKClientDesignSettingsViewController alloc] initWithTheme:VKThemeTypeKateMobile] animated:YES];
        else if (buttonIndex == 4) [self.navigationController pushViewController:[[VKSettingsViewController alloc] init] animated:YES];
        else if (buttonIndex == 5) [self refreshCurrentTabAction];
        else if (buttonIndex == 6 && [VKKateSettings isUnlocked]) [self.navigationController pushViewController:[[VKKateSettingsViewController alloc] init] animated:YES];
        else if (buttonIndex == ([VKKateSettings isUnlocked] ? 7 : 6)) [[VKAuthService sharedService] logout];
    } else if (actionSheet.tag == 1002) {
        // Выбор аккаунта
        NSArray *accounts = [[VKAuthService sharedService] accounts];
        if (buttonIndex < (NSInteger)accounts.count) {
            VKAuthAccount *targetAcc = accounts[buttonIndex];
            [[VKAuthService sharedService] switchToAccount:targetAcc];
        } else if (buttonIndex == (NSInteger)accounts.count) {
            // Добавить учётную запись
            VKLoginViewController *loginVC = [[VKLoginViewController alloc] init];
            VKNavigationController *nav = [[VKNavigationController alloc] initWithRootViewController:loginVC];
            [self presentViewController:nav animated:YES completion:nil];
        }
    }
}

- (void)showAccountsMenu {
    NSArray *accounts = [[VKAuthService sharedService] accounts];
    UIActionSheet *accSheet = [[UIActionSheet alloc] initWithTitle:@"Учётные записи"
                                                          delegate:self
                                                 cancelButtonTitle:nil
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:nil];
    accSheet.tag = 1002;
    for (VKAuthAccount *acc in accounts) {
        NSString *title = acc.user.displayName ?: [NSString stringWithFormat:@"id%ld", (long)acc.user.uid];
        if (acc.instanceHost.length > 0) {
            title = [NSString stringWithFormat:@"%@ (%@)", title, acc.instanceHost];
        }
        [accSheet addButtonWithTitle:title];
    }
    [accSheet addButtonWithTitle:@"+ Добавить аккаунт"];
    [accSheet addButtonWithTitle:@"Отмена"];
    accSheet.cancelButtonIndex = accounts.count + 1;
    [accSheet showInView:self.view];
}

#pragma mark - Badges & Theme

- (void)updateUnreadCounters {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger count = [[VKAuthService sharedService] messagesCount];
        if (count > 0) {
            self.messagesBadgeLabel.hidden = NO;
            self.messagesBadgeLabel.text = (count > 99) ? @"99+" : [NSString stringWithFormat:@"%ld", (long)count];
        } else {
            self.messagesBadgeLabel.hidden = YES;
        }
    });
}

- (void)themeDidChange {
    VKKateTheme *kt = [VKKateTheme currentTheme];
    self.view.backgroundColor = kt.headerColor;
    self.headerView.backgroundColor = kt.headerColor;
    self.titleLabel.textColor = kt.headerTitleColor;
    self.tabsContainerView.backgroundColor = kt.tabsBackgroundColor;
    self.tabIndicatorView.backgroundColor = kt.tabIndicatorColor;
    self.horDividerView.backgroundColor = kt.tabDividerColor;
    [self.overflowButton setImage:[VKClientDesign iconNamed:@"kate_overflow" color:kt.headerTitleColor] forState:UIControlStateNormal];
    [self.searchButton setImage:[VKClientDesign iconNamed:@"kate_search" color:kt.headerTitleColor] forState:UIControlStateNormal];
    [self.composeButton setImage:[VKClientDesign iconNamed:@"kate_compose" color:kt.headerTitleColor] forState:UIControlStateNormal];
    self.messagesBadgeLabel.backgroundColor = kt.unreadBadgeColor;
    self.messagesBadgeLabel.textColor = kt.unreadBadgeTextColor;
    [self updateTabHighlightForIndex:_currentTabIndex];
}

@end
