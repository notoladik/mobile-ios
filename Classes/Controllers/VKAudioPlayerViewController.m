#import "VKAudioPlayerViewController.h"
#import "VKAudioPlayer.h"
#import "VKAudioService.h"
#if ENABLE_MILKDROP_VISUALIZER
#import "VKProjectMGLView.h"
#endif
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import <MediaPlayer/MediaPlayer.h>

#import "VKAudioCacheManager.h"
#import "VKMiniPlayerBar.h"

@interface VKAudioPlayerViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIView *coverContainerView;
@property (nonatomic, strong) UILabel *notePlaceholderLabel;
@property (nonatomic, strong) UIImageView *coverImageView;
#if ENABLE_MILKDROP_VISUALIZER
@property (nonatomic, strong) VKProjectMGLView *visualizerView;
#endif
@property (nonatomic, strong) UIView *lyricsContainerView;
@property (nonatomic, strong) UITextView *lyricsTextView;
@property (nonatomic, strong) UIButton *lyricsCloseButton;
@property (nonatomic, strong) UIButton *cacheButton;

@property (nonatomic, strong) UISlider *progressSlider;
@property (nonatomic, strong) UILabel *timeElapsedLabel;
@property (nonatomic, strong) UILabel *timeRemainingLabel;

@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) UIButton *addButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIButton *shuffleButton;

@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playPauseButton;
@property (nonatomic, strong) UIButton *nextButton;

@property (nonatomic, strong) MPVolumeView *volumeView;

@property (nonatomic, strong) UIView *navHeaderView;
@property (nonatomic, strong) UILabel *navTitleLabel;
@property (nonatomic, strong) UILabel *navSubtitleLabel;

@property (nonatomic, assign) BOOL isUserScrubbing;
@property (nonatomic, assign) BOOL isVisualizerActive;
@property (nonatomic, assign) BOOL isLyricsVisible;
@end

@implementation VKAudioPlayerViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self layoutAllViews];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [VKMiniPlayerBar sharedBar].hidden = YES;
#if ENABLE_MILKDROP_VISUALIZER
    if (self.isVisualizerActive) {
        [self.visualizerView startAnimation];
    }
#endif
    [self updateUI];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [VKMiniPlayerBar sharedBar].hidden = NO;
#if ENABLE_MILKDROP_VISUALIZER
    [self.visualizerView stopAnimation];
#endif
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    self.view.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:242.0/255.0 blue:245.0/255.0 alpha:1.0];
    
    // Читаем настройку визуализатора из настроек (по умолчанию включен)
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"openvk.audio.visualizer.enabled"]) {
        self.isVisualizerActive = [[NSUserDefaults standardUserDefaults] boolForKey:@"openvk.audio.visualizer.enabled"];
    } else {
        self.isVisualizerActive = YES;
    }
    
    // 1. Navigation Bar
    if (!isFlat) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Закрыть" target:self action:@selector(closeAction) isBack:NO];
    } else {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово"
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(closeAction)];
    }
    
    UIImage *playlistImg = [UIImage imageNamed:@"7_audioplayer_playlist"];
    if (playlistImg) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:playlistImg
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(playlistAction)];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"☰"
                                                                                  style:UIBarButtonItemStylePlain
                                                                                 target:self
                                                                                 action:@selector(playlistAction)];
    }
    
    self.navHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 36)];
    self.navTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 1, 180, 18)];
    self.navTitleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.navTitleLabel.textColor = [UIColor whiteColor];
    self.navTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.navHeaderView addSubview:self.navTitleLabel];
    
    self.navSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 19, 180, 14)];
    self.navSubtitleLabel.font = [UIFont systemFontOfSize:11];
    self.navSubtitleLabel.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    self.navSubtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.navHeaderView addSubview:self.navSubtitleLabel];
    
    self.navigationItem.titleView = self.navHeaderView;
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem.tintColor = [UIColor whiteColor];
    
    // Жест свайпа вниз для закрытия плеера
    UISwipeGestureRecognizer *swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(closeAction)];
    swipeDown.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipeDown];
    
    // 2. Контейнер обложки / Визуализатора
    self.coverContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.coverContainerView.backgroundColor = [UIColor colorWithRed:232.0/255.0 green:234.0/255.0 blue:238.0/255.0 alpha:1.0];
    self.coverContainerView.layer.cornerRadius = 6.0;
    self.coverContainerView.clipsToBounds = YES;
    self.coverContainerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleCoverOrVisualizer)];
    [self.coverContainerView addGestureRecognizer:tap];
    [self.view addSubview:self.coverContainerView];
    
    // Нота ♫ по центру (оригинал VK iOS 7)
    self.notePlaceholderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.notePlaceholderLabel.text = @"♫";
    self.notePlaceholderLabel.font = [UIFont systemFontOfSize:60];
    self.notePlaceholderLabel.textColor = [UIColor colorWithRed:175.0/255.0 green:180.0/255.0 blue:190.0/255.0 alpha:1.0];
    self.notePlaceholderLabel.textAlignment = NSTextAlignmentCenter;
    [self.coverContainerView addSubview:self.notePlaceholderLabel];
    
    // Обложка альбома
    self.coverImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.coverImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.coverImageView.clipsToBounds = YES;
    [self.coverContainerView addSubview:self.coverImageView];
    
