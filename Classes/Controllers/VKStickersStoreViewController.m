#import "VKStickersStoreViewController.h"
#import "VKStickersService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"

@interface VKStickersStoreViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSMutableArray<VKStickerPack *> *packs;
@property (nonatomic, assign) BOOL isLoading;

@end

@implementation VKStickersStoreViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _packs = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Магазин стикеров";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Закрыть"
                                                                                            target:self
                                                                                            action:@selector(closeAction)
                                                                                            isBack:NO];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, width, height) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 74.0;
    
    if (NSClassFromString(@"UIRefreshControl")) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(loadStorePacks) forControlEvents:UIControlEventValueChanged];
        [self.tableView addSubview:self.refreshControl];
    }
    [self.view addSubview:self.tableView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(width / 2.0, height / 2.0);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    [self loadStorePacks];
}

- (void)closeAction {
    if (self.onPacksUpdated) {
        self.onPacksUpdated();
    }
    if (self.navigationController.viewControllers.firstObject == self) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)loadStorePacks {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    if (self.packs.count == 0) {
        [self.spinner startAnimating];
    }
    
    __weak typeof(self) weakSelf = self;
    [[VKStickersService sharedService] fetchStorePacksWithCompletion:^(NSArray<VKStickerPack *> *packs, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isLoading = NO;
            [strongSelf.spinner stopAnimating];
            if ([strongSelf.refreshControl isRefreshing]) {
                [strongSelf.refreshControl endRefreshing];
            }
            
            [strongSelf.packs removeAllObjects];
            if (packs) {
                [strongSelf.packs addObjectsFromArray:packs];
            }
            [strongSelf.tableView reloadData];
        });
    }];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.packs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKStickerPackCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 54, 54)];
        icon.tag = 101;
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.clipsToBounds = YES;
        [cell.contentView addSubview:icon];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 12, cell.contentView.bounds.size.width - 180, 20)];
        titleLabel.tag = 102;
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        titleLabel.textColor = [UIColor blackColor];
        [cell.contentView addSubview:titleLabel];
        
        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(76, 32, cell.contentView.bounds.size.width - 180, 32)];
        descLabel.tag = 103;
        descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        descLabel.font = [UIFont systemFontOfSize:12];
        descLabel.textColor = [UIColor grayColor];
        descLabel.numberOfLines = 2;
        [cell.contentView addSubview:descLabel];
        
        UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        actionBtn.tag = 104;
        actionBtn.frame = CGRectMake(cell.contentView.bounds.size.width - 96, 22, 86, 30);
        actionBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        actionBtn.layer.cornerRadius = 15.0;
        actionBtn.clipsToBounds = YES;
        [cell.contentView addSubview:actionBtn];
    }
    
    if (indexPath.row >= (NSInteger)self.packs.count) return cell;
    VKStickerPack *pack = self.packs[indexPath.row];
    
    UIImageView *icon = (UIImageView *)[cell.contentView viewWithTag:101];
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:102];
    UILabel *descLabel = (UILabel *)[cell.contentView viewWithTag:103];
    UIButton *actionBtn = (UIButton *)[cell.contentView viewWithTag:104];
    
    titleLabel.text = pack.title;
    descLabel.text = pack.packDescription.length > 0 ? pack.packDescription : [NSString stringWithFormat:@"%ld стикеров", (long)pack.stickers.count];
    
    icon.image = nil;
    if (pack.previewURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:pack.previewURL completion:^(UIImage *img) {
            if (img) icon.image = img;
        }];
    }
    
    BOOL isActive = [[VKStickersService sharedService] isPackActive:pack.packId];
    if (isActive) {
        [actionBtn setTitle:@"Установлен" forState:UIControlStateNormal];
        [actionBtn setTitleColor:[UIColor colorWithWhite:0.5 alpha:1.0] forState:UIControlStateNormal];
        actionBtn.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0];
        actionBtn.layer.borderWidth = 0.5;
        actionBtn.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:222.0/255.0 alpha:1.0].CGColor;
    } else {
        [actionBtn setTitle:@"Добавить" forState:UIControlStateNormal];
        [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        actionBtn.backgroundColor = [[VKThemeManager sharedManager] accentColor];
        actionBtn.layer.borderWidth = 0.0;
    }
    
    [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
    actionBtn.tag = 1000 + indexPath.row;
    [actionBtn addTarget:self action:@selector(actionButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    return cell;
}

- (void)actionButtonTapped:(UIButton *)sender {
    NSInteger row = sender.tag - 1000;
    if (row < 0 || row >= (NSInteger)self.packs.count) return;
    VKStickerPack *pack = self.packs[row];
    
    BOOL isActive = [[VKStickersService sharedService] isPackActive:pack.packId];
    if (isActive) {
        [[VKStickersService sharedService] deactivatePackId:pack.packId];
    } else {
        [[VKStickersService sharedService] activatePack:pack];
    }
    
    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    if (self.onPacksUpdated) {
        self.onPacksUpdated();
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.packs.count) return;
    
    VKStickerPack *pack = self.packs[indexPath.row];
    [self showPackDetails:pack];
}

- (void)showPackDetails:(VKStickerPack *)pack {
    UIViewController *vc = [[UIViewController alloc] init];
    vc.title = pack.title;
    vc.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
    sv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    sv.alwaysBounceVertical = YES;
    [vc.view addSubview:sv];
    
    // Превью и описание
    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((width - 80) / 2.0, 16, 80, 80)];
    iv.contentMode = UIViewContentModeScaleAspectFit;
    if (pack.previewURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:pack.previewURL completion:^(UIImage *img) {
            if (img) iv.image = img;
        }];
    }
    [sv addSubview:iv];
    
    UILabel *tLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 102, width - 40, 22)];
    tLabel.text = pack.title;
    tLabel.font = [UIFont boldSystemFontOfSize:18];
    tLabel.textAlignment = NSTextAlignmentCenter;
    [sv addSubview:tLabel];
    
    UILabel *dLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 126, width - 40, 36)];
    dLabel.text = pack.packDescription;
    dLabel.font = [UIFont systemFontOfSize:13];
    dLabel.textColor = [UIColor grayColor];
    dLabel.textAlignment = NSTextAlignmentCenter;
    dLabel.numberOfLines = 2;
    [sv addSubview:dLabel];
    
    // Сетка стикеров
    NSInteger cols = 4;
    CGFloat pad = 8.0;
    CGFloat itemSize = floor((width - (pad * (cols + 1))) / cols);
    CGFloat curX = pad;
    CGFloat curY = 172.0;
    
    for (NSInteger i = 0; i < (NSInteger)pack.stickers.count; i++) {
        VKSticker *st = pack.stickers[i];
        UIImageView *stIV = [[UIImageView alloc] initWithFrame:CGRectMake(curX, curY, itemSize, itemSize)];
        stIV.contentMode = UIViewContentModeScaleAspectFit;
        if (st.imageURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:st.imageURL completion:^(UIImage *img) {
                if (img) stIV.image = img;
            }];
        }
        [sv addSubview:stIV];
        
        if ((i + 1) % cols == 0) {
            curX = pad;
            curY += itemSize + pad;
        } else {
            curX += itemSize + pad;
        }
    }
    
    if (pack.stickers.count % cols != 0) {
        curY += itemSize + pad;
    }
    sv.contentSize = CGSizeMake(width, curY + 20.0);
    
    [self.navigationController pushViewController:vc animated:YES];
}

@end
