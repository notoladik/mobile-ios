#import "VKLikesListViewController.h"
#import "VKFeedViewController.h"
#import "VKFeedPostCell.h"
#import "VKFeedService.h"
#import "VKPostDetailViewController.h"
#import "VKProfileViewController.h"
#import "VKNewPostViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKGifViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"
#import "VKPost.h"
#import "VKOfflinePlaceholderView.h"
#import "VKNetworkStatusManager.h"
#import "VKShareManager.h"
#import "VKAppConfig.h"

typedef NS_ENUM(NSInteger, VKFeedTypeMode) {
    VKFeedTypeModeMyNews = 0,
    VKFeedTypeModeAllNews = 1,
    VKFeedTypeModeRecommended = 2
};

@interface VKFeedViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSMutableArray *posts;
@property (nonatomic, strong) VKPost *selectedPostForAction;
@property (nonatomic, strong) NSMutableSet *revealedPostIds;
@property (nonatomic, copy) NSString *nextFrom;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) VKFeedTypeMode feedMode;
@property (nonatomic, strong) UIButton *titleButton;
@end

@implementation VKFeedViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKFeedViewController] viewDidLoad started."];
    
    self.posts = [NSMutableArray array];
    self.revealedPostIds = [NSMutableSet set];
    self.feedMode = VKFeedTypeModeMyNews;
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = YES;
    }
    
    [self applyCurrentThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyCurrentThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkStatusDidChange:) name:VKNetworkStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nsfwSettingDidChange) name:VKNSFWSettingDidChangeNotification object:nil];
    
    [self setupNavigationItems];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadFeedFromStart:YES];
}

- (void)nsfwSettingDidChange {
    [self.tableView reloadData];
}

- (NSArray<VKPost *> *)visiblePosts {
    if ([VKAppConfig isNSFWFilterEnabled] && [VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeHideCompletely) {
        NSMutableArray *res = [NSMutableArray array];
        for (VKPost *p in self.posts) {
            if (!p.isExplicit) {
                [res addObject:p];
            }
        }
        return res;
    }
    return self.posts;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyCurrentThemeStyle];
}

- (void)networkStatusDidChange:(NSNotification *)note {
    if ([[VKNetworkStatusManager sharedManager] isServerReachable] && self.posts.count == 0 && !self.isLoading) {
        [self refreshFeed];
    }
}

- (void)applyCurrentThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    UIColor *titleColor = [[VKThemeManager sharedManager] navBarTitleColor];
    [self.titleButton setTitleColor:titleColor forState:UIControlStateNormal];
    
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.titleButton.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.titleButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    } else {
        self.titleButton.titleLabel.shadowColor = nil;
        self.titleButton.titleLabel.shadowOffset = CGSizeZero;
    }
    
    UINavigationBar *bar = self.navigationController.navigationBar;
    if (bar) {
        bar.barTintColor = [[VKThemeManager sharedManager] navBarBackgroundColor];
        bar.tintColor = [[VKThemeManager sharedManager] navBarTintColor];
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [[VKThemeManager sharedManager] navBarTitleColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
    
    [self setupNavigationItems];
    [self.tableView reloadData];
}

- (void)setupNavigationItems {
    self.titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.titleButton.frame = CGRectMake(0, 0, 160, 32);
    [self.titleButton setTitle:[self titleForFeedMode:self.feedMode] forState:UIControlStateNormal];
    [self.titleButton setTitleColor:[[VKThemeManager sharedManager] navBarTitleColor] forState:UIControlStateNormal];
    self.titleButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.titleButton.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.titleButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    }
    [self.titleButton addTarget:self action:@selector(selectFeedType) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.titleView = self.titleButton;
    
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
    } else {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarRefreshBarButtonItemWithTarget:self action:@selector(refreshAction)];
    }
    self.navigationItem.rightBarButtonItem = [[VKThemeManager sharedManager] navBarComposeBarButtonItemWithTarget:self action:@selector(newPostAction)];
}

- (void)leftMenuButtonAction {
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        [[VKSideMenuManager sharedManager] toggleMenu];
    } else {
        [self loadFeedFromStart:YES];
    }
}

- (void)refreshAction {
    [self loadFeedFromStart:YES];
}

