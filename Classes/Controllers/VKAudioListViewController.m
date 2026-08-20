#import "VKAudioListViewController.h"
#import "VKAudioService.h"
#import "VKAudioPlayer.h"
#import "VKAudioPlayerViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKImageLoader.h"

@interface VKAudioListViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSArray<VKAudioTrack *> *allTracks;
@property (nonatomic, strong) NSArray<VKAudioTrack *> *filteredTracks;
@property (nonatomic, strong) UIView *miniPlayerView;
@property (nonatomic, strong) UILabel *miniTitleLabel;
@property (nonatomic, strong) UIButton *miniPlayButton;
@end

@implementation VKAudioListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    self = [super init];
    if (self) {
        _userId = userId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Аудиозаписи";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    // SearchBar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск по музыке...";
    [self.view addSubview:self.searchBar];
    
    // TableView
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, width, height - 44 - 50) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 54.0;
    [self.view addSubview:self.tableView];
    
    // Мини-плеер внизу
    self.miniPlayerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 50, width, 50)];
    self.miniPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.miniPlayerView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98];
    self.miniPlayerView.layer.borderWidth = 0.5;
    self.miniPlayerView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
    
    UITapGestureRecognizer *tapMini = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openFullPlayer)];
    [self.miniPlayerView addGestureRecognizer:tapMini];
    
    self.miniTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 6, width - 76, 38)];
    self.miniTitleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.miniTitleLabel.textColor = [UIColor colorWithRed:40.0/255.0 green:40.0/255.0 blue:50.0/255.0 alpha:1.0];
    self.miniTitleLabel.text = @"Выберите трек для воспроизведения";
    [self.miniPlayerView addSubview:self.miniTitleLabel];
    
    self.miniPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.miniPlayButton.frame = CGRectMake(width - 50, 7, 36, 36);
    self.miniPlayButton.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    self.miniPlayButton.layer.cornerRadius = 18.0;
    self.miniPlayButton.clipsToBounds = YES;
    [self.miniPlayButton setTitle:@"▶" forState:UIControlStateNormal];
    [self.miniPlayButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.miniPlayButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.miniPlayButton addTarget:self action:@selector(miniPlayTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.miniPlayerView addSubview:self.miniPlayButton];
    
    [self.view addSubview:self.miniPlayerView];
    
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerStateChanged) name:VKAudioPlayerStateDidChangeNotification object:nil];
    
    [self loadAudios];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    if (self.navigationController.viewControllers.firstObject == self) {
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

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    [self.tableView reloadData];
    [self updateMiniPlayerUI];
}

- (void)loadAudios {
    [[VKAudioService sharedService] fetchAudiosWithUserId:self.userId offset:0 count:50 completion:^(NSArray<VKAudioTrack *> *tracks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allTracks = tracks ?: @[];
            self.filteredTracks = self.allTracks;
            [self.tableView reloadData];
        });
    }];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *q = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (q.length == 0) {
        self.filteredTracks = self.allTracks;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", q, q];
        self.filteredTracks = [self.allTracks filteredArrayUsingPredicate:pred];
    }
    [self.tableView reloadData];
}

- (void)miniPlayTapped {
    [[VKAudioPlayer sharedPlayer] togglePlayPause];
}

- (void)openFullPlayer {
    if ([VKAudioPlayer sharedPlayer].currentTrack) {
        VKAudioPlayerViewController *vc = [[VKAudioPlayerViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)playerStateChanged {
    [self updateMiniPlayerUI];
    [self.tableView reloadData];
}

- (void)updateMiniPlayerUI {
    VKAudioTrack *t = [VKAudioPlayer sharedPlayer].currentTrack;
    if (t) {
        self.miniTitleLabel.text = [NSString stringWithFormat:@"%@ — %@", t.artist, t.title];
        [self.miniPlayButton setTitle:[VKAudioPlayer sharedPlayer].isPlaying ? @"❚❚" : @"▶" forState:UIControlStateNormal];
    } else {
        self.miniTitleLabel.text = @"Аудиозаписи";
        [self.miniPlayButton setTitle:@"▶" forState:UIControlStateNormal];
    }
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *AudioCellId = @"VKAudioListTrackCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AudioCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AudioCellId];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    
    VKAudioTrack *track = self.filteredTracks[indexPath.row];
    BOOL isPlayingThis = [[VKAudioPlayer sharedPlayer].currentTrack.title isEqualToString:track.title] && [[VKAudioPlayer sharedPlayer].currentTrack.artist isEqualToString:track.artist];
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    cell.textLabel.text = [NSString stringWithFormat:@"%@  %@", isPlayingThis ? (@"▶") : @"🎵", track.title ?: @"Трек"];
    if (isPlayingThis) {
        cell.textLabel.textColor = [[VKThemeManager sharedManager] accentColor];
    } else if (isSkeuomorph) {
        cell.textLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        cell.textLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", track.artist ?: @"Исполнитель", track.duration ?: @"3:00"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[VKAudioPlayer sharedPlayer] playPlaylist:self.filteredTracks startIndex:indexPath.row];
}

@end
