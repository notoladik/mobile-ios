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

@interface VKSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIScrollView *categoriesScrollView;
@property (nonatomic, strong) NSMutableArray<UIButton *> *categoryButtons;
@property (nonatomic, assign) NSInteger selectedCategoryIndex;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *currentQuery;

// Результаты для режима "Все"
@property (nonatomic, strong) NSArray *allVideos;
@property (nonatomic, strong) NSArray *allPosts;
@property (nonatomic, strong) NSArray *allUsers;
@property (nonatomic, strong) NSArray *allGroups;
@property (nonatomic, strong) NSArray *allAudios;
@property (nonatomic, strong) NSMutableArray *singleResults;
@end

@implementation VKSearchViewController

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
    self.selectedCategoryIndex = 0;
    
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
    
    // TableView
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 82, width, self.view.bounds.size.height - 82) style:UITableViewStyleGrouped];
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
    self.tableView.frame = CGRectMake(0, 82, width, height - 82);
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
    
    [self updateCategoryButtonsStyle];
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
        [[VKSearchService sharedService] searchUsersWithQuery:clean offset:0 count:30 completion:^(NSArray *users, NSInteger totalCount, NSError *error) {
            [self.singleResults removeAllObjects];
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
    }
    return nil;
}

- (void)seeAllTapped:(UIButton *)sender {
    self.selectedCategoryIndex = sender.tag;
    [self updateCategoryButtonsStyle];
    [self performSearchWithQuery:self.currentQuery];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.selectedCategoryIndex == 0) return 36.0;
    return 0.01;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selectedCategoryIndex == 0) {
        if (indexPath.section == 0 && self.allVideos.count > 0) {
            return [VKSearchVideoGridCell heightForVideosCount:self.allVideos.count];
        }
        VKPost *p = self.allPosts[indexPath.row];
        return [VKFeedPostCell heightForPost:p width:tableView.bounds.size.width isRevealed:YES];
    } else if (self.selectedCategoryIndex == 5) {
        VKPost *p = self.singleResults[indexPath.row];
        return [VKFeedPostCell heightForPost:p width:tableView.bounds.size.width isRevealed:YES];
    } else if (self.selectedCategoryIndex == 4) {
        return 52.0; // Музыка
    }
    return 64.0;
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
            [cell configureWithPost:p isRevealed:YES];
            return cell;
        }
    } else if (self.selectedCategoryIndex == 5) {
        static NSString *PostCellId = @"VKSearchPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:PostCellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PostCellId];
        }
        VKPost *p = self.singleResults[indexPath.row];
        [cell configureWithPost:p isRevealed:YES];
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
        static NSString *UserCellId = @"VKSearchItemCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UserCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:UserCellId];
            cell.backgroundColor = [UIColor whiteColor];
        }
        
        cell.imageView.layer.cornerRadius = isSkeuomorph ? 4.0 : 24.0;
        cell.imageView.clipsToBounds = YES;
        if (isSkeuomorph) {
            cell.imageView.layer.borderWidth = 0.5;
            cell.imageView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
        } else {
            cell.imageView.layer.borderWidth = 0.0;
        }
        
        id item = self.singleResults[indexPath.row];
        if ([item isKindOfClass:[VKUser class]]) {
            VKUser *u = (VKUser *)item;
            cell.textLabel.text = u.displayName ?: @"Пользователь";
            if (isSkeuomorph) {
                cell.textLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
            } else {
                cell.textLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
            }
            cell.detailTextLabel.text = u.city.length > 0 ? u.city : @"";
            if (u.avatarURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:u.avatarURL completion:^(UIImage *img) {
                    if (img) {
                        cell.imageView.image = img;
                        [cell setNeedsLayout];
                    }
                }];
            }
        }
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