- (NSString *)titleForFeedMode:(VKFeedTypeMode)mode {
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        switch (mode) {
            case VKFeedTypeModeMyNews: return @"Новости ▾";
            case VKFeedTypeModeAllNews: return @"Все новости ▾";
            case VKFeedTypeModeRecommended: return @"Рекомендации ▾";
        }
    }
    switch (mode) {
        case VKFeedTypeModeMyNews: return @"Мои новости ▾";
        case VKFeedTypeModeAllNews: return @"Все новости ▾";
        case VKFeedTypeModeRecommended: return @"Рекомендации ▾";
    }
}

- (void)selectFeedType {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Выберите раздел новостей"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Мои новости", @"Все новости", @"Рекомендации", nil];
    sheet.tag = 201;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    if (actionSheet.tag == 201) {
        if (buttonIndex >= 0 && buttonIndex <= 2) {
            self.feedMode = (VKFeedTypeMode)buttonIndex;
            [self.titleButton setTitle:[self titleForFeedMode:self.feedMode] forState:UIControlStateNormal];
            [self loadFeedFromStart:YES];
        }
    } else if (actionSheet.tag == 701 && self.selectedPostForAction) {
        VKPost *p = self.selectedPostForAction;
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([title isEqualToString:@"Поделиться"]) {
            [[VKShareManager sharedManager] presentShareSheetForPost:p fromViewController:self completion:nil];
        } else if ([title isEqualToString:@"Скопировать ссылку"]) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/wall%ld_%ld", (long)p.ownerID, (long)p.vkID];
        } else if ([title isEqualToString:@"Кто оценил"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post" ownerId:p.ownerID itemId:p.vkID initialFilter:0];
            [self.navigationController pushViewController:likesVC animated:YES];
        } else if ([title isEqualToString:@"Кто поделился"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post" ownerId:p.ownerID itemId:p.vkID initialFilter:1];
            [self.navigationController pushViewController:likesVC animated:YES];
        } else if ([title isEqualToString:@"Пожаловаться"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Жалоба" message:@"Спасибо, жалоба отправлена модераторам." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (void)notificationsAction {
    // Всплывающее уведомление
}

- (void)newPostAction {
    VKNewPostViewController *newPostVC = [[VKNewPostViewController alloc] initWithOwnerId:0];
    __weak typeof(self) weakSelf = self;
    newPostVC.onPostCreated = ^{
        [weakSelf loadFeedFromStart:YES];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:newPostVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)refreshFeed {
    [self loadFeedFromStart:YES];
}

- (void)loadFeedFromStart:(BOOL)fromStart {
    if (fromStart) {
        if (self.isLoading) return;
        self.isLoading = YES;
        self.nextFrom = nil;
        
        [VKCrashLogger log:@"[VKFeedViewController] Loading feed from start, mode=%ld", (long)self.feedMode];
        
        NSInteger mode = (NSInteger)self.feedMode;
        __weak typeof(self) weakSelf = self;
        [[VKFeedService sharedService] fetchFeedMode:mode startFrom:nil completion:^(NSArray *posts, NSString *nextFrom, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.isLoading = NO;
                if (NSClassFromString(@"UIRefreshControl") && weakSelf.refreshControl.isRefreshing) {
                    [weakSelf.refreshControl endRefreshing];
                }
                
                if (error) {
                    [VKCrashLogger log:@"[VKFeedViewController] Error loading feed: %@", error.localizedDescription];
                    if (weakSelf.posts.count == 0) {
                        weakSelf.tableView.backgroundView = [VKOfflinePlaceholderView offlinePlaceholderWithFrame:weakSelf.tableView.bounds onRetry:^{
                            [weakSelf refreshFeed];
                        }];
                    }
                    return;
                }
                
                if (posts) {
                    weakSelf.tableView.backgroundView = nil;
                    [weakSelf.posts removeAllObjects];
                    [weakSelf.posts addObjectsFromArray:posts];
                    weakSelf.nextFrom = nextFrom;
                    [weakSelf.tableView reloadData];
                    [VKCrashLogger log:@"[VKFeedViewController] Feed loaded, total posts: %lu, nextFrom: %@", (unsigned long)weakSelf.posts.count, nextFrom];
                }
            });
        }];
    } else {
        [self loadMoreFeedPosts];
    }
}

- (void)loadMoreFeedPosts {
    if (self.isLoading || self.isLoadingMore || self.nextFrom.length == 0) return;
    self.isLoadingMore = YES;
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 44.0);
    [spinner startAnimating];
    self.tableView.tableFooterView = spinner;
    
    [VKCrashLogger log:@"[VKFeedViewController] Loading more feed posts with nextFrom: %@", self.nextFrom];
    
    NSString *startFrom = self.nextFrom;
    NSInteger mode = (NSInteger)self.feedMode;
    
    __weak typeof(self) weakSelf = self;
    [[VKFeedService sharedService] fetchFeedMode:mode startFrom:startFrom completion:^(NSArray *posts, NSString *nextFrom, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isLoadingMore = NO;
            weakSelf.tableView.tableFooterView = nil;
            
            if (error) {
                [VKCrashLogger log:@"[VKFeedViewController] Error loading more posts: %@", error.localizedDescription];
                return;
            }
            
            if (posts.count > 0) {
                CGPoint preservedOffset = weakSelf.tableView.contentOffset;
                NSMutableSet *existingIds = [NSMutableSet set];
                for (VKPost *p in weakSelf.posts) {
                    [existingIds addObject:@(p.vkID)];
                }
                
                NSMutableArray *newUnique = [NSMutableArray array];
                for (VKPost *p in posts) {
                    if (![existingIds containsObject:@(p.vkID)]) {
                        [newUnique addObject:p];
                        [existingIds addObject:@(p.vkID)];
                    }
                }
                
                NSInteger firstInsertedRow = weakSelf.posts.count;
                [weakSelf.posts addObjectsFromArray:newUnique];
                weakSelf.nextFrom = nextFrom;
                if (newUnique.count > 0) {
                    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:newUnique.count];
                    for (NSInteger i = 0; i < (NSInteger)newUnique.count; i++) {
                        [indexPaths addObject:[NSIndexPath indexPathForRow:firstInsertedRow + i inSection:0]];
                    }
                    [weakSelf.tableView beginUpdates];
                    [weakSelf.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
                    [weakSelf.tableView endUpdates];
                    [weakSelf.tableView setContentOffset:preservedOffset animated:NO];
                }
                [VKCrashLogger log:@"[VKFeedViewController] Appended %lu posts, total %lu, nextFrom: %@", (unsigned long)newUnique.count, (unsigned long)weakSelf.posts.count, nextFrom];
            } else {
                weakSelf.nextFrom = nil;
            }
        });
    }];
}

