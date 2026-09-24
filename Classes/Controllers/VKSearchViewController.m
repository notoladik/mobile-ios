#import "VKSearchViewController.h"
#import "VKSearchService.h"
#import "VKProfileViewController.h"
#import "VKPostDetailViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import "VKFeedPostCell.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import "VKAppConfig.h"
#import "VKProfileService.h"

@interface VKSearchVideoGridCell : UITableViewCell
@property (nonatomic, strong) NSArray<VKAttachment *> *videos;
@property (nonatomic, copy) void (^onVideoTapped)(VKAttachment *video);
@end

@implementation VKSearchVideoGridCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)configureWithVideos:(NSArray<VKAttachment *> *)videos width:(CGFloat)width {
    self.videos = videos;
    for (UIView *v in self.contentView.subviews) [v removeFromSuperview];
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    
    CGFloat margin = 12.0;
    CGFloat gap = 10.0;
    CGFloat itemW = (width - margin * 2.0 - gap) / 2.0;
    CGFloat itemH = 100.0;
    
    for (NSInteger i = 0; i < MIN(4, (NSInteger)videos.count); i++) {
        VKAttachment *v = videos[i];
        CGFloat x = margin + (i % 2) * (itemW + gap);
        CGFloat y = 4.0 + (i / 2) * (itemH + 46.0);
        
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, itemW, itemH + 40.0)];
        card.tag = i;
        card.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoClicked:)];
        [card addGestureRecognizer:tap];
        
        // Превью видео
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, itemW, itemH)];
        imgView.contentMode = UIViewContentModeScaleAspectFill;
        imgView.clipsToBounds = YES;
        imgView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        
        if (isSkeuomorph) {
            imgView.layer.cornerRadius = 3.5;
            imgView.layer.borderWidth = 0.5;
            imgView.layer.borderColor = [UIColor colorWithRed:200.0/255.0 green:205.0/255.0 blue:215.0/255.0 alpha:1.0].CGColor;
        } else if (isFlat) {
            imgView.layer.cornerRadius = 4.0;
            imgView.layer.borderWidth = 0.0;
        } else {
            imgView.layer.cornerRadius = 10.0;
            imgView.layer.borderWidth = 0.0;
        }
        
        if (v.videoImageURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:v.videoImageURL completion:^(UIImage *img) {
                if (img) imgView.image = img;
            }];
        }
        [card addSubview:imgView];
        
        // Кнопка play
        UILabel *playBadge = [[UILabel alloc] initWithFrame:CGRectMake((itemW - 36)/2.0, (itemH - 36)/2.0, 36, 36)];
        playBadge.text = @"▶";
        playBadge.textColor = [UIColor whiteColor];
        playBadge.font = [UIFont boldSystemFontOfSize:16];
        playBadge.textAlignment = NSTextAlignmentCenter;
        playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        playBadge.layer.cornerRadius = 18.0;
        playBadge.clipsToBounds = YES;
        [imgView addSubview:playBadge];
        
        // Бейдж длительности
        UILabel *durLbl = [[UILabel alloc] initWithFrame:CGRectMake(itemW - 46, itemH - 22, 40, 16)];
        durLbl.text = v.videoDuration ?: @"0:00";
        durLbl.textColor = [UIColor whiteColor];
        durLbl.font = [UIFont boldSystemFontOfSize:10];
        durLbl.textAlignment = NSTextAlignmentCenter;
        durLbl.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        durLbl.layer.cornerRadius = 3.5;
        durLbl.clipsToBounds = YES;
        [imgView addSubview:durLbl];
        
        // Заголовок под видео
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, itemH + 4, itemW, 34)];
        titleLbl.text = v.videoTitle ?: @"Видеозапись";
        titleLbl.font = [UIFont boldSystemFontOfSize:12];
        titleLbl.numberOfLines = 2;
        
        if (isSkeuomorph) {
            titleLbl.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0]; // #2B587A
        } else if (isFlat) {
            titleLbl.textColor = [UIColor colorWithRed:44.0/255.0 green:62.0/255.0 blue:80.0/255.0 alpha:1.0];
        } else {
            titleLbl.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
        }
        [card addSubview:titleLbl];
        
        [self.contentView addSubview:card];
    }
}

- (void)videoClicked:(UITapGestureRecognizer *)gesture {
    NSInteger idx = gesture.view.tag;
    if (idx >= 0 && idx < (NSInteger)self.videos.count && self.onVideoTapped) {
        self.onVideoTapped(self.videos[idx]);
    }
}

