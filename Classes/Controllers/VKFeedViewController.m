#import "VKFeedViewController.h"
#import "VKFeedPostCell.h"
#import "VKFeedService.h"
#import "VKPostDetailViewController.h"
#import "VKPostCommentsViewController.h"
#import "VKProfileViewController.h"
#import "VKNewPostViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"
#import "VKPost.h"

typedef NS_ENUM(NSInteger, VKFeedTypeMode) {
    VKFeedTypeModeMyNews = 0,
    VKFeedTypeModeAllNews = 1,
    VKFeedTypeModeRecommended = 2
};

@interface VKFeedViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) NSMutableArray *posts;
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
    
    [self setupNavigationItems];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshFeed) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadFeedFromStart:YES];
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
    if (actionSheet.tag == 201) {
        if (buttonIndex >= 0 && buttonIndex <= 2) {
            self.feedMode = (VKFeedTypeMode)buttonIndex;
            [self.titleButton setTitle:[self titleForFeedMode:self.feedMode] forState:UIControlStateNormal];
            [self loadFeedFromStart:YES];
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
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [VKCrashLogger log:@"[VKFeedViewController] Loading feed fromStart=%d, mode=%ld", fromStart, (long)self.feedMode];
    
    NSString *startFrom = fromStart ? nil : self.nextFrom;
    BOOL isGlobal = (self.feedMode == VKFeedTypeModeAllNews);
    
    [[VKFeedService sharedService] fetchFeedIsGlobal:isGlobal startFrom:startFrom completion:^(NSArray *posts, NSString *nextFrom, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            
            if (error) {
                [VKCrashLogger log:@"[VKFeedViewController] Error loading feed: %@", error.localizedDescription];
                return;
            }
            
            if (posts) {
                if (fromStart) {
                    [self.posts removeAllObjects];
                }
                [self.posts addObjectsFromArray:posts];
                self.nextFrom = nextFrom;
                [self.tableView reloadData];
                [VKCrashLogger log:@"[VKFeedViewController] Feed updated, total posts: %lu", (unsigned long)self.posts.count];
            }
        });
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.posts.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.posts.count) return 44.0;
    VKPost *post = self.posts[indexPath.row];
    BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)];
    return [VKFeedPostCell heightForPost:post width:tableView.bounds.size.width isRevealed:isRevealed];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"VKFeedPostMasterCardCell";
    VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.row >= (NSInteger)self.posts.count) return cell;
    
    VKPost *post = self.posts[indexPath.row];
    BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)];
    [cell configureWithPost:post isRevealed:isRevealed];
    
    __weak typeof(self) weakSelf = self;
    cell.onLikeTapped = ^(VKPost *p) {
        [[VKFeedService sharedService] likePost:p completion:nil];
    };
    
    cell.onCommentTapped = ^(VKPost *p) {
        VKPostCommentsViewController *commVC = [[VKPostCommentsViewController alloc] initWithPost:p];
        [weakSelf.navigationController pushViewController:commVC animated:YES];
    };
    
    cell.onRepostTapped = ^(VKPost *p) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:nil
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Поделиться на стене", @"Скопировать ссылку", nil];
        [sheet showInView:weakSelf.view];
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
    
    cell.onCommentTapped = ^(VKPost *p) {
        if (p) {
            VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:p];
            detailVC.focusCommentInputOnAppear = YES;
            [weakSelf.navigationController pushViewController:detailVC animated:YES];
        }
    };
    
    cell.onAuthorTapped = ^(VKUser *author) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:author];
        [weakSelf.navigationController pushViewController:profVC animated:YES];
    };
    
    cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
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
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:nil
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Пожаловаться", nil];
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
