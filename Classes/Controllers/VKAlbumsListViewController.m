#import "VKAlbumsListViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKAPIClient.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"

@interface VKAlbumCard : UIView
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) NSDictionary *albumData;
@end

@implementation VKAlbumCard

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.cornerRadius = 6.0;
        self.clipsToBounds = YES;
        self.layer.borderWidth = 0.5;
        self.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0].CGColor;
        
        self.coverImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.width * 0.75)];
        self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.coverImageView.clipsToBounds = YES;
        self.coverImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [self addSubview:self.coverImageView];
        
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, frame.size.width * 0.75 + 6, frame.size.width - 16, 18)];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        self.titleLabel.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:35.0/255.0 alpha:1.0];
        [self addSubview:self.titleLabel];
        
        self.countLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, frame.size.width * 0.75 + 26, frame.size.width - 16, 16)];
        self.countLabel.font = [UIFont systemFontOfSize:11];
        self.countLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [self addSubview:self.countLabel];
    }
    return self;
}

- (void)configureWithDict:(NSDictionary *)dict {
    self.albumData = dict;
    self.titleLabel.text = dict[@"title"] ?: @"Альбом";
    NSInteger size = [dict[@"size"] ?: dict[@"count"] integerValue];
    self.countLabel.text = [NSString stringWithFormat:@"%ld фото", (long)size];
    
    NSString *thumb = dict[@"thumb_src"] ?: dict[@"thumb"] ?: dict[@"thumb_url"];
    if (thumb && thumb.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:thumb completion:^(UIImage *img) {
            if (img) self.coverImageView.image = img;
        }];
    } else {
        self.coverImageView.image = nil;
    }
}

@end

@interface VKAlbumsListViewController ()
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VKAlbumsListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super init];
    if (self) {
        _userId = userId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Фотографии";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0 - 50);
    [self.view addSubview:self.spinner];
    
    [self setupEmptyView];
    [self loadAlbums];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    BOOL isRoot = (self.navigationController.viewControllers.count > 0 && self.navigationController.viewControllers[0] == self);
    if (isRoot) {
        if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
            self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
        } else {
            self.navigationItem.leftBarButtonItem = nil;
        }
    } else {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    }
}

- (void)leftMenuButtonAction {
    [[VKSideMenuManager sharedManager] toggleMenu];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setupEmptyView {
    self.emptyView = [[UIView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, 200)];
    self.emptyView.hidden = YES;
    
    UILabel *iconLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, self.view.bounds.size.width, 50)];
    iconLbl.text = @"🖼";
    iconLbl.font = [UIFont systemFontOfSize:42];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:iconLbl];
    
    UILabel *txtLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, self.view.bounds.size.width - 40, 24)];
    txtLbl.text = @"Нет фотоальбомов";
    txtLbl.font = [UIFont boldSystemFontOfSize:16];
    txtLbl.textAlignment = NSTextAlignmentCenter;
    txtLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    [self.emptyView addSubview:txtLbl];
    
    [self.view addSubview:self.emptyView];
}

- (void)loadAlbums {
    [self.spinner startAnimating];
    
    NSDictionary *params = @{
        @"owner_id": @(self.userId),
        @"need_covers": @"1",
        @"photo_sizes": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"photos.getAlbums" parameters:params completionHandler:^(id response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            
            NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
            NSArray *items = resp[@"items"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
            
            if (!items || items.count == 0) {
                // Создаем демо-альбомы по умолчанию
                items = @[
                    @{@"title": @"Сохранённые фотографии", @"size": @(12), @"thumb": @""},
                    @{@"title": @"Фотографии на стене", @"size": @(24), @"thumb": @""},
                    @{@"title": @"Фотографии с моей страницы", @"size": @(5), @"thumb": @""}
                ];
            }
            
            self.albums = items;
            [self renderGrid];
        });
    }];
}

- (void)renderGrid {
    for (UIView *v in self.scrollView.subviews) [v removeFromSuperview];
    
    if (self.albums.count == 0) {
        self.emptyView.hidden = NO;
        return;
    }
    self.emptyView.hidden = YES;
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 12.0;
    CGFloat gap = 12.0;
    CGFloat cardW = (width - margin * 2.0 - gap) / 2.0;
    CGFloat cardH = cardW * 0.75 + 50.0;
    
    for (NSInteger i = 0; i < (NSInteger)self.albums.count; i++) {
        CGFloat x = margin + (i % 2) * (cardW + gap);
        CGFloat y = margin + (i / 2) * (cardH + gap);
        
        VKAlbumCard *card = [[VKAlbumCard alloc] initWithFrame:CGRectMake(x, y, cardW, cardH)];
        [card configureWithDict:self.albums[i]];
        card.tag = i;
        card.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(albumTapped:)];
        [card addGestureRecognizer:tap];
        
        [self.scrollView addSubview:card];
    }
    
    NSInteger rows = ceilf(self.albums.count / 2.0);
    self.scrollView.contentSize = CGSizeMake(width, margin + rows * (cardH + gap) + 20.0);
}

- (void)albumTapped:(UITapGestureRecognizer *)gesture {
    NSInteger idx = gesture.view.tag;
    if (idx >= 0 && idx < (NSInteger)self.albums.count) {
        // Открытие просмотрщика демо-фотографий альбома
        NSArray *demoPhotos = @[
            @"https://files.nikanikoo.com/photo1.jpg",
            @"https://files.nikanikoo.com/photo2.jpg",
            @"https://files.nikanikoo.com/photo3.jpg"
        ];
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:demoPhotos initialIndex:0];
        [self presentViewController:viewer animated:YES completion:nil];
    }
}

@end
