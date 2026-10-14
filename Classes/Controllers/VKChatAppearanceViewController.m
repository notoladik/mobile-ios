#import "VKChatAppearanceViewController.h"
#import "VKChatAppearance.h"
#import "VKThemeManager.h"
#import "VKAudioPlayer.h"

#import "VKPresetsListViewController.h"
#import "VKBackgroundVisualizerManager.h"

@interface VKChatAppearanceViewController ()
@property (nonatomic, assign) NSInteger peerId;
@property (nonatomic, strong) NSTimer *diagnosticTimer;
@end

@implementation VKChatAppearanceViewController
- (instancetype)initWithPeerId:(NSInteger)peerId {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) _peerId = peerId;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.peerId == 0 ? @"Обои чатов" : @"Обои этого чата";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAppearance) name:VKChatAppearanceDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAppearance) name:VKThemeDidChangeNotification object:nil];
    [self reloadAppearance];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadAppearance];
    self.diagnosticTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refreshDiagnostics) userInfo:nil repeats:YES];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.diagnosticTimer invalidate];
    self.diagnosticTimer = nil;
}
- (void)dealloc {
    [self.diagnosticTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)goBack {
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)reloadAppearance {
    VKThemeManager *tm = [VKThemeManager sharedManager];
    self.view.backgroundColor = tm.backgroundColor;
    self.tableView.backgroundColor = tm.backgroundColor;
    self.navigationItem.leftBarButtonItem = [tm barButtonItemWithTitle:@"Назад" target:self action:@selector(goBack) isBack:YES];
    [self.tableView reloadData];
}
- (void)refreshDiagnostics {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:2]];
    cell.detailTextLabel.text = [[VKAudioPlayer sharedPlayer] pcmDiagnosticText];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 4 : (section == 1 ? 3 : (section == 2 ? 3 : 3));
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return @[@"ФОН", @"ВИЗУАЛИЗАЦИЯ", @"ПАРАМЕТРЫ", @"ФОТО И СБРОС"][section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return self.peerId == 0 ? @"Общий фон для чатов без собственного оформления. Не зависит от режима Kate или темы интерфейса." : @"Настройка сохраняется только для этого диалога и текущего аккаунта на этом сервере. «Как у всех чатов» возвращает общий фон.";
    if (section == 1) return @"Настоящие движки Winamp AVS и Milkdrop 2 на OpenGL ES под сообщениями. Анимация реагирует на PCM-звук в реальном времени и останавливается при выходе из чата.";
    if (section == 2) return @"PCM поступает от встроенного музыкального плеера, не от микрофона или других приложений. Для некоторых потоковых форматов AVPlayer не предоставляет audio tap.";
    return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)p {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"chatAppearance"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"chatAppearance"];
    VKThemeManager *tm = [VKThemeManager sharedManager];
    cell.backgroundColor = tm.cardBackgroundColor;
    cell.textLabel.textColor = (tm.isDarkTheme ? [UIColor whiteColor] : [UIColor colorWithWhite:0.12 alpha:1]);
    cell.textLabel.font = [UIFont systemFontOfSize:15];
    cell.detailTextLabel.textColor = tm.secondaryTextColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
    cell.detailTextLabel.numberOfLines = 2;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    NSDictionary *s = [VKChatAppearance settingsForPeerId:self.peerId];
    if (p.section == 0) {
        cell.textLabel.text = @[(self.peerId == 0 ? @"Фон темы" : @"Как у всех чатов"), @"Без обоев", @"Фотография", @"Визуализация музыки"][p.row];
        if ([s[@"mode"] integerValue] == p.row) cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else if (p.section == 1) {
        if (p.row == 0) {
            cell.textLabel.text = @"⚡  Winamp AVS (2D)";
            if ([s[@"style"] integerValue] == VKBackgroundVisualizerStyleAVS) cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else if (p.row == 1) {
            cell.textLabel.text = @"🌌  Milkdrop 2 (3D)";
            if ([s[@"style"] integerValue] == VKBackgroundVisualizerStyleMilkdrop) cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.textLabel.text = @"Управление пресетами";
            cell.detailTextLabel.text = @"Файлы .milk / .avs";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (p.section == 2) {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (p.row == 0) {
            cell.textLabel.text = @"Яркость";
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 130, 30)];
            slider.minimumValue = 0.05; slider.maximumValue = 0.6;
            slider.value = [s[@"opacity"] floatValue];
            [slider addTarget:self action:@selector(opacityChanged:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
            cell.accessoryView = slider;
        } else if (p.row == 1) {
            cell.textLabel.text = @"Только при музыке";
            UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
            sw.on = [s[@"onlyPlaying"] boolValue];
            [sw addTarget:self action:@selector(onlyPlayingChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
        } else {
            cell.textLabel.text = @"Аудиосигнал";
            cell.detailTextLabel.text = [[VKAudioPlayer sharedPlayer] pcmDiagnosticText];
        }
    } else {
        cell.textLabel.text = @[@"Выбрать фотографию", @"Удалить фотографию", @"Сбросить оформление"][p.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)p { return p.section == 2 && p.row == 2 ? 66 : 44; }
- (void)opacityChanged:(UISlider *)slider { [VKChatAppearance setValue:@(slider.value) forSetting:@"opacity" peerId:self.peerId]; }
- (void)onlyPlayingChanged:(UISwitch *)sw { [VKChatAppearance setValue:@(sw.on) forSetting:@"onlyPlaying" peerId:self.peerId]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)p {
    [tableView deselectRowAtIndexPath:p animated:YES];
    if (p.section == 0) {
        if (p.row == VKChatBackgroundModePhoto && ![VKChatAppearance hasOwnWallpaperForPeerId:self.peerId]) [self choosePhoto];
        else {
            [VKChatAppearance setValue:@(p.row) forSetting:@"mode" peerId:self.peerId];
            [self.tableView reloadData];
        }
    } else if (p.section == 1) {
        if (p.row == 0) {
            [VKChatAppearance setValue:@(VKBackgroundVisualizerStyleAVS) forSetting:@"style" peerId:self.peerId];
            [VKChatAppearance setValue:@(VKChatBackgroundModeVisualizer) forSetting:@"mode" peerId:self.peerId];
            [self.tableView reloadData];
        } else if (p.row == 1) {
            [VKChatAppearance setValue:@(VKBackgroundVisualizerStyleMilkdrop) forSetting:@"style" peerId:self.peerId];
            [VKChatAppearance setValue:@(VKChatBackgroundModeVisualizer) forSetting:@"mode" peerId:self.peerId];
            [self.tableView reloadData];
        } else {
            NSDictionary *s = [VKChatAppearance settingsForPeerId:self.peerId];
            VKPresetsListViewController *presetsVC = [[VKPresetsListViewController alloc] init];
            NSInteger currentStyle = [s[@"style"] integerValue];
            presetsVC.selectedEngine = (currentStyle == VKBackgroundVisualizerStyleAVS) ? 1 : 0;
            [self.navigationController pushViewController:presetsVC animated:YES];
        }
    } else if (p.section == 3) {
        if (p.row == 0) [self choosePhoto];
        else if (p.row == 1) [VKChatAppearance removeWallpaperForPeerId:self.peerId];
        else [VKChatAppearance resetPeerId:self.peerId];
    }
}
- (void)choosePhoto {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        NSError *error = nil;
        if (![VKChatAppearance saveWallpaper:image peerId:self.peerId error:&error]) {
            [[[UIAlertView alloc] initWithTitle:@"Не удалось сохранить обои" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
        }
    }];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [picker dismissViewControllerAnimated:YES completion:nil]; }
@end
