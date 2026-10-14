#import "VKKateSettingsViewController.h"
#import "VKKateSettings.h"
#import "VKKateTheme.h"
#import "VKThemeManager.h"
#import "VKAppConfig.h"
#import "VKAuthService.h"
#import "VKAPIClient.h"
#import "VKChatAppearanceViewController.h"

@interface VKKateSettingsViewController () <UIActionSheetDelegate>
@end

@implementation VKKateSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"🐱 Kate Mobile";
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSettingsChanged) name:VKKateSettingsDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onThemeChanged) name:VKThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)onSettingsChanged {
    [self.tableView reloadData];
}

- (void)onThemeChanged {
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4; // 0: Оформление, 1: Приватность, 2: Инстанс, 3: Скрыть секретный режим
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 5; // Режим Kate, Тема оформления, Меню разделов профиля, Облачка сообщений, Обои диалогов
    if (section == 1) return 3; // Невидимка, Нечиталка, Неписалка
    if (section == 2) return 2; // Текущий инстанс, Проверить статус
    return 1;                   // Заблокировать секретный режим
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"ОФОРМЛЕНИЕ В СТИЛЕ KATE";
    if (section == 1) return @"ПРИВАТНОСТЬ И ИНКОГНИТО";
    if (section == 2) return @"ИНСТАНС И СЕТЬ";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"13 аутентичных тем Kate Mobile (Индиго, Индиго тёмная, Чёрная, Holo, Металл, Кофе, Розовая и др.), меню профиля и облачка сообщений.";
    } else if (section == 1) {
        return @"«Невидимка» отправляет account.setOffline и блокирует пинги онлайна.\n«Нечиталка» оставляет сообщения непрочитанными при входе в диалог до явного ответа.";
    } else if (section == 2) {
        return @"Параметры текущего подключенного сервера OpenVK.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKKateSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    }
    
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"🐱 Режим оформления Kate Mobile";
            cell.detailTextLabel.text = @"Активировать верхние вкладки, Action Bar и стиль Kate";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = ([[VKThemeManager sharedManager] currentTheme] == VKThemeTypeKateMobile);
            [sw addTarget:self action:@selector(toggleKateThemeSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"🎨 Тема оформления (13 тем)";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"Текущая: %@", [[VKKateTheme currentTheme] name]];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"📋 Меню разделов во вкладке профиля";
            cell.detailTextLabel.text = @"Показывать список (Друзья, Стена, Музыка) вместо полного профиля";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = [VKKateSettings isProfileHubModeEnabled];
            [sw addTarget:self action:@selector(toggleProfileHubSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"💬 Прямоугольные облачка сообщений";
            cell.detailTextLabel.text = @"Стиль пузырей my_message_item из Kate Mobile";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = [VKKateSettings isKateBubblesEnabled];
            [sw addTarget:self action:@selector(toggleKateBubblesSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"🖼 Обои в диалогах";
            cell.detailTextLabel.text = @"Установить фоновое изображение для чатов";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"🕶 По возможности быть оффлайн (Невидимка)";
            cell.detailTextLabel.text = @"Всегда отправлять account.setOffline и не светить онлайн";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = [VKKateSettings isOfflineModeEnabled];
            [sw addTarget:self action:@selector(toggleOfflineSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"👁 Закрыть непрочитанным (Нечиталка)";
            cell.detailTextLabel.text = @"Не помечать диалоги прочитанными при открытии";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = [VKKateSettings isCloseUnreadEnabled];
            [sw addTarget:self action:@selector(toggleCloseUnreadSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"⌨️ Статус набора текста";
            cell.detailTextLabel.text = @"Отправлять собеседнику, что я набираю текст";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = ![VKKateSettings isTypingStatusHidden];
            [sw addTarget:self action:@selector(toggleTypingSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"🌐 Подключенный инстанс";
            cell.detailTextLabel.text = [VKAppConfig currentHost];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text = @"📡 Проверить онлайн на сервере";
            cell.detailTextLabel.text = @"Запросить текущий статус account.getInfo";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        }
    } else {
        cell.textLabel.text = @"🔒 Заблокировать секретный режим";
        cell.textLabel.textColor = [UIColor redColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.detailTextLabel.text = nil;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    
    return cell;
}

#pragma mark - Switch Actions

- (void)toggleKateThemeSwitch:(UISwitch *)sw {
    if (sw.isOn) {
        [[VKThemeManager sharedManager] applyTheme:VKThemeTypeKateMobile];
    } else {
        [[VKThemeManager sharedManager] applyTheme:VKThemeTypeClassicUIKit];
    }
}

- (void)toggleProfileHubSwitch:(UISwitch *)sw {
    [VKKateSettings setProfileHubModeEnabled:sw.isOn];
}

- (void)toggleKateBubblesSwitch:(UISwitch *)sw {
    [VKKateSettings setKateBubblesEnabled:sw.isOn];
}

- (void)toggleOfflineSwitch:(UISwitch *)sw {
    [VKKateSettings setOfflineModeEnabled:sw.isOn];
}

- (void)toggleCloseUnreadSwitch:(UISwitch *)sw {
    [VKKateSettings setCloseUnreadEnabled:sw.isOn];
}

- (void)toggleTypingSwitch:(UISwitch *)sw {
    [VKKateSettings setTypingStatusHidden:!sw.isOn];
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showKateThemePicker];
        return;
    } else if (indexPath.section == 0 && indexPath.row == 4) {
        [self.navigationController pushViewController:[[VKChatAppearanceViewController alloc] initWithPeerId:0] animated:YES];
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        // Проверить онлайн на сервере
        [[VKAPIClient sharedClient] callMethod:@"account.getInfo" parameters:@{} completionHandler:^(id response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Ошибка запроса"
                                                                       message:[error localizedDescription]
                                                                      delegate:nil
                                                             cancelButtonTitle:@"OK"
                                                             otherButtonTitles:nil];
                    [errAlert show];
                } else {
                    BOOL offlineActive = [VKKateSettings isOfflineModeEnabled];
                    NSString *msg = [NSString stringWithFormat:@"Инстанс: %@\nНевидимка в клиенте: %@\nСервер успешно ответил на запрос.", [VKAppConfig currentHost], (offlineActive ? @"ВКЛЮЧЕНА (Оффлайн)" : @"ВЫКЛЮЧЕНА")];
                    UIAlertView *okAlert = [[UIAlertView alloc] initWithTitle:@"Статус аккаунта"
                                                                      message:msg
                                                                     delegate:nil
                                                            cancelButtonTitle:@"Понятно"
                                                            otherButtonTitles:nil];
                    [okAlert show];
                }
            });
        }];
    } else if (indexPath.section == 3) {
        // Заблокировать секретный режим
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Скрыть секретный режим Kate Mobile из меню?"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:@"Скрыть секрет"
                                                  otherButtonTitles:nil];
        sheet.tag = 1002;
        [sheet showInView:self.view];
    }
}

- (void)showKateThemePicker {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Тема оформления Kate Mobile"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    sheet.tag = 888;
    NSArray *themeIds = [VKKateTheme allThemeIds];
    for (NSNumber *tid in themeIds) {
        NSString *name = [VKKateTheme nameForThemeId:(VKKateThemeId)[tid integerValue]];
        if ([tid integerValue] == [VKKateTheme currentThemeId]) {
            [sheet addButtonWithTitle:[NSString stringWithFormat:@"✓ %@", name]];
        } else {
            [sheet addButtonWithTitle:name];
        }
    }
    [sheet addButtonWithTitle:@"Отмена"];
    sheet.cancelButtonIndex = themeIds.count;
    [sheet showInView:self.view];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 888) {
        NSArray *themeIds = [VKKateTheme allThemeIds];
        if (buttonIndex < themeIds.count) {
            VKKateThemeId chosen = (VKKateThemeId)[themeIds[buttonIndex] integerValue];
            [VKKateTheme setCurrentThemeId:chosen];
            if ([[VKThemeManager sharedManager] currentTheme] == VKThemeTypeKateMobile) {
                [[VKThemeManager sharedManager] applyTheme:VKThemeTypeKateMobile];
            }
            [self.tableView reloadData];
        }
        return;
    }
    if (actionSheet.tag == 1002) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [VKKateSettings setUnlocked:NO];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
}


@end
