#import "VKVideoPlayerViewController.h"
#import "VKAPIClient.h"
#import "VKAudioPlayer.h"
#import "VKCrashLogger.h"
#import <AVFoundation/AVFoundation.h>

@interface VKVideoPlayerViewController ()
@property (nonatomic, strong) VKAttachment *attachment;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VKVideoPlayerViewController

- (instancetype)initWithVideoURL:(NSURL *)videoURL {
    self = [super initWithContentURL:videoURL];
    if (self) {
        _attachment = nil;
        [self setupPlayerOptions];
    }
    return self;
}

- (instancetype)initWithAttachment:(VKAttachment *)attachment {
    NSURL *url = nil;
    if (attachment.videoURL.length > 0) {
        url = [NSURL URLWithString:attachment.videoURL];
    }
    self = [super initWithContentURL:url];
    if (self) {
        _attachment = attachment;
        [self setupPlayerOptions];
    }
    return self;
}

- (void)setupPlayerOptions {
    // 1. Приостанавливаем музыкальный плеер, чтобы он не забирал аудиоканал
    if ([[VKAudioPlayer sharedPlayer] isPlaying]) {
        [[VKAudioPlayer sharedPlayer] pause];
    }
    
    // 2. Настраиваем нативную аудиосессию воспроизведения
    [self configureAudioSession];
    
    if (self.moviePlayer) {
        self.moviePlayer.controlStyle = MPMovieControlStyleFullscreen;
        self.moviePlayer.shouldAutoplay = YES;
        self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlaybackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];
}

- (void)configureAudioSession {
    @try {
        NSError *audioError = nil;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&audioError];
        [session setActive:YES error:&audioError];
        [VKCrashLogger log:@"[VKVideoPlayer] AudioSession category Playback configured."];
    } @catch (NSException *ex) {
        [VKCrashLogger log:[NSString stringWithFormat:@"[VKVideoPlayer] AudioSession exception: %@", ex]];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self configureAudioSession];
    
    // Кнопка закрытия для режима WebView или при задержке
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(12, 28, 40, 40);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.closeButton.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
    self.closeButton.layer.cornerRadius = 20.0;
    self.closeButton.clipsToBounds = YES;
    self.closeButton.hidden = YES;
    [self.closeButton addTarget:self action:@selector(closePlayerAction) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.closeButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    if (self.moviePlayer.contentURL) {
        [self.moviePlayer play];
    } else if (self.attachment) {
        [self fetchVideoDirectURL];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self configureAudioSession];
}

- (void)fetchVideoDirectURL {
    [self.spinner startAnimating];
    
    NSString *videoKey = [NSString stringWithFormat:@"%ld_%ld", (long)self.attachment.ownerId, (long)self.attachment.videoId];
    [VKCrashLogger log:[NSString stringWithFormat:@"[VKVideoPlayer] Fetching video details for key: %@", videoKey]];
    
    NSDictionary *params = @{
        @"videos": videoKey,
        @"extended": @"1"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"video.get" parameters:params completionHandler:^(id response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            
            if (error) {
                [VKCrashLogger log:[NSString stringWithFormat:@"[VKVideoPlayer] Error fetching video: %@", error]];
                [self closePlayerAction];
                return;
            }
            
            NSDictionary *resp = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
            NSArray *items = resp[@"items"] ?: @[];
            if (items.count > 0) {
                NSDictionary *item = items[0];
                
                NSString *directURL = nil;
                if ([item[@"files"] isKindOfClass:[NSDictionary class]]) {
                    NSDictionary *files = item[@"files"];
                    directURL = files[@"mp4_720"] ?: files[@"mp4_480"] ?: files[@"mp4_360"] ?: files[@"mp4_240"] ?: files[@"mp4_1080"] ?: files[@"src"] ?: files[@"url"];
                }
                
                if (directURL.length == 0) {
                    directURL = item[@"url"] ?: item[@"direct_url"];
                }
                
                NSString *embedPlayerURL = item[@"player"];
                
                if (directURL.length > 0) {
                    [VKCrashLogger log:[NSString stringWithFormat:@"[VKVideoPlayer] Playing direct MP4 URL: %@", directURL]];
                    [self configureAudioSession];
                    self.moviePlayer.contentURL = [NSURL URLWithString:directURL];
                    [self.moviePlayer play];
                } else if (embedPlayerURL.length > 0) {
                    [VKCrashLogger log:[NSString stringWithFormat:@"[VKVideoPlayer] Opening web embed player: %@", embedPlayerURL]];
                    [self openWebEmbedPlayerWithURL:[NSURL URLWithString:embedPlayerURL]];
                } else {
                    [VKCrashLogger log:@"[VKVideoPlayer] No playable video URL found."];
                    [self closePlayerAction];
                }
            } else {
                [self closePlayerAction];
            }
        });
    }];
}

- (void)openWebEmbedPlayerWithURL:(NSURL *)url {
    if (!self.webView) {
        self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.webView.allowsInlineMediaPlayback = YES;
        self.webView.mediaPlaybackRequiresUserAction = NO;
        self.webView.backgroundColor = [UIColor blackColor];
        [self.view insertSubview:self.webView belowSubview:self.closeButton];
    }
    
    self.closeButton.hidden = NO;
    [self.view bringSubviewToFront:self.closeButton];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)closePlayerAction {
    if (self.webView) {
        [self.webView loadHTMLString:@"" baseURL:nil];
    }
    if (self.moviePlayer) {
        [self.moviePlayer stop];
    }
    [self dismissMoviePlayerViewControllerAnimated];
    if ([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)moviePlaybackDidFinish:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo];
    NSNumber *reason = userInfo[MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    if (reason && [reason intValue] == MPMovieFinishReasonUserExited) {
        [self closePlayerAction];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
