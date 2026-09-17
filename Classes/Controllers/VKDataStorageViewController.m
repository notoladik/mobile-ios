#import "VKDataStorageViewController.h"
#import "VKImageLoader.h"
#import "VKAudioCacheManager.h"
#import "VKCrashLogger.h"
#import "VKThemeManager.h"

static NSString *VKFormatBytes(unsigned long long bytes) {
    if (bytes < 1024) {
        return [NSString stringWithFormat:@"%llu Б", bytes];
    } else if (bytes < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f КБ", bytes / 1024.0];
    } else if (bytes < 1024ULL * 1024ULL * 1024ULL) {
        return [NSString stringWithFormat:@"%.1f МБ", bytes / (1024.0 * 1024.0)];
    } else {
        return [NSString stringWithFormat:@"%.2f ГБ", bytes / (1024.0 * 1024.0 * 1024.0)];
    }
}

@interface VKDataStorageViewController ()
@property (nonatomic, assign) unsigned long long imageSizeBytes;
@property (nonatomic, assign) NSUInteger imageFilesCount;
@property (nonatomic, assign) unsigned long long audioSizeBytes;
@property (nonatomic, assign) NSUInteger audioFilesCount;
@property (nonatomic, assign) unsigned long long logSizeBytes;
@property (nonatomic, assign) BOOL isCalculating;
@end