+ (CGFloat)heightForVideosCount:(NSInteger)count {
    if (count <= 0) return 0;
    if (count <= 2) return 150.0;
    return 300.0;
}

@end

// Ячейка пользователя с кнопкой быстрого добавления в друзья (+👤) как в оригинальном клиенте VK (IMG_5187.PNG)
@interface VKSearchUserCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *verifiedBadgeLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, copy) void (^onActionTapped)(VKUser *user);
@property (nonatomic, strong) VKUser *currentUser;

- (void)configureWithUser:(VKUser *)user width:(CGFloat)width isFriendOrRequested:(BOOL)isRequested;
@end

@implementation VKSearchUserCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleDefault;
        self.backgroundColor = [UIColor whiteColor];
        
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 48, 48)];
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.clipsToBounds = YES;
        [self.contentView addSubview:_avatarImageView];
        
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 14, 180, 20)];
        _nameLabel.font = [UIFont boldSystemFontOfSize:15.0];
        _nameLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
        [self.contentView addSubview:_nameLabel];
        
        _verifiedBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _verifiedBadgeLabel.text = @"✓";
        _verifiedBadgeLabel.font = [UIFont boldSystemFontOfSize:10.0];
        _verifiedBadgeLabel.textColor = [UIColor whiteColor];
        _verifiedBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _verifiedBadgeLabel.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        _verifiedBadgeLabel.layer.cornerRadius = 7.0;
        _verifiedBadgeLabel.clipsToBounds = YES;
        _verifiedBadgeLabel.hidden = YES;
        [self.contentView addSubview:_verifiedBadgeLabel];
        
        _subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 36, 180, 18)];
        _subtitleLabel.font = [UIFont systemFontOfSize:13.0];
        _subtitleLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [self.contentView addSubview:_subtitleLabel];
        
        _actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _actionButton.frame = CGRectMake(0, 0, 46, 30);
        _actionButton.layer.cornerRadius = 5.0;
        _actionButton.clipsToBounds = YES;
        _actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
        [_actionButton addTarget:self action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_actionButton];
    }
    return self;
}

- (void)actionButtonTapped {
    if (self.onActionTapped && self.currentUser) {
        self.onActionTapped(self.currentUser);
    }
}

- (void)configureWithUser:(VKUser *)user width:(CGFloat)width isFriendOrRequested:(BOOL)isRequested {
    self.currentUser = user;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.avatarImageView.layer.cornerRadius = (isSkeuomorph || user.isGroup) ? 4.0 : 24.0;
    if (isSkeuomorph) {
        self.avatarImageView.layer.borderWidth = 0.5;
        self.avatarImageView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
        self.nameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        self.avatarImageView.layer.borderWidth = 0.0;
        self.nameLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    self.avatarImageView.image = [UIImage imageNamed:@"user_placeholder"];
    if (user.avatarURL.length > 0) {
        __weak typeof(self) weakSelf = self;
        [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
            if (img && weakSelf.currentUser == user) {
                weakSelf.avatarImageView.image = img;
            }
        }];
    }
    
    self.nameLabel.text = user.displayName ?: @"";
    CGSize nameSize = [self.nameLabel.text sizeWithFont:self.nameLabel.font];
    CGFloat maxNameW = width - 70.0 - 64.0;
    CGFloat actualNameW = MIN(ceilf(nameSize.width), maxNameW);
    self.nameLabel.frame = CGRectMake(70, 14, actualNameW, 20);
    
    if (user.isOfficial) {
        self.verifiedBadgeLabel.hidden = NO;
        self.verifiedBadgeLabel.frame = CGRectMake(70 + actualNameW + 5.0, 17.0, 14.0, 14.0);
    } else {
        self.verifiedBadgeLabel.hidden = YES;
    }
    
    NSString *sub = @"";
    if (user.isGroup) {
        sub = user.groupType.length > 0 ? user.groupType : @"Сообщество";
    } else {
        if (user.city.length > 0) {
            sub = user.city;
        } else if (user.isOnline) {
            sub = user.onlinePlatform.length > 0 ? [NSString stringWithFormat:@"Online (%@)", user.onlinePlatform] : @"Online";
        }
    }
    self.subtitleLabel.text = sub;
    self.subtitleLabel.frame = CGRectMake(70, 36, width - 70.0 - 64.0, 18);
    
    // Кнопка действия (в точности как в IMG_5187.PNG: +👤)
    CGFloat btnW = 46.0;
    CGFloat btnH = 30.0;
    self.actionButton.frame = CGRectMake(width - 12.0 - btnW, 19.0, btnW, btnH);
    
    if (isRequested || user.isFriend) {
        self.actionButton.enabled = NO;
        [self.actionButton setTitle:@"✓" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:[UIColor colorWithWhite:0.5 alpha:1.0] forState:UIControlStateNormal];
        self.actionButton.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:242.0/255.0 alpha:1.0];
        self.actionButton.layer.borderWidth = 0.5;
        self.actionButton.layer.borderColor = [UIColor colorWithWhite:0.82 alpha:1.0].CGColor;
    } else {
        self.actionButton.enabled = YES;
        [self.actionButton setTitle:@"+👤" forState:UIControlStateNormal];
        [self.actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.actionButton.backgroundColor = [UIColor colorWithRed:79.0/255.0 green:128.0/255.0 blue:185.0/255.0 alpha:1.0];
        self.actionButton.layer.borderWidth = 0.0;
    }
}

