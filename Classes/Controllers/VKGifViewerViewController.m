#import "VKGifViewerViewController.h"
#import "VKAnimatedImageView.h"

@interface VKGifViewerViewController () <UIScrollViewDelegate>
@property (nonatomic, copy) NSString *gifURL;
@property (nonatomic, copy) NSString *previewURL;
@property (nonatomic, copy) NSString *gifTitle;

@property (nonatomic, strong) UIView       *backgroundView;
@property (nonatomic, strong) UIScrollView *zoomScrollView;   // для pinch-to-zoom + pan
@property (nonatomic, strong) VKAnimatedImageView *gifImageView;
@property (nonatomic, strong) UILabel      *titleLabel;
@property (nonatomic, strong) UILabel      *loadingLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIButton     *closeButton;

@property (nonatomic, assign) CGPoint panStartCenter;
@property (nonatomic, assign) BOOL isDismissing;
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
        _gifURL    = gifURL;
        _previewURL = previewURL;
        _gifTitle  = title;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle   = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;

    // ── Фон ──────────────────────────────────────────────────────────
    _backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.92];
    _backgroundView.userInteractionEnabled = NO;
    [self.view addSubview:_backgroundView];

    // ── ScrollView для pinch-to-zoom + pan после зума ────────────────
    _zoomScrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _zoomScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _zoomScrollView.backgroundColor = [UIColor clearColor];
    _zoomScrollView.minimumZoomScale = 1.0;
    _zoomScrollView.maximumZoomScale = 5.0;
    _zoomScrollView.delegate = self;
    _zoomScrollView.showsHorizontalScrollIndicator = NO;
    _zoomScrollView.showsVerticalScrollIndicator   = NO;
    _zoomScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
    // Боюнс для ощущения живости
    _zoomScrollView.bounces = YES;
    _zoomScrollView.alwaysBounceVertical   = YES;
    _zoomScrollView.alwaysBounceHorizontal = YES;
    [self.view addSubview:_zoomScrollView];

    // ── GIF view ──────────────────────────────────────────────────────
    _gifImageView = [[VKAnimatedImageView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
    _gifImageView.contentMode = UIViewContentModeScaleAspectFit;
    _gifImageView.backgroundColor = [UIColor clearColor];
    [_zoomScrollView addSubview:_gifImageView];
    _zoomScrollView.contentSize = _gifImageView.bounds.size;

    // ── Двойной тап для сброса / зума ─────────────────────────────────
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [_zoomScrollView addGestureRecognizer:doubleTap];

    // ── Одиночный тап по фону — закрыть ──────────────────────────────
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeTapped)];
    singleTap.numberOfTapsRequired = 1;
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [_zoomScrollView addGestureRecognizer:singleTap];

    // ── Swipe-down для закрытия (только когда zoom = 1x) ────────────
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = (id<UIGestureRecognizerDelegate>)self;
    [_zoomScrollView addGestureRecognizer:pan];

    // ── Спиннер ───────────────────────────────────────────────────────
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = CGPointMake(w / 2.0, h / 2.0);
    _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleTopMargin  | UIViewAutoresizingFlexibleBottomMargin;
    [_spinner startAnimating];
    [self.view addSubview:_spinner];

    _loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, _spinner.center.y + 36, w, 20)];
    _loadingLabel.text = @"Загрузка GIF…";
    _loadingLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    _loadingLabel.font = [UIFont systemFontOfSize:13];
    _loadingLabel.textAlignment = NSTextAlignmentCenter;
    _loadingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:_loadingLabel];

    // ── Название файла внизу ─────────────────────────────────────────
    if (_gifTitle.length > 0) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, h - 60, w - 68, 40)];
        _titleLabel.text = _gifTitle;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:13];
        _titleLabel.numberOfLines = 2;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
        [self.view addSubview:_titleLabel];
    }

    // ── Кнопка закрытия ──────────────────────────────────────────────
    _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _closeButton.frame = CGRectMake(w - 52, 28, 44, 44);
    _closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _closeButton.titleLabel.font = [UIFont systemFontOfSize:20];
    _closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    _closeButton.layer.cornerRadius = 22;
    [_closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_closeButton];

    // ── Загружаем GIF ────────────────────────────────────────────────
    [_gifImageView loadGIFFromURL:_gifURL previewURL:_previewURL];
    [self pollGIFLoadState];
}

