#import "VKPhotoPickerViewController.h"
#import "VKAPIClient.h"
#import "VKAuthService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"

@interface VKPhotoPickerGridCell : UITableViewCell
@property (nonatomic, strong) NSArray<UIImageView *> *imageViews;
@property (nonatomic, strong) NSArray<UIView *> *overlayViews;
@property (nonatomic, strong) NSArray<UILabel *> *badgeLabels;
@property (nonatomic, copy) void (^onItemTapped)(NSInteger index);
@end

@implementation VKPhotoPickerGridCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        
        NSMutableArray *ivs = [NSMutableArray array];
        NSMutableArray *ovs = [NSMutableArray array];
        NSMutableArray *bls = [NSMutableArray array];
        
        for (NSInteger i = 0; i < 3; i++) {
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectZero];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.userInteractionEnabled = YES;
            iv.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            iv.tag = i;
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            [iv addGestureRecognizer:tap];
            [self.contentView addSubview:iv];
            [ivs addObject:iv];
            
            // Checkmark overlay
            UIView *overlay = [[UIView alloc] initWithFrame:CGRectZero];
            overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
            overlay.hidden = YES;
            overlay.userInteractionEnabled = NO;
            [iv addSubview:overlay];
            [ovs addObject:overlay];
            
            UILabel *badge = [[UILabel alloc] initWithFrame:CGRectZero];
            badge.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:110.0/255.0 blue:210.0/255.0 alpha:1.0];
            badge.textColor = [UIColor whiteColor];
            badge.font = [UIFont boldSystemFontOfSize:13];
            badge.textAlignment = NSTextAlignmentCenter;
            badge.layer.cornerRadius = 12.0;
            badge.layer.borderWidth = 1.5;
            badge.layer.borderColor = [UIColor whiteColor].CGColor;
            badge.clipsToBounds = YES;
            badge.hidden = YES;
            [iv addSubview:badge];
            [bls addObject:badge];
        }
        
        self.imageViews = ivs;
        self.overlayViews = ovs;
        self.badgeLabels = bls;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    CGFloat gap = 4.0;
    CGFloat itemW = floorf((w - gap * 4.0) / 3.0);
    CGFloat itemH = itemW;
    
    for (NSInteger i = 0; i < 3; i++) {
        CGFloat x = gap + i * (itemW + gap);
        UIImageView *iv = self.imageViews[i];
        iv.frame = CGRectMake(x, 2.0, itemW, itemH);
        
        UIView *ov = self.overlayViews[i];
        ov.frame = iv.bounds;
        
        UILabel *bl = self.badgeLabels[i];
        bl.frame = CGRectMake(itemW - 28.0, 4.0, 24.0, 24.0);
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    NSInteger idx = gesture.view.tag;
    if (self.onItemTapped) {
        self.onItemTapped(idx);
    }
}

@end


@interface VKPhotoPickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *emptyLabel;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *allPhotos;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *albums;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *currentPhotos;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *selectedPhotos;
@property (nonatomic, strong) NSMutableSet<NSString *> *selectedPhotoKeys;

@property (nonatomic, assign) BOOL isBrowsingAlbum;
@property (nonatomic, copy) NSString *currentAlbumTitle;
@end