@end

@interface VKSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIScrollView *categoriesScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *categoryButtons;
@property (nonatomic, assign) NSInteger selectedCategoryIndex;

// Панель параметров фильтрации (IMG_5187.PNG)
@property (nonatomic, strong) UIView *filterBarView;
@property (nonatomic, strong) UIButton *filterParamsButton;
@property (nonatomic, assign) BOOL filterOnlineOnly;
@property (nonatomic, assign) BOOL filterHasPhotoOnly;
@property (nonatomic, assign) NSInteger filterSex; // 0 = any, 1 = female, 2 = male
@property (nonatomic, assign) NSInteger filterSort; // 0 = default, 1 = popularity
@property (nonatomic, assign) NSInteger usersFoundCount;
@property (nonatomic, strong) NSMutableSet *requestedUserIds;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *currentQuery;

// Результаты для режима "Все"
@property (nonatomic, strong) NSArray *allVideos;
@property (nonatomic, strong) NSArray *allPosts;
@property (nonatomic, strong) NSArray *allUsers;
@property (nonatomic, strong) NSArray *allGroups;
@property (nonatomic, strong) NSArray *allAudios;
@property (nonatomic, strong) NSMutableArray *singleResults;
@property (nonatomic, strong) NSMutableSet *revealedPostIds;
@end

