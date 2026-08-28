#import "VKMoreViewController.h"
#import "VKProfileViewController.h"
#import "VKFriendsListViewController.h"
#import "VKGroupsListViewController.h"
#import "VKNotificationsViewController.h"
#import "VKAlbumsListViewController.h"
#import "VKVideosListViewController.h"
#import "VKAudioListViewController.h"
#import "VKSettingsViewController.h"
#import "VKLoginViewController.h"
#import "VKAuthService.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKSupportersViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import "VKAppConfig.h"

@interface VKMoreViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIButton *accountTitleButton;
@end

@implementation VKMoreViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKMoreViewController] viewDidLoad started."];
    
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    [self setupNavigationItems];
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    [[VKAuthService sharedService] fetchBalance];
    [[VKAuthService sharedService] fetchCounters];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeStyle];
    [self setupNavigationItems];
    [self updateAccountTitle];
    [self.tableView reloadData];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    UIColor *titleColor = [[VKThemeManager sharedManager] navBarTitleColor];
    [self.accountTitleButton setTitleColor:titleColor forState:UIControlStateNormal];
    
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

- (void)setupNavigationItems {
    self.accountTitleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.accountTitleButton.frame = CGRectMake(0, 0, 180, 32);
    [self.accountTitleButton setTitleColor:[[VKThemeManager sharedManager] navBarTitleColor] forState:UIControlStateNormal];
    self.accountTitleButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.accountTitleButton addTarget:self action:@selector(selectAccountAction) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.titleView = self.accountTitleButton;
    
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
    self.navigationItem.rightBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Настройки" target:self action:@selector(openSettingsAction) isBack:NO];
}

- (void)leftMenuButtonAction {
    [[VKSideMenuManager sharedManager] toggleMenu];
}

- (void)updateAccountTitle {
    VKUser *current = [[VKAuthService sharedService] currentUserModel];
    NSString *title = [NSString stringWithFormat:@"%@ ▾", current.displayName ?: @"Профиль"];
    [self.accountTitleButton setTitle:title forState:UIControlStateNormal];
}

- (void)selectAccountAction {
    NSArray *accounts = [[VKAuthService sharedService] accounts];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Учетные записи"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                          destructiveButtonTitle:nil
                                               otherButtonTitles:nil];
    for (VKAuthAccount *acc in accounts) {
        NSString *host = (acc.instanceHost.length > 0) ? acc.instanceHost : [VKAppConfig currentHost];
        BOOL isSameUser = [acc.user.username isEqualToString:[[VKAuthService sharedService] currentUserModel].username];
        BOOL isSameHost = (acc.instanceHost.length == 0) || [acc.instanceHost isEqualToString:[VKAppConfig currentHost]];
        BOOL isActive = isSameUser && isSameHost;
        NSString *name = [NSString stringWithFormat:@"%@ (%@) %@", acc.user.displayName, host, isActive ? @"✓" : @""];
        [sheet addButtonWithTitle:name];
    }
    [sheet addButtonWithTitle:@"+ Добавить аккаунт"];
    [sheet addButtonWithTitle:@"Отмена"];
    sheet.cancelButtonIndex = accounts.count + 1;
    sheet.tag = 101;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 101) {
        NSArray *accounts = [[VKAuthService sharedService] accounts];
        if (buttonIndex >= 0 && buttonIndex < (NSInteger)accounts.count) {
            VKAuthAccount *acc = accounts[buttonIndex];
            [[VKAuthService sharedService] switchToAccount:acc];
            [self updateAccountTitle];
            [self.tableView reloadData];
        } else if (buttonIndex == (NSInteger)accounts.count) {
            VKLoginViewController *loginVC = [[VKLoginViewController alloc] init];
            [self.navigationController pushViewController:loginVC animated:YES];
        }
    }
}

