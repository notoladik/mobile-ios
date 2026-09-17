#import "VKAppearanceViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKBackgroundVisualizerManager.h"
#import "VKPresetsListViewController.h"

@interface VKAppearanceViewController () <UIActionSheetDelegate>
@end

@implementation VKAppearanceViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Внешний вид";
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
}

- (void)setupNavigationItems {
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)applyThemeStyle {
    [self setupNavigationItems];
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Тема оформления интерфейса";
    } else if (section == 1) {
        return @"Навигация";
    } else if (section == 2) {
        return @"Аудиоплеер";
    } else {
        return @"Фоновая визуализация (Fun)";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"Выбранная тема меняет стиль карточек, навигационной панели, скруглений и цвета элементов.";
    } else if (section == 1) {
        return @"При включении бокового меню кнопка ≡ в навигационной панели открывает выдвижную панель со всеми разделами ВКонтакте.";
    } else if (section == 2) {
        return @"Включение режима визуализатора активирует динамические эффекты и спектроанализатор в плеере. При выключении отображается оригинальная обложка VK.";
    } else {
        return @"Живая визуализация на фоне всего клиента ВКонтакте. Динамически танцует под ритм музыки либо мягко переливается в покое, не мешая нажатиям и прокрутке.";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    if (section == 1) return 1;
    if (section == 2) {
        BOOL visOn = [[NSUserDefaults standardUserDefaults] objectForKey:@"openvk.audio.visualizer.enabled"] ? [[NSUserDefaults standardUserDefaults] boolForKey:@"openvk.audio.visualizer.enabled"] : YES;
        return visOn ? 3 : 1;
    }
    
    if ([[VKBackgroundVisualizerManager sharedManager] isEnabled]) {
        return 5;
    }
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
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
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
        } else if (indexPath.row == 1) {
            static NSString *VisEngineCellId = @"VKVisualizerEngineCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:VisEngineCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:VisEngineCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            }
            cell.textLabel.text = @"Движок визуализатора";
            NSInteger engine = [[NSUserDefaults standardUserDefaults] integerForKey:@"openvk.audio.visualizer.engine"];
            cell.detailTextLabel.text = (engine == 1) ? @"Winamp AVS (2D)" : @"Milkdrop 2 (3D)";
            return cell;
        } else {
            static NSString *VisPresetsCellId = @"VKVisualizerPresetsCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:VisPresetsCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:VisPresetsCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            }
            cell.textLabel.text = @"Управление пресетами";
            cell.detailTextLabel.text = @"Файлы .milk / .avs";
            return cell;
        }
    } else {
        VKBackgroundVisualizerManager *bgMan = [VKBackgroundVisualizerManager sharedManager];
        
        if (indexPath.row == 0) {
            static NSString *BgVisMainSwitchCellId = @"VKBgVisMainSwitchCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BgVisMainSwitchCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BgVisMainSwitchCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
                
                UISwitch *sw = [[UISwitch alloc] init];
                [sw addTarget:self action:@selector(toggleBgVisualizerSwitch:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
            }
            cell.textLabel.text = @"Визуализатор на фоне";
            UISwitch *sw = (UISwitch *)cell.accessoryView;
            sw.on = bgMan.isEnabled;
            return cell;
        } else if (indexPath.row == 1) {
            static NSString *BgVisValueCellId = @"VKBgVisValueCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BgVisValueCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:BgVisValueCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            }
            cell.textLabel.text = @"Стиль визуализации";
            cell.detailTextLabel.text = [bgMan titleForStyle:bgMan.style];
            return cell;
        } else if (indexPath.row == 2) {
            static NSString *BgVisValueCellId = @"VKBgVisValueCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BgVisValueCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:BgVisValueCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            }
            cell.textLabel.text = @"Режим слоя";
            cell.detailTextLabel.text = [bgMan titleForLayerMode:bgMan.layerMode];
            return cell;
        } else if (indexPath.row == 3) {
            static NSString *BgVisValueCellId = @"VKBgVisValueCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BgVisValueCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:BgVisValueCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
            }
            cell.textLabel.text = @"Прозрачность / Яркость";
            cell.detailTextLabel.text = [bgMan titleForOpacity:bgMan.opacity];
            return cell;
        } else {
            static NSString *BgVisOnlyPlayingCellId = @"VKBgVisOnlyPlayingCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BgVisOnlyPlayingCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:BgVisOnlyPlayingCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.font = [UIFont systemFontOfSize:15];
                
                UISwitch *sw = [[UISwitch alloc] init];
                [sw addTarget:self action:@selector(toggleBgVisualizerOnlyPlayingSwitch:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = sw;
            }
            cell.textLabel.text = @"Только при музыке";
            UISwitch *sw = (UISwitch *)cell.accessoryView;
            sw.on = bgMan.onlyWhenPlaying;
            return cell;
        }
    }
}

