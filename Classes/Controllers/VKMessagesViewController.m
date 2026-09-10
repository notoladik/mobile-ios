#import "VKMessagesViewController.h"
#import "VKMessagesService.h"
#import "VKMessage.h"
#import "VKChatViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import "VKLongPollService.h"
#import <QuartzCore/QuartzCore.h>

@interface VKMessagesViewController () <UISearchBarDelegate>
@property (nonatomic, strong) NSMutableArray *conversations;
@property (nonatomic, strong) NSMutableArray *filteredConversations;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKMessagesViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKMessagesViewController] viewDidLoad started."];
    
    self.title = @"Сообщения";
    self.conversations = [NSMutableArray array];
    self.filteredConversations = [NSMutableArray array];
    self.tableView.rowHeight = 72.0;
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 70, 0, 0);
    }
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    // Поисковая строка диалогов
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.placeholder = @"Поиск диалогов";
    self.searchBar.delegate = self;
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.searchBar.tintColor = [UIColor colorWithRed:80.0/255.0 green:110.0/255.0 blue:145.0/255.0 alpha:1.0];
    }
    self.tableView.tableHeaderView = self.searchBar;
    
    [self setupNavigationItems];
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewMessage:) name:VKLongPollDidReceiveNewMessageNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReadMessages:) name:VKLongPollDidReadMessagesNotification object:nil];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(loadDialogs) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadDialogs];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
    [self loadDialogs];
}