@implementation VKPhotoPickerViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super init];
    if (self) {
        _userId = (userId > 0) ? userId : [[VKAuthService sharedService] currentUserId];
        _maxSelectionCount = 10;
        _allPhotos = [NSMutableArray array];
        _albums = [NSMutableArray array];
        _currentPhotos = [NSMutableArray array];
        _selectedPhotos = [NSMutableArray array];
        _selectedPhotoKeys = [NSMutableSet set];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:245.0/255.0 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction)];
    [self updateDoneButton];
    
    // Segmented control: Все фото | Альбомы
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Все фото", @"Альбомы"]];
    self.modeSegment.selectedSegmentIndex = 0;
    [self.modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.modeSegment;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 160.0);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, self.view.bounds.size.width - 40, 40)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.text = @"Нет фотографий";
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    
    [self loadAllPhotos];
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneAction {
    if (self.selectedPhotos.count == 0) return;
    
    NSMutableArray *attachments = [NSMutableArray array];
    for (NSDictionary *p in self.selectedPhotos) {
        NSInteger photoId = [p[@"id"] integerValue] ?: [p[@"pid"] integerValue];
        NSInteger ownerId = [p[@"owner_id"] integerValue] ?: self.userId;
        NSString *accessKey = p[@"access_key"];
        
        NSString *attStr = (accessKey && accessKey.length > 0)
            ? [NSString stringWithFormat:@"photo%ld_%ld_%@", (long)ownerId, (long)photoId, accessKey]
            : [NSString stringWithFormat:@"photo%ld_%ld", (long)ownerId, (long)photoId];
        
        NSString *thumb = [self thumbnailURLForPhoto:p];
        [attachments addObject:@{
            @"attachmentString": attStr,
            @"thumbURL": thumb ?: @"",
            @"photo": p
        }];
    }
    
    if ([self.delegate respondsToSelector:@selector(photoPicker:didSelectAttachments:)]) {
        [self.delegate photoPicker:self didSelectAttachments:attachments];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)updateDoneButton {
    if (self.selectedPhotos.count > 0) {
        NSString *title = [NSString stringWithFormat:@"Прикрепить (%lu)", (unsigned long)self.selectedPhotos.count];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:self action:@selector(doneAction)];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (NSString *)photoKey:(NSDictionary *)photo {
    NSInteger pid = [photo[@"id"] integerValue] ?: [photo[@"pid"] integerValue];
    NSInteger oid = [photo[@"owner_id"] integerValue] ?: self.userId;
    return [NSString stringWithFormat:@"%ld_%ld", (long)oid, (long)pid];
}

- (NSString *)thumbnailURLForPhoto:(NSDictionary *)p {
    if (p[@"photo_130"]) return p[@"photo_130"];
    if (p[@"photo_604"]) return p[@"photo_604"];
    if (p[@"photo_75"]) return p[@"photo_75"];
    if (p[@"src"]) return p[@"src"];
    if (p[@"src_big"]) return p[@"src_big"];
    if (p[@"url"]) return p[@"url"];
    
    NSArray *sizes = p[@"sizes"];
    if ([sizes isKindOfClass:[NSArray class]] && sizes.count > 0) {
        for (NSDictionary *s in sizes) {
            if ([s[@"type"] isEqualToString:@"m"] || [s[@"type"] isEqualToString:@"s"] || [s[@"type"] isEqualToString:@"x"]) {
                return s[@"url"] ?: s[@"src"];
            }
        }
        NSDictionary *last = sizes.lastObject;
        return last[@"url"] ?: last[@"src"];
    }
    return nil;
}

- (void)modeChanged:(UISegmentedControl *)sender {
    self.isBrowsingAlbum = NO;
    self.emptyLabel.hidden = YES;
    
    if (sender.selectedSegmentIndex == 0) {
        self.currentPhotos = self.allPhotos;
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        [self.tableView reloadData];
        if (self.allPhotos.count == 0) {
            [self loadAllPhotos];
        }
    } else {
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        [self.tableView reloadData];
        if (self.albums.count == 0) {
            [self loadAlbums];
        }
    }
}

#pragma mark - API Loading

- (void)loadAllPhotos {
    [self.spinner startAnimating];
    self.emptyLabel.hidden = YES;
    
    NSDictionary *params = @{
        @"owner_id": @(self.userId),
        @"count": @100,
        @"extended": @1,
        @"photo_sizes": @1
    };
    
    [[VKAPIClient sharedClient] callMethod:@"photos.getAll" parameters:params completionHandler:^(id response, NSError *error) {
        [self.spinner stopAnimating];
        if (error) {
            // Fallback to photos.getUserPhotos
            [[VKAPIClient sharedClient] callMethod:@"photos.getUserPhotos" parameters:params completionHandler:^(id r2, NSError *e2) {
                [self processPhotosResponse:r2];
            }];
            return;
        }
        [self processPhotosResponse:response];
    }];
}

- (void)processPhotosResponse:(id)response {
    [self.allPhotos removeAllObjects];
    NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
    NSArray *items = resp[@"items"];
    if (![items isKindOfClass:[NSArray class]]) {
        items = [resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[];
    }
    
    for (id item in items) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            [self.allPhotos addObject:item];
        }
    }
    
    self.currentPhotos = self.allPhotos;
    self.emptyLabel.hidden = (self.currentPhotos.count > 0);
    [self.tableView reloadData];
}

- (void)loadAlbums {
    [self.spinner startAnimating];
    self.emptyLabel.hidden = YES;
    
    NSDictionary *params = @{
        @"owner_id": @(self.userId),
        @"need_covers": @1,
        @"need_system": @1
    };
    
    [[VKAPIClient sharedClient] callMethod:@"photos.getAlbums" parameters:params completionHandler:^(id response, NSError *error) {
        [self.spinner stopAnimating];
        [self.albums removeAllObjects];
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSArray *items = resp[@"items"] ?: ([resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[]);
        for (id item in items) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                [self.albums addObject:item];
            }
        }
        self.emptyLabel.hidden = (self.albums.count > 0);
        [self.tableView reloadData];
    }];
}

