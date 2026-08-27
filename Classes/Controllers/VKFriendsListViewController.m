#import "VKFriendsListViewController.h"
#import "VKProfileService.h"
#import "VKAuthService.h"
#import "VKProfileViewController.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKUser.h"
#import "VKCrashLogger.h"

@interface VKFriendsListViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSMutableArray *friends;
@property (nonatomic, strong) NSArray *filteredFriends;
@property (nonatomic, strong) NSMutableArray *requests;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *footerCountLabel;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isShowingRequests;
@end

@implementation VKFriendsListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _userId = userId;
    }
    return self;
}

- (BOOL)isCurrentUserList {
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    return (self.userId == 0 || self.userId == myId);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Друзья";
    self.friends = [NSMutableArray array];
    self.filteredFriends = @[];
    self.requests = [NSMutableArray array];
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.rowHeight = 60.0;
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 0);
    }
    
    [self setupNavigationItems];
    [self setupHeaderView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    self.footerCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.footerCountLabel.font = [UIFont systemFontOfSize:14];
    self.footerCountLabel.textColor = [UIColor grayColor];
    self.footerCountLabel.textAlignment = NSTextAlignmentCenter;
    self.tableView.tableFooterView = self.footerCountLabel;
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(loadAllData) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadAllData];
}

- (void)setupHeaderView {
    CGFloat width = self.view.bounds.size.width;
    BOOL isMy = [self isCurrentUserList];
    
    if (isMy) {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 88)];
        header.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
        
        self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Все друзья", @"Заявки"]];
        self.segmentedControl.frame = CGRectMake(12, 8, width - 24, 28);
        self.segmentedControl.selectedSegmentIndex = 0;
        [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        [header addSubview:self.segmentedControl];
        
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 44, width, 44)];
        self.searchBar.placeholder = @"Поиск";
        self.searchBar.delegate = self;
        [header addSubview:self.searchBar];
        
        self.tableView.tableHeaderView = header;
    } else {
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
        self.searchBar.placeholder = @"Поиск";
        self.searchBar.delegate = self;
        self.tableView.tableHeaderView = self.searchBar;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    if (self.navigationController.viewControllers.firstObject == self) {
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

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.isShowingRequests = (sender.selectedSegmentIndex == 1);
    self.tableView.rowHeight = self.isShowingRequests ? 70.0 : 60.0;
    [self filterFriendsWithText:self.searchBar.text];
}

- (void)loadAllData {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    NSInteger uid = self.userId;
    if (uid == 0) uid = [[VKAuthService sharedService] currentUserId];
    
    [[VKProfileService sharedService] fetchFriendsForUserId:uid completion:^(NSArray *friends, NSError *error) {
        if (!error && friends) {
            [self.friends removeAllObjects];
            [self.friends addObjectsFromArray:friends];
        }
        
        if ([self isCurrentUserList]) {
            [[VKProfileService sharedService] fetchFriendRequestsWithCompletion:^(NSArray<VKUser *> *requests, NSInteger totalCount, NSError *reqError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isLoading = NO;
                    if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                        [self.refreshControl endRefreshing];
                    }
                    if (!reqError && requests) {
                        [self.requests removeAllObjects];
                        [self.requests addObjectsFromArray:requests];
                        
                        NSString *reqTitle = (requests.count > 0) ? [NSString stringWithFormat:@"Заявки (%ld)", (long)requests.count] : @"Заявки";
                        [self.segmentedControl setTitle:reqTitle forSegmentAtIndex:1];
                    }
                    [self filterFriendsWithText:self.searchBar.text];
                });
            }];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.isLoading = NO;
                if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                    [self.refreshControl endRefreshing];
                }
                [self filterFriendsWithText:self.searchBar.text];
            });
        }
    }];
}