@implementation VKDataStorageViewController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Данные и память";
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад"
                                                                                            target:self
                                                                                            action:@selector(goBackAction)
                                                                                            isBack:YES];
    
    [self loadStorageSizes];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadStorageSizes {
    self.isCalculating = YES;
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        unsigned long long imgBytes = [[VKImageLoader sharedLoader] diskCacheSizeBytes];
        NSUInteger imgCount = [[VKImageLoader sharedLoader] diskCacheFilesCount];
        
        unsigned long long audioBytes = [[VKAudioCacheManager sharedManager] totalCacheSizeBytes];
        NSUInteger audioCount = [[VKAudioCacheManager sharedManager] allCachedTracks].count;
        
        unsigned long long logBytes = [VKCrashLogger totalLogSizeBytes];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageSizeBytes = imgBytes;
            self.imageFilesCount = imgCount;
            self.audioSizeBytes = audioBytes;
            self.audioFilesCount = audioCount;
            self.logSizeBytes = logBytes;
            self.isCalculating = NO;
            [self.tableView reloadData];
        });
    });
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1; // Экономия трафика
    if (section == 1) return 4; // Статистика (Фото, Аудио, Логи, Всего)
    if (section == 2) return 4; // Очистка (Фото, Аудио, Логи, Всё)
    if (section == 3) return 1; // Лимит кэша
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Экономия трафика";
    if (section == 1) return @"Использование памяти";
    if (section == 2) return @"Очистка данных";
    if (section == 3) return @"Лимит кэша фото";
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return @"При низком качестве загружаются сжатые превью (15–30 КБ), что существенно ускоряет работу при медленном интернете (2G / EDGE). Полноразмерное фото можно загрузить кнопкой [HQ] в просмотрщике.";
    } else if (section == 1) {
        return @"Кэшированные данные ускоряют повторный просмотр контента и экономят трафик.";
    } else if (section == 3) {
        return @"При превышении выбранного лимита старые закэшированные изображения автоматически удаляются с устройства.";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKStorageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    }
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.textLabel.textColor = [UIColor blackColor];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.text = @"";
    
    if (indexPath.section == 0) {
        // Качество фото
        cell.textLabel.text = @"Качество фото в ленте";
        NSInteger pref = [[NSUserDefaults standardUserDefaults] integerForKey:@"VKPhotoQualityPreference"];
        cell.detailTextLabel.text = (pref == 1) ? @"Высокое (оригинал)" : @"Низкое (экономия)";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1) {
        // Статистика
        if (self.isCalculating) {
            cell.detailTextLabel.text = @"Подсчёт...";
        }
        
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"🖼  Кэш изображений";
                if (!self.isCalculating) {
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%lu файлов)", VKFormatBytes(self.imageSizeBytes), (unsigned long)self.imageFilesCount];
                }
                break;
            case 1:
                cell.textLabel.text = @"🎵  Кэш музыки";
                if (!self.isCalculating) {
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ (%lu треков)", VKFormatBytes(self.audioSizeBytes), (unsigned long)self.audioFilesCount];
                }
                break;
            case 2:
                cell.textLabel.text = @"📋  Логи и диагностика";
                if (!self.isCalculating) {
                    cell.detailTextLabel.text = VKFormatBytes(self.logSizeBytes);
                }
                break;
            case 3:
                cell.textLabel.text = @"💾  Всего занято";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
                if (!self.isCalculating) {
                    unsigned long long total = self.imageSizeBytes + self.audioSizeBytes + self.logSizeBytes;
                    cell.detailTextLabel.text = VKFormatBytes(total);
                    cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:14];
                }
                break;
        }
    } else if (indexPath.section == 2) {
        // Действия очистки
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"Очистить кэш фото";
                break;
            case 1:
                cell.textLabel.text = @"Очистить сохранённую музыку";
                break;
            case 2:
                cell.textLabel.text = @"Очистить логи диагностики";
                break;
            case 3:
                cell.textLabel.text = @"Очистить весь кэш";
                cell.textLabel.textColor = [UIColor redColor];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.accessoryType = UITableViewCellAccessoryNone;
                break;
        }
    } else if (indexPath.section == 3) {
        // Лимит кэша
        cell.textLabel.text = @"Максимальный размер";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        unsigned long long maxB = [[VKImageLoader sharedLoader] maxDiskCacheBytes];
        if (maxB == 100ULL * 1024ULL * 1024ULL) {
            cell.detailTextLabel.text = @"100 МБ";
        } else if (maxB == 250ULL * 1024ULL * 1024ULL) {
            cell.detailTextLabel.text = @"250 МБ";
        } else if (maxB == 500ULL * 1024ULL * 1024ULL) {
            cell.detailTextLabel.text = @"500 МБ";
        } else if (maxB == 1024ULL * 1024ULL * 1024ULL) {
            cell.detailTextLabel.text = @"1 ГБ";
        } else {
            cell.detailTextLabel.text = @"Без лимита";
        }
    }
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        // Выбор качества фото
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Качество фото в ленте и комментариях"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Низкое (экономия трафика, ~25 КБ)", @"Высокое (оригинал, до 2 МБ)", nil];
        sheet.tag = 100;
        [sheet showInView:self.view];
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            // Очистить кэш фото
            [[VKImageLoader sharedLoader] clearCache];
            [self loadStorageSizes];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Успешно"
                                                            message:@"Кэш изображений очищен."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 1) {
            // Очистить кэш музыки
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Удалить все сохранённые аудиозаписи?"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:@"Удалить треки"
                                                      otherButtonTitles:nil];
            sheet.tag = 200;
            [sheet showInView:self.view];
        } else if (indexPath.row == 2) {
            // Очистить логи
            [VKCrashLogger clearAllLogs];
            [self loadStorageSizes];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Успешно"
                                                            message:@"Логи диагностики очищены."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else if (indexPath.row == 3) {
            // Очистить всё
            UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Очистить все кэшированные файлы (фото, музыку и логи)?"
                                                               delegate:self
                                                      cancelButtonTitle:@"Отмена"
                                                 destructiveButtonTitle:@"Очистить всё"
                                                      otherButtonTitles:nil];
            sheet.tag = 300;
            [sheet showInView:self.view];
        }
    } else if (indexPath.section == 3) {
        // Выбор лимита дискового кэша
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Максимальный размер дискового кэша фото"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"100 МБ", @"250 МБ", @"500 МБ", @"1 ГБ", @"Без ограничений", nil];
        sheet.tag = 400;
        [sheet showInView:self.view];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 100) {
        // Качество фото
        if (buttonIndex == 0) {
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"VKPhotoQualityPreference"];
        } else if (buttonIndex == 1) {
            [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"VKPhotoQualityPreference"];
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    } else if (actionSheet.tag == 200 && buttonIndex == actionSheet.destructiveButtonIndex) {
        // Удалить музыку
        [[VKAudioCacheManager sharedManager] clearAllCache];
        [self loadStorageSizes];
    } else if (actionSheet.tag == 300 && buttonIndex == actionSheet.destructiveButtonIndex) {
        // Очистить всё
        [[VKImageLoader sharedLoader] clearCache];
        [[VKAudioCacheManager sharedManager] clearAllCache];
        [VKCrashLogger clearAllLogs];
        [self loadStorageSizes];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Успешно"
                                                        message:@"Все кэшированные данные удалены."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    } else if (actionSheet.tag == 400) {
        unsigned long long limit = 250ULL * 1024ULL * 1024ULL;
        if (buttonIndex == 0) limit = 100ULL * 1024ULL * 1024ULL;
        else if (buttonIndex == 1) limit = 250ULL * 1024ULL * 1024ULL;
        else if (buttonIndex == 2) limit = 500ULL * 1024ULL * 1024ULL;
        else if (buttonIndex == 3) limit = 1024ULL * 1024ULL * 1024ULL;
        else if (buttonIndex == 4) limit = 10ULL * 1024ULL * 1024ULL * 1024ULL; // 10 GB
        
        [VKImageLoader sharedLoader].maxDiskCacheBytes = limit;
        [[NSUserDefaults standardUserDefaults] setDouble:(double)limit forKey:@"VKMaxDiskCacheBytes"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    }
}

@end