@implementation VKSearchViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.view setNeedsLayout];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Поиск";
    self.categoryButtons = [NSMutableArray array];
    self.singleResults = [NSMutableArray array];
    self.revealedPostIds = [NSMutableSet set];
    self.requestedUserIds = [NSMutableSet set];
    self.selectedCategoryIndex = 0;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nsfwSettingChanged) name:VKNSFWSettingDidChangeNotification object:nil];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    CGFloat width = self.view.bounds.size.width;
    if (width <= 0) width = 320.0;
    
    // SearchBar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск";
    [self.view addSubview:self.searchBar];
    
    // Карусель категорий
    self.categoriesScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 44, width, 38)];
    self.categoriesScrollView.showsHorizontalScrollIndicator = NO;
    self.categoriesScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.categoriesScrollView];
    
    NSArray *cats = @[
        @{@"title": @"Все", @"icon": @"✦"},
        @{@"title": @"Люди", @"icon": @"👥"},
        @{@"title": @"Сообщества", @"icon": @"👥"},
        @{@"title": @"Видеозаписи", @"icon": @"🎬"},
        @{@"title": @"Музыка", @"icon": @"🎵"},
        @{@"title": @"Записи", @"icon": @"📰"},
        @{@"title": @"Документы", @"icon": @"📄"}
    ];
    
    CGFloat curX = 10.0;
    for (NSInteger i = 0; i < (NSInteger)cats.count; i++) {
        NSDictionary *c = cats[i];
        NSString *title = [NSString stringWithFormat:@"%@  %@", c[@"icon"], c[@"title"]];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = i;
        [btn setTitle:title forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:12.5];
        
        CGSize s = [title sizeWithFont:[UIFont systemFontOfSize:12.5]];
        CGFloat btnW = ceilf(s.width) + 20.0;
        btn.frame = CGRectMake(curX, 6, btnW, 26);
        [btn addTarget:self action:@selector(categoryTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [self.categoriesScrollView addSubview:btn];
        [self.categoryButtons addObject:btn];
        curX += btnW + 6.0;
    }
    self.categoriesScrollView.contentSize = CGSizeMake(curX + 8.0, 38);
    
    // Панель параметров фильтрации ("Указать параметры" в стиле оригинального VK клиента / IMG_5187.PNG)
    self.filterBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 82, width, 32)];
    self.filterBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.filterBarView.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:249.0/255.0 blue:251.0/255.0 alpha:1.0];
    [self.view addSubview:self.filterBarView];
    
    UIView *filterSep = [[UIView alloc] initWithFrame:CGRectMake(0, 31.5, width, 0.5)];
    filterSep.backgroundColor = [UIColor colorWithRed:224.0/255.0 green:227.0/255.0 blue:232.0/255.0 alpha:1.0];
    filterSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.filterBarView addSubview:filterSep];
    
    self.filterParamsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.filterParamsButton.frame = CGRectMake(12, 3, width - 24, 26);
    self.filterParamsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.filterParamsButton setTitle:@"⚙️  Указать параметры" forState:UIControlStateNormal];
    [self.filterParamsButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.filterParamsButton.titleLabel.font = [UIFont systemFontOfSize:13.0];
    [self.filterParamsButton addTarget:self action:@selector(filterParamsTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.filterBarView addSubview:self.filterParamsButton];
    
    // TableView
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 114, width, self.view.bounds.size.height - 114) style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    [self setupNavigationItems];
    [self applyThemeStyle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    self.searchBar.frame = CGRectMake(0, 0, width, 44);
    self.categoriesScrollView.frame = CGRectMake(0, 44, width, 38);
    self.filterBarView.frame = CGRectMake(0, 82, width, 32);
    self.tableView.frame = CGRectMake(0, 114, width, height - 114);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
}

- (void)leftMenuButtonAction {
    [[VKSideMenuManager sharedManager] toggleMenu];
}

- (void)applyThemeStyle {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    if (isSkeuomorph) {
        self.categoriesScrollView.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0];
        if ([self.searchBar respondsToSelector:@selector(setBarStyle:)]) {
            self.searchBar.barStyle = UIBarStyleBlackTranslucent;
            self.searchBar.tintColor = [UIColor colorWithRed:75.0/255.0 green:95.0/255.0 blue:125.0/255.0 alpha:1.0];
        }
    } else if (isFlat) {
        self.categoriesScrollView.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:244.0/255.0 blue:247.0/255.0 alpha:1.0];
        if ([self.searchBar respondsToSelector:@selector(setBarStyle:)]) {
            self.searchBar.barStyle = UIBarStyleDefault;
            self.searchBar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        }
    } else {
        self.categoriesScrollView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:248.0/255.0 alpha:1.0];
        if ([self.searchBar respondsToSelector:@selector(setBarStyle:)]) {
            self.searchBar.barStyle = UIBarStyleDefault;
            self.searchBar.tintColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
        }
    }
    
    if (isSkeuomorph) {
        self.filterBarView.backgroundColor = [UIColor colorWithRed:228.0/255.0 green:231.0/255.0 blue:236.0/255.0 alpha:1.0];
    } else if (isFlat) {
        self.filterBarView.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:249.0/255.0 blue:251.0/255.0 alpha:1.0];
    } else {
        self.filterBarView.backgroundColor = [UIColor colorWithRed:250.0/255.0 green:251.0/255.0 blue:253.0/255.0 alpha:1.0];
    }
    
    [self updateCategoryButtonsStyle];
    
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar) {
        bar.barTintColor = [[VKThemeManager sharedManager] navBarBackgroundColor];
        bar.tintColor = [[VKThemeManager sharedManager] navBarTintColor];
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [[VKThemeManager sharedManager] navBarTitleColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
    
    [self.tableView reloadData];
}

- (void)categoryTapped:(UIButton *)sender {
    self.selectedCategoryIndex = sender.tag;
    [self updateCategoryButtonsStyle];
    [self performSearchWithQuery:self.currentQuery];
}

- (void)updateCategoryButtonsStyle {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    
    for (NSInteger i = 0; i < (NSInteger)self.categoryButtons.count; i++) {
        UIButton *btn = self.categoryButtons[i];
        BOOL isSelected = (i == self.selectedCategoryIndex);
        
        if (isSkeuomorph) {
            // iOS 6 Skeuomorphic
            btn.layer.cornerRadius = 3.5;
            btn.clipsToBounds = YES;
            btn.layer.borderWidth = 0.5;
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
            
            if (isSelected) {
                btn.backgroundColor = [UIColor colorWithRed:69.0/255.0 green:104.0/255.0 blue:142.0/255.0 alpha:1.0];
                btn.layer.borderColor = [UIColor colorWithRed:45.0/255.0 green:75.0/255.0 blue:110.0/255.0 alpha:1.0].CGColor;
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                btn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
                btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
            } else {
                btn.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0];
                btn.layer.borderColor = [UIColor colorWithRed:185.0/255.0 green:190.0/255.0 blue:200.0/255.0 alpha:1.0].CGColor;
                [btn setTitleColor:[UIColor colorWithRed:60.0/255.0 green:65.0/255.0 blue:75.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                btn.titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.8];
                btn.titleLabel.shadowOffset = CGSizeMake(0, 1);
            }
        } else if (isFlat) {
            // UIKit Classic Flat (iOS 7-10)
            btn.layer.cornerRadius = 13.0;
            btn.clipsToBounds = YES;
            btn.layer.borderWidth = 0.0;
            btn.titleLabel.shadowOffset = CGSizeZero;
            btn.titleLabel.font = isSelected ? [UIFont boldSystemFontOfSize:12.5] : [UIFont systemFontOfSize:12.5];
            
            if (isSelected) {
                btn.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else {
                btn.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:242.0/255.0 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:85.0/255.0 green:95.0/255.0 blue:110.0/255.0 alpha:1.0] forState:UIControlStateNormal];
            }
        } else {
            // Modern Swift (iOS 16-18)
            btn.layer.cornerRadius = 13.0;
            btn.clipsToBounds = YES;
            btn.layer.borderWidth = 0.0;
            btn.titleLabel.shadowOffset = CGSizeZero;
            btn.titleLabel.font = [UIFont systemFontOfSize:12.5];
            
            if (isSelected) {
                btn.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            } else {
                btn.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:243.0/255.0 alpha:1.0];
                [btn setTitleColor:[UIColor colorWithRed:100.0/255.0 green:105.0/255.0 blue:115.0/255.0 alpha:1.0] forState:UIControlStateNormal];
            }
        }
    }
}

