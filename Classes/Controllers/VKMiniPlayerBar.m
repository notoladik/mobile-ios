#import "VKMiniPlayerBar.h"
#import "VKThemeManager.h"
#import "VKAudioPlayerViewController.h"
#import "VKSideMenuManager.h"
#import <QuartzCore/QuartzCore.h>

@interface VKMiniPlayerBar () <UIGestureRecognizerDelegate>

@property (nonatomic, assign, readwrite) VKMiniPlayerMode currentMode;
@property (nonatomic, assign, readwrite) BOOL isCollapsed;
@property (nonatomic, assign, readwrite) BOOL isDismissed;

// Bar mode views
@property (nonatomic, strong) UIView *barContainerView;
@property (nonatomic, strong) UIView *progressContainerView;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *closeButton;

// Floating bubble mode views
@property (nonatomic, strong) UIView *bubbleContainerView;
@property (nonatomic, strong) UIImageView *bubbleCoverImageView;
@property (nonatomic, strong) UILabel *bubbleNoteLabel;
@property (nonatomic, strong) UIView *bubblePulseView;

@property (nonatomic, assign) CGFloat currentBottomOffset;
@property (nonatomic, assign) CGPoint bubbleCenter;
@property (nonatomic, assign) CGPoint panGestureStartCenter;
@property (nonatomic, strong) NSString *lastTrackTitle;

@end

@implementation VKMiniPlayerBar

+ (instancetype)sharedBar {
    static VKMiniPlayerBar *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] initWithFrame:CGRectMake(0, 0, 320, 48)];
    });
    return _shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        self.clipsToBounds = NO;
        
        _currentMode = VKMiniPlayerModeExpandedBar;
        _isCollapsed = NO;
        _isDismissed = NO;
        
        // -------------------------------------------------------------
        // 1. Полная панель (Bar Container)
        // -------------------------------------------------------------
        _barContainerView = [[UIView alloc] initWithFrame:self.bounds];
        _barContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _barContainerView.backgroundColor = [UIColor colorWithWhite:0.98 alpha:0.96];
        _barContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
        _barContainerView.layer.shadowOffset = CGSizeMake(0, -1);
        _barContainerView.layer.shadowOpacity = 0.12;
        _barContainerView.layer.shadowRadius = 2.0;
        _barContainerView.clipsToBounds = NO;
        [self addSubview:_barContainerView];
        
        UITapGestureRecognizer *barTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(barTapped)];
        [_barContainerView addGestureRecognizer:barTap];
        
        // Свайп вниз — свернуть в плавающий кружок
        UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeDownToCollapse)];
        swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
        [_barContainerView addGestureRecognizer:swipeDown];
        
        // Свайп вправо — свернуть в плавающий кружок
        UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRightToCollapse)];
        swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
        [_barContainerView addGestureRecognizer:swipeRight];
        
        // Свайп влево — следующий трек
        UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftForNext)];
        swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
        [_barContainerView addGestureRecognizer:swipeLeft];
        
        // Полоса прогресса
        _progressContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 2.0)];
        _progressContainerView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _progressContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_barContainerView addSubview:_progressContainerView];
        
        _progressBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 2.0)];
        _progressBar.backgroundColor = [[VKThemeManager sharedManager] accentColor];
        [_progressContainerView addSubview:_progressBar];
        
        // Иконка / Обложка
        _coverImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 32, 32)];
        _coverImageView.layer.cornerRadius = 6.0;
        _coverImageView.clipsToBounds = YES;
        _coverImageView.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:242.0/255.0 blue:250.0/255.0 alpha:1.0];
        _coverImageView.contentMode = UIViewContentModeCenter;
        
        UILabel *noteLbl = [[UILabel alloc] initWithFrame:_coverImageView.bounds];
        noteLbl.text = @"🎵";
        noteLbl.font = [UIFont systemFontOfSize:15];
        noteLbl.textAlignment = NSTextAlignmentCenter;
        [_coverImageView addSubview:noteLbl];
        [_barContainerView addSubview:_coverImageView];
        
        // Название трека и исполнитель
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 7, frame.size.width - 165, 17)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_barContainerView addSubview:_titleLabel];
        
        _artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 25, frame.size.width - 165, 15)];
        _artistLabel.font = [UIFont systemFontOfSize:11];
        _artistLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [_barContainerView addSubview:_artistLabel];
        
        // Кнопка Play / Pause
        _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playPauseButton.frame = CGRectMake(frame.size.width - 110, 6, 34, 36);
        _playPauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
        [_playPauseButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
        _playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [_playPauseButton addTarget:self action:@selector(playPauseTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_barContainerView addSubview:_playPauseButton];
        
        // Кнопка Next ⏭
        _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _nextButton.frame = CGRectMake(frame.size.width - 74, 6, 34, 36);
        _nextButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_nextButton setTitle:@"⏭" forState:UIControlStateNormal];
        [_nextButton setTitleColor:[UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateNormal];
        _nextButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [_nextButton addTarget:self action:@selector(nextTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_barContainerView addSubview:_nextButton];
        
        // Кнопка Свернуть / Закрыть ✕
        _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _closeButton.frame = CGRectMake(frame.size.width - 38, 6, 32, 36);
        _closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_closeButton setTitle:@"✕" forState:UIControlStateNormal];
        [_closeButton setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
        _closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_closeButton addTarget:self action:@selector(closeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_barContainerView addSubview:_closeButton];
        
        // -------------------------------------------------------------
        // 2. Плавающий кружок (Floating Bubble Container)
        // -------------------------------------------------------------
        _bubbleContainerView = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - 54, 2, 44, 44)];
        _bubbleContainerView.backgroundColor = [UIColor colorWithWhite:0.98 alpha:0.96];
        _bubbleContainerView.layer.cornerRadius = 22.0;
        _bubbleContainerView.layer.borderWidth = 1.5;
        _bubbleContainerView.layer.borderColor = [[VKThemeManager sharedManager] accentColor].CGColor;
        _bubbleContainerView.layer.shadowColor = [UIColor blackColor].CGColor;
        _bubbleContainerView.layer.shadowOffset = CGSizeMake(0, 2);
        _bubbleContainerView.layer.shadowOpacity = 0.25;
        _bubbleContainerView.layer.shadowRadius = 4.0;
        _bubbleContainerView.clipsToBounds = NO;
        _bubbleContainerView.hidden = YES;
        _bubbleContainerView.alpha = 0.0;
        [self addSubview:_bubbleContainerView];
        
        _bubblePulseView = [[UIView alloc] initWithFrame:_bubbleContainerView.bounds];
        _bubblePulseView.backgroundColor = [[[VKThemeManager sharedManager] accentColor] colorWithAlphaComponent:0.2];
        _bubblePulseView.layer.cornerRadius = 22.0;
        _bubblePulseView.clipsToBounds = YES;
        _bubblePulseView.hidden = YES;
        [_bubbleContainerView addSubview:_bubblePulseView];
        
        _bubbleNoteLabel = [[UILabel alloc] initWithFrame:_bubbleContainerView.bounds];
        _bubbleNoteLabel.text = @"🎵";
        _bubbleNoteLabel.font = [UIFont systemFontOfSize:20];
        _bubbleNoteLabel.textAlignment = NSTextAlignmentCenter;
        [_bubbleContainerView addSubview:_bubbleNoteLabel];
        
        UITapGestureRecognizer *bubbleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bubbleTapped)];
        [_bubbleContainerView addGestureRecognizer:bubbleTap];
        
        UIPanGestureRecognizer *bubblePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleBubblePan:)];
        bubblePan.delegate = self;
        [_bubbleContainerView addGestureRecognizer:bubblePan];
        
        // -------------------------------------------------------------
        // Уведомления
        // -------------------------------------------------------------
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerStateChanged:) name:VKAudioPlayerStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerProgressChanged:) name:VKAudioPlayerProgressNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sideMenuStateChanged:) name:VKSideMenuStateDidChangeNotification object:nil];
        
        [self applyThemeStyle];
        [self reloadData];
    }
    return self;
}