#if ENABLE_MILKDROP_VISUALIZER
    // Официальный OpenGL ES визуализатор Milkdrop 2 (projectM)
    self.visualizerView = [[VKProjectMGLView alloc] initWithFrame:CGRectZero];
    self.visualizerView.hidden = !self.isVisualizerActive;
    [self.coverContainerView addSubview:self.visualizerView];
    if (self.isVisualizerActive) {
        [self.coverContainerView bringSubviewToFront:self.visualizerView];
    }
#endif
    
    // Оверлей текста песни (Lyrics)
    self.lyricsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.lyricsContainerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    self.lyricsContainerView.hidden = YES;
    [self.coverContainerView addSubview:self.lyricsContainerView];
    
    self.lyricsTextView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.lyricsTextView.backgroundColor = [UIColor clearColor];
    self.lyricsTextView.textColor = [UIColor whiteColor];
    self.lyricsTextView.font = [UIFont systemFontOfSize:15];
    self.lyricsTextView.editable = NO;
    self.lyricsTextView.textAlignment = NSTextAlignmentCenter;
    [self.lyricsContainerView addSubview:self.lyricsTextView];
    
    self.lyricsCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.lyricsCloseButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.lyricsCloseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.lyricsCloseButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.lyricsCloseButton addTarget:self action:@selector(hideLyrics) forControlEvents:UIControlEventTouchUpInside];
    [self.lyricsContainerView addSubview:self.lyricsCloseButton];
    
    // 3. Таймлайн прогресса
    self.timeElapsedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeElapsedLabel.font = [UIFont systemFontOfSize:12];
    self.timeElapsedLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.timeElapsedLabel.text = @"0:00";
    [self.view addSubview:self.timeElapsedLabel];
    
    self.timeRemainingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.timeRemainingLabel.font = [UIFont systemFontOfSize:12];
    self.timeRemainingLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.timeRemainingLabel.textAlignment = NSTextAlignmentRight;
    self.timeRemainingLabel.text = @"-0:00";
    [self.view addSubview:self.timeRemainingLabel];
    
    self.progressSlider = [[UISlider alloc] initWithFrame:CGRectZero];
    self.progressSlider.minimumValue = 0.0;
    self.progressSlider.maximumValue = 1.0;
    
    UIImage *trackMin = [UIImage imageNamed:@"7_audioplayer_track_min"];
    UIImage *trackMax = [UIImage imageNamed:@"7_audioplayer_track_max"];
    if (trackMin) [self.progressSlider setMinimumTrackImage:trackMin forState:UIControlStateNormal];
    if (trackMax) [self.progressSlider setMaximumTrackImage:trackMax forState:UIControlStateNormal];
    
    UIImage *thumbImg = [UIImage imageNamed:@"7_audioplayer_thumb"] ?: [UIImage imageNamed:@"AudioPlayer_TimeControl"];
    if (thumbImg) {
        [self.progressSlider setThumbImage:thumbImg forState:UIControlStateNormal];
        [self.progressSlider setThumbImage:thumbImg forState:UIControlStateHighlighted];
    }
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.progressSlider];
    
    // 4. Панель кнопок (Повтор, Добавить, Оффлайн-кэш, Слова, Перемешать)
    self.repeatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *repImg = [UIImage imageNamed:@"7_audioplayer_repeat"];
    if (repImg) [self.repeatButton setImage:repImg forState:UIControlStateNormal];
    else [self.repeatButton setTitle:@"🔁" forState:UIControlStateNormal];
    [self.repeatButton addTarget:self action:@selector(toggleRepeatAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.repeatButton];
    
    self.addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *addImg = [UIImage imageNamed:@"7_audioplayer_add"];
    if (addImg) [self.addButton setImage:addImg forState:UIControlStateNormal];
    else [self.addButton setTitle:@"+" forState:UIControlStateNormal];
    [self.addButton addTarget:self action:@selector(addToMyAudiosAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.addButton];
    
    // Кнопка оффлайн-кэширования (⤓ / ✓)
    self.cacheButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.cacheButton setTitle:@"⤓" forState:UIControlStateNormal];
    [self.cacheButton setTitleColor:[UIColor colorWithWhite:0.35 alpha:1.0] forState:UIControlStateNormal];
    self.cacheButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [self.cacheButton addTarget:self action:@selector(cacheCurrentTrackAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cacheButton];
    
    self.shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.shareButton setTitle:@"TXT" forState:UIControlStateNormal];
    [self.shareButton setTitleColor:[UIColor colorWithWhite:0.35 alpha:1.0] forState:UIControlStateNormal];
    self.shareButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [self.shareButton addTarget:self action:@selector(showLyricsAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.shareButton];
    
    self.shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *shufImg = [UIImage imageNamed:@"7_audioplayer_shuffle"];
    if (shufImg) [self.shuffleButton setImage:shufImg forState:UIControlStateNormal];
    else [self.shuffleButton setTitle:@"🔀" forState:UIControlStateNormal];
    [self.shuffleButton addTarget:self action:@selector(toggleShuffleAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.shuffleButton];
    
    // 5. Главные кнопки воспроизведения (◀◀, ❚❚/▶, ▶▶)
    self.prevButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *prevImg = [UIImage imageNamed:@"7_audioplayer_previous"];
    if (prevImg) [self.prevButton setImage:prevImg forState:UIControlStateNormal];
    else [self.prevButton setTitle:@"◀◀" forState:UIControlStateNormal];
    [self.prevButton addTarget:self action:@selector(prevAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.prevButton];
    
    self.playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *playImg = [UIImage imageNamed:@"7_audioplayer_play"];
    if (playImg) [self.playPauseButton setImage:playImg forState:UIControlStateNormal];
    else [self.playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
    [self.playPauseButton addTarget:self action:@selector(playPauseAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playPauseButton];
    
    self.nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *nextImg = [UIImage imageNamed:@"7_audioplayer_next"];
    if (nextImg) [self.nextButton setImage:nextImg forState:UIControlStateNormal];
    else [self.nextButton setTitle:@"▶▶" forState:UIControlStateNormal];
    [self.nextButton addTarget:self action:@selector(nextAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.nextButton];
    
    // 6. Слайдер громкости (MPVolumeView)
    self.volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
    self.volumeView.showsRouteButton = NO;
    [self.view addSubview:self.volumeView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUI) name:VKAudioPlayerStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProgress) name:VKAudioPlayerProgressNotification object:nil];
    
    [self layoutAllViews];
    [self updateUI];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutAllViews];
}

- (void)layoutAllViews {
    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    if (w <= 0 || h <= 0) return;
    
    // 1. Квадратный контейнер обложки
    CGFloat coverMargin = 16.0;
    CGFloat availableCoverH = h - 230.0;
    CGFloat coverSize = MIN(w - coverMargin * 2.0, MAX(140.0, availableCoverH));
    CGFloat coverX = (w - coverSize) / 2.0;
    CGFloat coverY = 12.0;
    
    self.coverContainerView.frame = CGRectMake(coverX, coverY, coverSize, coverSize);
    self.notePlaceholderLabel.frame = self.coverContainerView.bounds;
    self.coverImageView.frame = self.coverContainerView.bounds;
#if ENABLE_MILKDROP_VISUALIZER
    self.visualizerView.frame = self.coverContainerView.bounds;
#endif
    self.lyricsContainerView.frame = self.coverContainerView.bounds;
    self.lyricsTextView.frame = CGRectMake(10, 34, coverSize - 20, coverSize - 44);
    self.lyricsCloseButton.frame = CGRectMake(coverSize - 36, 2, 32, 32);
    
    // 2. Таймлайн прогресса
    CGFloat sliderY = coverY + coverSize + 14.0;
    self.timeElapsedLabel.frame = CGRectMake(16, sliderY, 44, 20);
    self.timeRemainingLabel.frame = CGRectMake(w - 60, sliderY, 44, 20);
    self.progressSlider.frame = CGRectMake(64, sliderY - 5, w - 128, 30);
    
    // 3. Панель из 5 кнопок (Повтор, Добавить, Кэш, Слова, Перемешать)
    CGFloat subBtnY = sliderY + 30.0;
    CGFloat btnW = w / 5.0;
    self.repeatButton.frame = CGRectMake(0, subBtnY, btnW, 36);
    self.addButton.frame = CGRectMake(btnW, subBtnY, btnW, 36);
    self.cacheButton.frame = CGRectMake(btnW * 2, subBtnY, btnW, 36);
    self.shareButton.frame = CGRectMake(btnW * 3, subBtnY, btnW, 36);
    self.shuffleButton.frame = CGRectMake(btnW * 4, subBtnY, btnW, 36);
    
    // 4. Главные кнопки воспроизведения
    CGFloat mainBtnY = subBtnY + 44.0;
    CGFloat centerBtnW = 60.0;
    CGFloat centerBtnX = (w - centerBtnW) / 2.0;
    
    self.prevButton.frame = CGRectMake(centerBtnX - 76.0, mainBtnY + 4, 52, 52);
    self.playPauseButton.frame = CGRectMake(centerBtnX, mainBtnY, centerBtnW, 60);
    self.nextButton.frame = CGRectMake(centerBtnX + centerBtnW + 24.0, mainBtnY + 4, 52, 52);
    
    // 5. Слайдер громкости внизу
    CGFloat volY = h - 42.0;
    self.volumeView.frame = CGRectMake(32, volY, w - 64, 24);
}

- (void)showLyricsAction {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (!track) return;
    
    self.isLyricsVisible = YES;
    self.lyricsContainerView.hidden = NO;
    [self.coverContainerView bringSubviewToFront:self.lyricsContainerView];
    self.lyricsTextView.text = @"Загрузка текста песни...";
    
    [[VKAudioService sharedService] getLyricsWithLyricsId:track.lyricsID completion:^(NSString *lyricsText, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (lyricsText && lyricsText.length > 0) {
                self.lyricsTextView.text = lyricsText;
            } else {
                self.lyricsTextView.text = [NSString stringWithFormat:@"%@ — %@\n\n(Текст песни не найден)", track.artist ?: @"", track.title ?: @""];
            }
        });
    }];
}

- (void)hideLyrics {
    self.isLyricsVisible = NO;
    self.lyricsContainerView.hidden = YES;
}

- (void)cacheCurrentTrackAction {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (!track) return;
    
    if ([[VKAudioCacheManager sharedManager] isTrackCached:track]) {
        [[VKAudioCacheManager sharedManager] removeCachedTrack:track];
        [self.cacheButton setTitle:@"⬇" forState:UIControlStateNormal];
        [self.cacheButton setTitleColor:[UIColor colorWithWhite:0.3 alpha:1.0] forState:UIControlStateNormal];
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Оффлайн-кэш" message:@"Трек удален из памяти устройства" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [a show];
    } else {
        [self.cacheButton setTitle:@"⏳" forState:UIControlStateNormal];
        [[VKAudioCacheManager sharedManager] cacheTrack:track completion:^(BOOL success, NSString *filePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.cacheButton setTitle:@"✓" forState:UIControlStateNormal];
                    [self.cacheButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Оффлайн-кэш" message:@"Трек успешно сохранен для прослушивания без интернета!" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [a show];
                } else {
                    [self.cacheButton setTitle:@"⬇" forState:UIControlStateNormal];
                    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Не удалось скачать аудиозапись" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [a show];
                }
            });
        }];
    }
}

