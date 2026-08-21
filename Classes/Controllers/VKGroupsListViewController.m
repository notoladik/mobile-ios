#import "VKGroupsListViewController.h"
#import "VKProfileService.h"
#import "VKProfileViewController.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKSupportersService.h"
#import "VKUser.h"

@interface VKGroupsListViewController ()
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) NSMutableArray *filteredGroups;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKGroupsListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _userId = userId;
        _groups = [NSMutableArray array];
        _filteredGroups = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Группы";
    self.tableView.rowHeight = 64.0;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск сообществ";
    self.tableView.tableHeaderView = self.searchBar;
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(loadGroups) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadGroups];
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

- (void)loadGroups {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [[VKProfileService sharedService] fetchGroupsForUserId:self.userId offset:0 count:100 completion:^(NSArray *groups, NSInteger totalCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            if (!error && groups) {
                [self.groups removeAllObjects];
                [self.groups addObjectsFromArray:groups];
                [self filterGroupsWithText:self.searchBar.text];
            }
        });
    }];
}

- (void)filterGroupsWithText:(NSString *)text {
    [self.filteredGroups removeAllObjects];
    NSString *clean = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) {
        [self.filteredGroups addObjectsFromArray:self.groups];
    } else {
        for (VKUser *g in self.groups) {
            if ([g.displayName localizedCaseInsensitiveContainsString:clean] || [g.username localizedCaseInsensitiveContainsString:clean]) {
                [self.filteredGroups addObject:g];
            }
        }
    }
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterGroupsWithText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredGroups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKGroupRowCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        cell.imageView.layer.cornerRadius = 10.0;
        cell.imageView.clipsToBounds = YES;
        cell.imageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    if (indexPath.row >= (NSInteger)self.filteredGroups.count) return cell;
    
    VKUser *group = self.filteredGroups[indexPath.row];
    cell.textLabel.text = group.displayName;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        cell.textLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        cell.textLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    cell.detailTextLabel.text = group.status.length > 0 ? group.status : (group.followersCount > 0 ? [NSString stringWithFormat:@"%ld участников", (long)group.followersCount] : @"Сообщество");
    
    cell.imageView.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:44.0];
    cell.imageView.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    cell.imageView.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    cell.imageView.image = nil;
    if (group.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:group.avatarURL completion:^(UIImage *img) {
            if (img) {
                cell.imageView.image = img;
                [cell setNeedsLayout];
            }
        }];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.filteredGroups.count) {
        VKUser *group = self.filteredGroups[indexPath.row];
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:group];
        [self.navigationController pushViewController:profVC animated:YES];
    }
}

@end