- (void)loadAlbumPhotos:(NSInteger)albumId title:(NSString *)title {
    [self.spinner startAnimating];
    self.isBrowsingAlbum = YES;
    self.currentAlbumTitle = title;
    self.emptyLabel.hidden = YES;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    NSDictionary *params = @{
        @"owner_id": @(self.userId),
        @"album_id": @(albumId),
        @"count": @100,
        @"extended": @1,
        @"photo_sizes": @1
    };
    
    [[VKAPIClient sharedClient] callMethod:@"photos.get" parameters:params completionHandler:^(id response, NSError *error) {
        [self.spinner stopAnimating];
        [self.currentPhotos removeAllObjects];
        
        NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        NSArray *items = resp[@"items"] ?: ([resp isKindOfClass:[NSArray class]] ? (NSArray *)resp : @[]);
        for (id item in items) {
            if ([item isKindOfClass:[NSDictionary class]]) {
                [self.currentPhotos addObject:item];
            }
        }
        self.emptyLabel.hidden = (self.currentPhotos.count > 0);
        [self.tableView reloadData];
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.modeSegment.selectedSegmentIndex == 1 && !self.isBrowsingAlbum) {
        return self.albums.count;
    }
    return ceilf(self.currentPhotos.count / 3.0);
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.modeSegment.selectedSegmentIndex == 1 && !self.isBrowsingAlbum) {
        return 60.0;
    }
    CGFloat w = tableView.bounds.size.width;
    CGFloat itemW = floorf((w - 16.0) / 3.0);
    return itemW + 4.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 1. Режим списка альбомов
    if (self.modeSegment.selectedSegmentIndex == 1 && !self.isBrowsingAlbum) {
        static NSString *AlbId = @"VKAlbumRowCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AlbId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AlbId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
            cell.imageView.clipsToBounds = YES;
            cell.imageView.layer.cornerRadius = 4.0;
        }
        
        if (indexPath.row < (NSInteger)self.albums.count) {
            NSDictionary *alb = self.albums[indexPath.row];
            cell.textLabel.text = alb[@"title"] ?: @"Альбом";
            NSInteger cnt = [alb[@"size"] ?: alb[@"count"] integerValue];
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld фото", (long)cnt];
            
            NSString *thumb = alb[@"thumb_src"] ?: alb[@"thumb"];
            if (thumb.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:thumb completion:^(UIImage *img) {
                    if (img) cell.imageView.image = img;
                }];
            }
        }
        return cell;
    }
    
    // 2. Режим сетки фотографий
    static NSString *GridId = @"VKPhotoGridCell";
    VKPhotoPickerGridCell *cell = [tableView dequeueReusableCellWithIdentifier:GridId];
    if (!cell) {
        cell = [[VKPhotoPickerGridCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:GridId];
    }
    
    NSInteger startIdx = indexPath.row * 3;
    __weak typeof(self) weakSelf = self;
    cell.onItemTapped = ^(NSInteger subIdx) {
        NSInteger photoIdx = startIdx + subIdx;
        [weakSelf togglePhotoSelectionAtIndex:photoIdx];
    };
    
    for (NSInteger i = 0; i < 3; i++) {
        NSInteger pIdx = startIdx + i;
        UIImageView *iv = cell.imageViews[i];
        UIView *ov = cell.overlayViews[i];
        UILabel *bl = cell.badgeLabels[i];
        
        if (pIdx < (NSInteger)self.currentPhotos.count) {
            iv.hidden = NO;
            NSDictionary *p = self.currentPhotos[pIdx];
            NSString *key = [self photoKey:p];
            BOOL isSel = [self.selectedPhotoKeys containsObject:key];
            
            ov.hidden = !isSel;
            bl.hidden = !isSel;
            if (isSel) {
                NSInteger selIdx = [self.selectedPhotos indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
                    return [[self photoKey:obj] isEqualToString:key];
                }];
                bl.text = [NSString stringWithFormat:@"%ld", (long)(selIdx + 1)];
            }
            
            NSString *url = [self thumbnailURLForPhoto:p];
            iv.image = nil;
            if (url.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
            }
        } else {
            iv.hidden = YES;
            ov.hidden = YES;
            bl.hidden = YES;
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.modeSegment.selectedSegmentIndex == 1 && !self.isBrowsingAlbum) {
        if (indexPath.row < (NSInteger)self.albums.count) {
            NSDictionary *alb = self.albums[indexPath.row];
            NSInteger albId = [alb[@"id"] integerValue] ?: [alb[@"aid"] integerValue];
            NSString *title = alb[@"title"] ?: @"Альбом";
            [self loadAlbumPhotos:albId title:title];
        }
    }
}

- (void)togglePhotoSelectionAtIndex:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.currentPhotos.count) return;
    NSDictionary *photo = self.currentPhotos[index];
    NSString *key = [self photoKey:photo];
    
    if ([self.selectedPhotoKeys containsObject:key]) {
        [self.selectedPhotoKeys removeObject:key];
        NSInteger idx = [self.selectedPhotos indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger i, BOOL *stop) {
            return [[self photoKey:obj] isEqualToString:key];
        }];
        if (idx != NSNotFound) {
            [self.selectedPhotos removeObjectAtIndex:idx];
        }
    } else {
        if ((NSInteger)self.selectedPhotos.count >= self.maxSelectionCount) {
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Лимит" message:[NSString stringWithFormat:@"Можно прикрепить не более %ld фото", (long)self.maxSelectionCount] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
            return;
        }
        [self.selectedPhotoKeys addObject:key];
        [self.selectedPhotos addObject:photo];
    }
    
    [self updateDoneButton];
    [self.tableView reloadData];
}

@end