#pragma mark - Filter Parameters (IMG_5187.PNG)

- (void)filterParamsTapped {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Параметры поиска"
                                                       delegate:self
                                              cancelButtonTitle:@"Закрыть"
                                         destructiveButtonTitle:@"Сбросить все параметры"
                                              otherButtonTitles:
                            self.filterOnlineOnly ? @"✓ Только онлайн: Включено" : @"Только онлайн: Выключено",
                            self.filterHasPhotoOnly ? @"✓ Только с фото: Включено" : @"Только с фото: Выключено",
                            self.filterSex == 2 ? @"✓ Пол: Мужской" : @"Пол: Мужской",
                            self.filterSex == 1 ? @"✓ Пол: Женский" : @"Пол: Женский",
                            self.filterSex == 0 ? @"✓ Пол: Любой" : @"Пол: Любой",
                            self.filterSort == 1 ? @"✓ Сортировка: По популярности" : @"Сортировка: По популярности",
                            nil];
    sheet.tag = 7701;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 7701) {
        if (buttonIndex == 0) {
            // Сброс
            self.filterOnlineOnly = NO;
            self.filterHasPhotoOnly = NO;
            self.filterSex = 0;
            self.filterSort = 0;
        } else if (buttonIndex == 1) {
            self.filterOnlineOnly = !self.filterOnlineOnly;
        } else if (buttonIndex == 2) {
            self.filterHasPhotoOnly = !self.filterHasPhotoOnly;
        } else if (buttonIndex == 3) {
            self.filterSex = (self.filterSex == 2) ? 0 : 2;
        } else if (buttonIndex == 4) {
            self.filterSex = (self.filterSex == 1) ? 0 : 1;
        } else if (buttonIndex == 5) {
            self.filterSex = 0;
        } else if (buttonIndex == 6) {
            self.filterSort = (self.filterSort == 1) ? 0 : 1;
        }
        [self updateFilterButtonTitle];
        [self performSearchWithQuery:self.currentQuery];
    }
}

