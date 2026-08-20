#import "VKProfileViewController.h"
#import "VKProfileService.h"
#import "VKAuthService.h"
#import "VKNewPostViewController.h"
#import "VKChatViewController.h"
#import "VKSettingsViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "VKDetailedProfileInfoViewController.h"
#import "VKFriendsListViewController.h"
#import "VKGroupsListViewController.h"
#import "VKAlbumsListViewController.h"
#import "VKVideosListViewController.h"
#import "VKAudioListViewController.h"
#import "VKFeedPostCell.h"
#import "VKFeedService.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKPostDetailViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKCrashLogger.h"

@interface VKProfileViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSMutableArray *wallPosts;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKProfileViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.tableView reloadData];
}

- (instancetype)initWithUser:(VKUser *)user {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _user = user;
        _wallPosts = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!self.user) {
        self.user = [[VKAuthService sharedService] currentUserModel];
    }
    
    self.title = self.user.displayName ?: @"Профиль";
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    if ([self.user isCurrentUser] || self.user.canWriteOnWall || self.user.canPost) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(optionsAction)];
    }
    
    [self setupNavigationItems];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshProfile) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadProfileData];
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

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView reloadData];
}

- (void)refreshProfile {
    [self loadProfileData];
}

- (void)optionsAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:@"Новая запись", @"Скопировать ссылку", nil];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self newPostAction];
    }
}

