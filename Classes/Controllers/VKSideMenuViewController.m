#import "VKSideMenuViewController.h"
#import "VKSideMenuManager.h"
#import "VKAuthService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKUser.h"

@interface VKSideMenuViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *menuItems;
@end

@implementation VKSideMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupMenuItems];
    [self setupViews];
    [self applyThemeStyle];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:VKCountersDidUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:VKAuthStatusDidChangeNotification object:nil];
}

- (void)setupMenuItems {
    self.menuItems = @[
        @{@"title": @"Моя страница", @"icon": @"👤", @"badge": @""},
        @{@"title": @"Новости", @"icon": @"📰", @"badge": @""},
        @{@"title": @"Ответы", @"icon": @"💬", @"badge": @"notifications"},
        @{@"title": @"Сообщения", @"icon": @"✉️", @"badge": @"messages"},
        @{@"title": @"Друзья", @"icon": @"👥", @"badge": @"friends"},
        @{@"title": @"Группы", @"icon": @"👥", @"badge": @""},
        @{@"title": @"Фотографии", @"icon": @"🖼", @"badge": @""},
        @{@"title": @"Видеозаписи", @"icon": @"🎬", @"badge": @""},
        @{@"title": @"Аудиозаписи", @"icon": @"🎵", @"badge": @""},
        @{@"title": @"Заметки", @"icon": @"📝", @"badge": @""},
        @{@"title": @"Поиск", @"icon": @"🔍", @"badge": @""},
        @{@"title": @"Настройки", @"icon": @"⚙️", @"badge": @""}
    ];
}

- (void)setupViews {
    CGRect bounds = self.view.bounds;
    CGFloat width = 270.0;
    
    // Header
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 110)];
    self.headerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapHeader = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped)];
    [self.headerView addGestureRecognizer:tapHeader];
    [self.view addSubview:self.headerView];
    
    self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 36, 52, 52)];
    self.avatarImageView.clipsToBounds = YES;
    self.avatarImageView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.headerView addSubview:self.avatarImageView];
    
    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 40, width - 90, 22)];
    self.nameLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.headerView addSubview:self.nameLabel];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 64, width - 90, 18)];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    [self.headerView addSubview:self.statusLabel];
    
    // Table
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 110, width, bounds.size.height - 110) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleRightMargin;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.tableView];
    
    [self reloadData];
}

- (void)applyThemeStyle {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    
    if (isSkeuomorph) {
        // iOS 6 Classic: темный текстурный фон #272C35
        self.view.backgroundColor = [UIColor colorWithRed:39.0/255.0 green:44.0/255.0 blue:53.0/255.0 alpha:1.0];
        self.headerView.backgroundColor = [UIColor colorWithRed:31.0/255.0 green:35.0/255.0 blue:43.0/255.0 alpha:1.0];
        self.tableView.backgroundColor = [UIColor colorWithRed:39.0/255.0 green:44.0/255.0 blue:53.0/255.0 alpha:1.0];
        self.tableView.separatorColor = [UIColor colorWithRed:30.0/255.0 green:34.0/255.0 blue:41.0/255.0 alpha:1.0];
        
        self.nameLabel.textColor = [UIColor whiteColor];
        self.statusLabel.textColor = [UIColor colorWithRed:140.0/255.0 green:150.0/255.0 blue:170.0/255.0 alpha:1.0];
        
        self.avatarImageView.layer.cornerRadius = 4.0;
        self.avatarImageView.layer.borderWidth = 1.0;
        self.avatarImageView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    } else if (isFlat) {
        // Classic Flat: темно-синий VK #323E4F / #2E3846
        self.view.backgroundColor = [UIColor colorWithRed:46.0/255.0 green:56.0/255.0 blue:70.0/255.0 alpha:1.0];
        self.headerView.backgroundColor = [UIColor colorWithRed:38.0/255.0 green:47.0/255.0 blue:59.0/255.0 alpha:1.0];
        self.tableView.backgroundColor = [UIColor colorWithRed:46.0/255.0 green:56.0/255.0 blue:70.0/255.0 alpha:1.0];
        self.tableView.separatorColor = [UIColor colorWithRed:38.0/255.0 green:47.0/255.0 blue:59.0/255.0 alpha:1.0];
        
        self.nameLabel.textColor = [UIColor whiteColor];
        self.statusLabel.textColor = [UIColor colorWithRed:140.0/255.0 green:160.0/255.0 blue:190.0/255.0 alpha:1.0];
        
        self.avatarImageView.layer.cornerRadius = 26.0;
        self.avatarImageView.layer.borderWidth = 0.0;
    } else {
        // Modern Swift: светлая шторка #FFFFFF с мягкими серыми тонами
        self.view.backgroundColor = [UIColor whiteColor];
        self.headerView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0];
        self.tableView.backgroundColor = [UIColor whiteColor];
        self.tableView.separatorColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
        
        self.nameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
        self.statusLabel.textColor = [UIColor colorWithRed:130.0/255.0 green:135.0/255.0 blue:145.0/255.0 alpha:1.0];
        
        self.avatarImageView.layer.cornerRadius = 26.0;
        self.avatarImageView.layer.borderWidth = 0.0;
    }
    
    [self.tableView reloadData];
}

- (void)reloadData {
    VKUser *user = [[VKAuthService sharedService] currentUserModel];
    self.nameLabel.text = user.displayName ?: @"Мой профиль";
    self.statusLabel.text = user.status.length > 0 ? user.status : @"онлайн";
    
    self.avatarImageView.image = nil;
    if (user.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
            if (img) self.avatarImageView.image = img;
        }];
    }
    
    [self.tableView reloadData];
}

- (void)headerTapped {
    [[VKSideMenuManager sharedManager] navigateToIndex:0]; // Мой профиль
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuItems.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 48.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKSideMenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:12];
    }
    
    NSDictionary *item = self.menuItems[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@   %@", item[@"icon"], item[@"title"]];
    
    BOOL isModern = [[VKThemeManager sharedManager] isModern];
    if (isModern) {
        cell.textLabel.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    } else {
        cell.textLabel.textColor = [UIColor colorWithRed:225.0/255.0 green:230.0/255.0 blue:240.0/255.0 alpha:1.0];
        cell.detailTextLabel.textColor = [UIColor colorWithRed:120.0/255.0 green:170.0/255.0 blue:240.0/255.0 alpha:1.0];
    }
    
    // Бейджи счетчиков
    NSString *badgeType = item[@"badge"];
    cell.detailTextLabel.text = @"";
    if ([badgeType isEqualToString:@"messages"]) {
        NSInteger c = [[VKAuthService sharedService] messagesCount];
        if (c > 0) cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)c];
    } else if ([badgeType isEqualToString:@"friends"]) {
        NSInteger f = [[VKAuthService sharedService] friendsCount];
        if (f > 0) cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)f];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[VKSideMenuManager sharedManager] navigateToIndex:indexPath.row];
}

@end