- (void)applyThemeStyle {
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    UIColor *bgCol = isSkeuo ? [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98] : [UIColor colorWithWhite:0.98 alpha:0.96];
    
    self.barContainerView.backgroundColor = bgCol;
    self.titleLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.artistLabel.textColor = [[VKThemeManager sharedManager] secondaryTextColor];
    self.progressBar.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    [self.playPauseButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
    
    self.bubbleContainerView.backgroundColor = bgCol;
    self.bubbleContainerView.layer.borderColor = [[VKThemeManager sharedManager] accentColor].CGColor;
    self.bubblePulseView.backgroundColor = [[[VKThemeManager sharedManager] accentColor] colorWithAlphaComponent:0.25];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications

- (void)audioPlayerStateChanged:(NSNotification *)note {
    VKAudioPlayer *player = [VKAudioPlayer sharedPlayer];
    VKAudioTrack *track = player.currentTrack;
    
    if (track) {
        // Если трек сменился на новый, восстанавливаем видимость
        if (self.lastTrackTitle && ![self.lastTrackTitle isEqualToString:track.title]) {
            self.isDismissed = NO;
        }
        self.lastTrackTitle = track.title;
        [self reloadData];
        
        if (!self.isDismissed && self.superview) {
            self.hidden = NO;
        }
    } else {
        self.lastTrackTitle = nil;
        [self hideAnimated:YES];
    }
}

- (void)audioPlayerProgressChanged:(NSNotification *)note {
    VKAudioPlayer *player = [VKAudioPlayer sharedPlayer];
    if (player.duration > 0) {
        CGFloat progress = player.currentTime / player.duration;
        CGFloat w = self.barContainerView.bounds.size.width * progress;
        self.progressBar.frame = CGRectMake(0, 0, w, 2.0);
    }
}

- (void)sideMenuStateChanged:(NSNotification *)note {
    // Если боковое меню открыто, мягко прячем или смещаем панель, чтобы не перекрывать меню
    if ([VKSideMenuManager sharedManager].isMenuOpen) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0.0;
        }];
    } else if (!self.isDismissed && [VKAudioPlayer sharedPlayer].currentTrack != nil) {
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 1.0;
        }];
    }
}

