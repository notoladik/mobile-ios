#import "VKSettingsViewController.h"
#import "VKAuthService.h"
#import "VKLoginViewController.h"
#import "VKAppearanceViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKSupportersViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import "VKAppConfig.h"

@interface VKSettingsViewController () <UIActionSheetDelegate>
@end

@implementation VKSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKSettingsViewController] viewDidLoad started."];
    
    self.title = @"Настройки";
    [self applyThemeStyle];
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyThemeStyle];
    [self setupNavigationItems];
    [self.tableView reloadData];
}

- (void)applyThemeStyle {
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

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4; // 0: Аккаунты, 1: Настройки разделов, 2: О приложении, 3: Выход
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[VKAuthService sharedService] accounts].count + 1; // Все аккаунты + "+ Добавить аккаунт"
    } else if (section == 1) {
        return 9; // Лента, Устройства, Аккаунт, Уведомления, Конфиденциальность, Данные и память, Внешний вид, Энергосбережение, Язык
    } else if (section == 2) {
        return 3; // О приложении, Другие (Тестеры и донатеры), Лог диагностики и сбоев
    } else {
        return 1; // Выйти из аккаунта
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"АККАУНТЫ";
    if (section == 1) return @"НАСТРОЙКИ";
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 46.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSArray *accounts = [[VKAuthService sharedService] accounts];
        if (indexPath.row < (NSInteger)accounts.count) {
            static NSString *AccCellId = @"VKSettingsAccountCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AccCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AccCellId];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
                cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
                cell.imageView.layer.cornerRadius = 14.0;
                cell.imageView.clipsToBounds = YES;
                cell.imageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            }
            
            VKAuthAccount *acc = accounts[indexPath.row];
            BOOL isActive = [acc.user.username isEqualToString:[[VKAuthService sharedService] currentUserModel].username];
            
            cell.textLabel.text = acc.user.displayName;
            cell.detailTextLabel.text = acc.user.username ? [NSString stringWithFormat:@"@%@  •  %@", acc.user.username, [VKAppConfig currentHost]] : [VKAppConfig currentHost];
            cell.accessoryType = isActive ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            
            cell.imageView.image = nil;
            if (acc.user.avatarURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:acc.user.avatarURL completion:^(UIImage *img) {
                    if (img) {
                        cell.imageView.image = img;
                        [cell setNeedsLayout];
                    }
                }];
            }
            return cell;
        } else {
            static NSString *AddAccCellId = @"VKSettingsAddAccCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AddAccCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AddAccCellId];
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.textLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            }
            cell.textLabel.text = @"+  Добавить аккаунт";
            return cell;
        }
    } else if (indexPath.section == 1) {
        static NSString *MenuCellId = @"VKSettingsMenuRowCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MenuCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MenuCellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        switch (indexPath.row) {
            case 0: cell.textLabel.text = @"📰  Лента"; break;
            case 1: cell.textLabel.text = @"📱  Устройства"; break;
            case 2: cell.textLabel.text = @"👤  Аккаунт"; break;
            case 3: cell.textLabel.text = @"🔔  Уведомления и звуки"; break;
            case 4: cell.textLabel.text = @"🛡  Конфиденциальность"; break;
            case 5: cell.textLabel.text = @"💾  Данные и память"; break;
            case 6: cell.textLabel.text = @"🎨  Внешний вид"; break;
            case 7: cell.textLabel.text = @"🔋  Энергосбережение"; break;
            case 8: cell.textLabel.text = @"🌐  Язык"; break;
        }
        return cell;
    } else if (indexPath.section == 2) {
        static NSString *AboutCellId = @"VKSettingsAboutRowCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AboutCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AboutCellId];
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"ℹ️  О приложении";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"💖  Другие (Тестеры и донатеры)";
        } else {
            cell.textLabel.text = @"🛠  Лог диагностики и сбоев";
        }
        return cell;
    } else {
        static NSString *SignOutCellId = @"VKSettingsSignOutCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SignOutCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SignOutCellId];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            cell.textLabel.textColor = [UIColor redColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        cell.textLabel.text = @"Выйти из учетной записи";
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSArray *accounts = [[VKAuthService sharedService] accounts];
        if (indexPath.row < (NSInteger)accounts.count) {
            VKAuthAccount *acc = accounts[indexPath.row];
            [[VKAuthService sharedService] switchToAccount:acc];
            [self.tableView reloadData];
        } else {
            VKLoginViewController *loginVC = [[VKLoginViewController alloc] init];
            [self.navigationController pushViewController:loginVC animated:YES];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 5) {
            // Данные и память
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Очистка кэша"
                                                            message:@"Вы хотите очистить кэш изображений и данных?"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                                  otherButtonTitles:@"Очистить", nil];
            alert.tag = 501;
            [alert show];
        } else if (indexPath.row == 6) {
            // Внешний вид
            VKAppearanceViewController *appearanceVC = [[VKAppearanceViewController alloc] init];
            [self.navigationController pushViewController:appearanceVC animated:YES];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"В разработке"
                                                            message:@"Раздел находится в разработке и будет доступен в следующих версиях."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            // О приложении
            NSString *aboutMsg = [NSString stringWithFormat:@"OpenVK for iOS (Legacy UIKit Edition)\nВерсия 1.0\n\nРазработчик оригинала: Ника Фалалеева (@nikanikoo)\nCEO OpenVK: Владимир Баринов (@Veselcraft)\n\nСайт: openvk.org\nЛицензия: AGPL-3.0"];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"О приложении"
                                                            message:aboutMsg
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 1) {
            // Другие (Тестеры и донатеры)
            VKSupportersViewController *supVC = [[VKSupportersViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:supVC animated:YES];
        } else {
            // Лог диагностики и сбоев
            [self showLogsViewer];
        }
    } else if (indexPath.section == 3) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Вы действительно хотите выйти?"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:@"Выйти"
                                                  otherButtonTitles:nil];
        sheet.tag = 601;
        [sheet showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 601 && buttonIndex == actionSheet.destructiveButtonIndex) {
        [[VKAuthService sharedService] logout];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 501 && buttonIndex == 1) {
        [[VKImageLoader sharedLoader] clearCache];
        UIAlertView *done = [[UIAlertView alloc] initWithTitle:@"Готово" message:@"Кэш успешно очищен" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [done show];
    }
}

- (void)showLogsViewer {
    UIViewController *logVC = [[UIViewController alloc] init];
    logVC.title = @"Диагностика и сбои";
    logVC.view.backgroundColor = [UIColor whiteColor];
    
    UITextView *tv = [[UITextView alloc] initWithFrame:logVC.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.editable = NO;
    tv.font = [UIFont fontWithName:@"Courier" size:11] ?: [UIFont systemFontOfSize:11];
    tv.text = [VKCrashLogger readAllLogs];
    [logVC.view addSubview:tv];
    
    [self.navigationController pushViewController:logVC animated:YES];
}

@end