#pragma mark - UIScrollViewDelegate (Infinite Scroll)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.isLoading || self.isLoadingMore || self.nextFrom.length == 0) return;
    
    CGFloat offsetY = scrollView.contentOffset.y;
    CGFloat contentHeight = scrollView.contentSize.height;
    CGFloat frameHeight = scrollView.bounds.size.height;
    
    if (offsetY > contentHeight - frameHeight * 1.8 && contentHeight > frameHeight) {
        [self loadMoreFeedPosts];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visiblePosts.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *posts = self.visiblePosts;
    if (indexPath.row >= (NSInteger)posts.count) return 44.0;
    VKPost *post = posts[indexPath.row];
    BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
    return [VKFeedPostCell heightForPost:post width:tableView.bounds.size.width isRevealed:isRevealed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"VKFeedPostMasterCardCell";
    VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    NSArray *posts = self.visiblePosts;
    if (indexPath.row >= (NSInteger)posts.count) return cell;
    
    VKPost *post = posts[indexPath.row];
    BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
    [cell configureWithPost:post isRevealed:isRevealed width:tableView.bounds.size.width];
    
    __weak typeof(self) weakSelf = self;
    cell.onLikeTapped = ^(VKPost *p) {
        [[VKFeedService sharedService] likePost:p completion:nil];
    };
    
    cell.onShowLikesTapped = ^(VKPost *p, NSInteger filter) {
        VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post"
                                                                                     ownerId:p.ownerID
                                                                                      itemId:p.vkID
                                                                               initialFilter:filter];
        [weakSelf.navigationController pushViewController:likesVC animated:YES];
    };
    
    cell.onCommentTapped = ^(VKPost *p) {
        if (p) {
            VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:p];
            detailVC.focusCommentInputOnAppear = YES;
            [weakSelf.navigationController pushViewController:detailVC animated:YES];
        }
    };
    
    cell.onRepostTapped = ^(VKPost *p) {
        [[VKShareManager sharedManager] presentShareSheetForPost:p fromViewController:weakSelf completion:^{
            [weakSelf.tableView reloadData];
        }];
    };
    
    cell.onRevealSpoilerTapped = ^(VKPost *p) {
        [weakSelf.revealedPostIds addObject:@(p.vkID)];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    };
    
    cell.onToggleTextExpanded = ^(VKPost *p) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger row = [weakSelf.posts indexOfObject:p];
            if (row != NSNotFound) {
                NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                [weakSelf.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            } else {
                [weakSelf.tableView reloadData];
            }
        });
    };
    
    cell.onToggleRepostTextExpanded = ^(VKPost *p) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger row = [weakSelf.posts indexOfObject:p];
            if (row != NSNotFound) {
                NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
                [weakSelf.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];
            } else {
                [weakSelf.tableView reloadData];
            }
        });
    };
    
    cell.onAuthorTapped = ^(VKUser *author) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:author];
        [weakSelf.navigationController pushViewController:profVC animated:YES];
    };
    
    cell.onPhotosGalleryWithFullURLsTapped = ^(NSArray<NSString *> *photoURLs, NSArray<NSString *> *fullPhotoURLs, NSInteger initialIndex) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs fullPhotoURLs:fullPhotoURLs initialIndex:initialIndex];
        [weakSelf presentViewController:viewer animated:YES completion:nil];
    };
    
    cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
        [weakSelf presentViewController:viewer animated:YES completion:nil];
    };
    
    cell.onPhotoWithFullURLTapped = ^(NSString *photoURL, NSString *fullPhotoURL, UIImage *image) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL fullImageURL:fullPhotoURL initialImage:image];
        [weakSelf presentViewController:viewer animated:YES completion:nil];
    };
    
    cell.onPhotoTapped = ^(NSString *photoURL, UIImage *image) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL initialImage:image];
        [weakSelf presentViewController:viewer animated:YES completion:nil];
    };
    
    cell.onVideoTapped = ^(VKAttachment *videoAttachment) {
        VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:videoAttachment];
        [weakSelf presentMoviePlayerViewControllerAnimated:player];
    };
    
    cell.onAudioTapped = ^(VKAttachment *audioAttachment) {
        [weakSelf.tableView reloadData];
    };
    
    cell.onPollVoted = ^(VKAttachment *pollAttachment, NSInteger optionId) {
        [weakSelf.tableView reloadData];
    };
    
    cell.onDocTapped = ^(VKAttachment *docAttachment) {
        if (docAttachment.docURL.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:docAttachment.docURL]];
        }
    };
    
    cell.onGifTapped = ^(VKAttachment *gifAttachment) {
        VKGifViewerViewController *gifVC = [[VKGifViewerViewController alloc] initWithAttachment:gifAttachment];
        [weakSelf presentViewController:gifVC animated:YES completion:nil];
    };
    
    cell.onLinkTapped = ^(NSString *url) {
        if (url.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
    };
    
    cell.onCopyrightTapped = ^(NSString *url) {
        if (url.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
        }
    };
    
    cell.onOptionsTapped = ^(VKPost *p) {
        weakSelf.selectedPostForAction = p;
        UIActionSheet *sheet = [[UIActionSheet alloc] init];
        sheet.delegate = weakSelf;
        sheet.tag = 701;
        [sheet addButtonWithTitle:@"Поделиться"];
        [sheet addButtonWithTitle:@"Скопировать ссылку"];
        if (p.likesCount > 0) {
            [sheet addButtonWithTitle:@"Кто оценил"];
        }
        if (p.repostsCount > 0) {
            [sheet addButtonWithTitle:@"Кто поделился"];
        }
        [sheet addButtonWithTitle:@"Пожаловаться"];
        sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
        [sheet showInView:weakSelf.view];
    };
    
    // Пагинация при приближении к концу списка
    if (indexPath.row == (NSInteger)self.posts.count - 1 && self.nextFrom.length > 0 && !self.isLoading) {
        [self loadFeedFromStart:NO];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.posts.count) {
        VKPost *post = self.posts[indexPath.row];
        VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:post];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

@end