- (void)toggleCoverOrVisualizer {
#if ENABLE_MILKDROP_VISUALIZER
    if (!self.isVisualizerActive) {
        self.isVisualizerActive = YES;
        self.visualizerView.hidden = NO;
        [self.coverContainerView bringSubviewToFront:self.visualizerView];
        [self.visualizerView showPresetBadge];
    } else {
        [self.visualizerView nextPreset];
    }
    [[NSUserDefaults standardUserDefaults] setBool:self.isVisualizerActive forKey:@"openvk.audio.visualizer.enabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playlistAction {
    NSArray *pl = [VKAudioPlayer sharedPlayer].playlist;
    NSString *title = [NSString stringWithFormat:@"Текущий плейлист (%ld)", (long)pl.count];
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title
                                                       delegate:self
                                              cancelButtonTitle:@"Закрыть"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    sheet.tag = 5001;
    [sheet showInView:self.view];
}

- (void)toggleRepeatAction {
    NSInteger r = [VKAudioPlayer sharedPlayer].repeatMode;
    [VKAudioPlayer sharedPlayer].repeatMode = (r + 1) % 3;
    [self updateButtonsStyle];
}

- (void)toggleShuffleAction {
    [VKAudioPlayer sharedPlayer].isShuffleEnabled = ![VKAudioPlayer sharedPlayer].isShuffleEnabled;
    [self updateButtonsStyle];
}

- (void)addToMyAudiosAction {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (!track) return;
    
    [[VKAudioService sharedService] addAudioWithAudioId:track.trackId ownerId:track.ownerId completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                            message:success ? @"Аудиозапись добавлена" : @"Не удалось добавить"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        });
    }];
}

