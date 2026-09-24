#import "VKFeedSettingsViewController.h"
#import "VKAppConfig.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"

@interface VKFeedSettingsViewController ()
@end

@implementation VKFeedSettingsViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Лента";
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад"
                                                                                            target:self
                                                                                            action:@selector(goBackAction)
                                                                                            isBack:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeDidChange)
                                                 name:VKThemeDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)themeDidChange {
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад"
                                                                                            target:self
                                                                                            action:@selector(goBackAction)
                                                                                            isBack:YES];
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        BOOL isEnabled = [VKAppConfig isNSFWFilterEnabled];
        return isEnabled ? 4 : 1;
    } else {
        return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Контент 18+ (NSFW)";
    } else {
        return @"Лента новостей";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Когда фильтр включен, посты и материалы с пометкой 18+ (NSFW) скрываются предупреждающей плашкой. Вы можете открыть содержимое в любой момент.";
    } else {
        return @"Автоматически проверять и подгружать свежие записи при открытии вкладки «Новости».";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            static NSString *SwitchCellId = @"VKFeedNSFWSwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:SwitchCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
                cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
                
                UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
                sw.tag = 1001;
                [sw addTarget:self action:@selector(nsfwFilterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
            }
            
            cell.textLabel.text = @"🔞 Скрывать контент 18+";
            cell.detailTextLabel.text = @"Защита от нежелательного контента";
            
            UISwitch *sw = (UISwitch *)cell.accessoryView;
            sw.on = [VKAppConfig isNSFWFilterEnabled];
            return cell;
        } else {
            static NSString *OptionCellId = @"VKFeedNSFWOptionCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:OptionCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:OptionCellId];
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
                cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
            }
            
            VKNSFWDisplayMode currentMode = [VKAppConfig nsfwDisplayMode];
            if (indexPath.row == 1) {
                cell.textLabel.text = @"Скрывать под плашку";
                cell.detailTextLabel.text = @"Показывает плашку-спойлер с кнопкой «Показать»";
                cell.accessoryType = (currentMode == VKNSFWDisplayModeSpoiler) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Показывать сразу";
                cell.detailTextLabel.text = @"Отображать с пометкой 18+, но без скрытия";
                cell.accessoryType = (currentMode == VKNSFWDisplayModeShowAlways) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"Полностью скрывать из ленты";
                cell.detailTextLabel.text = @"Посты 18+ не будут появляться в новостной ленте";
                cell.accessoryType = (currentMode == VKNSFWDisplayModeHideCompletely) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
            }
            return cell;
        }
    } else {
        static NSString *AutoRefreshCellId = @"VKFeedAutoRefreshCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AutoRefreshCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AutoRefreshCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
            
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.tag = 2001;
            [sw addTarget:self action:@selector(autoRefreshSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        }
        
        cell.textLabel.text = @"Автообновление ленты";
        cell.detailTextLabel.text = @"Проверять новые посты при открытии";
        
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        id val = [[NSUserDefaults standardUserDefaults] objectForKey:@"openvk.feed.auto_refresh"];
        sw.on = (val == nil) ? YES : [val boolValue];
        return cell;
    }
}

#pragma mark - Actions

- (void)nsfwFilterSwitchChanged:(UISwitch *)sender {
    [VKCrashLogger log:@"[VKFeedSettings] NSFW filter switch changed to %d", sender.isOn];
    [VKAppConfig setNSFWFilterEnabled:sender.isOn];
    
    // Перезагружаем секцию с анимацией
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)autoRefreshSwitchChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"openvk.feed.auto_refresh"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row >= 1) {
        VKNSFWDisplayMode mode = VKNSFWDisplayModeSpoiler;
        if (indexPath.row == 1) {
            mode = VKNSFWDisplayModeSpoiler;
        } else if (indexPath.row == 2) {
            mode = VKNSFWDisplayModeShowAlways;
        } else if (indexPath.row == 3) {
            mode = VKNSFWDisplayModeHideCompletely;
        }
        
        [VKAppConfig setNSFWDisplayMode:mode];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    }
}

@end