#pragma mark - Data

- (void)reloadData {
    VKAudioPlayer *player = [VKAudioPlayer sharedPlayer];
    VKAudioTrack *t = player.currentTrack;
    
    if (t) {
        self.titleLabel.text = t.title ?: @"Аудиозапись";
        self.artistLabel.text = t.artist ?: @"Неизвестный исполнитель";
        [self.playPauseButton setTitle:(player.isPlaying ? @"⏸" : @"▶") forState:UIControlStateNormal];
        
        if (player.isPlaying) {
            self.bubblePulseView.hidden = NO;
            [self startBubblePulseAnimation];
        } else {
            self.bubblePulseView.hidden = YES;
            [self.bubblePulseView.layer removeAllAnimations];
        }
    } else {
        self.titleLabel.text = @"";
        self.artistLabel.text = @"";
        self.bubblePulseView.hidden = YES;
    }
}

- (void)startBubblePulseAnimation {
    [self.bubblePulseView.layer removeAllAnimations];
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulse.duration = 0.8;
    pulse.fromValue = @(1.0);
    pulse.toValue = @(1.18);
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    pulse.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [self.bubblePulseView.layer addAnimation:pulse forKey:@"pulse"];
}

#pragma mark - Gestures & Actions

- (void)playPauseTapped:(UIButton *)btn {
    [[VKAudioPlayer sharedPlayer] togglePlayPause];
}

- (void)nextTapped:(UIButton *)btn {
    [[VKAudioPlayer sharedPlayer] nextTrack];
}

- (void)closeButtonTapped:(UIButton *)btn {
    // При нажатии на ✕ — сворачиваем в плавающий кружок
    [self collapseToFloatingBubbleAnimated:YES];
}

- (void)swipeDownToCollapse {
    [self collapseToFloatingBubbleAnimated:YES];
}

- (void)swipeRightToCollapse {
    [self collapseToFloatingBubbleAnimated:YES];
}