- (void)shareAction {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (!track) return;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Транслировать в статус", @"Поделиться на стене", nil];
    sheet.tag = 5002;
    [sheet showInView:self.view];
}

- (void)prevAction {
    [[VKAudioPlayer sharedPlayer] previousTrack];
}

- (void)nextAction {
    [[VKAudioPlayer sharedPlayer] nextTrack];
}

- (void)playPauseAction {
    [[VKAudioPlayer sharedPlayer] togglePlayPause];
}

- (void)sliderTouchDown {
    self.isUserScrubbing = YES;
}

- (void)sliderValueChanged:(UISlider *)slider {
    NSTimeInterval dur = [VKAudioPlayer sharedPlayer].duration;
    NSTimeInterval cur = slider.value * dur;
    self.timeElapsedLabel.text = [self formatTime:cur];
    self.timeRemainingLabel.text = [NSString stringWithFormat:@"-%@", [self formatTime:MAX(0, dur - cur)]];
}

- (void)sliderTouchUp {
    self.isUserScrubbing = NO;
    NSTimeInterval dur = [VKAudioPlayer sharedPlayer].duration;
    [[VKAudioPlayer sharedPlayer] seekToTime:self.progressSlider.value * dur];
}

- (void)updateUI {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (!track) return;
    
    self.navTitleLabel.text = track.title ?: @"Аудиозапись";
    self.navSubtitleLabel.text = track.artist ?: @"Исполнитель";
    
    BOOL isPlaying = [VKAudioPlayer sharedPlayer].isPlaying;
    UIImage *playPauseImg = [UIImage imageNamed:(isPlaying ? @"7_audioplayer_pause" : @"7_audioplayer_play")];
    if (playPauseImg) {
        [self.playPauseButton setImage:playPauseImg forState:UIControlStateNormal];
        [self.playPauseButton setTitle:@"" forState:UIControlStateNormal];
    } else {
        [self.playPauseButton setTitle:isPlaying ? @"❚❚" : @"▶" forState:UIControlStateNormal];
        self.playPauseButton.titleLabel.font = [UIFont boldSystemFontOfSize:isPlaying ? 24 : 32];
    }
    
#if ENABLE_MILKDROP_VISUALIZER
    self.visualizerView.isPlaying = isPlaying;
#endif
    
    if (track.coverURL && track.coverURL.length > 0) {
        self.coverImageView.hidden = NO;
        [[VKImageLoader sharedLoader] loadImageWithURL:track.coverURL completion:^(UIImage *img) {
            if (img) self.coverImageView.image = img;
        }];
    } else {
        self.coverImageView.image = nil;
        self.coverImageView.hidden = YES;
    }
    
#if ENABLE_MILKDROP_VISUALIZER
    self.visualizerView.hidden = !self.isVisualizerActive;
    if (self.isVisualizerActive) {
        [self.coverContainerView bringSubviewToFront:self.visualizerView];
    }
#endif
    
    [self updateButtonsStyle];
    [self updateProgress];
}