- (void)updateFilterButtonTitle {
    NSMutableArray *active = [NSMutableArray array];
    if (self.filterOnlineOnly) [active addObject:@"Онлайн"];
    if (self.filterHasPhotoOnly) [active addObject:@"С фото"];
    if (self.filterSex == 2) [active addObject:@"Мужчины"];
    if (self.filterSex == 1) [active addObject:@"Женщины"];
    if (self.filterSort == 1) [active addObject:@"Популярные"];
    
    if (active.count > 0) {
        NSString *t = [NSString stringWithFormat:@"⚙️  Параметры: %@  (изменить)", [active componentsJoinedByString:@", "]];
        [self.filterParamsButton setTitle:t forState:UIControlStateNormal];
        [self.filterParamsButton setTitleColor:[UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.filterParamsButton setTitle:@"⚙️  Указать параметры" forState:UIControlStateNormal];
        [self.filterParamsButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.currentQuery = searchText;
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(performSearchDelayed) withObject:nil afterDelay:0.35];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self performSearchWithQuery:searchBar.text];
}

- (void)performSearchDelayed {
    [self performSearchWithQuery:self.currentQuery];
}

- (void)performSearchWithQuery:(NSString *)query {
    NSString *clean = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        self.allVideos = @[];
        self.allPosts = @[];
        self.allUsers = @[];
        self.allGroups = @[];
        self.allAudios = @[];
        [self.singleResults removeAllObjects];
        [self.tableView reloadData];
        return;
    }
    
    if (self.selectedCategoryIndex == 0) {
        // ✦ Все
        [[VKSearchService sharedService] searchAllWithQuery:clean completion:^(NSArray *videos, NSArray *posts, NSArray *users, NSArray *groups, NSArray *audios) {
            self.allVideos = videos ?: @[];
            self.allPosts = posts ?: @[];
            self.allUsers = users ?: @[];
            self.allGroups = groups ?: @[];
            self.allAudios = audios ?: @[];
            [self.tableView reloadData];
        }];
    } else if (self.selectedCategoryIndex == 1) {
        // 👥 Люди
        [[VKSearchService sharedService] searchUsersWithQuery:clean
                                                         sort:self.filterSort
                                                          sex:self.filterSex
                                                       online:self.filterOnlineOnly
                                                     hasPhoto:self.filterHasPhotoOnly
                                                       offset:0
                                                        count:30
                                                   completion:^(NSArray *users, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            self.usersFoundCount = totalCount;
            if (users) [self.singleResults addObjectsFromArray:users];
            [self.tableView reloadData];
        }];
    } else if (self.selectedCategoryIndex == 2) {
        // 👥 Сообщества
        [[VKSearchService sharedService] searchGroupsWithQuery:clean offset:0 count:30 completion:^(NSArray *groups, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            if (groups) [self.singleResults addObjectsFromArray:groups];
            [self.tableView reloadData];
        }];
    } else if (self.selectedCategoryIndex == 3) {
        // 🎬 Видеозаписи
        [[VKSearchService sharedService] searchVideosWithQuery:clean offset:0 count:30 completion:^(NSArray *videos, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            if (videos) [self.singleResults addObjectsFromArray:videos];
            [self.tableView reloadData];
        }];
    } else if (self.selectedCategoryIndex == 4) {
        // 🎵 Музыка
        [[VKSearchService sharedService] searchAudiosWithQuery:clean offset:0 count:30 completion:^(NSArray *audios, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            if (audios) [self.singleResults addObjectsFromArray:audios];
            [self.tableView reloadData];
        }];
    } else if (self.selectedCategoryIndex == 5) {
        // 📰 Записи
        [[VKSearchService sharedService] searchNewsWithQuery:clean offset:0 count:30 completion:^(NSArray *posts, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            if (posts) [self.singleResults addObjectsFromArray:posts];
            [self.tableView reloadData];
        }];
    } else {
        // 📄 Документы
        [[VKSearchService sharedService] searchDocsWithQuery:clean offset:0 count:30 completion:^(NSArray *docs, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
            if (docs) [self.singleResults addObjectsFromArray:docs];
            [self.tableView reloadData];
        }];
    }
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.selectedCategoryIndex == 0) {
        NSInteger s = 0;
        if (self.allVideos.count > 0) s++;
        if (self.allPosts.count > 0) s++;
        if (self.allAudios.count > 0) s++;
        if (self.allUsers.count > 0) s++;
        if (self.allGroups.count > 0) s++;
        return s;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.selectedCategoryIndex == 0) {
        if (section == 0 && self.allVideos.count > 0) return 1; // Сетка 2x2
        return self.allPosts.count;
    }
    return self.singleResults.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.selectedCategoryIndex == 0) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 36)];
        header.backgroundColor = [UIColor clearColor];
        
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 160, 20)];
        titleLbl.font = [UIFont boldSystemFontOfSize:14];
        
        BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
        titleLbl.textColor = isSkeuomorph ? [UIColor colorWithRed:75.0/255.0 green:85.0/255.0 blue:100.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.5 alpha:1.0];
        
        UIButton *seeAllBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        seeAllBtn.frame = CGRectMake(tableView.bounds.size.width - 130, 8, 118, 20);
        [seeAllBtn setTitle:@"Показать все ›" forState:UIControlStateNormal];
        
        UIColor *accent = [[VKThemeManager sharedManager] accentColor];
        [seeAllBtn setTitleColor:accent forState:UIControlStateNormal];
        seeAllBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        seeAllBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        
        if (section == 0 && self.allVideos.count > 0) {
            titleLbl.text = @"ВИДЕОЗАПИСИ";
            seeAllBtn.tag = 3;
            [seeAllBtn addTarget:self action:@selector(seeAllTapped:) forControlEvents:UIControlEventTouchUpInside];
        } else {
            titleLbl.text = @"ЗАПИСИ";
            seeAllBtn.tag = 5;
            [seeAllBtn addTarget:self action:@selector(seeAllTapped:) forControlEvents:UIControlEventTouchUpInside];
        }
        
        [header addSubview:titleLbl];
        [header addSubview:seeAllBtn];
        return header;
    } else if (self.selectedCategoryIndex == 1 && self.singleResults.count > 0) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 28)];
        header.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:248.0/255.0 alpha:1.0];
        
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 4, tableView.bounds.size.width - 24, 20)];
        titleLbl.font = [UIFont systemFontOfSize:13.0];
        titleLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        NSInteger cnt = (self.usersFoundCount > 0) ? self.usersFoundCount : self.singleResults.count;
        titleLbl.text = [NSString stringWithFormat:@"Найдено %ld %@", (long)cnt, (cnt == 1 ? @"пользователь" : (cnt >= 2 && cnt <= 4 ? @"пользователя" : @"пользователей"))];
        [header addSubview:titleLbl];
        return header;
    }
    return nil;
}