- (void)newPostAction {
    NSInteger targetOwner = self.user.uid;
    if (targetOwner == 0) targetOwner = [[VKAuthService sharedService] currentUserModel].uid;
    VKNewPostViewController *newPostVC = [[VKNewPostViewController alloc] initWithOwnerId:targetOwner];
    __weak typeof(self) weakSelf = self;
    newPostVC.onPostCreated = ^{
        [weakSelf loadProfileData];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:newPostVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)loadProfileData {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    NSInteger uid = self.user.uid;
    if (uid == 0 && [self.user isCurrentUser]) {
        uid = [[VKAuthService sharedService] currentUserModel].uid;
    }
    
    [[VKProfileService sharedService] fetchProfileForUserId:uid completion:^(VKUser *updatedUser, NSError *error) {
        if (!error && updatedUser) {
            self.user = updatedUser;
            self.title = self.user.displayName;
        }
        
        [[VKProfileService sharedService] fetchWallForOwnerId:uid offset:0 count:30 completion:^(NSArray *posts, NSInteger totalCount, NSError *wallErr) {
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            if (!wallErr && posts) {
                [self.wallPosts removeAllObjects];
                [self.wallPosts addObjectsFromArray:posts];
            }
            [self.tableView reloadData];
        }];
    }];
}

- (void)writeMessageAction {
    VKChatViewController *chatVC = [[VKChatViewController alloc] initWithPeerId:self.user.uid peerUser:self.user title:self.user.displayName];
    [self.navigationController pushViewController:chatVC animated:YES];
}

- (void)toggleFriendAction {
    BOOL isFriend = self.user.isFriend;
    self.user.isFriend = !isFriend;
    [self.tableView reloadData];
    
    if (isFriend) {
        [[VKProfileService sharedService] deleteFriend:self.user.uid completion:nil];
    } else {
        [[VKProfileService sharedService] addFriend:self.user.uid completion:nil];
    }
}

- (void)toggleGroupAction {
    BOOL isMember = self.user.isFriend;
    self.user.isFriend = !isMember;
    [self.tableView reloadData];
    
    if (isMember) {
        [[VKProfileService sharedService] leaveGroup:self.user.uid completion:nil];
    } else {
        [[VKProfileService sharedService] joinGroup:self.user.uid completion:nil];
    }
}

- (void)showDetailsAction {
    VKDetailedProfileInfoViewController *detailsVC = [[VKDetailedProfileInfoViewController alloc] initWithUser:self.user];
    [self.navigationController pushViewController:detailsVC animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // Секция 0: Шапка профиля и счетчики, Секция 1: Стена постов
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return self.wallPosts.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if ([[VKThemeManager sharedManager] isModern]) {
            return 196.0;
        }
        // Высота шапки со счетчиками и кнопками для iOS 6 и iOS 7
        return self.user.isGroup ? 200.0 : 210.0;
    } else {
        if (indexPath.row >= (NSInteger)self.wallPosts.count) return 44.0;
        VKPost *post = self.wallPosts[indexPath.row];
        return [VKFeedPostCell heightForPost:post width:tableView.bounds.size.width isRevealed:YES];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        BOOL isModern = [[VKThemeManager sharedManager] isModern];
        NSString *HeaderCellId = isModern ? @"VKProfileSwiftUIHeaderCell" : @"VKProfileAuthenticHeaderCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:HeaderCellId];
        
        if (isModern) {
            // Оригинальный SwiftUI Profile Header (ProfileHeaderView.swift & ProfileInfoSection.swift)
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HeaderCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor whiteColor];
                
                // Аватар 76x76
                UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 76, 76)];
                avatar.tag = 801;
                avatar.layer.cornerRadius = 38.0;
                avatar.clipsToBounds = YES;
                avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
                [cell.contentView addSubview:avatar];
                
                // Имя
                UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(108, 22, cell.contentView.bounds.size.width - 124, 24)];
                nameLabel.font = [UIFont boldSystemFontOfSize:18];
                nameLabel.textColor = [UIColor blackColor];
                nameLabel.tag = 802;
                [cell.contentView addSubview:nameLabel];
                
                // Статус online / last seen
                UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(108, 48, cell.contentView.bounds.size.width - 124, 18)];
                statusLabel.font = [UIFont systemFontOfSize:13];
                statusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
                statusLabel.tag = 803;
                [cell.contentView addSubview:statusLabel];
                
                // Кнопка действия (Редактировать / Вступить / Добавить)
                UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                actionBtn.frame = CGRectMake(16, 104, cell.contentView.bounds.size.width - 32, 36);
                actionBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                actionBtn.layer.cornerRadius = 8.0;
                actionBtn.clipsToBounds = YES;
                actionBtn.tag = 804;
                [cell.contentView addSubview:actionBtn];
                
                // Разделитель
                UIView *div = [[UIView alloc] initWithFrame:CGRectMake(0, 150, cell.contentView.bounds.size.width, 0.5)];
                div.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:232.0/255.0 blue:236.0/255.0 alpha:1.0];
                div.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:div];
                
                // Строка Подробная информация ›
                UIButton *detailsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                detailsBtn.frame = CGRectMake(0, 151, cell.contentView.bounds.size.width, 44);
                detailsBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [detailsBtn setTitle:@"Подробная информация ›" forState:UIControlStateNormal];
                [detailsBtn setTitleColor:[UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                detailsBtn.titleLabel.font = [UIFont systemFontOfSize:14.5];
                detailsBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
                detailsBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);
                [detailsBtn addTarget:self action:@selector(showDetailsAction) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:detailsBtn];
            }
            
            UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:801];
            UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:802];
            UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:803];
            UIButton *actionBtn = (UIButton *)[cell.contentView viewWithTag:804];
            
            avatar.image = nil;
            if (self.user.avatarURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:self.user.avatarURL completion:^(UIImage *img) {
                    if (img) avatar.image = img;
                }];
            }
            
            nameLabel.text = self.user.displayName;
            statusLabel.text = self.user.isOnline ? @"online" : (self.user.lastSeen ?: @"был(а) недавно");
            
            NSInteger myId = [[VKAuthService sharedService] currentUserId];
            BOOL isMyProfile = (self.user.uid == myId || self.user.uid == 0);
            
            if (isMyProfile) {
                actionBtn.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0];
                [actionBtn setTitle:@"Редактировать" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [actionBtn addTarget:self action:@selector(newPostAction) forControlEvents:UIControlEventTouchUpInside];
            } else if (self.user.isGroup) {
                actionBtn.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                [actionBtn setTitle:self.user.isFriend ? @"Вы подписаны ✓" : @"Подписаться" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [actionBtn addTarget:self action:@selector(toggleGroupAction) forControlEvents:UIControlEventTouchUpInside];
            } else {
                actionBtn.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                [actionBtn setTitle:self.user.isFriend ? @"У вас в друзьях ✓" : @"Добавить в друзья" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
            }
            
            return cell;
        }
        
        // Классический аутентичный профиль для iOS 6 и iOS 7
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HeaderCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor whiteColor];
            
            // Шапка профиля
            UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 72, 72)];
            avatar.tag = 601;
            avatar.clipsToBounds = YES;
            avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            [cell.contentView addSubview:avatar];
            
            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 16, cell.contentView.bounds.size.width - 150, 22)];
            nameLabel.font = [UIFont boldSystemFontOfSize:17];
            nameLabel.textColor = [UIColor blackColor];
            nameLabel.tag = 602;
            [cell.contentView addSubview:nameLabel];
            
            UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 40, cell.contentView.bounds.size.width - 150, 18)];
            statusLabel.font = [UIFont systemFontOfSize:13];
            statusLabel.textColor = [UIColor grayColor];
            statusLabel.tag = 603;
            [cell.contentView addSubview:statusLabel];
            
            UILabel *cityLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 60, cell.contentView.bounds.size.width - 150, 18)];
            cityLabel.font = [UIFont systemFontOfSize:13];
            cityLabel.textColor = [UIColor grayColor];
            cityLabel.tag = 604;
            [cell.contentView addSubview:cityLabel];
            
            // Круглая синяя кнопка (i)
            UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
            infoButton.frame = CGRectMake(cell.contentView.bounds.size.width - 44, 24, 30, 30);
            infoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            [infoButton setTitle:@"ⓘ" forState:UIControlStateNormal];
            [infoButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
            infoButton.titleLabel.font = [UIFont systemFontOfSize:22];
            [infoButton addTarget:self action:@selector(showDetailsAction) forControlEvents:UIControlEventTouchUpInside];
            infoButton.tag = 605;
            [cell.contentView addSubview:infoButton];
            
            // Разделитель
            UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(0, 100, cell.contentView.bounds.size.width, 0.5)];
            sep1.backgroundColor = [UIColor colorWithRed:220.0/255.0 green:223.0/255.0 blue:228.0/255.0 alpha:1.0];
            sep1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep1];
            
            // Горизонтальный блок счетчиков (Скриншот 2)
            UIScrollView *countersScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 101, cell.contentView.bounds.size.width, 54)];
            countersScroll.showsHorizontalScrollIndicator = NO;
            countersScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            countersScroll.tag = 606;
            [cell.contentView addSubview:countersScroll];
            
            // Разделитель
            UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(0, 155, cell.contentView.bounds.size.width, 0.5)];
            sep2.backgroundColor = [UIColor colorWithRed:220.0/255.0 green:223.0/255.0 blue:228.0/255.0 alpha:1.0];
            sep2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep2];
            
            // Панель действий [Запись] [Фото] [Место] или кнопка [Вступить]
            UIView *actionsBar = [[UIView alloc] initWithFrame:CGRectMake(0, 156, cell.contentView.bounds.size.width, 48)];
            actionsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            actionsBar.tag = 607;
            [cell.contentView addSubview:actionsBar];
            
            // Разделитель снизу
            UIView *sep3 = [[UIView alloc] initWithFrame:CGRectMake(0, 204, cell.contentView.bounds.size.width, 6)];
            sep3.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:243.0/255.0 alpha:1.0];
            sep3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep3];
        }
        
        UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:601];
        UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:602];
        UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:603];
        UILabel *cityLabel = (UILabel *)[cell.contentView viewWithTag:604];
        UIScrollView *countersScroll = (UIScrollView *)[cell.contentView viewWithTag:606];
        UIView *actionsBar = [cell.contentView viewWithTag:607];
        
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:72.0];
        avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
        avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
        avatar.image = nil;
        if (self.user.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:self.user.avatarURL completion:^(UIImage *img) {
                if (img) avatar.image = img;
            }];
        }
        
        nameLabel.text = self.user.displayName;
        if (self.user.isGroup) {
            statusLabel.text = @"открытая группа";
            cityLabel.text = self.user.status.length > 0 ? self.user.status : @"";
        } else {
            statusLabel.text = self.user.isOnline ? @"online" : (self.user.lastSeen ?: @"был(а) недавно");
            statusLabel.textColor = self.user.isOnline ? [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] : [UIColor grayColor];
            cityLabel.text = self.user.city.length > 0 ? self.user.city : (self.user.status ?: @"");
        }
        
        // Заполняем счетчики (Скриншоты 2 и 5)
        for (UIView *v in countersScroll.subviews) [v removeFromSuperview];
        
        NSMutableArray *counters = [NSMutableArray array];
        if (self.user.isGroup) {
            [counters addObject:@{@"count": @(self.user.followersCount > 0 ? self.user.followersCount : 1900), @"title": @"участников", @"action": @"followers"}];
            [counters addObject:@{@"count": @(self.user.photoCount > 0 ? self.user.photoCount : 12), @"title": @"фото", @"action": @"photos"}];
            [counters addObject:@{@"count": @(self.user.videoCount > 0 ? self.user.videoCount : 2), @"title": @"видео", @"action": @"videos"}];
            [counters addObject:@{@"count": @(self.user.audioCount > 0 ? self.user.audioCount : 1), @"title": @"аудио", @"action": @"audios"}];
        } else {
            [counters addObject:@{@"count": @(self.user.friendsCount > 0 ? self.user.friendsCount : 93), @"title": @"друга", @"action": @"friends"}];
            [counters addObject:@{@"count": @(self.user.followersCount > 0 ? self.user.followersCount : 17), @"title": @"подписчиков", @"action": @"followers"}];
            [counters addObject:@{@"count": @(self.user.groupsCount > 0 ? self.user.groupsCount : 26), @"title": @"групп", @"action": @"groups"}];
            [counters addObject:@{@"count": @(self.user.photoCount > 0 ? self.user.photoCount : 405), @"title": @"фото", @"action": @"photos"}];
            [counters addObject:@{@"count": @(self.user.videoCount > 0 ? self.user.videoCount : 17), @"title": @"видео", @"action": @"videos"}];
            [counters addObject:@{@"count": @(self.user.audioCount > 0 ? self.user.audioCount : 48), @"title": @"аудио", @"action": @"audios"}];
        }
        
        CGFloat itemW = 76.0;
        for (NSInteger i = 0; i < counters.count; i++) {
            NSDictionary *c = counters[i];
            UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            cBtn.frame = CGRectMake(i * itemW, 0, itemW, 54);
            
            UILabel *countLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, itemW, 20)];
            countLbl.text = [NSString stringWithFormat:@"%@", c[@"count"]];
            countLbl.font = [UIFont boldSystemFontOfSize:16];
            countLbl.textColor = [UIColor colorWithRed:40.0/255.0 green:40.0/255.0 blue:45.0/255.0 alpha:1.0];
            countLbl.textAlignment = NSTextAlignmentCenter;
            [cBtn addSubview:countLbl];
            
            UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, itemW, 16)];
            titleLbl.text = c[@"title"];
            titleLbl.font = [UIFont systemFontOfSize:12];
            titleLbl.textColor = [UIColor grayColor];
            titleLbl.textAlignment = NSTextAlignmentCenter;
            [cBtn addSubview:titleLbl];
            
            if ([c[@"action"] isEqualToString:@"friends"] || [c[@"action"] isEqualToString:@"followers"]) {
                [cBtn addTarget:self action:@selector(openFriendsList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"groups"]) {
                [cBtn addTarget:self action:@selector(openGroupsList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"photos"]) {
                [cBtn addTarget:self action:@selector(openPhotosList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"videos"]) {
                [cBtn addTarget:self action:@selector(openVideosList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"audios"]) {
                [cBtn addTarget:self action:@selector(openAudiosList) forControlEvents:UIControlEventTouchUpInside];
            }
            [countersScroll addSubview:cBtn];
        }
        countersScroll.contentSize = CGSizeMake(counters.count * itemW, 54);
        
        // Заполняем панель быстрых действий (Скриншот 2)
        for (UIView *v in actionsBar.subviews) [v removeFromSuperview];
        
        if (self.user.isGroup) {
            UIButton *joinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            joinBtn.frame = CGRectMake(16, 6, cell.contentView.bounds.size.width - 32, 36);
            joinBtn.layer.cornerRadius = 4.0;
            joinBtn.clipsToBounds = YES;
            joinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            
            if (self.user.isFriend) {
                joinBtn.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:245.0/255.0 alpha:1.0];
                [joinBtn setTitleColor:[UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                [joinBtn setTitle:@"Вы состоите в группе ✓" forState:UIControlStateNormal];
            } else {
                joinBtn.backgroundColor = [UIColor colorWithRed:81.0/255.0 green:129.0/255.0 blue:184.0/255.0 alpha:1.0];
                [joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                [joinBtn setTitle:@"Вступить" forState:UIControlStateNormal];
            }
            [joinBtn addTarget:self action:@selector(toggleGroupAction) forControlEvents:UIControlEventTouchUpInside];
            [actionsBar addSubview:joinBtn];
        } else {
            CGFloat actW = cell.contentView.bounds.size.width / 3.0;
            NSArray *acts = @[@"Запись", @"Фото", @"Место"];
            for (NSInteger i = 0; i < 3; i++) {
                UIButton *actBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                actBtn.frame = CGRectMake(i * actW, 0, actW, 44);
                [actBtn setTitle:acts[i] forState:UIControlStateNormal];
                [actBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                actBtn.titleLabel.font = [UIFont systemFontOfSize:14];
                if (i == 0) [actBtn addTarget:self action:@selector(newPostAction) forControlEvents:UIControlEventTouchUpInside];
                [actionsBar addSubview:actBtn];
                
                if (i < 2) {
                    UIView *div = [[UIView alloc] initWithFrame:CGRectMake((i + 1) * actW, 10, 0.5, 24)];
                    div.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:232.0/255.0 blue:236.0/255.0 alpha:1.0];
                    [actionsBar addSubview:div];
                }
            }
        }
        
        return cell;
    } else {
        static NSString *CellId = @"VKFeedPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        }
        
        if (indexPath.row < (NSInteger)self.wallPosts.count) {
            VKPost *post = self.wallPosts[indexPath.row];
            [cell configureWithPost:post isRevealed:YES];
            
            __weak typeof(self) weakSelf = self;
            cell.onLikeTapped = ^(VKPost *p) {
                [[VKFeedService sharedService] likePost:p completion:^(VKPost *updatedPost, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.tableView reloadData];
                    });
                }];
            };
            cell.onCommentTapped = ^(VKPost *p) {
                VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:p];
                [weakSelf.navigationController pushViewController:detailVC animated:YES];
            };
            cell.onRepostTapped = ^(VKPost *p) {
                UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                                   delegate:nil
                                                          cancelButtonTitle:@"Отмена"
                                                     destructiveButtonTitle:nil
                                                          otherButtonTitles:@"Поделиться на стене", @"Скопировать ссылку", nil];
                [sheet showInView:weakSelf.view];
            };
            cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
                VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
                [weakSelf presentViewController:viewer animated:YES completion:nil];
            };
            cell.onPhotoTapped = ^(NSString *url, UIImage *img) {
                VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:url initialImage:img];
                [weakSelf presentViewController:viewer animated:YES completion:nil];
            };
            cell.onVideoTapped = ^(VKAttachment *videoAttachment) {
                VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:videoAttachment];
                [weakSelf presentMoviePlayerViewControllerAnimated:player];
            };
            cell.onAudioTapped = ^(VKAttachment *audioAttachment) {
                [weakSelf.tableView reloadData];
            };
            cell.onPollVoted = ^(VKAttachment *pollAttachment, NSInteger optionId) {
                [weakSelf.tableView reloadData];
            };
            cell.onDocTapped = ^(VKAttachment *docAttachment) {
                if (docAttachment.docURL.length > 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:docAttachment.docURL]];
                }
            };
            cell.onLinkTapped = ^(NSString *url) {
                if (url.length > 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                }
            };
            cell.onCopyrightTapped = ^(NSString *url) {
                if (url.length > 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                }
            };
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row < (NSInteger)self.wallPosts.count) {
        VKPost *post = self.wallPosts[indexPath.row];
        VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:post];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (void)openFriendsList {
    VKFriendsListViewController *vc = [[VKFriendsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openGroupsList {
    VKGroupsListViewController *vc = [[VKGroupsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openPhotosList {
    VKAlbumsListViewController *vc = [[VKAlbumsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openVideosList {
    VKVideosListViewController *vc = [[VKVideosListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openAudiosList {
    VKAudioListViewController *vc = [[VKAudioListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