- (void)toggleSideMenuSwitch:(UISwitch *)sender {
    [[VKSideMenuManager sharedManager] setIsSideMenuEnabled:sender.isOn];
}

- (void)toggleVisualizerSwitch:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"openvk.audio.visualizer.enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleBgVisualizerSwitch:(UISwitch *)sender {
    [[VKBackgroundVisualizerManager sharedManager] setIsEnabled:sender.isOn];
    [self.tableView reloadData];
}

- (void)toggleBgVisualizerOnlyPlayingSwitch:(UISwitch *)sender {
    [[VKBackgroundVisualizerManager sharedManager] setOnlyWhenPlaying:sender.isOn];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        [[VKThemeManager sharedManager] applyTheme:(VKThemeType)indexPath.row];
        [self.tableView reloadData];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 1) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Движок визуализатора в плеере"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"Milkdrop 2 (projectM 3D)", @"Winamp AVS (Nullsoft 2D)", nil];
            sheet.tag = 9004;
            [sheet showInView:self.view];
        } else if (indexPath.row == 2) {
            VKPresetsListViewController *presetsVC = [[VKPresetsListViewController alloc] initWithStyle:UITableViewStyleGrouped];
            NSInteger engine = [[NSUserDefaults standardUserDefaults] integerForKey:@"openvk.audio.visualizer.engine"];
            presetsVC.selectedEngine = engine;
            [self.navigationController pushViewController:presetsVC animated:YES];
        }
    } else if (indexPath.section == 3) {
        if (indexPath.row == 1) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Стиль визуализации"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"⚡  Winamp AVS (2D)", @"🌌  Milkdrop 2 (3D)", @"🌊  Неоновые волны (2D)", @"📊  Ретро-эквалайзер (2D)", @"✨  Северное сияние (2D)", @"🪐  Звёздная пыль (2D)", nil];
            sheet.tag = 9001;
            [sheet showInView:self.view];
        } else if (indexPath.row == 2) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Режим отображения"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"Поверх контента (Наложение)", @"Подложка под контент (Задний план)", nil];
            sheet.tag = 9002;
            [sheet showInView:self.view];
        } else if (indexPath.row == 3) {
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Прозрачность"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:nil
                                                      otherButtonTitles:@"15% (Нежная)", @"25% (Оптимальная)", @"40% (Насыщенная)", @"60% (Яркая)", nil];
            sheet.tag = 9003;
            [sheet showInView:self.view];
        }
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 9004) {
        if (buttonIndex == 0 || buttonIndex == 1) {
            [[NSUserDefaults standardUserDefaults] setInteger:buttonIndex forKey:@"openvk.audio.visualizer.engine"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }
        return;
    }
    
    VKBackgroundVisualizerManager *bgMan = [VKBackgroundVisualizerManager sharedManager];
    if (actionSheet.tag == 9001) {
        if (buttonIndex >= 0 && buttonIndex <= 5) {
            bgMan.style = (VKBackgroundVisualizerStyle)buttonIndex;
            [self.tableView reloadData];
        }
    } else if (actionSheet.tag == 9002) {
        if (buttonIndex == 0) {
            bgMan.layerMode = VKBackgroundVisualizerLayerModeOverlay;
        } else if (buttonIndex == 1) {
            bgMan.layerMode = VKBackgroundVisualizerLayerModeUnderlay;
        }
        [self.tableView reloadData];
    } else if (actionSheet.tag == 9003) {
        CGFloat opacities[4] = { 0.15f, 0.25f, 0.40f, 0.60f };
        if (buttonIndex >= 0 && buttonIndex < 4) {
            bgMan.opacity = opacities[buttonIndex];
            [self.tableView reloadData];
        }
    }
}

@end
