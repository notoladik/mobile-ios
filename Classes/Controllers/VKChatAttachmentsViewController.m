#import "VKChatAttachmentsViewController.h"
#import "VKMessagesService.h"
#import "VKAttachment.h"
#import "VKUser.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKProfileViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface VKChatAttachmentItem : NSObject
@property (nonatomic, assign) NSInteger messageId;
@property (nonatomic, assign) NSInteger fromId;
@property (nonatomic, strong) VKAttachment *attachment;
@property (nonatomic, strong) VKUser *author;
@property (nonatomic, copy) NSString *dateString;
@end

@implementation VKChatAttachmentItem
@end

@interface VKChatAttachmentsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@property (nonatomic, strong) NSMutableArray<VKChatAttachmentItem *> *items;
@property (nonatomic, copy) NSString *nextFrom;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL canLoadMore;

@end

@implementation VKChatAttachmentsViewController

- (instancetype)initWithPeerId:(NSInteger)peerId chatTitle:(NSString *)chatTitle {
    self = [super init];
    if (self) {
        _peerId = peerId;
        _chatTitle = [chatTitle copy];
        _items = [NSMutableArray array];
        _canLoadMore = YES;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Вложения";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад"
                                                                                            target:self
                                                                                            action:@selector(goBackAction)
                                                                                            isBack:YES];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    // 1. Сегмент-контроллер выбора типа медиа
    UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44.0)];
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBar.backgroundColor = [[VKThemeManager sharedManager] isSkeuomorphic] ?
        [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0] :
        [UIColor colorWithRed:246.0/255.0 green:247.0/255.0 blue:249.0/255.0 alpha:1.0];
    
    NSArray *segments = @[@"Фото", @"Видео", @"Аудио", @"Документы", @"Ссылки"];
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:segments];
    self.segmentedControl.frame = CGRectMake(8, 7, width - 16, 30);
    self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.segmentedControl.selectedSegmentIndex = 0;
    [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    
    if (![[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.segmentedControl.tintColor = [[VKThemeManager sharedManager] accentColor];
    }
    [topBar addSubview:self.segmentedControl];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 43.5, width, 0.5)];
    sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    sep.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:222.0/255.0 alpha:1.0];
    [topBar addSubview:sep];
    
    [self.view addSubview:topBar];
    
    // 2. Таблица вложений
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44.0, width, height - 44.0) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 72.0;
    
    if (NSClassFromString(@"UIRefreshControl")) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(refreshAttachments) forControlEvents:UIControlEventValueChanged];
        [self.tableView addSubview:self.refreshControl];
    }
    
    [self.view addSubview:self.tableView];
    
    // 3. Индикатор загрузки
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(width / 2.0, (height - 44.0) / 2.0 + 44.0);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    // 4. Плейсхолдер пустого списка
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, width - 40, 60)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = [UIColor grayColor];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    
    [self loadAttachmentsReset:YES];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    if (![[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.segmentedControl.tintColor = [[VKThemeManager sharedManager] accentColor];
    }
    [self.tableView reloadData];
}

- (NSString *)currentMediaType {
    switch (self.segmentedControl.selectedSegmentIndex) {
        case 0: return @"photo";
        case 1: return @"video";
        case 2: return @"audio";
        case 3: return @"doc";
        case 4: return @"link";
        default: return @"photo";
    }
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    [self.items removeAllObjects];
    [self.tableView reloadData];
    self.nextFrom = nil;
    self.canLoadMore = YES;
    [self loadAttachmentsReset:YES];
}

- (void)refreshAttachments {
    self.nextFrom = nil;
    self.canLoadMore = YES;
    [self loadAttachmentsReset:NO];
}

- (void)loadAttachmentsReset:(BOOL)reset {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    if (reset && self.items.count == 0) {
        [self.spinner startAnimating];
    }
    self.emptyLabel.hidden = YES;
    
    NSString *mediaType = [self currentMediaType];
    NSString *startFrom = reset ? nil : self.nextFrom;
    
    __weak typeof(self) weakSelf = self;
    [[VKMessagesService sharedService] getHistoryAttachmentsForPeerId:self.peerId
                                                            mediaType:mediaType
                                                            startFrom:startFrom
                                                                count:30
                                                           completion:^(NSArray *rawItems, NSString *nextFrom, NSDictionary<NSNumber *,VKUser *> *profiles, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isLoading = NO;
            [strongSelf.spinner stopAnimating];
            if ([strongSelf.refreshControl isRefreshing]) {
                [strongSelf.refreshControl endRefreshing];
            }
            
            if (error) {
                if (strongSelf.items.count == 0) {
                    strongSelf.emptyLabel.text = [NSString stringWithFormat:@"Не удалось загрузить вложения\n%@", error.localizedDescription];
                    strongSelf.emptyLabel.hidden = NO;
                }
                return;
            }
            
            if (reset) {
                [strongSelf.items removeAllObjects];
            }
            
            strongSelf.nextFrom = nextFrom;
            strongSelf.canLoadMore = (nextFrom.length > 0 && rawItems.count > 0);
            
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            [df setDateFormat:@"d MMM, HH:mm"];
            
            for (NSDictionary *rawItem in rawItems) {
                if (![rawItem isKindOfClass:[NSDictionary class]]) continue;
                
                NSDictionary *attDict = rawItem[@"attachment"];
                if (![attDict isKindOfClass:[NSDictionary class]]) continue;
                
                VKAttachment *att = [VKAttachment attachmentFromDictionary:attDict];
                if (!att) continue;
                
                VKChatAttachmentItem *item = [[VKChatAttachmentItem alloc] init];
                item.messageId = [rawItem[@"message_id"] integerValue];
                item.fromId = [rawItem[@"from_id"] integerValue];
                item.attachment = att;
                
                // Автор вложения
                if (item.fromId != 0 && profiles[@(item.fromId)]) {
                    item.author = profiles[@(item.fromId)];
                }
                
                // Дата сообщения
                NSTimeInterval ts = [rawItem[@"date"] doubleValue];
                if (ts > 0) {
                    item.dateString = [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:ts]];
                }
                
                [strongSelf.items addObject:item];
            }
            
            if (strongSelf.items.count == 0) {
                NSString *emptyText = @"Нет вложений";
                switch (strongSelf.segmentedControl.selectedSegmentIndex) {
                    case 0: emptyText = @"В этой беседе нет фотографий"; break;
                    case 1: emptyText = @"В этой беседе нет видеозаписей"; break;
                    case 2: emptyText = @"В этой беседе нет аудиозаписей"; break;
                    case 3: emptyText = @"В этой беседе нет документов"; break;
                    case 4: emptyText = @"В этой беседе нет ссылок"; break;
                }
                strongSelf.emptyLabel.text = emptyText;
                strongSelf.emptyLabel.hidden = NO;
            } else {
                strongSelf.emptyLabel.hidden = YES;
            }
            
            [strongSelf.tableView reloadData];
        });
    }];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKChatAttachmentCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        UIImageView *thumb = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 56, 56)];
        thumb.tag = 101;
        thumb.contentMode = UIViewContentModeScaleAspectFill;
        thumb.clipsToBounds = YES;
        thumb.layer.cornerRadius = 4.0;
        thumb.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [cell.contentView addSubview:thumb];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 8, cell.contentView.bounds.size.width - 90, 20)];
        titleLabel.tag = 102;
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        titleLabel.font = [UIFont boldSystemFontOfSize:14];
        titleLabel.textColor = [UIColor blackColor];
        [cell.contentView addSubview:titleLabel];
        
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 28, cell.contentView.bounds.size.width - 90, 18)];
        subLabel.tag = 103;
        subLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        subLabel.font = [UIFont systemFontOfSize:12];
        subLabel.textColor = [UIColor grayColor];
        [cell.contentView addSubview:subLabel];
        
        // Кнопка автора: аватарка + имя
        UIButton *authorBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        authorBtn.tag = 104;
        authorBtn.frame = CGRectMake(78, 48, cell.contentView.bounds.size.width - 90, 18);
        authorBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        authorBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        authorBtn.titleLabel.font = [UIFont systemFontOfSize:12];
        [authorBtn setTitleColor:[UIColor colorWithRed:45.0/255.0 green:110.0/255.0 blue:210.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        [cell.contentView addSubview:authorBtn];
    }
    
    if (indexPath.row >= (NSInteger)self.items.count) return cell;
    VKChatAttachmentItem *item = self.items[indexPath.row];
    VKAttachment *att = item.attachment;
    
    UIImageView *thumb = (UIImageView *)[cell.contentView viewWithTag:101];
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:102];
    UILabel *subLabel = (UILabel *)[cell.contentView viewWithTag:103];
    UIButton *authorBtn = (UIButton *)[cell.contentView viewWithTag:104];
    
    thumb.image = nil;
    
    // 1. Заголовок и превью вложения
    switch (att.type) {
        case VKAttachmentTypePhoto: {
            titleLabel.text = @"Фотография";
            subLabel.text = item.dateString ?: @"";
            NSString *url = att.photoURLLow ?: att.photoURL ?: att.photoURLFull;
            if (url) {
                [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                    if (img) thumb.image = img;
                }];
            }
            break;
        }
        case VKAttachmentTypeVideo: {
            titleLabel.text = att.videoTitle.length > 0 ? att.videoTitle : @"Видеозапись";
            subLabel.text = [NSString stringWithFormat:@"%@%@", (att.videoDuration.length > 0 ? [NSString stringWithFormat:@"%@  ", att.videoDuration] : @""), item.dateString ?: @""];
            if (att.videoImageURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.videoImageURL completion:^(UIImage *img) {
                    if (img) thumb.image = img;
                }];
            } else {
                thumb.image = [UIImage imageNamed:@"attach_video"];
            }
            break;
        }
        case VKAttachmentTypeAudio: {
            titleLabel.text = att.audioTitle.length > 0 ? att.audioTitle : @"Аудиозапись";
            subLabel.text = [NSString stringWithFormat:@"%@%@", (att.audioArtist.length > 0 ? [NSString stringWithFormat:@"%@ • ", att.audioArtist] : @""), item.dateString ?: @""];
            thumb.image = [UIImage imageNamed:@"music_icon"];
            break;
        }
        case VKAttachmentTypeDoc: {
            titleLabel.text = att.docTitle.length > 0 ? att.docTitle : @"Документ";
            subLabel.text = [NSString stringWithFormat:@"%@%@", (att.docSize.length > 0 ? [NSString stringWithFormat:@"%@ • ", att.docSize] : @""), item.dateString ?: @""];
            thumb.image = [UIImage imageNamed:@"doc_icon"];
            break;
        }
        case VKAttachmentTypeLink: {
            titleLabel.text = att.linkTitle.length > 0 ? att.linkTitle : (att.linkURL ?: @"Ссылка");
            subLabel.text = att.linkURL ?: (item.dateString ?: @"");
            if (att.linkImageURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.linkImageURL completion:^(UIImage *img) {
                    if (img) thumb.image = img;
                }];
            } else {
                thumb.image = [UIImage imageNamed:@"link_icon"];
            }
            break;
        }
        default: {
            titleLabel.text = @"Вложение";
            subLabel.text = item.dateString ?: @"";
            thumb.image = nil;
            break;
        }
    }
    
    // 2. Автор вложения
    NSString *authorName = item.author ? item.author.displayName : (item.fromId > 0 ? [NSString stringWithFormat:@"id%ld", (long)item.fromId] : @"");
    if (authorName.length > 0) {
        [authorBtn setTitle:[NSString stringWithFormat:@"От: %@ ›", authorName] forState:UIControlStateNormal];
        authorBtn.hidden = NO;
        [authorBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [authorBtn addTarget:self action:@selector(authorButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        authorBtn.hidden = YES;
    }
    
    // Подгрузка следующей страницы
    if (indexPath.row == (NSInteger)self.items.count - 3 && self.canLoadMore && !self.isLoading) {
        [self loadAttachmentsReset:NO];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.items.count) return;
    
    VKChatAttachmentItem *item = self.items[indexPath.row];
    VKAttachment *att = item.attachment;
    
    switch (att.type) {
        case VKAttachmentTypePhoto: {
            // Собираем все фото из текущего списка
            NSMutableArray *photoURLs = [NSMutableArray array];
            NSMutableArray *fullURLs = [NSMutableArray array];
            NSInteger targetIdx = 0;
            
            for (VKChatAttachmentItem *it in self.items) {
                if (it.attachment.type == VKAttachmentTypePhoto) {
                    NSString *u = it.attachment.photoURL ?: it.attachment.photoURLLow;
                    NSString *fu = it.attachment.photoURLFull ?: u;
                    if (u.length > 0) {
                        if (it == item) targetIdx = photoURLs.count;
                        [photoURLs addObject:u];
                        [fullURLs addObject:fu ?: u];
                    }
                }
            }
            
            if (photoURLs.count > 0) {
                VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs
                                                                                               fullPhotoURLs:fullURLs
                                                                                                initialIndex:targetIdx];
                [self presentViewController:viewer animated:YES completion:nil];
            }
            break;
        }
        case VKAttachmentTypeVideo: {
            VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:att];
            [self presentMoviePlayerViewControllerAnimated:player];
            break;
        }
        case VKAttachmentTypeAudio: {
            if (att.audioURL.length > 0) {
                MPMoviePlayerViewController *player = [[MPMoviePlayerViewController alloc] initWithContentURL:[NSURL URLWithString:att.audioURL]];
                [self presentMoviePlayerViewControllerAnimated:player];
            }
            break;
        }
        case VKAttachmentTypeDoc: {
            if (att.docURL.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:att.docURL]];
            }
            break;
        }
        case VKAttachmentTypeLink: {
            if (att.linkURL.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:att.linkURL]];
            }
            break;
        }
        default:
            break;
    }
}

- (void)authorButtonTapped:(UIButton *)sender {
    // Находим ячейку и соответствующий item
    UIView *p = sender.superview;
    while (p && ![p isKindOfClass:[UITableViewCell class]]) {
        p = p.superview;
    }
    if (!p) return;
    
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)p];
    if (!indexPath || indexPath.row >= (NSInteger)self.items.count) return;
    
    VKChatAttachmentItem *item = self.items[indexPath.row];
    if (item.author) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:item.author];
        [self.navigationController pushViewController:profVC animated:YES];
    } else if (item.fromId != 0) {
        VKUser *stub = [[VKUser alloc] init];
        stub.uid = labs(item.fromId);
        stub.isGroup = (item.fromId < 0);
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:stub];
        [self.navigationController pushViewController:profVC animated:YES];
    }
}

@end
