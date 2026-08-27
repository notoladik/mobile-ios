#import "VKGifViewerViewController.h"
#import "VKAnimatedImageView.h"

@interface VKGifViewerViewController ()
@property (nonatomic, copy) NSString *gifURL;
@property (nonatomic, copy) NSString *previewURL;
@property (nonatomic, copy) NSString *gifTitle;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) VKAnimatedImageView *gifImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *loadingLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, assign) CGPoint panStartCenter;
@end

@implementation VKGifViewerViewController

- (instancetype)initWithAttachment:(VKAttachment *)attachment {
    return [self initWithGIFURL:attachment.docURL
                     previewURL:attachment.gifPreviewURL
                          title:attachment.docTitle];
}

- (instancetype)initWithGIFURL:(NSString *)gifURL previewURL:(NSString *)previewURL title:(NSString *)title {
    self = [super init];
    if (self) {
        _gifURL = gifURL;
        _previewURL = previewURL;
        _gifTitle = title;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    // Dim background
    _backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.92];
    [self.view addSubview:_backgroundView];

    // GIF view (centered, aspect-fit)
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    _gifImageView = [[VKAnimatedImageView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    _gifImageView.center = CGPointMake(w / 2.0, h / 2.0);
    _gifImageView.contentMode = UIViewContentModeScaleAspectFit;
    _gifImageView.backgroundColor = [UIColor clearColor];
    _gifImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_gifImageView];

    // Loading indicator
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = CGPointMake(w / 2.0, h / 2.0);
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [_spinner startAnimating];
    [self.view addSubview:_spinner];

    _loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, _spinner.center.y + 32, w, 20)];
    _loadingLabel.text = @"Загрузка GIF…";
    _loadingLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    _loadingLabel.font = [UIFont systemFontOfSize:13];
    _loadingLabel.textAlignment = NSTextAlignmentCenter;
    _loadingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_loadingLabel];

    // Title label at bottom
    if (_gifTitle.length > 0) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, h - 60, w - 60, 40)];
        _titleLabel.text = _gifTitle;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:14];
        _titleLabel.numberOfLines = 2;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        [self.view addSubview:_titleLabel];
    }

    // Close button
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.frame = CGRectMake(w - 50, 30, 44, 44);
    _closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:20];
    _closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    _closeButton.layer.cornerRadius = 22;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];

    // Swipe down to dismiss
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.view addGestureRecognizer:pan];

    // Tap background to close
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTapped)];
    tap.cancelsTouchesInView = NO;
    [_backgroundView addGestureRecognizer:tap];

    // Start loading
    [_gifImageView loadGIFFromURL:_gifURL previewURL:_previewURL];

    // Hide spinner when GIF is loaded
    [self pollGIFLoadState];
}

- (void)pollGIFLoadState {
    if (self.gifImageView.isGIFLoaded) {
        [self.spinner stopAnimating];
        self.loadingLabel.hidden = YES;
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pollGIFLoadState];
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.view.alpha = 1.0; }];
}

- (void)closeTapped {
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL done) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.view];

    if (pan.state == UIGestureRecognizerStateBegan) {
        _panStartCenter = self.gifImageView.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGFloat progress = MIN(1.0, ABS(translation.y) / 200.0);
        self.backgroundView.alpha = 1.0 - progress * 0.7;
        self.gifImageView.transform = CGAffineTransformMakeTranslation(translation.x * 0.3, translation.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat velocityY = [pan velocityInView:self.view].y;
        if (ABS(translation.y) > 100 || ABS(velocityY) > 700) {
            [UIView animateWithDuration:0.25 animations:^{
                self.view.alpha = 0;
                CGFloat dir = (translation.y > 0) ? 1 : -1;
                self.gifImageView.transform = CGAffineTransformMakeTranslation(0, dir * self.view.bounds.size.height);
            } completion:^(BOOL done) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
                self.gifImageView.transform = CGAffineTransformIdentity;
                self.backgroundView.alpha = 1.0;
            } completion:nil];
        }
    }
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)dealloc {
    [_gifImageView resetGIF];
}

@end
