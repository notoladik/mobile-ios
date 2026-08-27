#import "VKNotificationsViewController.h"
#import "VKNotificationsService.h"
#import "VKProfileViewController.h"
#import "VKPostDetailViewController.h"
#import "VKProfileService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"

@interface VKNotificationCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *previewLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UIButton *acceptButton;
@property (nonatomic, copy) void (^onAcceptFriend)(void);
@end

@implementation VKNotificationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        self.backgroundColor = [UIColor whiteColor];
        
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 44, 44)];
        _avatarImageView.clipsToBounds = YES;
        _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [self.contentView addSubview:_avatarImageView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont systemFontOfSize:14];
        _titleLabel.textColor = [UIColor blackColor];
        _titleLabel.numberOfLines = 2;
        [self.contentView addSubview:_titleLabel];
        
        _previewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _previewLabel.font = [UIFont systemFontOfSize:13];
        _previewLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        _previewLabel.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:248.0/255.0 alpha:1.0];
        _previewLabel.layer.cornerRadius = 4.0;
        _previewLabel.clipsToBounds = YES;
        _previewLabel.numberOfLines = 2;
        _previewLabel.hidden = YES;
        [self.contentView addSubview:_previewLabel];
        
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.font = [UIFont systemFontOfSize:12];
        _dateLabel.textColor = [UIColor grayColor];
        [self.contentView addSubview:_dateLabel];
        
        _acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _acceptButton.frame = CGRectMake(0, 0, 90, 28);
        _acceptButton.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        _acceptButton.layer.cornerRadius = 4.0;
        _acceptButton.clipsToBounds = YES;
        [_acceptButton setTitle:@"Добавить" forState:UIControlStateNormal];
        [_acceptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _acceptButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [_acceptButton addTarget:self action:@selector(acceptClicked) forControlEvents:UIControlEventTouchUpInside];
        _acceptButton.hidden = YES;
        [self.contentView addSubview:_acceptButton];
    }
    return self;
}

- (void)acceptClicked {
    if (self.onAcceptFriend) self.onAcceptFriend();
}

- (void)configureWithNotification:(VKNotification *)n width:(CGFloat)width {
    self.avatarImageView.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:44.0];
    self.avatarImageView.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    self.avatarImageView.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    
    self.avatarImageView.image = nil;
    if (n.user.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:n.user.avatarURL completion:^(UIImage *img) {
            if (img) self.avatarImageView.image = img;
        }];
    }
    
    NSString *name = n.user.displayName ?: @"Пользователь";
    NSString *actionText = @"";
    switch (n.type) {
        case VKNotificationTypeLike: actionText = @"оценил(а) вашу запись"; break;
        case VKNotificationTypeComment: actionText = @"оставил(а) комментарий"; break;
        case VKNotificationTypeFriendRequest: actionText = @"хочет добавить вас в друзья"; break;
        case VKNotificationTypeRepost: actionText = @"поделился(ась) вашей записью"; break;
        case VKNotificationTypeMention: actionText = @"упомянул(а) вас"; break;
        case VKNotificationTypeWallPost: actionText = @"опубликовал(а) запись на вашей стене"; break;
        case VKNotificationTypeGift: actionText = @"отправил(а) вам подарок"; break;
        case VKNotificationTypeVoicesTransfer: actionText = @"перевел(а) вам голоса"; break;
        case VKNotificationTypeRatingUp: actionText = @"повысил(а) вам рейтинг"; break;
        case VKNotificationTypeMakeAdmin: actionText = @"назначил(а) вас администратором"; break;
    }
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@", name, actionText]];
    [attr addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:14] range:NSMakeRange(0, name.length)];
    [attr addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(0, attr.length)];
    self.titleLabel.attributedText = attr;
    
    CGFloat contentX = 66.0;
    CGFloat contentW = width - contentX - 16.0;
    self.titleLabel.frame = CGRectMake(contentX, 10, contentW, 36);
    
    CGFloat currentY = 48.0;
    if (n.type == VKNotificationTypeFriendRequest) {
        self.acceptButton.hidden = NO;
        self.acceptButton.frame = CGRectMake(contentX, currentY, 90, 26);
        currentY += 32.0;
    } else {
        self.acceptButton.hidden = YES;
    }
    
    if (n.textPreview.length > 0 && n.type != VKNotificationTypeFriendRequest) {
        self.previewLabel.hidden = NO;
        self.previewLabel.text = [NSString stringWithFormat:@"  %@", n.textPreview];
        self.previewLabel.frame = CGRectMake(contentX, currentY, contentW, 26);
        currentY += 30.0;
    } else {
        self.previewLabel.hidden = YES;
    }
    
    self.dateLabel.text = n.timeAgo;
    self.dateLabel.frame = CGRectMake(contentX, currentY, contentW, 16);
}

+ (CGFloat)heightForNotification:(VKNotification *)n width:(CGFloat)width {
    CGFloat h = 68.0;
    if (n.type == VKNotificationTypeFriendRequest) h += 32.0;
    if (n.textPreview.length > 0 && n.type != VKNotificationTypeFriendRequest) h += 30.0;
    return h;
}

@end

@interface VKNotificationsViewController ()
@property (nonatomic, strong) NSMutableArray *notifications;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKNotificationsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStylePlain];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = [[VKThemeManager sharedManager] isSkeuomorphic] ? @"Ответы" : @"Уведомления";
    self.notifications = [NSMutableArray array];
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 66, 0, 0);
    }
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(loadNotifications) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadNotifications];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    BOOL isRoot = (self.navigationController.viewControllers.count > 0 && self.navigationController.viewControllers[0] == self);
    if (isRoot) {
        if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
            self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
        } else {
            self.navigationItem.leftBarButtonItem = nil;
        }
    } else {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    }
}

- (void)leftMenuButtonAction {
    [[VKSideMenuManager sharedManager] toggleMenu];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadNotifications {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [[VKNotificationsService sharedService] fetchNotificationsWithArchived:NO offset:0 count:40 completion:^(NSArray *notifications, NSError *error) {
        self.isLoading = NO;
        if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
            [self.refreshControl endRefreshing];
        }
        
        if (!error && notifications) {
            [self.notifications removeAllObjects];
            [self.notifications addObjectsFromArray:notifications];
            [self.tableView reloadData];
            [[VKNotificationsService sharedService] markAsReadWithCompletion:nil];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.notifications.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.notifications.count) return 60.0;
    VKNotification *n = self.notifications[indexPath.row];
    return [VKNotificationCell heightForNotification:n width:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKNotificationCell";
    VKNotificationCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[VKNotificationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
    }
    
    if (indexPath.row < (NSInteger)self.notifications.count) {
        VKNotification *n = self.notifications[indexPath.row];
        [cell configureWithNotification:n width:tableView.bounds.size.width];
        
        __weak typeof(self) weakSelf = self;
        cell.onAcceptFriend = ^{
            [[VKProfileService sharedService] addFriend:n.user.uid completion:^(BOOL success, NSError *error) {
                [weakSelf loadNotifications];
            }];
        };
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.notifications.count) return;
    
    VKNotification *n = self.notifications[indexPath.row];
    if (n.targetPostID != 0) {
        VKPost *dummyPost = [[VKPost alloc] init];
        dummyPost.vkID = n.targetPostID;
        dummyPost.ownerID = n.targetPostOwnerID;
        VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:dummyPost];
        [self.navigationController pushViewController:detailVC animated:YES];
    } else if (n.user && n.user.uid != 0) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:n.user];
        [self.navigationController pushViewController:profVC animated:YES];
    }
}

@end
