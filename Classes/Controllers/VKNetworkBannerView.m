#import "VKNetworkBannerView.h"
#import "VKNetworkStatusManager.h"
#import "VKThemeManager.h"
#import <QuartzCore/QuartzCore.h>

@interface VKNetworkBannerView ()

@property (nonatomic, assign, readwrite) VKNetworkBannerState currentState;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, weak) UIWindow *attachedWindow;
@property (nonatomic, strong) NSTimer *autoHideTimer;

@end

@implementation VKNetworkBannerView

+ (instancetype)sharedBanner {
    static VKNetworkBannerView *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] initWithFrame:CGRectMake(0, 20, 320, 28)];
    });
    return _shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
        self.hidden = YES;
        _currentState = VKNetworkBannerStateHidden;
        
        // Градиент для скевоморфизма
        _gradientLayer = [CAGradientLayer layer];
        _gradientLayer.frame = self.bounds;
        [self.layer insertSublayer:_gradientLayer atIndex:0];
        
        // Индикатор
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicator.frame = CGRectMake(12, 4, 20, 20);
        _activityIndicator.hidesWhenStopped = YES;
        [self addSubview:_activityIndicator];
        
        // Текст статуса
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 0, frame.size.width - 72, frame.size.height)];
        _statusLabel.font = [UIFont boldSystemFontOfSize:12];
        _statusLabel.textColor = [UIColor whiteColor];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _statusLabel.backgroundColor = [UIColor clearColor];
        _statusLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _statusLabel.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:_statusLabel];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bannerTapped)];
        [self addGestureRecognizer:tap];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusChanged:) name:VKNetworkStatusDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:VKThemeDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.autoHideTimer invalidate];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}

- (void)attachToWindow:(UIWindow *)window {
    self.attachedWindow = window;
    if (!self.superview && window) {
        BOOL isIOS7 = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
        CGFloat topY = isIOS7 ? 64.0 : 44.0;
        self.frame = CGRectMake(0, topY, window.bounds.size.width, 28.0);
        [window addSubview:self];
    }
}

- (void)themeChanged:(NSNotification *)note {
    [self updateAppearanceForCurrentState];
}

- (void)networkStatusChanged:(NSNotification *)note {
    VKNetworkStatusManager *mgr = [VKNetworkStatusManager sharedManager];
    
    if (![mgr isNetworkReachable]) {
        [self showState:VKNetworkBannerStateWaitingForNetwork animated:YES];
    } else if (![mgr isServerReachable]) {
        [self showState:VKNetworkBannerStateServerUnavailable animated:YES];
    } else {
        // Сеть и сервер в порядке
        if (self.currentState != VKNetworkBannerStateHidden && self.currentState != VKNetworkBannerStateConnected) {
            [self showState:VKNetworkBannerStateConnected animated:YES];
        }
    }
}

- (void)bannerTapped {
    if (self.currentState == VKNetworkBannerStateWaitingForNetwork ||
        self.currentState == VKNetworkBannerStateServerUnavailable) {
        [self showState:VKNetworkBannerStateConnecting animated:YES];
        [[VKNetworkStatusManager sharedManager] checkServerStatusWithCompletion:^(BOOL reachable) {
            if (!reachable) {
                [self showState:VKNetworkBannerStateServerUnavailable animated:YES];
            }
        }];
        if (self.onRetryTapped) {
            self.onRetryTapped();
        }
    }
}