- (void)filterFriendsWithText:(NSString *)text {
    NSArray *source = self.isShowingRequests ? self.requests : self.friends;
    
    if (!text || text.length == 0) {
        self.filteredFriends = [source copy];
    } else {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"displayName CONTAINS[cd] %@ OR username CONTAINS[cd] %@", text, text];
        self.filteredFriends = [source filteredArrayUsingPredicate:p];
    }
    
    if (self.isShowingRequests) {
        self.footerCountLabel.text = [NSString stringWithFormat:@"%lu заявок", (unsigned long)self.filteredFriends.count];
    } else {
        self.footerCountLabel.text = [NSString stringWithFormat:@"%lu человек", (unsigned long)self.filteredFriends.count];
    }
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterFriendsWithText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredFriends.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isShowingRequests) {
        static NSString *ReqCellId = @"VKFriendRequestCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ReqCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ReqCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 50, 50)];
            avatar.tag = 301;
            avatar.clipsToBounds = YES;
            avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            [cell.contentView addSubview:avatar];
            
            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(72, 12, cell.contentView.bounds.size.width - 190, 20)];
            nameLabel.tag = 302;
            nameLabel.font = [UIFont boldSystemFontOfSize:15];
            nameLabel.textColor = [UIColor blackColor];
            [cell.contentView addSubview:nameLabel];
            
            // Кнопка Принять
            UIButton *acceptBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            acceptBtn.frame = CGRectMake(cell.contentView.bounds.size.width - 110, 14, 100, 28);
            acceptBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            acceptBtn.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            acceptBtn.layer.cornerRadius = 4.0;
            acceptBtn.clipsToBounds = YES;
            [acceptBtn setTitle:@"Принять" forState:UIControlStateNormal];
            [acceptBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            acceptBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            acceptBtn.tag = 303;
            [cell.contentView addSubview:acceptBtn];
            
            // Кнопка Оставить в подписчиках
            UIButton *rejectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            rejectBtn.frame = CGRectMake(cell.contentView.bounds.size.width - 110, 44, 100, 20);
            rejectBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            [rejectBtn setTitle:@"Отклонить" forState:UIControlStateNormal];
            [rejectBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
            rejectBtn.titleLabel.font = [UIFont systemFontOfSize:11.5];
            rejectBtn.tag = 304;
            [cell.contentView addSubview:rejectBtn];
        }
        
        if (indexPath.row >= (NSInteger)self.filteredFriends.count) return cell;
        VKUser *user = self.filteredFriends[indexPath.row];
        
        UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:301];
        UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:302];
        UIButton *acceptBtn = (UIButton *)[cell.contentView viewWithTag:303];
        UIButton *rejectBtn = (UIButton *)[cell.contentView viewWithTag:304];
        
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:50.0];
        avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
        avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
        avatar.image = nil;
        if (user.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
                if (img) avatar.image = img;
            }];
        }
        nameLabel.text = user.displayName;
        
        acceptBtn.tag = indexPath.row;
        [acceptBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [acceptBtn addTarget:self action:@selector(acceptRequestTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        rejectBtn.tag = indexPath.row;
        [rejectBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [rejectBtn addTarget:self action:@selector(rejectRequestTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        return cell;
    }
    
    // Обычная ячейка друга
    static NSString *CellIdentifier = @"VKFriendCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 44, 44)];
        avatar.tag = 101;
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(68, 11, cell.contentView.bounds.size.width - 110, 20)];
        nameLabel.tag = 102;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        [cell.contentView addSubview:nameLabel];
        
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(68, 32, cell.contentView.bounds.size.width - 110, 16)];
        statusLabel.tag = 104;
        statusLabel.font = [UIFont systemFontOfSize:12];
        statusLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [cell.contentView addSubview:statusLabel];
        
        UILabel *onlineDot = [[UILabel alloc] initWithFrame:CGRectMake(cell.contentView.bounds.size.width - 32, 22, 22, 16)];
        onlineDot.tag = 103;
        onlineDot.text = @"●";
        onlineDot.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        onlineDot.font = [UIFont systemFontOfSize:12];
        onlineDot.textAlignment = NSTextAlignmentRight;
        onlineDot.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        onlineDot.hidden = YES;
        [cell.contentView addSubview:onlineDot];
    }
    
    if (indexPath.row >= (NSInteger)self.filteredFriends.count) return cell;
    
    VKUser *friend = self.filteredFriends[indexPath.row];
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:101];
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:102];
    UILabel *onlineDot = (UILabel *)[cell.contentView viewWithTag:103];
    UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:104];
    
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:44.0];
    avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    avatar.image = nil;
    
    if (friend.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:friend.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        nameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        nameLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    nameLabel.text = friend.displayName;
    
    if (friend.status.length > 0) {
        statusLabel.text = friend.status;
    } else if (friend.city.length > 0) {
        statusLabel.text = friend.city;
    } else {
        statusLabel.text = friend.isOnline ? @"В сети" : @"";
    }
    
    if (friend.isOnline) {
        onlineDot.hidden = NO;
        if ([friend.onlinePlatform isEqualToString:@"iphone"] || [friend.onlinePlatform isEqualToString:@"ipad"]) {
            onlineDot.text = @"";
            onlineDot.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
            onlineDot.font = [UIFont boldSystemFontOfSize:14];
        } else if ([friend.onlinePlatform isEqualToString:@"android"]) {
            onlineDot.text = @"📱";
            onlineDot.font = [UIFont systemFontOfSize:12];
        } else {
            onlineDot.text = @"●";
            onlineDot.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            onlineDot.font = [UIFont systemFontOfSize:11];
        }
    } else {
        onlineDot.hidden = YES;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.filteredFriends.count) {
        VKUser *user = self.filteredFriends[indexPath.row];
        VKProfileViewController *profileVC = [[VKProfileViewController alloc] initWithUser:user];
        [self.navigationController pushViewController:profileVC animated:YES];
    }
}

- (void)acceptRequestTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.filteredFriends.count) return;
    VKUser *user = self.filteredFriends[idx];
    
    [[VKProfileService sharedService] addFriend:user.uid completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.requests removeObject:user];
                [self.friends insertObject:user atIndex:0];
                [self filterFriendsWithText:self.searchBar.text];
                
                NSString *reqTitle = (self.requests.count > 0) ? [NSString stringWithFormat:@"Заявки (%ld)", (long)self.requests.count] : @"Заявки";
                [self.segmentedControl setTitle:reqTitle forSegmentAtIndex:1];
            }
        });
    }];
}

- (void)rejectRequestTapped:(UIButton *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.filteredFriends.count) return;
    VKUser *user = self.filteredFriends[idx];
    
    [[VKProfileService sharedService] deleteFriend:user.uid completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self.requests removeObject:user];
                [self filterFriendsWithText:self.searchBar.text];
                
                NSString *reqTitle = (self.requests.count > 0) ? [NSString stringWithFormat:@"Заявки (%ld)", (long)self.requests.count] : @"Заявки";
                [self.segmentedControl setTitle:reqTitle forSegmentAtIndex:1];
            }
        });
    }];
}

@end
