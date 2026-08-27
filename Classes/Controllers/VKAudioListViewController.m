#import "VKAudioListViewController.h"
#import "VKAudioService.h"
#import "VKAudioPlayer.h"
#import "VKAudioPlayerViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKImageLoader.h"
#import "VKAuthService.h"
#import "VKAudioAlbum.h"

@interface VKAudioListViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, assign) NSInteger userId;
@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, copy) NSString *albumTitle;

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *footerSpinner;

@property (nonatomic, strong) NSMutableArray<VKAudioTrack *> *allTracks;
@property (nonatomic, strong) NSArray<VKAudioTrack *> *filteredTracks;
@property (nonatomic, strong) NSArray<VKAudioAlbum *> *albums;

@property (nonatomic, assign) NSInteger selectedTab; // 0: My, 1: Albums, 2: Popular, 3: Recommendations
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) BOOL hasMore;
@end

@implementation VKAudioListViewController

- (instancetype)initWithUserId:(NSInteger)userId {
    return [self initWithUserId:userId albumId:0 albumTitle:nil];
}

- (instancetype)initWithUserId:(NSInteger)userId albumId:(NSInteger)albumId albumTitle:(NSString *)albumTitle {
    self = [super init];
    if (self) {
        _userId = userId;
        _albumId = albumId;
        _albumTitle = albumTitle;
        _selectedTab = 0;
        _allTracks = [NSMutableArray array];
        _filteredTracks = @[];
        _albums = @[];
        _hasMore = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (self.albumId > 0) {
        self.title = self.albumTitle.length > 0 ? self.albumTitle : @"Альбом";
    } else {
        self.title = @"Аудиозаписи";
    }
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    CGFloat topOffset = 0;
    
    // 1. Header Container with Segmented Control & SearchBar (только если не в отдельном альбоме)
    if (self.albumId == 0) {
        topOffset = 84.0;
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, topOffset)];
        headerView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
        
        self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Мои", @"Альбомы", @"Топ", @"Реком."]];
        self.segmentedControl.frame = CGRectMake(10, 6, width - 20, 28);
        self.segmentedControl.selectedSegmentIndex = self.selectedTab;
        [self.segmentedControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
        [headerView addSubview:self.segmentedControl];
        
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 40, width, 44)];
        self.searchBar.delegate = self;
        self.searchBar.placeholder = @"Поиск по музыке...";
        [headerView addSubview:self.searchBar];
        
        [self.view addSubview:headerView];
    }
    
    // 2. TableView
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, topOffset, width, height - topOffset) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 56.0;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 52.0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 52.0, 0);
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(loadAudios) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refreshControl];
    
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    self.footerSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.footerSpinner.center = CGPointMake(width / 2.0, 22.0);
    self.footerSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.footerSpinner.hidesWhenStopped = YES;
    [footerView addSubview:self.footerSpinner];
    self.tableView.tableFooterView = footerView;
    
    [self.view addSubview:self.tableView];
    
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

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.segmentedControl.tintColor = [[VKThemeManager sharedManager] accentColor];
    [self.tableView reloadData];
}

- (void)segmentChanged:(UISegmentedControl *)seg {
    self.selectedTab = seg.selectedSegmentIndex;
    self.searchBar.text = @"";
    [self loadAudios];
}

- (void)loadAudios {
    [self.refreshControl beginRefreshing];
    self.hasMore = YES;
    self.isLoadingMore = NO;
    
    if (self.selectedTab == 1 && self.albumId == 0) {
        // Загрузка списка альбомов
        [[VKAudioService sharedService] fetchAlbumsWithUserId:self.userId offset:0 count:50 completion:^(NSArray<VKAudioAlbum *> *albums, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.refreshControl endRefreshing];
                self.albums = albums ?: @[];
                [self.tableView reloadData];
            });
        }];
        return;
    }
    
    void (^completion)(NSArray<VKAudioTrack *> *tracks, NSError *error) = ^(NSArray<VKAudioTrack *> *tracks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            [self.allTracks removeAllObjects];
            if (tracks) [self.allTracks addObjectsFromArray:tracks];
            self.filteredTracks = [self.allTracks copy];
            self.hasMore = (tracks.count >= 40);
            [self.tableView reloadData];
        });
    };
    
    if (self.albumId > 0) {
        [[VKAudioService sharedService] fetchAudiosWithUserId:self.userId albumId:self.albumId offset:0 count:50 completion:completion];
    } else if (self.selectedTab == 0) {
        [[VKAudioService sharedService] fetchAudiosWithUserId:self.userId offset:0 count:50 completion:completion];
    } else if (self.selectedTab == 2) {
        [[VKAudioService sharedService] fetchPopularAudiosWithOffset:0 count:50 completion:completion];
    } else if (self.selectedTab == 3) {
        [[VKAudioService sharedService] fetchRecommendationsWithOffset:0 count:50 completion:completion];
    }
}

