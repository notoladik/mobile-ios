#import "VKAppearanceViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"

@implementation VKAppearanceViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Внешний вид";
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Тема оформления интерфейса";
    } else if (section == 1) {
        return @"Навигация";
    } else {
        return @"Аудиоплеер";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Выбранная тема меняет стиль карточек, навигационной панели, скруглений и цвета элементов.";
    } else if (section == 1) {
        return @"При включении бокового меню кнопка ≡ в навигационной панели открывает выдвижную панель со всеми разделами ВКонтакте.";
    } else {
        return @"Включение режима визуализатора активирует динамические эффекты и спектроанализатор в плеере. При выключении отображается оригинальная обложка VK.";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        static NSString *CellId = @"VKAppearanceThemeCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        }
        
        VKThemeType current = [[VKThemeManager sharedManager] currentTheme];
        cell.accessoryType = (current == indexPath.row) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        
        cell.textLabel.text = [[VKThemeManager sharedManager] nameForTheme:(VKThemeType)indexPath.row];
        cell.detailTextLabel.text = [[VKThemeManager sharedManager] eraDescriptionForTheme:(VKThemeType)indexPath.row];
        cell.detailTextLabel.numberOfLines = 2;
        return cell;
    } else if (indexPath.section == 1) {
        static NSString *SwitchCellId = @"VKAppearanceSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SwitchCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:SwitchCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            
            UISwitch *sideSwitch = [[UISwitch alloc] init];
            [sideSwitch addTarget:self action:@selector(toggleSideMenuSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sideSwitch;
        }
        
        cell.textLabel.text = @"Боковое меню (Side Drawer)";
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.on = [[VKSideMenuManager sharedManager] isSideMenuEnabled];
        return cell;
    } else {
        static NSString *VisSwitchCellId = @"VKVisualizerSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:VisSwitchCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:VisSwitchCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            
            UISwitch *visSwitch = [[UISwitch alloc] init];
            [visSwitch addTarget:self action:@selector(toggleVisualizerSwitch:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = visSwitch;
        }
        
        cell.textLabel.text = @"Визуализация в плеере";
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.on = [[NSUserDefaults standardUserDefaults] objectForKey:@"openvk.audio.visualizer.enabled"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"openvk.audio.visualizer.enabled"] : YES;
        return cell;
    }
}

- (void)toggleSideMenuSwitch:(UISwitch *)sender {
    [[VKSideMenuManager sharedManager] setIsSideMenuEnabled:sender.isOn];
}

- (void)toggleVisualizerSwitch:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"openvk.audio.visualizer.enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [[VKThemeManager sharedManager] applyTheme:(VKThemeType)indexPath.row];
        [self.tableView reloadData];
    }
}

@end
