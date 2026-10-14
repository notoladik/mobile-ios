#import "VKClientDesignSettingsViewController.h"
#import "VKClientDesign.h"
#import "VKKateTheme.h"
#import "VKChatAppearanceViewController.h"

@interface VKClientDesignSettingsViewController ()
@property (nonatomic, assign) VKThemeType designTheme;
@end

@implementation VKClientDesignSettingsViewController
- (instancetype)initWithTheme:(VKThemeType)theme {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) _designTheme = theme;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.designTheme == VKThemeTypeKateMobile ? @"Настройки Kate Mobile" : @"Настройки Android";
    self.tableView.rowHeight = 54.0;
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBack) isBack:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDesign) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDesign) name:VKClientDesignDidChangeNotification object:nil];
    [self refreshDesign];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)goBack { [self.navigationController popViewControllerAnimated:YES]; }
- (void)refreshDesign {
    self.tableView.backgroundColor = [VKThemeManager sharedManager].backgroundColor;
    self.tableView.separatorColor = [VKThemeManager sharedManager].separatorColor;
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBack) isBack:YES];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.designTheme == VKThemeTypeKateMobile ? 2 : 1;
    if (section == 1) return 4;
    if (section == 2) return self.designTheme == VKThemeTypeKateMobile ? 2 : 0;
    return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Оформление";
    if (section == 1) return @"Сообщения";
    if (section == 2 && self.designTheme == VKThemeTypeKateMobile) return @"Главный экран";
    return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"Размер текста применяется к сообщениям. Обои и визуализация общие для всех дизайнов; отдельный фон диалога выбирается в самом чате.";
    if (section == 2 && self.designTheme == VKThemeTypeKateMobile) return @"Стартовая вкладка выбирается при следующем открытии главного экрана. Настройки оформления не включают невидимку или другие функции аккаунта.";
    return nil;
}
- (NSString *)optionAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == (self.designTheme == VKThemeTypeKateMobile ? 1 : 0)) return VKClientRoundAvatarsOption;
    if (indexPath.section == 1 && indexPath.row == 0) return VKClientChatAvatarsOption;
    if (indexPath.section == 1 && indexPath.row == 1) return VKClientTwoLinePreviewsOption;
    if (indexPath.section == 2 && indexPath.row == 1) return VKClientProfileMenuOption;
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DesignSetting"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"DesignSetting"];
    VKThemeManager *tm = [VKThemeManager sharedManager];
    cell.backgroundColor = tm.cardBackgroundColor;
    cell.textLabel.textColor = tm.primaryTextColor;
    cell.detailTextLabel.textColor = tm.secondaryTextColor;
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    NSString *option = [self optionAtIndexPath:indexPath];
    if (option) {
        if ([option isEqualToString:VKClientRoundAvatarsOption]) cell.textLabel.text = @"Круглые аватары";
        if ([option isEqualToString:VKClientChatAvatarsOption]) cell.textLabel.text = @"Аватары в чате";
        if ([option isEqualToString:VKClientTwoLinePreviewsOption]) cell.textLabel.text = @"Превью диалогов в две строки";
        if ([option isEqualToString:VKClientProfileMenuOption]) {
            cell.textLabel.text = @"Профиль как меню разделов";
            cell.detailTextLabel.text = @"Вместо полной страницы своего профиля";
        }
        UISwitch *sw = [[UISwitch alloc] init];
        sw.on = [VKClientDesign boolForOption:option theme:self.designTheme];
        sw.accessibilityLabel = cell.textLabel.text;
        sw.tag = indexPath.section * 10 + indexPath.row;
        [sw addTarget:self action:@selector(toggleOption:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"Цветовая палитра";
        cell.detailTextLabel.text = [VKKateTheme currentTheme].name;
    } else if (indexPath.section == 1 && indexPath.row == 2) {
        cell.textLabel.text = @"Размер текста сообщений";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f pt", [VKClientDesign messageFontSizeForTheme:self.designTheme]];
    } else if (indexPath.section == 1 && indexPath.row == 3) {
        cell.textLabel.text = @"Обои и визуализация";
        cell.detailTextLabel.text = @"Общий фон и фон отдельных диалогов";
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Стартовая вкладка";
        cell.detailTextLabel.text = @[@"Профиль", @"Новости", @"Сообщения"][[VKClientDesign firstTab]];
    } else {
        cell.textLabel.text = @"Сбросить настройки этой темы";
        cell.detailTextLabel.text = @"Не удаляет сообщения, аккаунт или обои";
    }
    return cell;
}
- (void)toggleOption:(UISwitch *)sender {
    NSIndexPath *ip = [NSIndexPath indexPathForRow:sender.tag % 10 inSection:sender.tag / 10];
    NSString *option = [self optionAtIndexPath:ip];
    if (option) [VKClientDesign setBool:sender.on forOption:option theme:self.designTheme];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([self optionAtIndexPath:indexPath]) return;
    if (indexPath.section == 1 && indexPath.row == 3) {
        [self.navigationController pushViewController:[[VKChatAppearanceViewController alloc] initWithPeerId:0] animated:YES];
        return;
    }
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    if (indexPath.section == 0) {
        sheet.title = @"Палитра Kate Mobile";
        sheet.tag = 8100;
        for (NSNumber *n in [VKKateTheme allThemeIds]) [sheet addButtonWithTitle:[VKKateTheme nameForThemeId:n.integerValue]];
    } else if (indexPath.section == 1) {
        sheet.title = @"Размер текста сообщений";
        sheet.tag = 8101;
        for (NSNumber *n in @[@13, @15, @17, @19]) [sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ pt", n]];
    } else if (indexPath.section == 2) {
        sheet.title = @"Стартовая вкладка";
        sheet.tag = 8102;
        for (NSString *name in @[@"Профиль", @"Новости", @"Сообщения"]) [sheet addButtonWithTitle:name];
    } else {
        sheet.title = @"Сбросить только оформление этой темы?";
        sheet.tag = 8103;
        sheet.destructiveButtonIndex = [sheet addButtonWithTitle:@"Сбросить"];
    }
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index < 0 || index == sheet.cancelButtonIndex) return;
    if (sheet.tag == 8100 && index < (NSInteger)[VKKateTheme allThemeIds].count) {
        [VKKateTheme setCurrentThemeId:[[VKKateTheme allThemeIds][index] integerValue]];
    } else if (sheet.tag == 8101 && index < 4) {
        [VKClientDesign setMessageFontSize:[@[@13, @15, @17, @19][index] doubleValue] theme:self.designTheme];
    } else if (sheet.tag == 8102 && index < 3) {
        [VKClientDesign setFirstTab:index];
    } else if (sheet.tag == 8103 && index == sheet.destructiveButtonIndex) {
        [VKClientDesign resetTheme:self.designTheme];
        if (self.designTheme == VKThemeTypeKateMobile) [VKKateTheme setCurrentThemeId:VKKateThemeIndigo];
    }
}
@end