- (void)updateButtonsStyle {
    VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
    if (track && [[VKAudioCacheManager sharedManager] isTrackCached:track]) {
        [self.cacheButton setTitle:@"✓" forState:UIControlStateNormal];
        [self.cacheButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.cacheButton setTitle:@"⤓" forState:UIControlStateNormal];
        [self.cacheButton setTitleColor:[UIColor colorWithWhite:0.35 alpha:1.0] forState:UIControlStateNormal];
    }
    
    // 1. Повтор
    NSInteger repeatMode = [VKAudioPlayer sharedPlayer].repeatMode;
    UIImage *repSetImg = [UIImage imageNamed:@"7_audioplayer_repeat_set"];
    UIImage *repNormImg = [UIImage imageNamed:@"7_audioplayer_repeat"];
    if (repeatMode == 0) {
        if (repNormImg) [self.repeatButton setImage:repNormImg forState:UIControlStateNormal];
        self.repeatButton.alpha = 0.45;
    } else {
        if (repSetImg) [self.repeatButton setImage:repSetImg forState:UIControlStateNormal];
        self.repeatButton.alpha = 1.0;
    }
    
    // 2. Перемешать
    BOOL isShuffle = [VKAudioPlayer sharedPlayer].isShuffleEnabled;
    UIImage *shufSetImg = [UIImage imageNamed:@"7_audioplayer_shuffle_set"];
    UIImage *shufNormImg = [UIImage imageNamed:@"7_audioplayer_shuffle"];
    if (isShuffle) {
        if (shufSetImg) [self.shuffleButton setImage:shufSetImg forState:UIControlStateNormal];
        self.shuffleButton.alpha = 1.0;
    } else {
        if (shufNormImg) [self.shuffleButton setImage:shufNormImg forState:UIControlStateNormal];
        self.shuffleButton.alpha = 0.45;
    }
}