- (void)loadMoreAudios {
    if (self.isLoadingMore || !self.hasMore || (self.selectedTab == 1 && self.albumId == 0)) return;
    if (self.searchBar.text.length > 0) return;
    
    self.isLoadingMore = YES;
    [self.footerSpinner startAnimating];
    
    NSInteger nextOffset = self.allTracks.count;
    void (^completion)(NSArray<VKAudioTrack *> *tracks, NSError *error) = ^(NSArray<VKAudioTrack *> *tracks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.footerSpinner stopAnimating];
            self.isLoadingMore = NO;
            if (tracks.count > 0) {
                [self.allTracks addObjectsFromArray:tracks];
                self.filteredTracks = [self.allTracks copy];
                self.hasMore = (tracks.count >= 40);
                [self.tableView reloadData];
            } else {
                self.hasMore = NO;
            }
        });
    };
    
    if (self.albumId > 0) {
        [[VKAudioService sharedService] fetchAudiosWithUserId:self.userId albumId:self.albumId offset:nextOffset count:50 completion:completion];
    } else if (self.selectedTab == 0) {
        [[VKAudioService sharedService] fetchAudiosWithUserId:self.userId offset:nextOffset count:50 completion:completion];
    } else if (self.selectedTab == 2) {
        [[VKAudioService sharedService] fetchPopularAudiosWithOffset:nextOffset count:50 completion:completion];
    } else if (self.selectedTab == 3) {
        [[VKAudioService sharedService] fetchRecommendationsWithOffset:nextOffset count:50 completion:completion];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (self.selectedTab == 1 && self.albumId == 0) {
        // Поиск по альбомам
        NSString *q = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (q.length == 0) {
            [self.tableView reloadData];
        } else {
            [self.tableView reloadData];
        }
        return;
    }
    
    NSString *q = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (q.length == 0) {
        self.filteredTracks = [self.allTracks copy];
        [self.tableView reloadData];
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", q, q];
        self.filteredTracks = [self.allTracks filteredArrayUsingPredicate:pred];
        [self.tableView reloadData];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *q = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (q.length > 0) {
        [[VKAudioService sharedService] searchAudiosWithQuery:q offset:0 count:60 completion:^(NSArray<VKAudioTrack *> *tracks, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (tracks.count > 0) {
                    self.filteredTracks = tracks;
                    [self.tableView reloadData];
                }
            });
        }];
    }
}