- (void)swipeLeftForNext {
    [[VKAudioPlayer sharedPlayer] nextTrack];
    
    // Легкая анимация подтверждения свайпа
    [UIView animateWithDuration:0.15 animations:^{
        self.barContainerView.transform = CGAffineTransformMakeTranslation(-20, 0);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.15 animations:^{
            self.barContainerView.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)barTapped {
    if (self.onTapBar) {
        self.onTapBar();
    } else {
        [self openFullScreenPlayer];
    }
}

- (void)bubbleTapped {
    [self expandToBarAnimated:YES];
}

- (void)openFullScreenPlayer {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    VKAudioPlayerViewController *playerVC = [[VKAudioPlayerViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:playerVC];
    [topVC presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Bubble Drag & Snap (Pan Gesture)

- (void)handleBubblePan:(UIPanGestureRecognizer *)pan {
    if (!self.isCollapsed || !self.superview) return;
    
    UIView *parent = self.superview;
    CGPoint translation = [pan translationInView:parent];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panGestureStartCenter = self.frame.origin;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGRect curFrame = self.frame;
        curFrame.origin.x += translation.x;
        curFrame.origin.y += translation.y;
        self.frame = curFrame;
        [pan setTranslation:CGPointZero inView:parent];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // Проверяем смахнули ли кружок далеко за экран вниз/вбок для полного закрытия
        CGPoint velocity = [pan velocityInView:parent];
        if (self.frame.origin.x < -30 || self.frame.origin.x > parent.bounds.size.width - 10 ||
            self.frame.origin.y > parent.bounds.size.height - 20 || ABS(velocity.y) > 1200) {
            [self hideFullyAnimated:YES];
            return;
        }
        
        // Магнитим к ближайшему краю экрана (слева или справа)
        CGFloat parentW = parent.bounds.size.width;
        CGFloat parentH = parent.bounds.size.height;
        CGFloat targetX = (self.frame.origin.x + self.frame.size.width / 2.0 < parentW / 2.0) ? 10.0 : (parentW - 54.0);
        
        CGFloat minY = 70.0; // ниже навбара
        CGFloat maxY = parentH - self.currentBottomOffset - 56.0; // выше таббара
        CGFloat targetY = MIN(maxY, MAX(minY, self.frame.origin.y));
        
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.frame = CGRectMake(targetX, targetY, 44, 44);
        } completion:nil];
    }
}

#pragma mark - Modes (Expand / Collapse / Hide)

- (void)collapseToFloatingBubbleAnimated:(BOOL)animated {
    if (!self.superview || self.isCollapsed) return;
    self.isCollapsed = YES;
    self.currentMode = VKMiniPlayerModeFloatingBubble;
    
    CGFloat parentW = self.superview.bounds.size.width;
    CGFloat parentH = self.superview.bounds.size.height;
    
    CGFloat bubbleX = parentW - 54.0;
    CGFloat bubbleY = parentH - self.currentBottomOffset - 58.0;
    
    self.bubbleContainerView.hidden = NO;
    self.bubbleContainerView.frame = CGRectMake(0, 0, 44, 44);
    
    void (^collapseBlock)(void) = ^{
        self.barContainerView.alpha = 0.0;
        self.bubbleContainerView.alpha = 1.0;
        self.frame = CGRectMake(bubbleX, bubbleY, 44, 44);
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished) {
        self.barContainerView.hidden = YES;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:collapseBlock completion:completionBlock];
    } else {
        collapseBlock();
        completionBlock(YES);
    }
}

- (void)expandToBarAnimated:(BOOL)animated {
    if (!self.superview || !self.isCollapsed) return;
    self.isCollapsed = NO;
    self.isDismissed = NO;
    self.currentMode = VKMiniPlayerModeExpandedBar;
    
    CGFloat parentW = self.superview.bounds.size.width;
    CGFloat parentH = self.superview.bounds.size.height;
    CGFloat barY = parentH - self.currentBottomOffset - 48.0;
    
    self.barContainerView.hidden = NO;
    self.barContainerView.frame = CGRectMake(0, 0, parentW, 48.0);
    
    void (^expandBlock)(void) = ^{
        self.frame = CGRectMake(0, barY, parentW, 48.0);
        self.bubbleContainerView.alpha = 0.0;
        self.barContainerView.alpha = 1.0;
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished) {
        self.bubbleContainerView.hidden = YES;
    };
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:expandBlock completion:completionBlock];
    } else {
        expandBlock();
        completionBlock(YES);
    }
}

- (void)hideFullyAnimated:(BOOL)animated {
    self.isDismissed = YES;
    self.currentMode = VKMiniPlayerModeHidden;
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 0.0;
            self.transform = CGAffineTransformMakeTranslation(0, 50);
        } completion:^(BOOL finished) {
            self.hidden = YES;
            self.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.alpha = 0.0;
        self.hidden = YES;
    }
}

- (void)restoreIfPlayingInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset {
    if ([VKAudioPlayer sharedPlayer].currentTrack != nil) {
        self.isDismissed = NO;
        [self showInView:parentView bottomOffset:bottomOffset];
    }
}

#pragma mark - Public Layout

- (void)showInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset {
    self.currentBottomOffset = bottomOffset;
    if (self.isDismissed) return;
    
    CGFloat width = parentView.bounds.size.width;
    CGFloat height = parentView.bounds.size.height;
    
    if (!self.isCollapsed) {
        self.frame = CGRectMake(0, height - bottomOffset - 48, width, 48);
        self.barContainerView.frame = self.bounds;
        self.barContainerView.hidden = NO;
        self.barContainerView.alpha = 1.0;
        self.bubbleContainerView.hidden = YES;
        self.bubbleContainerView.alpha = 0.0;
    } else {
        self.frame = CGRectMake(width - 54, height - bottomOffset - 58, 44, 44);
        self.bubbleContainerView.frame = CGRectMake(0, 0, 44, 44);
        self.bubbleContainerView.hidden = NO;
        self.bubbleContainerView.alpha = 1.0;
        self.barContainerView.hidden = YES;
        self.barContainerView.alpha = 0.0;
    }
    
    if (!self.superview) {
        [parentView addSubview:self];
        self.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 1.0;
        }];
    } else {
        [parentView bringSubviewToFront:self];
        self.hidden = NO;
        self.alpha = 1.0;
    }
    [self reloadData];
}

- (void)hideAnimated:(BOOL)animated {
    if (animated) {
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 0.0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    } else {
        [self removeFromSuperview];
    }
}

- (void)updateLayoutWithBottomOffset:(CGFloat)bottomOffset {
    if (!self.superview) return;
    self.currentBottomOffset = bottomOffset;
    CGFloat width = self.superview.bounds.size.width;
    CGFloat height = self.superview.bounds.size.height;
    
    if (!self.isCollapsed) {
        self.frame = CGRectMake(0, height - bottomOffset - 48, width, 48);
        self.barContainerView.frame = self.bounds;
    }
}

@end
