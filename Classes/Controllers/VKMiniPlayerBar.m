#import "VKMiniPlayerBar.h"
#import "VKThemeManager.h"
#import "VKAudioPlayerViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface VKMiniPlayerBar ()

@property (nonatomic, strong) UIView *progressContainerView;
@property (nonatomic, strong) UIView *progressBar;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, assign) CGFloat currentBottomOffset;

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
        self.backgroundColor = [UIColor colorWithWhite:0.98 alpha:0.96];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, -1);
        self.layer.shadowOpacity = 0.12;
        self.layer.shadowRadius = 2.0;
        self.clipsToBounds = NO;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(barTapped)];
        [self addGestureRecognizer:tap];
        
        // Полоса прогресса
        _progressContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 2.0)];
        _progressContainerView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _progressContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_progressContainerView];
        
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
        [self addSubview:_coverImageView];
        
        // Название трека и исполнитель
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 7, frame.size.width - 145, 17)];
        _titleLabel.font = [UIFont boldSystemFontOfSize:13];
        _titleLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
        _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_titleLabel];
        
        _artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(50, 25, frame.size.width - 145, 15)];
        _artistLabel.font = [UIFont systemFontOfSize:11];
        _artistLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_artistLabel];
        
        // Кнопка Play / Pause
        _playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playPauseButton.frame = CGRectMake(frame.size.width - 86, 6, 36, 36);
        _playPauseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
        [_playPauseButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
        _playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [_playPauseButton addTarget:self action:@selector(playPauseTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_playPauseButton];
        
        // Кнопка Next ⏭
        _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _nextButton.frame = CGRectMake(frame.size.width - 44, 6, 36, 36);
        _nextButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_nextButton setTitle:@"⏭" forState:UIControlStateNormal];
        [_nextButton setTitleColor:[UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateNormal];
        _nextButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [_nextButton addTarget:self action:@selector(nextTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_nextButton];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerStateChanged:) name:VKAudioPlayerStateDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioPlayerProgressChanged:) name:VKAudioPlayerProgressNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
        
        [self applyThemeStyle];
        [self reloadData];
    }
    return self;
}

- (void)applyThemeStyle {
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    self.backgroundColor = isSkeuo ? [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98] : [UIColor colorWithWhite:0.98 alpha:0.96];
    self.titleLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    self.artistLabel.textColor = [[VKThemeManager sharedManager] secondaryTextColor];
    self.progressBar.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    [self.playPauseButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)audioPlayerStateChanged:(NSNotification *)note {
    [self reloadData];
}

- (void)audioPlayerProgressChanged:(NSNotification *)note {
    VKAudioPlayer *player = [VKAudioPlayer sharedPlayer];
    if (player.duration > 0) {
        CGFloat progress = player.currentTime / player.duration;
        CGFloat w = self.bounds.size.width * progress;
        self.progressBar.frame = CGRectMake(0, 0, w, 2.0);
    }
}

- (void)reloadData {
    VKAudioPlayer *player = [VKAudioPlayer sharedPlayer];
    VKAudioTrack *t = player.currentTrack;
    
    if (t) {
        self.titleLabel.text = t.title ?: @"Аудиозапись";
        self.artistLabel.text = t.artist ?: @"Неизвестный исполнитель";
        [self.playPauseButton setTitle:(player.isPlaying ? @"⏸" : @"▶") forState:UIControlStateNormal];
    } else {
        self.titleLabel.text = @"";
        self.artistLabel.text = @"";
    }
}

- (void)playPauseTapped:(UIButton *)btn {
    [[VKAudioPlayer sharedPlayer] togglePlayPause];
}

- (void)nextTapped:(UIButton *)btn {
    [[VKAudioPlayer sharedPlayer] nextTrack];
}

- (void)barTapped {
    if (self.onTapBar) {
        self.onTapBar();
    } else {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *topVC = keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        
        VKAudioPlayerViewController *playerVC = [[VKAudioPlayerViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:playerVC];
        [topVC presentViewController:nav animated:YES completion:nil];
    }
}

- (void)showInView:(UIView *)parentView bottomOffset:(CGFloat)bottomOffset {
    self.currentBottomOffset = bottomOffset;
    CGFloat width = parentView.bounds.size.width;
    CGFloat height = parentView.bounds.size.height;
    
    self.frame = CGRectMake(0, height - bottomOffset - 48, width, 48);
    if (!self.superview) {
        [parentView addSubview:self];
        self.alpha = 0.0;
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 1.0;
        }];
    } else {
        [parentView bringSubviewToFront:self];
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
    self.frame = CGRectMake(0, height - bottomOffset - 48, width, 48);
}

@end
