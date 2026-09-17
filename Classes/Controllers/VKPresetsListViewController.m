#import "VKPresetsListViewController.h"
#import "VKPresetManager.h"

@interface VKPresetsListViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) NSArray<NSString *> *customPresets;
@property (nonatomic, strong) NSArray<NSString *> *bundledPresets;
@end

@implementation VKPresetsListViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _selectedEngine = 0; // Milkdrop по умолчанию
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Пресеты";
    
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Milkdrop 2", @"Winamp AVS"]];
    self.segmentedControl.selectedSegmentIndex = self.selectedEngine;
    [self.segmentedControl addTarget:self action:@selector(engineChanged:) forControlEvents:UIControlEventValueChanged];
    
    if ([self.segmentedControl respondsToSelector:@selector(setTintColor:)]) {
        self.segmentedControl.tintColor = [UIColor colorWithRed:0.28 green:0.45 blue:0.65 alpha:1.0];
    }
    self.navigationItem.titleView = self.segmentedControl;
    
    UIBarButtonItem *helpBtn = [[UIBarButtonItem alloc] initWithTitle:@"Инфо"
                                                               style:UIBarButtonItemStyleBordered
                                                              target:self
                                                              action:@selector(showHelpAction)];
    self.navigationItem.rightBarButtonItem = helpBtn;
    
    [self reloadDataFromDisk];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(presetsUpdatedNotification:)
                                                 name:VKPresetsDidUpdateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)presetsUpdatedNotification:(NSNotification *)note {
    [self reloadDataFromDisk];
}

- (void)engineChanged:(UISegmentedControl *)sender {
    self.selectedEngine = sender.selectedSegmentIndex;
    [self reloadDataFromDisk];
}

- (void)reloadDataFromDisk {
    if (self.selectedEngine == 0) {
        self.customPresets = [VKPresetManager customMilkdropPresetPaths];
        
        NSArray *all = [VKPresetManager allMilkdropPresetPaths];
        NSMutableArray *bundled = [NSMutableArray array];
        for (NSString *p in all) {
            if (![self.customPresets containsObject:p]) {
                [bundled addObject:p];
            }
        }
        self.bundledPresets = bundled;
    } else {
        self.customPresets = [VKPresetManager customAVSPresetPaths];
        
        NSArray *all = [VKPresetManager allAVSPresetPaths];
        NSMutableArray *bundled = [NSMutableArray array];
        for (NSString *p in all) {
            if (![self.customPresets containsObject:p]) {
                [bundled addObject:p];
            }
        }
        self.bundledPresets = bundled;
    }
    
    [self.tableView reloadData];
}

- (NSString *)formattedFileSizeForPath:(NSString *)path {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    if (!attrs) return @"";
    unsigned long long bytes = [attrs fileSize];
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu B", bytes];
    } else {
        return [NSString stringWithFormat:@"%.1f KB", (double)bytes / 1024.0];
    }
}

- (void)showHelpAction {
    NSString *ext = (self.selectedEngine == 0) ? @"*.milk" : @"*.avs";
    NSString *dirName = (self.selectedEngine == 0) ? @"Presets" : @"AVSPresets";
    NSString *msg = [NSString stringWithFormat:
        @"Добавление пресетов (%@):\n\n"
        @"1. Без джейлбрейка:\n"
        @"Подключите iPhone к компьютеру, откройте iTunes / Finder -> Общий доступ к файлам -> OpenVK и поместите файлы %@ в папку «%@».\n"
        @"Либо скачайте файл в Safari/Telegram и нажмите «Открыть в OpenVK».\n\n"
        @"2. С джейлбрейком:\n"
        @"Скопируйте файлы через Filza в /var/mobile/Media/Presets/ или в Documents приложения.",
        ext, ext, dirName];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Как добавить пресеты"
                                                    message:msg
                                                   delegate:nil
                                          cancelButtonTitle:@"Понятно"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        NSString *engine = (self.selectedEngine == 0) ? @"Milkdrop 2" : @"Winamp AVS";
        return [NSString stringWithFormat:@"Пользовательские пресеты %@ (%lu)", engine, (unsigned long)self.customPresets.count];
    } else if (section == 1) {
        return [NSString stringWithFormat:@"Встроенные пресеты (%lu)", (unsigned long)self.bundledPresets.count];
    } else {
        return @"Инструкция по загрузке";
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return (self.customPresets.count == 0) ? 1 : self.customPresets.count;
    } else if (section == 1) {
        return self.bundledPresets.count;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (self.customPresets.count == 0) {
            static NSString *EmptyCellId = @"EmptyCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EmptyCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:EmptyCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.textLabel.font = [UIFont italicSystemFontOfSize:14];
                cell.textLabel.textColor = [UIColor grayColor];
                cell.textLabel.numberOfLines = 0;
            }
            NSString *folder = (self.selectedEngine == 0) ? @"Documents/Presets" : @"Documents/AVSPresets";
            cell.textLabel.text = [NSString stringWithFormat:@"Нет файлов. Добавьте свои пресеты через iTunes File Sharing в папку «%@» или через «Открыть в OpenVK».", folder];
            cell.detailTextLabel.text = nil;
            return cell;
        } else {
            static NSString *CustomCellId = @"CustomPresetCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CustomCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CustomCellId];
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1.0];
            }
            NSString *fullPath = self.customPresets[indexPath.row];
            cell.textLabel.text = [fullPath lastPathComponent];
            cell.detailTextLabel.text = [self formattedFileSizeForPath:fullPath];
            return cell;
        }
    } else if (indexPath.section == 1) {
        static NSString *BundleCellId = @"BundlePresetCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BundleCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:BundleCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:14];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor lightGrayColor];
        }
        NSString *fullPath = self.bundledPresets[indexPath.row];
        cell.textLabel.text = [fullPath lastPathComponent];
        cell.detailTextLabel.text = @"Встроенный";
        return cell;
    } else {
        static NSString *InfoCellId = @"InfoCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:InfoCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:InfoCellId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
            cell.textLabel.textColor = [UIColor colorWithRed:0.18 green:0.42 blue:0.72 alpha:1.0];
        }
        cell.textLabel.text = @"📖  Подробная справка по пресетам";
        return cell;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && self.customPresets.count > 0) {
        return YES;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 0 && self.customPresets.count > 0) {
        NSString *targetPath = self.customPresets[indexPath.row];
        NSError *err = nil;
        BOOL ok = [VKPresetManager deleteCustomPresetAtPath:targetPath error:&err];
        if (ok) {
            [self reloadDataFromDisk];
        } else {
            NSString *msg = err.localizedDescription ?: @"Не удалось удалить файл";
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                            message:msg
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 2) {
        [self showHelpAction];
    }
}

@end
