#import "VKAudioPlayerViewController.h"
#import "VKAudioPlayer.h"
#import "VKAudioService.h"
#import "VKProjectMGLView.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import <MediaPlayer/MediaPlayer.h>

@interface VKAudioPlayerViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIView *coverContainerView;
@property (nonatomic, strong) UILabel *notePlaceholderLabel;
@property (nonatomic, strong) UIImageView *coverImageView;
@property (nonatomic, strong) VKProjectMGLView *visualizerView;

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

@property (nonatomic, assign) BOOL isUserScrubbing;
@property (nonatomic, assign) BOOL isVisualizerActive;
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
    // 1. Navigation Bar
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:(isFlat ? @"Готово" : @"Закрыть")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(closeAction)];
    
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
    self.progressSlider.tintColor = [UIColor colorWithRed:230.0/255.0 green:70.0/255.0 blue:80.0/255.0 alpha:1.0];
    UIImage *thumbImg = [UIImage imageNamed:@"7_audioplayer_thumb"] ?: [UIImage imageNamed:@"AudioPlayer_TimeControl"];
    if (thumbImg) {
        [self.progressSlider setThumbImage:thumbImg forState:UIControlStateNormal];
    }
    [self.progressSlider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.progressSlider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.progressSlider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.view addSubview:self.progressSlider];
    
    // 4. Панель из 4 кнопок (Повтор, Добавить, Статус, Перемешать)
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
    
    self.shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *hornImg = [UIImage imageNamed:@"7_audioplayer_horn"];
    if (hornImg) [self.shareButton setImage:hornImg forState:UIControlStateNormal];
    else [self.shareButton setTitle:@"📢" forState:UIControlStateNormal];
    [self.shareButton addTarget:self action:@selector(shareAction) forControlEvents:UIControlEventTouchUpInside];
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
    self.visualizerView.frame = self.coverContainerView.bounds;
    
    // 2. Таймлайн прогресса
    CGFloat sliderY = coverY + coverSize + 14.0;
    self.timeElapsedLabel.frame = CGRectMake(16, sliderY, 44, 20);
    self.timeRemainingLabel.frame = CGRectMake(w - 60, sliderY, 44, 20);
    self.progressSlider.frame = CGRectMake(64, sliderY - 5, w - 128, 30);
    
    // 3. Панель из 4 кнопок
    CGFloat subBtnY = sliderY + 30.0;
    CGFloat quarterW = w / 4.0;
    self.repeatButton.frame = CGRectMake(0, subBtnY, quarterW, 36);
    self.addButton.frame = CGRectMake(quarterW, subBtnY, quarterW, 36);
    self.shareButton.frame = CGRectMake(quarterW * 2, subBtnY, quarterW, 36);
    self.shuffleButton.frame = CGRectMake(quarterW * 3, subBtnY, quarterW, 36);
    
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
    
    NSInteger curIdx = [VKAudioPlayer sharedPlayer].currentIndex + 1;
    NSInteger total = [VKAudioPlayer sharedPlayer].playlist.count;
    if (total > 0) {
        self.title = [NSString stringWithFormat:@"%ld из %ld", (long)curIdx, (long)total];
    } else {
        self.title = @"Сейчас играет";
    }
    
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

@end