- (void)updateProgress {
    if (self.isUserScrubbing) return;
    
    NSTimeInterval cur = [VKAudioPlayer sharedPlayer].currentTime;
    NSTimeInterval dur = [VKAudioPlayer sharedPlayer].duration;
    
    if (dur > 0) {
        self.progressSlider.value = cur / dur;
    } else {
        self.progressSlider.value = 0.0;
    }
    
    self.timeElapsedLabel.text = [self formatTime:cur];
    self.timeRemainingLabel.text = [NSString stringWithFormat:@"-%@", [self formatTime:MAX(0, dur - cur)]];
}

- (NSString *)formatTime:(NSTimeInterval)interval {
    NSInteger sec = (NSInteger)interval;
    NSInteger m = sec / 60;
    NSInteger s = sec % 60;
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 5002) {
        // 0: Транслировать в статус
        VKAudioTrack *track = [VKAudioPlayer sharedPlayer].currentTrack;
        if (!track) return;
        
        if (buttonIndex == 0) {
            NSString *audioStr = [NSString stringWithFormat:@"%ld_%ld", (long)track.ownerId, (long)track.audioId];
            [[VKAudioService sharedService] setBroadcastAudio:audioStr completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                                    message:success ? @"Статус обновлен" : @"Не удалось транслировать в статус"
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alert show];
                });
            }];
        }
    }
}

@end
