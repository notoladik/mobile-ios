#import "VKLikesListViewController.h"
#import "VKAPIClient.h"
#import "VKUser.h"
#import "VKImageLoader.h"
#import "VKProfileViewController.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"

@interface VKLikesListViewController ()
@property (nonatomic, copy) NSString *likeType;
@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, assign) NSInteger itemId;
@property (nonatomic, assign) NSInteger currentFilter; // 0 = likes, 1 = copies
@property (nonatomic, strong) NSMutableArray<VKUser *> *users;
@property (nonatomic, assign) NSInteger totalCount;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VKLikesListViewController

- (instancetype)initWithType:(NSString *)type
                     ownerId:(NSInteger)ownerId
                      itemId:(NSInteger)itemId
               initialFilter:(NSInteger)initialFilter {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _likeType = [type copy] ?: @"post";
        _ownerId = ownerId;
        _itemId = itemId;
        _currentFilter = (initialFilter == 1) ? 1 : 0;
        _users = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.rowHeight = 56.0;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад"
                                                                                            target:self
                                                                                            action:@selector(goBackAction)
                                                                                            isBack:YES];
    
    if ([self.likeType isEqualToString:@"post"]) {
        self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Понравилось", @"Поделились"]];
        self.segmentedControl.selectedSegmentIndex = self.currentFilter;
        [self.segmentedControl sizeToFit];
        self.segmentedControl.frame = CGRectMake(0, 0, 210, 30);
        [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        self.navigationItem.titleView = self.segmentedControl;
    } else {
        self.title = @"Оценили";
    }
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *rc = [[UIRefreshControl alloc] init];
        [rc addTarget:self action:@selector(refreshAction) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = rc;
    }
    
    UIView *bgView = [[UIView alloc] initWithFrame:self.view.bounds];
    bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bgView.backgroundColor = [UIColor clearColor];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:14];
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.hidden = YES;
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bgView addSubview:self.emptyLabel];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 100);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.spinner.hidesWhenStopped = YES;
    [bgView addSubview:self.spinner];
    
    self.tableView.backgroundView = bgView;
    
    [self loadDataReset:YES];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.currentFilter = sender.selectedSegmentIndex;
    [self loadDataReset:YES];
}

- (void)refreshAction {
    [self loadDataReset:YES];
}

- (void)finishLoadingUI {
    self.isLoading = NO;
    [self.spinner stopAnimating];
    if (self.refreshControl.isRefreshing) {
        [self.refreshControl endRefreshing];
    }
    
    if (self.segmentedControl && self.currentFilter < self.segmentedControl.numberOfSegments) {
        NSString *title = (self.currentFilter == 0) ?
            [NSString stringWithFormat:@"Понравилось (%ld)", (long)self.totalCount] :
            [NSString stringWithFormat:@"Поделились (%ld)", (long)self.totalCount];
        [self.segmentedControl setTitle:title forSegmentAtIndex:self.currentFilter];
    } else if (!self.segmentedControl) {
        self.title = (self.totalCount > 0) ?
            [NSString stringWithFormat:@"Оценили (%ld)", (long)self.totalCount] : @"Оценили";
    }
    
    if (self.users.count == 0) {
        self.emptyLabel.text = (self.currentFilter == 1) ? @"Пока никто не поделился записью." : @"Пока никто не оценил.";
        self.emptyLabel.hidden = NO;
    } else {
        self.emptyLabel.hidden = YES;
    }
    
    [self.tableView reloadData];
}

