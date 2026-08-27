#import "VKVideosListViewController.h"
#import "VKVideoPlayerViewController.h"
#import "VKAttachment.h"
#import "VKAPIClient.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"

@interface VKVideosListViewController ()
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSArray<VKAttachment *> *videos;
@property (nonatomic, strong) UIView *emptyView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VKVideosListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super init];
    if (self) {
        _userId = userId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Видеозаписи";
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
    [self loadVideos];
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
    iconLbl.text = @"🎬";
    iconLbl.font = [UIFont systemFontOfSize:42];
    iconLbl.textAlignment = NSTextAlignmentCenter;
    [self.emptyView addSubview:iconLbl];
    
    UILabel *txtLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, self.view.bounds.size.width - 40, 24)];
    txtLbl.text = @"Видеозаписи не найдены";
    txtLbl.font = [UIFont boldSystemFontOfSize:16];
    txtLbl.textAlignment = NSTextAlignmentCenter;
    txtLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    [self.emptyView addSubview:txtLbl];
    
    [self.view addSubview:self.emptyView];
}

- (void)loadVideos {
    [self.spinner startAnimating];
    
    NSDictionary *params = @{
        @"owner_id": @(self.userId),
        @"count": @(30)
    };
    
    [[VKAPIClient sharedClient] callMethod:@"video.get" parameters:params completionHandler:^(id response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            
            NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
            NSArray *items = resp[@"items"] ?: ([response isKindOfClass:[NSArray class]] ? response : nil);
            
            NSMutableArray *vids = [NSMutableArray array];
            if (items && items.count > 0) {
                for (NSDictionary *d in items) {
                    VKAttachment *att = [VKAttachment attachmentFromDictionary:@{@"type": @"video", @"video": d}];
                    if (att) [vids addObject:att];
                }
            } else {
                // Демо видео-плейсхолдеры
                NSArray *demos = @[
                    @{@"title": @"ВКонтакте: История создания", @"duration": @"4:15", @"thumb": @""},
                    @{@"title": @"OpenVK Project: Демонстрация возможностей", @"duration": @"2:40", @"thumb": @""},
                    @{@"title": @"Обзор iOS 6 на iPhone 4s", @"duration": @"8:12", @"thumb": @""}
                ];
                for (NSDictionary *d in demos) {
                    VKAttachment *att = [[VKAttachment alloc] init];
                    att.type = VKAttachmentTypeVideo;
                    att.videoTitle = d[@"title"];
                    att.videoDuration = d[@"duration"];
                    [vids addObject:att];
                }
            }
            
            self.videos = vids;
            [self renderGrid];
        });
    }];
}

- (void)renderGrid {
    for (UIView *v in self.scrollView.subviews) [v removeFromSuperview];
    
    if (self.videos.count == 0) {
        self.emptyView.hidden = NO;
        return;
    }
    self.emptyView.hidden = YES;
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 12.0;
    CGFloat gap = 10.0;
    CGFloat cardW = (width - margin * 2.0 - gap) / 2.0;
    CGFloat cardH = cardW * 0.65 + 46.0;
    
    for (NSInteger i = 0; i < (NSInteger)self.videos.count; i++) {
        VKAttachment *v = self.videos[i];
        CGFloat x = margin + (i % 2) * (cardW + gap);
        CGFloat y = margin + (i / 2) * (cardH + gap);
        
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(x, y, cardW, cardH)];
        card.tag = i;
        card.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoTapped:)];
        [card addGestureRecognizer:tap];
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cardW, cardW * 0.65)];
        imgView.contentMode = UIViewContentModeScaleAspectFill;
        imgView.clipsToBounds = YES;
        imgView.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        imgView.layer.cornerRadius = 6.0;
        
        if (v.videoImageURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:v.videoImageURL completion:^(UIImage *img) {
                if (img) imgView.image = img;
            }];
        }
        [card addSubview:imgView];
        
        // Play badge
        UILabel *playBadge = [[UILabel alloc] initWithFrame:CGRectMake((cardW - 32)/2.0, (cardW * 0.65 - 32)/2.0, 32, 32)];
        playBadge.text = @"▶";
        playBadge.textColor = [UIColor whiteColor];
        playBadge.font = [UIFont boldSystemFontOfSize:15];
        playBadge.textAlignment = NSTextAlignmentCenter;
        playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
        playBadge.layer.cornerRadius = 16.0;
        playBadge.clipsToBounds = YES;
        [imgView addSubview:playBadge];
        
        // Duration badge
        UILabel *durLbl = [[UILabel alloc] initWithFrame:CGRectMake(cardW - 44, cardW * 0.65 - 20, 38, 16)];
        durLbl.text = v.videoDuration ?: @"0:00";
        durLbl.textColor = [UIColor whiteColor];
        durLbl.font = [UIFont boldSystemFontOfSize:10];
        durLbl.textAlignment = NSTextAlignmentCenter;
        durLbl.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        durLbl.layer.cornerRadius = 3.0;
        durLbl.clipsToBounds = YES;
        [imgView addSubview:durLbl];
        
        // Title
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, cardW * 0.65 + 4, cardW, 36)];
        titleLbl.text = v.videoTitle ?: @"Видеозапись";
        titleLbl.font = [UIFont boldSystemFontOfSize:12];
        titleLbl.numberOfLines = 2;
        titleLbl.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:35.0/255.0 alpha:1.0];
        [card addSubview:titleLbl];
        
        [self.scrollView addSubview:card];
    }
    
    NSInteger rows = ceilf(self.videos.count / 2.0);
    self.scrollView.contentSize = CGSizeMake(width, margin + rows * (cardH + gap) + 20.0);
}

- (void)videoTapped:(UITapGestureRecognizer *)gesture {
    NSInteger idx = gesture.view.tag;
    if (idx >= 0 && idx < (NSInteger)self.videos.count) {
        VKAttachment *v = self.videos[idx];
        VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:v];
        [self presentMoviePlayerViewControllerAnimated:player];
    }
}

@end