- (void)playerStateChanged {
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.selectedTab == 1 && self.albumId == 0) {
        return self.albums.count;
    }
    return self.filteredTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    // Вкладка "Альбомы"
    if (self.selectedTab == 1 && self.albumId == 0) {
        static NSString *AlbumCellId = @"VKAudioAlbumCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AlbumCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:AlbumCellId];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
            
            UIImageView *albumCover = [[UIImageView alloc] initWithFrame:CGRectMake(10, 6, 44, 44)];
            albumCover.tag = 601;
            albumCover.layer.cornerRadius = 4.0;
            albumCover.clipsToBounds = YES;
            albumCover.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:233.0/255.0 blue:238.0/255.0 alpha:1.0];
            albumCover.contentMode = UIViewContentModeScaleAspectFill;
            [cell.contentView addSubview:albumCover];
            
            UILabel *albumIcon = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 44, 44)];
            albumIcon.tag = 602;
            albumIcon.text = @"💿";
            albumIcon.textAlignment = NSTextAlignmentCenter;
            albumIcon.font = [UIFont systemFontOfSize:22];
            [cell.contentView addSubview:albumIcon];
        }
        
        UIImageView *albumCover = (UIImageView *)[cell.contentView viewWithTag:601];
        UILabel *albumIcon = (UILabel *)[cell.contentView viewWithTag:602];
        
        VKAudioAlbum *album = self.albums[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"      %@", album.title ?: @"Альбом"];
        cell.textLabel.textColor = isSkeuomorph ? [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"      %ld аудиозаписей", (long)album.trackCount];
        
        if (album.thumbURL.length > 0) {
            albumIcon.hidden = YES;
            albumCover.image = nil;
            [[VKImageLoader sharedLoader] loadImageWithURL:album.thumbURL completion:^(UIImage *img) {
                if (img) albumCover.image = img;
            }];
        } else {
            albumCover.image = nil;
            albumIcon.hidden = NO;
        }
        return cell;
    }
    
    // Вкладка треков
    static NSString *AudioCellId = @"VKAudioListTrackCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AudioCellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AudioCellId];
        
        UIImageView *coverIv = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 40, 40)];
        coverIv.tag = 501;
        coverIv.layer.cornerRadius = 4.0;
        coverIv.clipsToBounds = YES;
        coverIv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:242.0/255.0 alpha:1.0];
        coverIv.contentMode = UIViewContentModeScaleAspectFill;
        [cell.contentView addSubview:coverIv];
        
        UILabel *noteLbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 40, 40)];
        noteLbl.tag = 502;
        noteLbl.text = @"♫";
        noteLbl.textAlignment = NSTextAlignmentCenter;
        noteLbl.font = [UIFont systemFontOfSize:20];
        noteLbl.textColor = [UIColor colorWithRed:170.0/255.0 green:175.0/255.0 blue:185.0/255.0 alpha:1.0];
        [cell.contentView addSubview:noteLbl];
        
        UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLbl.tag = 503;
        titleLbl.font = [UIFont boldSystemFontOfSize:14];
        [cell.contentView addSubview:titleLbl];
        
        UILabel *artistLbl = [[UILabel alloc] initWithFrame:CGRectZero];
        artistLbl.tag = 504;
        artistLbl.font = [UIFont systemFontOfSize:12];
        artistLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        [cell.contentView addSubview:artistLbl];
        
        UILabel *durLbl = [[UILabel alloc] initWithFrame:CGRectZero];
        durLbl.tag = 505;
        durLbl.font = [UIFont systemFontOfSize:11.5];
        durLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        durLbl.textAlignment = NSTextAlignmentRight;
        [cell.contentView addSubview:durLbl];
    }
    
    CGFloat width = tableView.bounds.size.width;
    UIImageView *coverIv = (UIImageView *)[cell.contentView viewWithTag:501];
    UILabel *noteLbl = (UILabel *)[cell.contentView viewWithTag:502];
    UILabel *titleLbl = (UILabel *)[cell.contentView viewWithTag:503];
    UILabel *artistLbl = (UILabel *)[cell.contentView viewWithTag:504];
    UILabel *durLbl = (UILabel *)[cell.contentView viewWithTag:505];
    
    VKAudioTrack *track = self.filteredTracks[indexPath.row];
    BOOL isPlayingThis = [[VKAudioPlayer sharedPlayer].currentTrack.title isEqualToString:track.title] && [[VKAudioPlayer sharedPlayer].currentTrack.artist isEqualToString:track.artist];
    
    titleLbl.frame = CGRectMake(60, 9, width - 125, 19);
    artistLbl.frame = CGRectMake(60, 29, width - 125, 17);
    durLbl.frame = CGRectMake(width - 60, 18, 50, 20);
    
    durLbl.text = track.duration ?: @"";
    artistLbl.text = track.artist ?: @"Исполнитель";
    
    if (isPlayingThis) {
        titleLbl.text = [NSString stringWithFormat:@"▶ %@", track.title ?: @"Трек"];
        titleLbl.textColor = [[VKThemeManager sharedManager] accentColor];
    } else if (isSkeuomorph) {
        titleLbl.text = track.title ?: @"Трек";
        titleLbl.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        titleLbl.text = track.title ?: @"Трек";
        titleLbl.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    if (track.coverURL.length > 0) {
        noteLbl.hidden = YES;
        coverIv.image = nil;
        [[VKImageLoader sharedLoader] loadImageWithURL:track.coverURL completion:^(UIImage *img) {
            if (img) coverIv.image = img;
        }];
    } else {
        coverIv.image = nil;
        noteLbl.hidden = NO;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.selectedTab != 1 || self.albumId > 0) {
        if (indexPath.row >= (NSInteger)self.filteredTracks.count - 4) {
            [self loadMoreAudios];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (self.selectedTab == 1 && self.albumId == 0) {
        VKAudioAlbum *album = self.albums[indexPath.row];
        VKAudioListViewController *albumVC = [[VKAudioListViewController alloc] initWithUserId:self.userId albumId:album.albumId albumTitle:album.title];
        [self.navigationController pushViewController:albumVC animated:YES];
        return;
    }
    
    [[VKAudioPlayer sharedPlayer] playPlaylist:self.filteredTracks startIndex:indexPath.row];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return (self.selectedTab == 0 && self.albumId == 0);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        VKAudioTrack *track = self.filteredTracks[indexPath.row];
        [[VKAudioService sharedService] deleteAudioWithAudioId:track.audioId ownerId:track.ownerId completion:^(BOOL success, NSError *error) {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.allTracks removeObject:track];
                    NSMutableArray *mFilt = [self.filteredTracks mutableCopy];
                    [mFilt removeObject:track];
                    self.filteredTracks = [mFilt copy];
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                });
            }
        }];
    }
}

@end