- (void)openSettingsAction {
    VKSettingsViewController *settingsVC = [[VKSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    [self.navigationController pushViewController:settingsVC animated:YES];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return 11; // Ответы, Друзья, Группы, Фото, Видео, Аудио, Заметки, Приложения, Документы, Баланс, Другие
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return 68.0;
    return 46.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *ProfileCellId = @"VKMoreProfileCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ProfileCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ProfileCellId];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
            cell.imageView.layer.cornerRadius = 24.0;
            cell.imageView.clipsToBounds = YES;
            cell.imageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        VKUser *user = [[VKAuthService sharedService] currentUserModel];
        cell.textLabel.text = user.displayName ?: @"Мой профиль";
        cell.detailTextLabel.text = @"Перейти в профиль";
        
        cell.imageView.image = nil;
        if (user.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
                if (img) {
                    cell.imageView.image = img;
                    [cell setNeedsLayout];
                }
            }];
        }
        return cell;
    } else {
        static NSString *MenuCellId = @"VKMoreMenuCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MenuCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:MenuCellId];
            cell.textLabel.font = [UIFont systemFontOfSize:16];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        cell.detailTextLabel.text = @"";
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = [[VKThemeManager sharedManager] isSkeuomorphic] ? @"💬  Ответы" : @"🔔  Уведомления";
                break;
            case 1:
                cell.textLabel.text = @"👥  Друзья";
                if ([[VKAuthService sharedService] friendsCount] > 0) {
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[[VKAuthService sharedService] friendsCount]];
                }
                break;
            case 2: cell.textLabel.text = @"👥  Группы"; break;
            case 3: cell.textLabel.text = @"🖼  Фотографии"; break;
            case 4: cell.textLabel.text = @"🎬  Видеозаписи"; break;
            case 5: cell.textLabel.text = @"🎵  Аудиозаписи"; break;
            case 6: cell.textLabel.text = @"📝  Заметки"; break;
            case 7: cell.textLabel.text = @"🎮  Приложения"; break;
            case 8: cell.textLabel.text = @"📄  Документы"; break;
            case 9:
                cell.textLabel.text = @"💰  Баланс";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld голосов", (long)[[VKAuthService sharedService] balanceVotes]];
                break;
            case 10:
                cell.textLabel.text = @"💖  Другие (Тестеры и донатеры)";
                break;
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:[[VKAuthService sharedService] currentUserModel]];
        [self.navigationController pushViewController:profVC animated:YES];
    } else {
        NSInteger uid = [[VKAuthService sharedService] currentUserModel].uid;
        switch (indexPath.row) {
            case 0: {
                VKNotificationsViewController *notifVC = [[VKNotificationsViewController alloc] init];
                [self.navigationController pushViewController:notifVC animated:YES];
                break;
            }
            case 1: {
                VKFriendsListViewController *friendsVC = [[VKFriendsListViewController alloc] initWithUserId:uid];
                [self.navigationController pushViewController:friendsVC animated:YES];
                break;
            }
            case 2: {
                VKGroupsListViewController *groupsVC = [[VKGroupsListViewController alloc] initWithUserId:uid];
                [self.navigationController pushViewController:groupsVC animated:YES];
                break;
            }
            case 3: {
                VKAlbumsListViewController *albumsVC = [[VKAlbumsListViewController alloc] initWithUserId:uid];
                [self.navigationController pushViewController:albumsVC animated:YES];
                break;
            }
            case 4: {
                VKVideosListViewController *videosVC = [[VKVideosListViewController alloc] initWithUserId:uid];
                [self.navigationController pushViewController:videosVC animated:YES];
                break;
            }
            case 5: {
                VKAudioListViewController *audioVC = [[VKAudioListViewController alloc] initWithUserId:uid];
                [self.navigationController pushViewController:audioVC animated:YES];
                break;
            }
            case 10: {
                VKSupportersViewController *supVC = [[VKSupportersViewController alloc] initWithStyle:UITableViewStyleGrouped];
                [self.navigationController pushViewController:supVC animated:YES];
                break;
            }
            default: {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"В разработке"
                                                                message:@"Раздел находится в разработке и будет доступен в следующих версиях."
                                                                delegate:nil
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil];
                [alert show];
                break;
            }
        }
    }
}

@end