#pragma mark - Polling загрузки

- (void)pollGIFLoadState {
    if (self.gifImageView.isGIFLoaded) {
        [_spinner stopAnimating];
        _loadingLabel.hidden = YES;
        // Явно запустить анимацию — на случай если willMoveToWindow отработал раньше загрузки
        [_gifImageView startGIFAnimation];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self pollGIFLoadState];
    });
}

#pragma mark - UIScrollViewDelegate (zoom)

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _gifImageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    // Центрировать gifImageView в scrollView при зуме меньше экрана
    CGFloat offsetX = MAX((scrollView.bounds.size.width  - scrollView.contentSize.width)  * 0.5, 0);
    CGFloat offsetY = MAX((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0);
    _gifImageView.center = CGPointMake(scrollView.contentSize.width  * 0.5 + offsetX,
                                       scrollView.contentSize.height * 0.5 + offsetY);
}

#pragma mark - Жесты

- (void)handleDoubleTap:(UITapGestureRecognizer *)tap {
    if (_zoomScrollView.zoomScale > 1.0) {
        [_zoomScrollView setZoomScale:1.0 animated:YES];
    } else {
        CGPoint pt = [tap locationInView:_gifImageView];
        CGRect zoomRect = CGRectMake(pt.x - 40, pt.y - 40, 80, 80);
        [_zoomScrollView zoomToRect:zoomRect animated:YES];
    }
}

// Swipe-to-dismiss работает только при zoomScale == 1
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (_zoomScrollView.zoomScale > 1.0 + 0.01) return; // при зуме — прокрутка, не dismiss
    CGPoint translation = [pan translationInView:self.view];

    if (pan.state == UIGestureRecognizerStateBegan) {
        _panStartCenter = _gifImageView.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        // Только вертикальный свайп
        if (ABS(translation.y) < ABS(translation.x) * 0.5) return;
        CGFloat progress = MIN(1.0, ABS(translation.y) / 200.0);
        _backgroundView.alpha = 1.0 - progress * 0.7;
        _zoomScrollView.transform = CGAffineTransformMakeTranslation(translation.x * 0.2, translation.y);
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        CGFloat velocityY = [pan velocityInView:self.view].y;
        if (ABS(translation.y) > 100 || ABS(velocityY) > 700) {
            _isDismissing = YES;
            [UIView animateWithDuration:0.25 animations:^{
                self.view.alpha = 0;
                CGFloat dir = (translation.y > 0) ? 1 : -1;
                self.zoomScrollView.transform = CGAffineTransformMakeTranslation(0, dir * self.view.bounds.size.height);
            } completion:^(BOOL done) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            if ([UIView respondsToSelector:@selector(animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)]) {
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:0 animations:^{
                    self.zoomScrollView.transform = CGAffineTransformIdentity;
                    self.backgroundView.alpha = 1.0;
                } completion:nil];
            } else {
                [UIView animateWithDuration:0.3 animations:^{
                    self.zoomScrollView.transform = CGAffineTransformIdentity;
                    self.backgroundView.alpha = 1.0;
                }];
            }
        }
    }
}

// Позволяем pan gesture и scroll gesture работать вместе
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

#pragma mark - Fade in / Close

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ self.view.alpha = 1.0; }];
}

- (void)closeTapped {
    if (_isDismissing) return;
    _isDismissing = YES;
    [UIView animateWithDuration:0.2 animations:^{
        self.view.alpha = 0;
    } completion:^(BOOL done) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (BOOL)prefersStatusBarHidden { return YES; }

- (void)dealloc {
    [_gifImageView resetGIF];
}

@end