- (void)setupNavigationItems {
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
    
    self.navigationItem.rightBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Обновить" target:self action:@selector(loadDialogs) isBack:NO];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar) {
        bar.barTintColor = [[VKThemeManager sharedManager] navBarBackgroundColor];
        bar.tintColor = [[VKThemeManager sharedManager] navBarTintColor];
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [[VKThemeManager sharedManager] navBarTitleColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
    
    [self setupNavigationItems];
    [self.tableView reloadData];
}

#pragma mark - Search Filtering

- (NSArray *)currentDataSource {
    return self.isSearching ? self.filteredConversations : self.conversations;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *query = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.isSearching = NO;
        [self.filteredConversations removeAllObjects];
    } else {
        self.isSearching = YES;
        [self.filteredConversations removeAllObjects];
        for (VKConversation *conv in self.conversations) {
            if ([conv.title rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [conv.lastMessage.text rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [self.filteredConversations addObject:conv];
            }
        }
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.isSearching = NO;
    [self.filteredConversations removeAllObjects];
    [searchBar resignFirstResponder];
    [self.tableView reloadData];
}

#pragma mark - Загрузка диалогов

- (void)loadDialogs {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [VKCrashLogger log:@"[VKMessagesViewController] Loading conversations..."];
    
    [[VKMessagesService sharedService] fetchConversationsWithOffset:0 count:40 completion:^(NSArray *conversations, NSInteger unreadCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            
            if (error) {
                [VKCrashLogger log:@"[VKMessagesViewController] Error loading dialogs: %@", error.localizedDescription];
                return;
            }
            
            self.conversations = [NSMutableArray arrayWithArray:conversations ?: @[]];
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - LongPoll Notifications

- (void)didReceiveNewMessage:(NSNotification *)note {
    VKMessage *msg = note.userInfo[@"message"];
    if (!msg) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        VKConversation *targetConv = nil;
        for (VKConversation *c in self.conversations) {
            if (c.peerId == msg.peerId) {
                targetConv = c;
                break;
            }
        }
        
        if (targetConv) {
            targetConv.lastMessage = msg;
            if (!msg.isOutgoing && !msg.isRead) {
                targetConv.unreadCount += 1;
            }
            // Поднимаем диалог наверх списка
            [self.conversations removeObject:targetConv];
            [self.conversations insertObject:targetConv atIndex:0];
            [self.tableView reloadData];
        } else {
            // Новый диалог, подгружаем актуальный список диалогов
            [self loadDialogs];
        }
    });
}

- (void)didReadMessages:(NSNotification *)note {
    NSInteger peerId = [note.userInfo[@"peer_id"] integerValue];
    BOOL isOutgoing = [note.userInfo[@"is_outgoing"] boolValue];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (VKConversation *c in self.conversations) {
            if (c.peerId == peerId) {
                if (isOutgoing) {
                    if (c.lastMessage.isOutgoing) {
                        c.lastMessage.isRead = YES;
                    }
                } else {
                    c.unreadCount = 0;
                }
                [self.tableView reloadData];
                break;
            }
        }
    });
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self currentDataSource].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKConversationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 12, 48, 48)];
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        avatar.tag = 301;
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:25.0/255.0 alpha:1.0];
        nameLabel.tag = 302;
        [cell.contentView addSubview:nameLabel];
        
        UILabel *badgeVerified = [[UILabel alloc] initWithFrame:CGRectZero];
        badgeVerified.text = @"✓";
        badgeVerified.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        badgeVerified.font = [UIFont boldSystemFontOfSize:12];
        badgeVerified.hidden = YES;
        badgeVerified.tag = 303;
        [cell.contentView addSubview:badgeVerified];
        
        UIImageView *supporterBadge = [[UIImageView alloc] initWithFrame:CGRectZero];
        supporterBadge.contentMode = UIViewContentModeScaleAspectFit;
        supporterBadge.hidden = YES;
        supporterBadge.tag = 304;
        [cell.contentView addSubview:supporterBadge];
        
        UILabel *msgLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        msgLabel.font = [UIFont systemFontOfSize:13];
        msgLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        msgLabel.tag = 305;
        [cell.contentView addSubview:msgLabel];
        
        UILabel *unreadBadge = [[UILabel alloc] initWithFrame:CGRectZero];
        unreadBadge.font = [UIFont boldSystemFontOfSize:12];
        unreadBadge.textColor = [UIColor whiteColor];
        unreadBadge.textAlignment = NSTextAlignmentCenter;
        unreadBadge.layer.cornerRadius = 9.0;
        unreadBadge.clipsToBounds = YES;
        unreadBadge.hidden = YES;
        unreadBadge.tag = 306;
        [cell.contentView addSubview:unreadBadge];
        
        UILabel *dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        dateLabel.font = [UIFont systemFontOfSize:11.5];
        dateLabel.textColor = [UIColor colorWithRed:145.0/255.0 green:150.0/255.0 blue:160.0/255.0 alpha:1.0];
        dateLabel.textAlignment = NSTextAlignmentRight;
        dateLabel.tag = 307;
        [cell.contentView addSubview:dateLabel];
        
        UIView *unreadDot = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
        unreadDot.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        unreadDot.layer.cornerRadius = 4.0;
        unreadDot.clipsToBounds = YES;
        unreadDot.hidden = YES;
        unreadDot.tag = 308;
        [cell.contentView addSubview:unreadDot];
    }
    
    NSArray *data = [self currentDataSource];
    if (indexPath.row >= (NSInteger)data.count) return cell;
    
    VKConversation *conv = data[indexPath.row];
    CGFloat width = tableView.bounds.size.width;
    
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:301];
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:48.0];
    avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:302];
    nameLabel.font = [[VKThemeManager sharedManager] titleFontOfSize:15];
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        nameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        nameLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    UILabel *badgeVerified = (UILabel *)[cell.contentView viewWithTag:303];
    UIImageView *supporterBadge = (UIImageView *)[cell.contentView viewWithTag:304];
    UILabel *msgLabel = (UILabel *)[cell.contentView viewWithTag:305];
    UILabel *unreadBadge = (UILabel *)[cell.contentView viewWithTag:306];
    UILabel *dateLabel = (UILabel *)[cell.contentView viewWithTag:307];
    UIView *unreadDot = [cell.contentView viewWithTag:308];
    
    if (conv.isChat) {
        avatar.image = [UIImage imageNamed:isSkeuomorph ? @"MessagesGroup" : @"7_messages_group"];
    } else if (conv.isGroup) {
        avatar.image = [UIImage imageNamed:@"7_group_placeholder"];
    } else {
        avatar.image = [UIImage imageNamed:isSkeuomorph ? @"user_placeholder" : @"7_user_placeholder"];
    }
    
    NSString *avatarURL = [conv displayAvatarURL];
    if (avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    nameLabel.text = [conv displayTitle];
    CGSize nameSize = [nameLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:15]];
    nameLabel.frame = CGRectMake(70, 14, MIN(nameSize.width, width - 150), 20);
    
    CGFloat nextX = CGRectGetMaxX(nameLabel.frame) + 4;
    if (conv.peerUser.isOfficial) {
        badgeVerified.hidden = NO;
        badgeVerified.frame = CGRectMake(nextX, 17, 13, 13);
        nextX += 17;
    } else {
        badgeVerified.hidden = YES;
    }
    
    NSString *badgeURL = [[VKSupportersService sharedService] badgeIconURLForScreenName:conv.peerUser.username];
    if (badgeURL.length > 0) {
        supporterBadge.hidden = NO;
        supporterBadge.frame = CGRectMake(nextX, 16, 14, 14);
        [[VKImageLoader sharedLoader] loadImageWithURL:badgeURL completion:^(UIImage *img) {
            if (img) supporterBadge.image = img;
        }];
    } else {
        supporterBadge.hidden = YES;
    }
    
    // Дата последнего сообщения
    dateLabel.text = conv.lastMessage.timeString ?: @"";
    dateLabel.frame = CGRectMake(width - 80, 16, 70, 16);
    
    msgLabel.text = [conv previewText];
    msgLabel.frame = CGRectMake(70, 36, width - 130, 18);
    
    if (conv.unreadCount > 0) {
        unreadBadge.hidden = NO;
        unreadBadge.text = [NSString stringWithFormat:@"%ld", (long)conv.unreadCount];
        unreadBadge.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:215.0/255.0 green:40.0/255.0 blue:40.0/255.0 alpha:1.0] : [UIColor colorWithRed:255.0/255.0 green:59.0/255.0 blue:48.0/255.0 alpha:1.0];
        unreadBadge.frame = CGRectMake(width - 42, 36, 26, 18);
        unreadDot.hidden = YES;
        cell.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:238.0/255.0 green:243.0/255.0 blue:250.0/255.0 alpha:1.0] : [UIColor colorWithRed:242.0/255.0 green:245.0/255.0 blue:252.0/255.0 alpha:1.0];
    } else {
        unreadBadge.hidden = YES;
        cell.backgroundColor = [UIColor clearColor];
        
        if (conv.lastMessage.isOutgoing && !conv.lastMessage.isRead) {
            unreadDot.hidden = NO;
            unreadDot.frame = CGRectMake(width - 24, 41, 8, 8);
            unreadDot.backgroundColor = [[VKThemeManager sharedManager] accentColor];
        } else {
            unreadDot.hidden = YES;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *data = [self currentDataSource];
    if (indexPath.row < (NSInteger)data.count) {
        VKConversation *conv = data[indexPath.row];
        VKChatViewController *chatVC = [[VKChatViewController alloc] initWithPeerId:conv.peerId peerUser:conv.peerUser title:[conv displayTitle]];
        chatVC.chatPhotoURL = conv.chatPhotoURL;
        chatVC.membersCount = conv.membersCount;
        chatVC.adminId = conv.adminId;
        [self.navigationController pushViewController:chatVC animated:YES];
    }
}

@end