- (void)loadDataReset:(BOOL)reset {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    if (reset) {
        [self.users removeAllObjects];
        [self.tableView reloadData];
        self.emptyLabel.hidden = YES;
        [self.spinner startAnimating];
    }
    
    NSInteger offset = reset ? 0 : self.users.count;
    NSString *filterStr = (self.currentFilter == 1) ? @"copies" : @"likes";
    
    NSDictionary *params = @{
        @"type": self.likeType,
        @"owner_id": @(self.ownerId),
        @"item_id": @(self.itemId),
        @"filter": filterStr,
        @"extended": @"1",
        @"fields": @"photo_100,photo_200,city,online,verified,screen_name,status,sex,last_seen",
        @"offset": @(offset),
        @"count": @"50"
    };
    
    __weak typeof(self) weakSelf = self;
    [[VKAPIClient sharedClient] callMethod:@"likes.getList" parameters:params completionHandler:^(id response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (error) {
            [VKCrashLogger log:@"[VKLikesListViewController] Error: %@", error.localizedDescription];
            strongSelf.isLoading = NO;
            [strongSelf.spinner stopAnimating];
            if (strongSelf.refreshControl.isRefreshing) {
                [strongSelf.refreshControl endRefreshing];
            }
            if (strongSelf.users.count == 0) {
                strongSelf.emptyLabel.text = @"Не удалось загрузить список пользователей.\nПотяните вниз для повтора.";
                strongSelf.emptyLabel.hidden = NO;
            }
            return;
        }
        
        id respObj = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : response;
        NSArray *rawItems = @[];
        NSArray *rawProfiles = @[];
        
        if ([respObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)respObj;
            strongSelf.totalCount = [dict[@"count"] integerValue];
            rawItems = dict[@"items"] ?: dict[@"users"] ?: @[];
            rawProfiles = dict[@"profiles"] ?: @[];
        } else if ([respObj isKindOfClass:[NSArray class]]) {
            rawItems = (NSArray *)respObj;
            strongSelf.totalCount = rawItems.count;
        }
        
        NSMutableDictionary *profilesMap = [NSMutableDictionary dictionary];
        if ([rawProfiles isKindOfClass:[NSArray class]]) {
            for (NSDictionary *p in rawProfiles) {
                if ([p isKindOfClass:[NSDictionary class]]) {
                    id pid = p[@"id"] ?: p[@"uid"];
                    if (pid) profilesMap[pid] = p;
                }
            }
        }
        
        NSMutableArray *idsToFetch = [NSMutableArray array];
        for (id item in rawItems) {
            VKUser *u = nil;
            if ([item isKindOfClass:[NSDictionary class]]) {
                u = [VKUser userFromDictionary:item];
            } else if ([item respondsToSelector:@selector(integerValue)]) {
                NSInteger uid = [item integerValue];
                NSDictionary *p = profilesMap[@(uid)];
                if (p) {
                    u = [VKUser userFromDictionary:p];
                } else if (uid != 0) {
                    [idsToFetch addObject:@(uid)];
                }
            }
            if (u && u.displayName.length > 0) {
                [strongSelf.users addObject:u];
            }
        }
        
        // Если API вернуло только ID без profiles, запрашиваем профили через users.get
        if (idsToFetch.count > 0) {
            NSString *idList = [idsToFetch componentsJoinedByString:@","];
            NSDictionary *uParams = @{
                @"user_ids": idList,
                @"fields": @"photo_100,photo_200,city,online,verified,screen_name,status,sex,last_seen"
            };
            [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:uParams completionHandler:^(id uResp, NSError *uErr) {
                id uRespObj = [uResp isKindOfClass:[NSDictionary class]] ? (uResp[@"response"] ?: uResp) : uResp;
                NSArray *userDicts = [uRespObj isKindOfClass:[NSArray class]] ? uRespObj : nil;
                if (userDicts) {
                    for (NSDictionary *ud in userDicts) {
                        if ([ud isKindOfClass:[NSDictionary class]]) {
                            VKUser *u = [VKUser userFromDictionary:ud];
                            if (u && u.displayName.length > 0) {
                                [strongSelf.users addObject:u];
                            }
                        }
                    }
                }
                [strongSelf finishLoadingUI];
            }];
            return;
        }
        
        [strongSelf finishLoadingUI];
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.users.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKLikesUserCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 7, 42, 42)];
        avatar.tag = 501;
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        avatar.clipsToBounds = YES;
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:42.0];
        avatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 10, cell.contentView.bounds.size.width - 94, 20)];
        nameLabel.tag = 502;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:nameLabel];
        
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 30, cell.contentView.bounds.size.width - 94, 16)];
        subLabel.tag = 503;
        subLabel.font = [UIFont systemFontOfSize:13];
        subLabel.textColor = [UIColor grayColor];
        subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:subLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.users.count) {
        return cell;
    }
    
    VKUser *u = self.users[indexPath.row];
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:501];
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:502];
    UILabel *subLabel = (UILabel *)[cell.contentView viewWithTag:503];
    
    cell.backgroundColor = [UIColor whiteColor];
    nameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
    subLabel.textColor = [[VKThemeManager sharedManager] secondaryTextColor] ?: [UIColor colorWithRed:128.0/255.0 green:134.0/255.0 blue:142.0/255.0 alpha:1.0];
    
    avatar.image = nil;
    if (u.avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:u.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    NSString *verifiedMark = u.isOfficial ? @" ✓" : @"";
    NSString *onlineMark = u.isOnline ? @" • онлайн" : @"";
    NSString *dName = u.displayName ?: @"Пользователь";
    nameLabel.text = [NSString stringWithFormat:@"%@%@%@", dName, verifiedMark, onlineMark];
    
    NSString *subText = @"";
    if ([u.status isKindOfClass:[NSString class]] && u.status.length > 0) {
        subText = u.status;
    } else if ([u.city isKindOfClass:[NSString class]] && u.city.length > 0) {
        subText = u.city;
    } else {
        subText = u.isOnline ? @"В сети" : (([u.lastSeen isKindOfClass:[NSString class]] && u.lastSeen.length > 0) ? u.lastSeen : @"");
    }
    subLabel.text = subText;
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.users.count) {
        VKUser *user = self.users[indexPath.row];
        if (user) {
            VKProfileViewController *prof = [[VKProfileViewController alloc] initWithUser:user];
            [self.navigationController pushViewController:prof animated:YES];
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat currentOffset = scrollView.contentOffset.y;
    CGFloat maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
    
    if (maximumOffset - currentOffset <= 200.0 && !self.isLoading && self.users.count < self.totalCount) {
        [self loadDataReset:NO];
    }
}

@end