- (void)showState:(VKNetworkBannerState)state animated:(BOOL)animated {
    if (_currentState == state && !self.hidden) return;
    
    [self.autoHideTimer invalidate];
    self.autoHideTimer = nil;
    _currentState = state;
    
    if (state == VKNetworkBannerStateHidden) {
        [self hideAnimated:animated];
        return;
    }
    
    BOOL isIOS7 = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
    CGFloat topY = isIOS7 ? 64.0 : 44.0;
    
    if (self.attachedWindow && !self.superview) {
        self.frame = CGRectMake(0, topY, self.attachedWindow.bounds.size.width, 28.0);
        [self.attachedWindow addSubview:self];
    }
    if (self.superview) {
        self.frame = CGRectMake(0, topY, self.superview.bounds.size.width, 28.0);
        [self.superview bringSubviewToFront:self];
    }
    
    [self updateAppearanceForCurrentState];
    
    if (self.hidden) {
        self.hidden = NO;
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, -28.0);
        
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.alpha = 1.0;
            self.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    
    if (state == VKNetworkBannerStateConnected) {
        self.autoHideTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                              target:self
                                                            selector:@selector(autoHideTimerFired)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)autoHideTimerFired {
    [self hideAnimated:YES];
}

- (void)hideAnimated:(BOOL)animated {
    [self.autoHideTimer invalidate];
    self.autoHideTimer = nil;
    _currentState = VKNetworkBannerStateHidden;
    
    if (animated) {
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.alpha = 0.0;
            self.transform = CGAffineTransformMakeTranslation(0, -28.0);
        } completion:^(BOOL finished) {
            self.hidden = YES;
            self.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.alpha = 0.0;
        self.hidden = YES;
        self.transform = CGAffineTransformIdentity;
    }
}

- (void)updateAppearanceForCurrentState {
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    switch (self.currentState) {
        case VKNetworkBannerStateWaitingForNetwork: {
            [self.activityIndicator stopAnimating];
            self.statusLabel.frame = CGRectMake(12, 0, self.bounds.size.width - 24, self.bounds.size.height);
            self.statusLabel.text = @"⚡ Ожидание сети... (нажмите для повтора)";
            
            if (isSkeuo) {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:225.0/255.0 green:115.0/255.0 blue:35.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:185.0/255.0 green:80.0/255.0 blue:15.0/255.0 alpha:0.95].CGColor
                ];
            } else {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:235.0/255.0 green:110.0/255.0 blue:30.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:235.0/255.0 green:110.0/255.0 blue:30.0/255.0 alpha:0.95].CGColor
                ];
            }
            break;
        }
        case VKNetworkBannerStateConnecting: {
            [self.activityIndicator startAnimating];
            self.statusLabel.frame = CGRectMake(36, 0, self.bounds.size.width - 48, self.bounds.size.height);
            self.statusLabel.text = @"Подключение к серверу...";
            
            if (isSkeuo) {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:90.0/255.0 green:135.0/255.0 blue:185.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:60.0/255.0 green:95.0/255.0 blue:145.0/255.0 alpha:0.95].CGColor
                ];
            } else {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:0.95].CGColor
                ];
            }
            break;
        }
        case VKNetworkBannerStateServerUnavailable: {
            [self.activityIndicator stopAnimating];
            self.statusLabel.frame = CGRectMake(12, 0, self.bounds.size.width - 24, self.bounds.size.height);
            self.statusLabel.text = @"📡 Сервер недоступен (нажмите для повтора)";
            
            if (isSkeuo) {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:210.0/255.0 green:60.0/255.0 blue:55.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:165.0/255.0 green:35.0/255.0 blue:30.0/255.0 alpha:0.95].CGColor
                ];
            } else {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:215.0/255.0 green:55.0/255.0 blue:50.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:215.0/255.0 green:55.0/255.0 blue:50.0/255.0 alpha:0.95].CGColor
                ];
            }
            break;
        }
        case VKNetworkBannerStateConnected: {
            [self.activityIndicator stopAnimating];
            self.statusLabel.frame = CGRectMake(12, 0, self.bounds.size.width - 24, self.bounds.size.height);
            self.statusLabel.text = @"✓ Подключение восстановлено";
            
            if (isSkeuo) {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:75.0/255.0 green:170.0/255.0 blue:75.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:45.0/255.0 green:130.0/255.0 blue:45.0/255.0 alpha:0.95].CGColor
                ];
            } else {
                self.gradientLayer.colors = @[
                    (id)[UIColor colorWithRed:65.0/255.0 green:165.0/255.0 blue:65.0/255.0 alpha:0.95].CGColor,
                    (id)[UIColor colorWithRed:65.0/255.0 green:165.0/255.0 blue:65.0/255.0 alpha:0.95].CGColor
                ];
            }
            break;
        }
        default:
            break;
    }
}

@end