- (void)seeAllTapped:(UIButton *)sender {
    self.selectedCategoryIndex = sender.tag;
    [self updateCategoryButtonsStyle];
    [self performSearchWithQuery:self.currentQuery];
}

- (void)nsfwSettingChanged {
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.selectedCategoryIndex == 0) return 36.0;
    if (self.selectedCategoryIndex == 1 && self.singleResults.count > 0) return 28.0;
    return 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selectedCategoryIndex == 0) {
        if (indexPath.section == 0 && self.allVideos.count > 0) {
            return [VKSearchVideoGridCell heightForVideosCount:self.allVideos.count];
        }
        VKPost *p = self.allPosts[indexPath.row];
        BOOL isRevealed = [self.revealedPostIds containsObject:@(p.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
        return [VKFeedPostCell heightForPost:p width:tableView.bounds.size.width isRevealed:isRevealed];
    } else if (self.selectedCategoryIndex == 5) {
        VKPost *p = self.singleResults[indexPath.row];
        BOOL isRevealed = [self.revealedPostIds containsObject:@(p.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
        return [VKFeedPostCell heightForPost:p width:tableView.bounds.size.width isRevealed:isRevealed];
    } else if (self.selectedCategoryIndex == 4) {
        return 52.0; // Музыка
    } else if (self.selectedCategoryIndex == 1 || self.selectedCategoryIndex == 2) {
        return 68.0; // Пользователи / Сообщества
    }
    return 56.0; // Документы
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    if (self.selectedCategoryIndex == 0) {
        if (indexPath.section == 0 && self.allVideos.count > 0) {
            static NSString *GridId = @"VKSearchVideoGridCell";
            VKSearchVideoGridCell *cell = [tableView dequeueReusableCellWithIdentifier:GridId];
            if (!cell) {
                cell = [[VKSearchVideoGridCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:GridId];
            }
            [cell configureWithVideos:self.allVideos width:tableView.bounds.size.width];
            __weak typeof(self) weakSelf = self;
            cell.onVideoTapped = ^(VKAttachment *video) {
                VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:video];
                [weakSelf presentMoviePlayerViewControllerAnimated:player];
            };
            return cell;
        } else {
            static NSString *PostCellId = @"VKSearchUnifiedPostCell";
            VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:PostCellId];
            if (!cell) {
                cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PostCellId];
            }
            VKPost *p = self.allPosts[indexPath.row];
            BOOL isRevealed = [self.revealedPostIds containsObject:@(p.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
            [cell configureWithPost:p isRevealed:isRevealed width:tableView.bounds.size.width];
            __weak typeof(self) weakSelf = self;
            cell.onRevealSpoilerTapped = ^(VKPost *revealedPost) {
                [weakSelf.revealedPostIds addObject:@(revealedPost.vkID)];
                [weakSelf.tableView reloadData];
            };
            return cell;
        }
    } else if (self.selectedCategoryIndex == 5) {
        static NSString *PostCellId = @"VKSearchPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:PostCellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PostCellId];
        }
        VKPost *p = self.singleResults[indexPath.row];
        BOOL isRevealed = [self.revealedPostIds containsObject:@(p.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
        [cell configureWithPost:p isRevealed:isRevealed width:tableView.bounds.size.width];
        __weak typeof(self) weakSelf = self;
        cell.onRevealSpoilerTapped = ^(VKPost *revealedPost) {
            [weakSelf.revealedPostIds addObject:@(revealedPost.vkID)];
            [weakSelf.tableView reloadData];
        };
        return cell;
    } else if (self.selectedCategoryIndex == 4) {
        static NSString *AudioCellId = @"VKSearchAudioCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AudioCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AudioCellId];
            cell.backgroundColor = [UIColor whiteColor];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        }
        VKAttachment *att = self.singleResults[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"🎵  %@", att.audioTitle ?: @"Аудиозапись"];
        if (isSkeuomorph) {
            cell.textLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
        } else {
            cell.textLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
        }
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", att.audioArtist ?: @"Исполнитель", att.audioDuration ?: @"3:00"];
        return cell;
    } else {
        id item = self.singleResults[indexPath.row];
        if ([item isKindOfClass:[VKUser class]]) {
            static NSString *UserCellId = @"VKSearchUserCustomCell";
            VKSearchUserCell *cell = [tableView dequeueReusableCellWithIdentifier:UserCellId];
            if (!cell) {
                cell = [[VKSearchUserCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:UserCellId];
            }
            VKUser *u = (VKUser *)item;
            BOOL isRequested = [self.requestedUserIds containsObject:@(u.uid)];
            [cell configureWithUser:u width:tableView.bounds.size.width isFriendOrRequested:isRequested];
            __weak typeof(self) weakSelf = self;
            cell.onActionTapped = ^(VKUser *targetUser) {
                if (targetUser.isGroup) {
                    [[VKProfileService sharedService] joinGroup:labs(targetUser.uid) completion:^(BOOL success, NSError *error) {
                        if (success) {
                            [weakSelf.requestedUserIds addObject:@(targetUser.uid)];
                            [weakSelf.tableView reloadData];
                        }
                    }];
                } else {
                    [[VKProfileService sharedService] addFriend:targetUser.uid completion:^(BOOL success, NSError *error) {
                        if (success) {
                            [weakSelf.requestedUserIds addObject:@(targetUser.uid)];
                            [weakSelf.tableView reloadData];
                        }
                    }];
                }
            };
            return cell;
        }
        
        static NSString *DocCellId = @"VKSearchDocCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:DocCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:DocCellId];
            cell.backgroundColor = [UIColor whiteColor];
        }
        VKAttachment *doc = (VKAttachment *)item;
        cell.textLabel.text = [NSString stringWithFormat:@"📄  %@", doc.docTitle ?: @"Документ"];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", [doc.docExt uppercaseString] ?: @"DOC", doc.docSize ?: @""];
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.selectedCategoryIndex == 0) {
        if (indexPath.section > 0 || self.allVideos.count == 0) {
            VKPost *post = self.allPosts[indexPath.row];
            VKPostDetailViewController *detail = [[VKPostDetailViewController alloc] initWithPost:post];
            [self.navigationController pushViewController:detail animated:YES];
        }
    } else if (self.selectedCategoryIndex == 1 || self.selectedCategoryIndex == 2) {
        VKUser *user = self.singleResults[indexPath.row];
        VKProfileViewController *prof = [[VKProfileViewController alloc] initWithUser:user];
        [self.navigationController pushViewController:prof animated:YES];
    } else if (self.selectedCategoryIndex == 5) {
        VKPost *post = self.singleResults[indexPath.row];
        VKPostDetailViewController *detail = [[VKPostDetailViewController alloc] initWithPost:post];
        [self.navigationController pushViewController:detail animated:YES];
    }
}

@end
