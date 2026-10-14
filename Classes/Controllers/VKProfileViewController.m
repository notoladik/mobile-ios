#import "VKLikesListViewController.h"
#import "VKProfileViewController.h"
#import "VKProfileService.h"
#import "VKAuthService.h"
#import "VKNewPostViewController.h"
#import "VKNotificationsViewController.h"
#import "VKChatViewController.h"
#import "VKSettingsViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "VKDetailedProfileInfoViewController.h"
#import "VKFriendsListViewController.h"
#import "VKGroupsListViewController.h"
#import "VKAlbumsListViewController.h"
#import "VKVideosListViewController.h"
#import "VKAudioListViewController.h"
#import "VKFeedPostCell.h"
#import "VKFeedService.h"
#import "VKThemeManager.h"
#import "VKClientDesign.h"
#import "VKSideMenuManager.h"
#import "VKPostDetailViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKCrashLogger.h"
#import "VKShareManager.h"
#import "VKAppConfig.h"
#import "VKKateSettings.h"
#import "VKKateTheme.h"

@interface VKProfileViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) NSMutableArray *wallPosts;
@property (nonatomic, strong) NSMutableSet *revealedPostIds;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isLoadingMore;
@property (nonatomic, assign) NSInteger wallTotalCount;
@property (nonatomic, assign) BOOL isShowingArchive;
@property (nonatomic, strong) VKPost *selectedPostForAction;
@end

static NSString *pluralForm(NSInteger n, NSString *one, NSString *few, NSString *many) {
    NSInteger count = labs(n);
    NSInteger mod10 = count % 10;
    NSInteger mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 19) return many;
    if (mod10 == 1) return one;
    if (mod10 >= 2 && mod10 <= 4) return few;
    return many;
}

@implementation VKProfileViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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

- (instancetype)initWithUser:(VKUser *)user {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _user = user;
        _wallPosts = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (!self.user) {
        self.user = [[VKAuthService sharedService] currentUserModel];
    }
    
    self.title = self.user.displayName ?: @"Профиль";
    self.revealedPostIds = [NSMutableSet set];
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKClientDesignDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nsfwSettingDidChange) name:VKNSFWSettingDidChangeNotification object:nil];
    
    if ([self.user isCurrentUser] || self.user.canWriteOnWall || self.user.canPost) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(optionsAction)];
    }
    
    [self setupNavigationItems];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(refreshProfile) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadProfileData];
}

- (void)nsfwSettingDidChange {
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (BOOL)shouldDisplayKateHub {
    if (![[VKThemeManager sharedManager] isKateTheme]) return NO;
    if (self.isFullProfileMode) return NO;
    if (![VKClientDesign profileMenu]) return NO;
    
    NSInteger myUid = [[VKAuthService sharedService] currentUserModel].uid;
    BOOL isMyProfile = [self.user isCurrentUser] || (self.user.uid == myUid) || (self.user.uid == 0);
    return isMyProfile;
}

- (void)setupNavigationItems {
    BOOL isKate = [[VKThemeManager sharedManager] isKateTheme];
    BOOL isRoot = (self.navigationController.viewControllers.count > 0 && self.navigationController.viewControllers[0] == self);
    
    if (isKate) {
        if (!isRoot) {
            UIImage *homeImg = [UIImage imageNamed:@"kate_home"];
            if (homeImg) {
                self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:homeImg style:UIBarButtonItemStylePlain target:self action:@selector(goBackAction)];
            } else {
                self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
            }
            
            UIBarButtonItem *overflowItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"kate_overflow"] style:UIBarButtonItemStylePlain target:self action:@selector(optionsAction)];
            UIBarButtonItem *refreshItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"kate_refresh"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshProfile)];
            self.navigationItem.rightBarButtonItems = @[overflowItem, refreshItem];
        }
        return;
    }
    
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
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.tableView reloadData];
}

- (void)refreshProfile {
    [self loadProfileData];
}

- (void)optionsAction {
    NSInteger myUid = [[VKAuthService sharedService] currentUserModel].uid;
    BOOL isMyProfile = [self.user isCurrentUser] || (self.user.uid == myUid);
    
    if (isMyProfile) {
        NSString *archiveTitle = self.isShowingArchive ? @"Вернуться к стене" : @"Архив записей";
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Новая запись", archiveTitle, @"Открыть веб-архив в Safari", @"Скопировать ссылку", nil];
        sheet.tag = 501;
        [sheet showInView:self.view];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Новая запись", @"Скопировать ссылку", nil];
        sheet.tag = 502;
        [sheet showInView:self.view];
    }
}

- (void)showPostOptions:(VKPost *)post {
    self.selectedPostForAction = post;
    NSInteger myUid = [[VKAuthService sharedService] currentUserModel].uid;
    BOOL isMyProfile = [self.user isCurrentUser] || (self.user.uid == myUid);
    BOOL isGroupAdmin = self.user.isGroup && self.user.isAdmin;
    BOOL canManageWall = isMyProfile || isGroupAdmin;
    BOOL isMyPost = (post.author.uid == myUid || (self.user.isGroup && post.author.uid == self.user.uid));
    BOOL canDelete = canManageWall || isMyPost || (post.ownerID == myUid);
    
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    sheet.tag = 601;
    
    if (canDelete) {
        sheet.destructiveButtonIndex = [sheet addButtonWithTitle:@"Удалить запись"];
    }
    
    if (canManageWall) {
        NSString *pinTitle = post.isPinned ? @"Открепить запись" : @"Закрепить запись";
        [sheet addButtonWithTitle:pinTitle];
    }
    
    if (isMyProfile && (isMyPost || post.ownerID == myUid)) {
        NSString *archiveTitle = post.isArchived ? @"Восстановить на стену" : @"Архивировать запись";
        [sheet addButtonWithTitle:archiveTitle];
    }
    
    [sheet addButtonWithTitle:@"Поделиться"];
    [sheet addButtonWithTitle:@"Скопировать ссылку"];
    if (post.likesCount > 0) {
        [sheet addButtonWithTitle:@"Кто оценил"];
    }
    if (post.repostsCount > 0) {
        [sheet addButtonWithTitle:@"Кто поделился"];
    }
    if (!isMyPost) {
        [sheet addButtonWithTitle:@"Пожаловаться"];
    }
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}

- (void)toggleArchiveMode {
    self.isShowingArchive = !self.isShowingArchive;
    self.wallTotalCount = 0;
    [self.wallPosts removeAllObjects];
    [self.tableView reloadData];
    [self loadProfileData];
}

- (void)openWebArchive {
    NSInteger uid = self.user.uid;
    if (uid == 0 && [self.user isCurrentUser]) {
        uid = [[VKAuthService sharedService] currentUserModel].uid;
    }
    NSString *base = [[VKAppConfig apiBaseURL] absoluteString];
    if ([base hasSuffix:@"/"]) {
        base = [base substringToIndex:base.length - 1];
    }
    NSString *urlStr = [NSString stringWithFormat:@"%@/wall%ld?type=archive", base, (long)uid];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (url) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == 501) {
        if (buttonIndex == 0) {
            [self newPostAction];
        } else if (buttonIndex == 1) {
            [self toggleArchiveMode];
        } else if (buttonIndex == 2) {
            [self openWebArchive];
        } else if (buttonIndex == 3) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/id%ld", (long)self.user.uid];
        }
    } else if (actionSheet.tag == 502) {
        if (buttonIndex == 0) {
            [self newPostAction];
        } else if (buttonIndex == 1) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/id%ld", (long)self.user.uid];
        }
    } else if (actionSheet.tag == 601 || actionSheet.tag == 602) {
        if (!self.selectedPostForAction) return;
        VKPost *post = self.selectedPostForAction;
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        NSInteger owner = post.ownerID != 0 ? post.ownerID : self.user.uid;
        
        if ([title isEqualToString:@"Удалить запись"]) {
            NSInteger idx = [self.wallPosts indexOfObject:post];
            [[VKProfileService sharedService] deletePost:post.vkID ownerId:owner completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success && idx != NSNotFound && idx < (NSInteger)self.wallPosts.count) {
                        [self.wallPosts removeObjectAtIndex:idx];
                        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:1]] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Закрепить запись"]) {
            [[VKProfileService sharedService] pinPost:post.vkID ownerId:owner completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        post.isPinned = YES;
                        [self.tableView reloadData];
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Закреплено" message:@"Запись закреплена в начале стены." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Открепить запись"]) {
            [[VKProfileService sharedService] unpinPost:post.vkID ownerId:owner completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        post.isPinned = NO;
                        [self.tableView reloadData];
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Откреплено" message:@"Запись откреплена." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Архивировать запись"]) {
            NSInteger idx = [self.wallPosts indexOfObject:post];
            [[VKProfileService sharedService] archivePost:post.vkID ownerId:owner completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        if (idx != NSNotFound && idx < (NSInteger)self.wallPosts.count) {
                            [self.wallPosts removeObjectAtIndex:idx];
                            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:1]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"В архиве" message:@"Запись сохранена в архив." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    } else {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка архивации" message:@"Сервер OpenVK пока не поддерживает архивацию через мобильное API. Воспользуйтесь веб-версией OpenVK." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Восстановить на стену"]) {
            NSInteger idx = [self.wallPosts indexOfObject:post];
            [[VKProfileService sharedService] restorePost:post.vkID ownerId:owner completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        if (idx != NSNotFound && idx < (NSInteger)self.wallPosts.count) {
                            [self.wallPosts removeObjectAtIndex:idx];
                            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:1]] withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Восстановлено" message:@"Запись восстановлена на стену." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    } else {
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка восстановления" message:@"Сервер OpenVK пока не поддерживает восстановление через мобильное API. Воспользуйтесь веб-версией OpenVK." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Поделиться"]) {
            [[VKShareManager sharedManager] presentShareSheetForPost:post fromViewController:self completion:nil];
        } else if ([title isEqualToString:@"Скопировать ссылку"]) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/wall%ld_%ld", (long)owner, (long)post.vkID];
        } else if ([title isEqualToString:@"Кто оценил"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post" ownerId:owner itemId:post.vkID initialFilter:0];
            [self.navigationController pushViewController:likesVC animated:YES];
        } else if ([title isEqualToString:@"Кто поделился"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post" ownerId:owner itemId:post.vkID initialFilter:1];
            [self.navigationController pushViewController:likesVC animated:YES];
        } else if ([title isEqualToString:@"Пожаловаться"]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Жалоба" message:@"Спасибо, жалоба отправлена модераторам." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (void)newPostAction {
    NSInteger targetOwner = self.user.uid;
    if (targetOwner == 0) targetOwner = [[VKAuthService sharedService] currentUserModel].uid;
    VKNewPostViewController *newPostVC = [[VKNewPostViewController alloc] initWithOwnerId:targetOwner];
    __weak typeof(self) weakSelf = self;
    newPostVC.onPostCreated = ^{
        [weakSelf loadProfileData];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:newPostVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)postPhotoAction {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (chosenImage) {
            NSInteger targetOwner = self.user.uid;
            if (targetOwner == 0) targetOwner = [[VKAuthService sharedService] currentUserModel].uid;
            VKNewPostViewController *newPostVC = [[VKNewPostViewController alloc] initWithOwnerId:targetOwner initialImage:chosenImage];
            __weak typeof(self) weakSelf = self;
            newPostVC.onPostCreated = ^{
                [weakSelf loadProfileData];
            };
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:newPostVC];
            [self presentViewController:nav animated:YES completion:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadProfileData {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    NSInteger uid = self.user.uid;
    if (uid == 0 && [self.user isCurrentUser]) {
        uid = [[VKAuthService sharedService] currentUserModel].uid;
    }
    
    NSString *filter = self.isShowingArchive ? @"archived" : nil;
    [[VKProfileService sharedService] fetchProfileForUserId:uid completion:^(VKUser *updatedUser, NSError *error) {
        if (!error && updatedUser) {
            self.user = updatedUser;
            self.title = self.isShowingArchive ? @"Архив записей" : self.user.displayName;
        }
        
        [[VKProfileService sharedService] fetchWallForOwnerId:uid offset:0 count:30 filter:filter completion:^(NSArray *posts, NSInteger totalCount, NSError *wallErr) {
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            if (!wallErr && posts) {
                self.wallTotalCount = totalCount;
                if (posts.count < 30) {
                    self.wallTotalCount = posts.count;
                }
                [self.wallPosts removeAllObjects];
                [self.wallPosts addObjectsFromArray:posts];
            } else if (self.isShowingArchive) {
                [self.wallPosts removeAllObjects];
                self.wallTotalCount = 0;
            }
            [self.tableView reloadData];
        }];
    }];
}

- (void)loadMoreWallPosts {
    if (self.isLoading || self.isLoadingMore) return;
    if (self.wallTotalCount > 0 && (NSInteger)self.wallPosts.count >= self.wallTotalCount) return;
    
    self.isLoadingMore = YES;
    
    NSInteger uid = self.user.uid;
    if (uid == 0 && [self.user isCurrentUser]) {
        uid = [[VKAuthService sharedService] currentUserModel].uid;
    }
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 44);
    [spinner startAnimating];
    self.tableView.tableFooterView = spinner;
    
    NSInteger currentOffset = self.wallPosts.count;
    NSString *filter = self.isShowingArchive ? @"archived" : nil;
    
    __weak typeof(self) weakSelf = self;
    [[VKProfileService sharedService] fetchWallForOwnerId:uid offset:currentOffset count:30 filter:filter completion:^(NSArray *posts, NSInteger totalCount, NSError *wallErr) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        strongSelf.isLoadingMore = NO;
        strongSelf.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
        
        if (!wallErr && posts.count > 0) {
            strongSelf.wallTotalCount = totalCount;
            if (posts.count < 30) {
                strongSelf.wallTotalCount = strongSelf.wallPosts.count + posts.count;
            }
            NSMutableArray *indexPaths = [NSMutableArray array];
            for (NSInteger i = 0; i < (NSInteger)posts.count; i++) {
                [indexPaths addObject:[NSIndexPath indexPathForRow:strongSelf.wallPosts.count + i inSection:1]];
            }
            [strongSelf.wallPosts addObjectsFromArray:posts];
            [strongSelf.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        } else {
            strongSelf.wallTotalCount = strongSelf.wallPosts.count;
        }
    }];
}

#pragma mark - UIScrollViewDelegate (Infinite Scroll)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.isLoading || self.isLoadingMore) return;
    if (self.wallTotalCount > 0 && (NSInteger)self.wallPosts.count >= self.wallTotalCount) return;
    
    CGFloat currentOffset = scrollView.contentOffset.y;
    CGFloat maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
    
    if (maximumOffset - currentOffset <= 350.0 && scrollView.contentSize.height > scrollView.bounds.size.height) {
        [self loadMoreWallPosts];
    }
}

- (void)writeMessageAction {
    VKChatViewController *chatVC = [[VKChatViewController alloc] initWithPeerId:self.user.uid peerUser:self.user title:self.user.displayName];
    [self.navigationController pushViewController:chatVC animated:YES];
}

- (void)toggleFriendAction {
    BOOL isFriend = self.user.isFriend;
    self.user.isFriend = !isFriend;
    [self.tableView reloadData];
    
    if (isFriend) {
        [[VKProfileService sharedService] deleteFriend:self.user.uid completion:nil];
    } else {
        [[VKProfileService sharedService] addFriend:self.user.uid completion:nil];
    }
}

- (void)toggleGroupAction {
    BOOL isMember = self.user.isFriend;
    self.user.isFriend = !isMember;
    [self.tableView reloadData];
    
    if (isMember) {
        [[VKProfileService sharedService] leaveGroup:self.user.uid completion:nil];
    } else {
        [[VKProfileService sharedService] joinGroup:self.user.uid completion:nil];
    }
}

- (void)profileAvatarTapped:(UITapGestureRecognizer *)gesture {
    NSString *previewURL = self.user.avatarURL;
    NSString *fullURL = self.user.avatarURLFull ?: previewURL;
    if (previewURL.length == 0 && fullURL.length == 0) return;
    
    UIImageView *iv = (UIImageView *)gesture.view;
    UIImage *initialImg = [iv isKindOfClass:[UIImageView class]] ? iv.image : nil;
    
    VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:previewURL fullImageURL:fullURL initialImage:initialImg];
    [self presentViewController:viewer animated:YES completion:nil];
}

- (void)showDetailsAction {
    VKDetailedProfileInfoViewController *detailsVC = [[VKDetailedProfileInfoViewController alloc] initWithUser:self.user];
    [self.navigationController pushViewController:detailsVC animated:YES];
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self shouldDisplayKateHub]) {
        return 0.0;
    }
    if (section == 1) {
        return self.isShowingArchive ? 42.0 : 36.0;
    }
    return 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if ([self shouldDisplayKateHub]) {
        return nil;
    }
    if (section == 1) {
        NSInteger myUid = [[VKAuthService sharedService] currentUserModel].uid;
        BOOL isMyProfile = [self.user isCurrentUser] || (self.user.uid == myUid);
        
        if (self.isShowingArchive) {
            UIView *banner = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 42.0)];
            banner.backgroundColor = [UIColor colorWithRed:236.0/255.0 green:242.0/255.0 blue:252.0/255.0 alpha:0.98];
            
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 11, tableView.bounds.size.width - 110, 20)];
            lbl.font = [UIFont boldSystemFontOfSize:13];
            lbl.textColor = [UIColor colorWithRed:60.0/255.0 green:90.0/255.0 blue:130.0/255.0 alpha:1.0];
            lbl.text = self.wallPosts.count > 0 ? [NSString stringWithFormat:@"📦 Архив записей (%ld)", (long)self.wallPosts.count] : @"📦 Архив записей";
            [banner addSubview:lbl];
            
            UIButton *exitBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            exitBtn.frame = CGRectMake(tableView.bounds.size.width - 95, 7, 85, 28);
            exitBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            exitBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
            [exitBtn setTitle:@"К стене ✕" forState:UIControlStateNormal];
            [exitBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
            [exitBtn addTarget:self action:@selector(toggleArchiveMode) forControlEvents:UIControlEventTouchUpInside];
            [banner addSubview:exitBtn];
            
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 41.5, tableView.bounds.size.width, 0.5)];
            sep.backgroundColor = [UIColor colorWithRed:210.0/255.0 green:220.0/255.0 blue:235.0/255.0 alpha:1.0];
            sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [banner addSubview:sep];
            return banner;
        } else {
            UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 36.0)];
            headerView.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:245.0/255.0 blue:247.0/255.0 alpha:0.98];
            
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, tableView.bounds.size.width - 120, 20)];
            lbl.font = [UIFont boldSystemFontOfSize:12];
            lbl.textColor = [[VKThemeManager sharedManager] secondaryTextColor] ?: [UIColor colorWithRed:101.0/255.0 green:113.0/255.0 blue:127.0/255.0 alpha:1.0];
            
            NSInteger count = self.wallTotalCount > 0 ? self.wallTotalCount : self.wallPosts.count;
            if (count > 0) {
                lbl.text = [NSString stringWithFormat:@"ЗАПИСИ НА СТЕНЕ  %ld", (long)count];
            } else {
                lbl.text = @"ЗАПИСИ НА СТЕНЕ";
            }
            [headerView addSubview:lbl];
            
            if (isMyProfile) {
                UIButton *archiveBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                archiveBtn.frame = CGRectMake(tableView.bounds.size.width - 105, 4, 95, 28);
                archiveBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                archiveBtn.titleLabel.font = [UIFont systemFontOfSize:12];
                [archiveBtn setTitle:@"📦 Архив ›" forState:UIControlStateNormal];
                [archiveBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                [archiveBtn addTarget:self action:@selector(toggleArchiveMode) forControlEvents:UIControlEventTouchUpInside];
                [headerView addSubview:archiveBtn];
            }
            
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 35.5, tableView.bounds.size.width, 0.5)];
            sep.backgroundColor = [[VKThemeManager sharedManager] separatorColor] ?: [UIColor colorWithRed:215.0/255.0 green:217.0/255.0 blue:220.0/255.0 alpha:1.0];
            sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [headerView addSubview:sep];
            return headerView;
        }
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ([self shouldDisplayKateHub]) {
        return 2;
    }
    return 2; // Секция 0: Шапка профиля и счетчики, Секция 1: Стена постов
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([self shouldDisplayKateHub]) {
        if (section == 0) return 1;
        return 9;
    }
    if (section == 0) return 1;
    if (self.isShowingArchive && self.wallPosts.count == 0 && !self.isLoading) {
        return 1;
    }
    return self.wallPosts.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self shouldDisplayKateHub]) {
        return 48.0;
    }
    if (indexPath.section == 0) {
        if ([[VKThemeManager sharedManager] isKateTheme]) {
            NSInteger myId = [[VKAuthService sharedService] currentUserId];
            BOOL isMyProfile = (self.user.uid == myId || self.user.uid == 0 || [self.user isCurrentUser]);
            return isMyProfile ? 736.0 : 790.0;
        }
        if ([[VKThemeManager sharedManager] isModern]) {
            return 196.0;
        }
        return self.user.isGroup ? 200.0 : 210.0;
    } else {
        if (self.isShowingArchive && self.wallPosts.count == 0 && !self.isLoading) {
            return 130.0;
        }
        if (indexPath.row >= (NSInteger)self.wallPosts.count) return 44.0;
        VKPost *post = self.wallPosts[indexPath.row];
        BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
        return [VKFeedPostCell heightForPost:post width:tableView.bounds.size.width isRevealed:isRevealed];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self shouldDisplayKateHub]) {
        if (indexPath.section == 0) {
            static NSString *HubHeaderId = @"VKKateProfileHubHeaderCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:HubHeaderId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HubHeaderId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, tableView.bounds.size.width - 64, 24)];
                nameLabel.tag = 101;
                nameLabel.font = [UIFont boldSystemFontOfSize:16.5];
                nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:nameLabel];
                
                UIImageView *mobileIV = [[UIImageView alloc] initWithFrame:CGRectMake(tableView.bounds.size.width - 34, 14, 16, 20)];
                mobileIV.tag = 102;
                mobileIV.contentMode = UIViewContentModeScaleAspectFit;
                mobileIV.image = [UIImage imageNamed:@"kate_mobile_online"];
                mobileIV.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                [cell.contentView addSubview:mobileIV];
                
                UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 47.5, tableView.bounds.size.width, 0.5)];
                sep.tag = 103;
                sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:sep];
            }
            
            VKKateTheme *kt = [VKKateTheme currentTheme];
            cell.backgroundColor = kt.cardBackgroundColor;
            
            UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:101];
            nameLabel.text = self.user.displayName ?: @"";
            nameLabel.textColor = kt.primaryTextColor;
            
            UIView *sep = [cell.contentView viewWithTag:103];
            sep.backgroundColor = kt.separatorColor;
            
            return cell;
        } else {
            static NSString *HubMenuId = @"VKKateProfileHubMenuCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:HubMenuId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HubMenuId];
                cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                
                UIImageView *iconIV = [[UIImageView alloc] initWithFrame:CGRectMake(16, 12, 24, 24)];
                iconIV.tag = 201;
                iconIV.contentMode = UIViewContentModeScaleAspectFit;
                [cell.contentView addSubview:iconIV];
                
                UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(54, 13, tableView.bounds.size.width - 120, 22)];
                titleLabel.tag = 202;
                titleLabel.font = [UIFont systemFontOfSize:15.5];
                titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:titleLabel];
                
                UILabel *badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(tableView.bounds.size.width - 60, 14, 48, 20)];
                badgeLabel.tag = 203;
                badgeLabel.font = [UIFont systemFontOfSize:14];
                badgeLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
                badgeLabel.textAlignment = NSTextAlignmentRight;
                badgeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                [cell.contentView addSubview:badgeLabel];
                
                UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 47.5, tableView.bounds.size.width, 0.5)];
                sep.tag = 204;
                sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:sep];
            }
            
            VKKateTheme *kt = [VKKateTheme currentTheme];
            cell.backgroundColor = kt.cardBackgroundColor;
            
            UIImageView *iconIV = (UIImageView *)[cell.contentView viewWithTag:201];
            UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:202];
            UILabel *badgeLabel = (UILabel *)[cell.contentView viewWithTag:203];
            UIView *sep = [cell.contentView viewWithTag:204];
            
            titleLabel.textColor = kt.primaryTextColor;
            sep.backgroundColor = kt.separatorColor;
            badgeLabel.textColor = kt.secondaryTextColor;
            
            badgeLabel.text = @"";
            
            switch (indexPath.row) {
                case 0:
                    iconIV.image = [UIImage imageNamed:@"profile_friends_icon_4"];
                    titleLabel.text = @"Друзья";
                    if (self.user.friendsCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.user.friendsCount];
                    break;
                case 1:
                    iconIV.image = [UIImage imageNamed:@"profile_wall_icon_4"];
                    titleLabel.text = @"Стена";
                    if (self.wallTotalCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.wallTotalCount];
                    break;
                case 2:
                    iconIV.image = [UIImage imageNamed:@"profile_groups_icon_4"];
                    titleLabel.text = @"Группы";
                    if (self.user.groupsCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.user.groupsCount];
                    break;
                case 3:
                    iconIV.image = [UIImage imageNamed:@"profile_photos_icon_4"];
                    titleLabel.text = @"Фотографии";
                    if (self.user.photoCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.user.photoCount];
                    break;
                case 4:
                    iconIV.image = [UIImage imageNamed:@"profile_audio_icon_4"];
                    titleLabel.text = @"Аудио";
                    if (self.user.audioCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.user.audioCount];
                    break;
                case 5:
                    iconIV.image = [UIImage imageNamed:@"profile_video_icon_4"];
                    titleLabel.text = @"Видео";
                    if (self.user.videoCount > 0) badgeLabel.text = [NSString stringWithFormat:@"%ld", (long)self.user.videoCount];
                    break;
                case 6:
                    iconIV.image = [UIImage imageNamed:@"profile_fave_icon_4"];
                    titleLabel.text = @"Закладки";
                    break;
                case 7:
                    iconIV.image = [UIImage imageNamed:@"profile_replies_icon_4"];
                    titleLabel.text = @"Ответы";
                    break;
                case 8:
                    iconIV.image = [UIImage imageNamed:@"profile_full_profile_icon_4"];
                    titleLabel.text = @"Полный профиль";
                    break;
            }
            return cell;
        }
    }
    
    if (indexPath.section == 0) {
        BOOL isKate = [[VKThemeManager sharedManager] isKateTheme];
        BOOL isModern = [[VKThemeManager sharedManager] isModern];
        NSString *HeaderCellId = isKate ? @"VKProfileKateWideAvaHeaderCell" : (isModern ? @"VKProfileSwiftUIHeaderCell" : @"VKProfileAuthenticHeaderCell");
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:HeaderCellId];
        
        if (isKate) {
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HeaderCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                
                CGFloat width = tableView.bounds.size.width;
                VKKateTheme *kt = [VKKateTheme currentTheme];
                cell.backgroundColor = kt.cardBackgroundColor;
                
                // 1. Cover Photo (265.0pt)
                UIImageView *coverIV = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, 265.0)];
                coverIV.tag = 910;
                coverIV.contentMode = UIViewContentModeScaleAspectFill;
                coverIV.clipsToBounds = YES;
                coverIV.userInteractionEnabled = YES;
                coverIV.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:coverIV];
                
                // Градиентная тень внизу фото
                UIView *gradView = [[UIView alloc] initWithFrame:CGRectMake(0, 165.0, width, 100.0)];
                gradView.tag = 930;
                gradView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                CAGradientLayer *gradLayer = [CAGradientLayer layer];
                gradLayer.frame = CGRectMake(0, 0, width, 100.0);
                gradLayer.colors = @[(id)[UIColor clearColor].CGColor, (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor];
                [gradView.layer addSublayer:gradLayer];
                [cell.contentView addSubview:gradView];
                
                // Имя пользователя (22sp bold white с тенью)
                UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 206, width - 32, 28)];
                nameLabel.tag = 911;
                nameLabel.font = [UIFont boldSystemFontOfSize:22.0];
                nameLabel.textColor = [UIColor whiteColor];
                nameLabel.shadowColor = [UIColor blackColor];
                nameLabel.shadowOffset = CGSizeMake(1, 1);
                nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:nameLabel];
                
                // Статус online / last seen (12.5pt white с тенью)
                UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 236, width - 50, 18)];
                statusLabel.tag = 912;
                statusLabel.font = [UIFont systemFontOfSize:12.5];
                statusLabel.textColor = [UIColor whiteColor];
                statusLabel.shadowColor = [UIColor blackColor];
                statusLabel.shadowOffset = CGSizeMake(1, 1);
                [cell.contentView addSubview:statusLabel];
                
                // Зеленый индикатор / иконка телефона
                UIImageView *onlineDot = [[UIImageView alloc] initWithFrame:CGRectMake(60, 239, 12, 12)];
                onlineDot.tag = 913;
                onlineDot.contentMode = UIViewContentModeScaleAspectFit;
                [cell.contentView addSubview:onlineDot];
                
                // 2. Кнопки действий (40pt)
                CGFloat btnW = (width - 40.0) / 2.0;
                UIButton *btn1 = [UIButton buttonWithType:UIButtonTypeCustom];
                btn1.frame = CGRectMake(16, 277, btnW, 40.0);
                btn1.tag = 914;
                btn1.backgroundColor = kt.profileButtonBackgroundColor;
                btn1.layer.cornerRadius = 3.0;
                btn1.clipsToBounds = YES;
                btn1.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
                [btn1 setTitleColor:kt.profileButtonTextColor forState:UIControlStateNormal];
                [cell.contentView addSubview:btn1];
                
                UIButton *btn2 = [UIButton buttonWithType:UIButtonTypeCustom];
                btn2.frame = CGRectMake(16 + btnW + 8.0, 277, btnW, 40.0);
                btn2.tag = 915;
                btn2.backgroundColor = kt.profileButtonBackgroundColor;
                btn2.layer.cornerRadius = 3.0;
                btn2.clipsToBounds = YES;
                btn2.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
                [btn2 setTitleColor:kt.profileButtonTextColor forState:UIControlStateNormal];
                [cell.contentView addSubview:btn2];
                
                // 3. Сетка 3x2 (Стена | Друзья | Группы) и (Фото | Все фото | Музыка)
                CGFloat colW = floorf(width / 3.0);
                CGFloat gridY = 329.0;
                
                // Разделитель над сеткой
                UIView *divGridTop = [[UIView alloc] initWithFrame:CGRectMake(0, gridY, width, 0.5)];
                divGridTop.tag = 940;
                divGridTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:divGridTop];
                
                // Col 0: Стена
                UIButton *colWall = [UIButton buttonWithType:UIButtonTypeCustom];
                colWall.frame = CGRectMake(0, gridY, colW, 60.0);
                colWall.tag = 916;
                [colWall addTarget:self action:@selector(scrollToWallAction) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colWall];
                
                // Col 1: Друзья
                UIButton *colFriends = [UIButton buttonWithType:UIButtonTypeCustom];
                colFriends.frame = CGRectMake(colW, gridY, colW, 60.0);
                colFriends.tag = 917;
                [colFriends addTarget:self action:@selector(openFriendsList) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colFriends];
                
                // Col 2: Группы
                UIButton *colGroups = [UIButton buttonWithType:UIButtonTypeCustom];
                colGroups.frame = CGRectMake(colW * 2, gridY, width - colW * 2, 60.0);
                colGroups.tag = 918;
                [colGroups addTarget:self action:@selector(openGroupsList) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colGroups];
                
                // Разделитель между строками 1 и 2
                UIView *divGridMid = [[UIView alloc] initWithFrame:CGRectMake(0, gridY + 60.0, width, 0.5)];
                divGridMid.tag = 941;
                divGridMid.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:divGridMid];
                
                // Row 2
                CGFloat row2Y = gridY + 60.5;
                // Col 3: Фото
                UIButton *colPhotos = [UIButton buttonWithType:UIButtonTypeCustom];
                colPhotos.frame = CGRectMake(0, row2Y, colW, 60.0);
                colPhotos.tag = 919;
                [colPhotos addTarget:self action:@selector(openPhotosList) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colPhotos];
                
                // Col 4: Все фото
                UIButton *colAllPhotos = [UIButton buttonWithType:UIButtonTypeCustom];
                colAllPhotos.frame = CGRectMake(colW, row2Y, colW, 60.0);
                colAllPhotos.tag = 920;
                [colAllPhotos addTarget:self action:@selector(openPhotosList) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colAllPhotos];
                
                // Col 5: Музыка
                UIButton *colAudios = [UIButton buttonWithType:UIButtonTypeCustom];
                colAudios.frame = CGRectMake(colW * 2, row2Y, width - colW * 2, 60.0);
                colAudios.tag = 921;
                [colAudios addTarget:self action:@selector(openAudiosList) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:colAudios];
                
                // Разделитель под сеткой
                UIView *divGridBot = [[UIView alloc] initWithFrame:CGRectMake(0, row2Y + 60.0, width, 0.5)];
                divGridBot.tag = 942;
                divGridBot.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:divGridBot];
                
                // 4. Список деталей (Подписчики, Видео, Документы, Заметки, Интересные страницы, Подробная инфа)
                CGFloat detY = row2Y + 61.0;
                
                NSArray *detailTitles = @[@"Подписчики", @"Видео", @"Документы", @"Заметки", @"Интересные страницы", @"Подробная информация"];
                for (NSInteger d = 0; d < (NSInteger)detailTitles.count; d++) {
                    CGFloat rowH = (d >= 4) ? 38.0 : 42.0;
                    
                    UIButton *detBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                    detBtn.frame = CGRectMake(0, detY, width, rowH);
                    detBtn.tag = 950 + d;
                    detBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                    [cell.contentView addSubview:detBtn];
                    
                    UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, width - 80, 20)];
                    tLbl.tag = 960 + d;
                    tLbl.font = [UIFont systemFontOfSize:15];
                    tLbl.text = detailTitles[d];
                    [detBtn addSubview:tLbl];
                    
                    UILabel *cLbl = [[UILabel alloc] initWithFrame:CGRectMake(width - 60, 10, 44, 20)];
                    cLbl.tag = 970 + d;
                    cLbl.font = [UIFont systemFontOfSize:14];
                    cLbl.textAlignment = NSTextAlignmentRight;
                    cLbl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                    [detBtn addSubview:cLbl];
                    
                    detY += rowH;
                }
                
                // 5. Блок с фактами (Пол, ID, Был(а) в сети, Город)
                UIView *factsView = [[UIView alloc] initWithFrame:CGRectMake(16, detY + 6.0, width - 32, 75.0)];
                factsView.tag = 980;
                factsView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:factsView];
                
                UILabel *factsLabel = [[UILabel alloc] initWithFrame:factsView.bounds];
                factsLabel.tag = 981;
                factsLabel.font = [UIFont systemFontOfSize:13.5];
                factsLabel.numberOfLines = 4;
                factsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [factsView addSubview:factsLabel];
                
                // Нижний разделитель секции
                UIView *botSep = [[UIView alloc] initWithFrame:CGRectMake(0, 782.0, width, 8.0)];
                botSep.tag = 990;
                botSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:botSep];
            }
            
            // Наполняем данными:
            UIImageView *coverIV = (UIImageView *)[cell.contentView viewWithTag:910];
            UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:911];
            UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:912];
            UIImageView *onlineDot = (UIImageView *)[cell.contentView viewWithTag:913];
            UIButton *btn1 = (UIButton *)[cell.contentView viewWithTag:914];
            UIButton *btn2 = (UIButton *)[cell.contentView viewWithTag:915];
            UIButton *colWall = (UIButton *)[cell.contentView viewWithTag:916];
            UIButton *colFriends = (UIButton *)[cell.contentView viewWithTag:917];
            UIButton *colGroups = (UIButton *)[cell.contentView viewWithTag:918];
            UIButton *colPhotos = (UIButton *)[cell.contentView viewWithTag:919];
            UIButton *colAllPhotos = (UIButton *)[cell.contentView viewWithTag:920];
            UIButton *colAudios = (UIButton *)[cell.contentView viewWithTag:921];
            
            VKKateTheme *kt = [VKKateTheme currentTheme];
            UIColor *bgCol = kt.cardBackgroundColor;
            UIColor *textCol = kt.primaryTextColor;
            UIColor *subCol = kt.secondaryTextColor;
            UIColor *divCol = kt.separatorColor;
            
            cell.backgroundColor = bgCol;
            btn1.backgroundColor = kt.profileButtonBackgroundColor;
            [btn1 setTitleColor:kt.profileButtonTextColor forState:UIControlStateNormal];
            btn2.backgroundColor = kt.profileButtonBackgroundColor;
            [btn2 setTitleColor:kt.profileButtonTextColor forState:UIControlStateNormal];
            
            // Загрузка обложки
            coverIV.image = nil;
            for (UIGestureRecognizer *gr in coverIV.gestureRecognizers) [coverIV removeGestureRecognizer:gr];
            [coverIV addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(profileAvatarTapped:)]];
            NSString *coverUrl = self.user.avatarURLFull ?: self.user.avatarURL;
            if (coverUrl.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:coverUrl completion:^(UIImage *img) {
                    if (img) coverIV.image = img;
                }];
            }
            
            nameLabel.text = self.user.displayName ?: @"";
            
            NSString *statusText = self.user.isOnline ? @"Online" : (self.user.lastSeen ?: @"был(а) недавно");
            statusLabel.text = statusText;
            CGSize stSz = [statusText sizeWithFont:[UIFont systemFontOfSize:12.5]];
            onlineDot.frame = CGRectMake(16 + ceilf(stSz.width) + 6, 239, 12, 12);
            if (self.user.isOnline) {
                onlineDot.image = [UIImage imageNamed:@"kate_online_green"];
                onlineDot.hidden = NO;
            } else {
                onlineDot.hidden = YES;
            }
            
            // Кнопки
            NSInteger myId = [[VKAuthService sharedService] currentUserId];
            BOOL isMyProfile = (self.user.uid == myId || self.user.uid == 0 || [self.user isCurrentUser]);
            CGFloat width = tableView.bounds.size.width;
            CGFloat colW = floorf(width / 3.0);
            CGFloat gridY = isMyProfile ? 268.0 : 329.0;
            
            btn1.hidden = isMyProfile;
            btn2.hidden = isMyProfile;
            if (!isMyProfile) {
                NSString *fTitle = self.user.isFriend ? @"В ДРУЗЬЯХ ✓" : @"ДОБАВИТЬ В ДРУЗЬЯ";
                [btn1 setTitle:fTitle forState:UIControlStateNormal];
                [btn1 removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [btn1 addTarget:self action:@selector(toggleFriendAction) forControlEvents:UIControlEventTouchUpInside];
                
                [btn2 setTitle:@"СООБЩЕНИЕ" forState:UIControlStateNormal];
                [btn2 removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [btn2 addTarget:self action:@selector(writeMessageAction) forControlEvents:UIControlEventTouchUpInside];
            }
            
            // Разделители и сетка
            UIView *divGridTop = [cell.contentView viewWithTag:940];
            UIView *divGridMid = [cell.contentView viewWithTag:941];
            UIView *divGridBot = [cell.contentView viewWithTag:942];
            divGridTop.backgroundColor = divCol;
            divGridMid.backgroundColor = divCol;
            divGridBot.backgroundColor = divCol;
            
            divGridTop.frame = CGRectMake(0, gridY, width, 0.5);
            colWall.frame = CGRectMake(0, gridY, colW, 60.0);
            colFriends.frame = CGRectMake(colW, gridY, colW, 60.0);
            colGroups.frame = CGRectMake(colW * 2, gridY, width - colW * 2, 60.0);
            
            divGridMid.frame = CGRectMake(0, gridY + 60.0, width, 0.5);
            CGFloat row2Y = gridY + 60.5;
            colPhotos.frame = CGRectMake(0, row2Y, colW, 60.0);
            colAllPhotos.frame = CGRectMake(colW, row2Y, colW, 60.0);
            colAudios.frame = CGRectMake(colW * 2, row2Y, width - colW * 2, 60.0);
            divGridBot.frame = CGRectMake(0, row2Y + 60.0, width, 0.5);
            
            // Сетка
            void (^setupStatCol)(UIButton *, NSString *, NSString *) = ^(UIButton *b, NSString *title, NSString *val) {
                [b setTitle:[NSString stringWithFormat:@"%@\n%@", title, val] forState:UIControlStateNormal];
                b.titleLabel.numberOfLines = 2;
                b.titleLabel.textAlignment = NSTextAlignmentCenter;
                [b setTitleColor:textCol forState:UIControlStateNormal];
                b.titleLabel.font = [UIFont systemFontOfSize:14];
            };
            
            setupStatCol(colWall, @"Стена", (self.wallTotalCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.wallTotalCount] : @"0"));
            setupStatCol(colFriends, @"Друзья", (self.user.friendsCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.friendsCount] : @"0"));
            setupStatCol(colGroups, @"Группы", (self.user.groupsCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.groupsCount] : @"0"));
            setupStatCol(colPhotos, @"Фотографии", (self.user.photoCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.photoCount] : @"0"));
            setupStatCol(colAllPhotos, @"Все фото", (self.user.photoCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.photoCount] : @"0"));
            setupStatCol(colAudios, @"Аудио", (self.user.audioCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.audioCount] : @"0"));
            
            // Детали
            CGFloat detY = row2Y + 61.0;
            NSArray *counts = @[
                (self.user.followersCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.followersCount] : @"0"),
                (self.user.videoCount > 0 ? [NSString stringWithFormat:@"%ld", (long)self.user.videoCount] : @"0"),
                @"",
                @"0",
                @"",
                @""
            ];
            for (NSInteger d = 0; d < 6; d++) {
                CGFloat rowH = (d >= 4) ? 38.0 : 42.0;
                UIButton *detBtn = (UIButton *)[cell.contentView viewWithTag:950 + d];
                detBtn.frame = CGRectMake(0, detY, width, rowH);
                detY += rowH;
                
                UILabel *tLbl = (UILabel *)[detBtn viewWithTag:960 + d];
                UILabel *cLbl = (UILabel *)[detBtn viewWithTag:970 + d];
                tLbl.textColor = textCol;
                cLbl.textColor = subCol;
                cLbl.text = counts[d];
                
                [detBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                if (d == 0) [detBtn addTarget:self action:@selector(openFriendsList) forControlEvents:UIControlEventTouchUpInside];
                else if (d == 1) [detBtn addTarget:self action:@selector(openVideosList) forControlEvents:UIControlEventTouchUpInside];
                else if (d == 4) [detBtn addTarget:self action:@selector(openGroupsList) forControlEvents:UIControlEventTouchUpInside];
                else if (d == 5) [detBtn addTarget:self action:@selector(showDetailsAction) forControlEvents:UIControlEventTouchUpInside];
            }
            
            UIView *botSep = [cell.contentView viewWithTag:990];
            botSep.frame = CGRectMake(0, detY, width, 0.5);
            botSep.backgroundColor = kt.separatorColor;
            
            UIView *infoView = [cell.contentView viewWithTag:980];
            infoView.frame = CGRectMake(16, detY + 8.0, width - 32, 110.0);
            
            // Факты
            UILabel *factsLabel = (UILabel *)[cell.contentView viewWithTag:981];
            factsLabel.textColor = subCol;
            NSString *genderStr = self.user.sex == 2 ? @"Пол: мужской" : (self.user.sex == 1 ? @"Пол: женский" : @"Пол: не указан");
            NSString *idStr = [NSString stringWithFormat:@"id: %ld", (long)self.user.uid];
            NSString *seenStr = [NSString stringWithFormat:@"Был(а) в сети: %@", self.user.lastSeen ?: @"недавно"];
            NSString *cityStr = self.user.city.length > 0 ? [NSString stringWithFormat:@"Город: %@", self.user.city] : @"";
            factsLabel.text = [NSString stringWithFormat:@"%@\n%@\n%@\n%@", genderStr, idStr, seenStr, cityStr];
            
            return cell;
        }
        
        if (isModern) {
            // Оригинальный SwiftUI Profile Header (ProfileHeaderView.swift & ProfileInfoSection.swift)
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HeaderCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor whiteColor];
                
                // Аватар 76x76
                UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 76, 76)];
                avatar.tag = 801;
                avatar.layer.cornerRadius = 38.0;
                avatar.clipsToBounds = YES;
                avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
                [cell.contentView addSubview:avatar];
                
                // Имя
                UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(108, 22, cell.contentView.bounds.size.width - 124, 24)];
                nameLabel.font = [UIFont boldSystemFontOfSize:18];
                nameLabel.textColor = [UIColor blackColor];
                nameLabel.tag = 802;
                [cell.contentView addSubview:nameLabel];
                
                // Статус online / last seen
                UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(108, 48, cell.contentView.bounds.size.width - 124, 18)];
                statusLabel.font = [UIFont systemFontOfSize:13];
                statusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
                statusLabel.tag = 803;
                [cell.contentView addSubview:statusLabel];
                
                // Кнопка действия (Редактировать / Вступить / Добавить)
                UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                actionBtn.frame = CGRectMake(16, 104, cell.contentView.bounds.size.width - 32, 36);
                actionBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                actionBtn.layer.cornerRadius = 8.0;
                actionBtn.clipsToBounds = YES;
                actionBtn.tag = 804;
                [cell.contentView addSubview:actionBtn];
                
                // Разделитель
                UIView *div = [[UIView alloc] initWithFrame:CGRectMake(0, 150, cell.contentView.bounds.size.width, 0.5)];
                div.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:232.0/255.0 blue:236.0/255.0 alpha:1.0];
                div.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [cell.contentView addSubview:div];
                
                // Строка Подробная информация ›
                UIButton *detailsBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                detailsBtn.frame = CGRectMake(0, 151, cell.contentView.bounds.size.width, 44);
                detailsBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                [detailsBtn setTitle:@"Подробная информация ›" forState:UIControlStateNormal];
                [detailsBtn setTitleColor:[UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                detailsBtn.titleLabel.font = [UIFont systemFontOfSize:14.5];
                detailsBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
                detailsBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);
                [detailsBtn addTarget:self action:@selector(showDetailsAction) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:detailsBtn];
            }
            
            UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:801];
            UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:802];
            UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:803];
            UIButton *actionBtn = (UIButton *)[cell.contentView viewWithTag:804];
            
            avatar.image = nil;
            avatar.userInteractionEnabled = YES;
            for (UIGestureRecognizer *gr in avatar.gestureRecognizers) {
                [avatar removeGestureRecognizer:gr];
            }
            [avatar addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(profileAvatarTapped:)]];
            if (self.user.avatarURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:self.user.avatarURL completion:^(UIImage *img) {
                    if (img) avatar.image = img;
                }];
            }
            
            nameLabel.text = self.user.displayName;
            statusLabel.text = self.user.isOnline ? @"online" : (self.user.lastSeen ?: @"был(а) недавно");
            
            NSInteger myId = [[VKAuthService sharedService] currentUserId];
            BOOL isMyProfile = (self.user.uid == myId || self.user.uid == 0);
            
            if (isMyProfile) {
                actionBtn.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0];
                [actionBtn setTitle:@"Редактировать" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [actionBtn addTarget:self action:@selector(newPostAction) forControlEvents:UIControlEventTouchUpInside];
            } else if (self.user.isGroup) {
                actionBtn.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                [actionBtn setTitle:self.user.isFriend ? @"Вы подписаны ✓" : @"Подписаться" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
                [actionBtn addTarget:self action:@selector(toggleGroupAction) forControlEvents:UIControlEventTouchUpInside];
            } else {
                actionBtn.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                [actionBtn setTitle:self.user.isFriend ? @"У вас в друзьях ✓" : @"Добавить в друзья" forState:UIControlStateNormal];
                [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14.5];
                [actionBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
            }
            
            return cell;
        }
        
        // Классический аутентичный профиль для iOS 6 и iOS 7
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:HeaderCellId];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor whiteColor];
            
            // Шапка профиля
            UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 72, 72)];
            avatar.tag = 601;
            avatar.clipsToBounds = YES;
            avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            [cell.contentView addSubview:avatar];
            
            UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 16, cell.contentView.bounds.size.width - 150, 22)];
            nameLabel.font = [UIFont boldSystemFontOfSize:17];
            nameLabel.textColor = [UIColor blackColor];
            nameLabel.tag = 602;
            [cell.contentView addSubview:nameLabel];
            
            UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 40, cell.contentView.bounds.size.width - 150, 18)];
            statusLabel.font = [UIFont systemFontOfSize:13];
            statusLabel.textColor = [UIColor grayColor];
            statusLabel.tag = 603;
            [cell.contentView addSubview:statusLabel];
            
            UILabel *cityLabel = [[UILabel alloc] initWithFrame:CGRectMake(100, 60, cell.contentView.bounds.size.width - 150, 18)];
            cityLabel.font = [UIFont systemFontOfSize:13];
            cityLabel.textColor = [UIColor grayColor];
            cityLabel.tag = 604;
            [cell.contentView addSubview:cityLabel];
            
            // Круглая синяя кнопка (i)
            UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeCustom];
            infoButton.frame = CGRectMake(cell.contentView.bounds.size.width - 44, 24, 30, 30);
            infoButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            UIImage *infoImg = [UIImage imageNamed:@"7_profile_info"];
            if (infoImg) {
                [infoButton setImage:infoImg forState:UIControlStateNormal];
            } else {
                [infoButton setTitle:@"ⓘ" forState:UIControlStateNormal];
                [infoButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                infoButton.titleLabel.font = [UIFont systemFontOfSize:22];
            }
            [infoButton addTarget:self action:@selector(showDetailsAction) forControlEvents:UIControlEventTouchUpInside];
            infoButton.tag = 605;
            [cell.contentView addSubview:infoButton];
            
            // Разделитель
            UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(0, 100, cell.contentView.bounds.size.width, 0.5)];
            sep1.backgroundColor = [UIColor colorWithRed:220.0/255.0 green:223.0/255.0 blue:228.0/255.0 alpha:1.0];
            sep1.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep1];
            
            // Горизонтальный блок счетчиков (Скриншот 2)
            UIScrollView *countersScroll = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 101, cell.contentView.bounds.size.width, 54)];
            countersScroll.showsHorizontalScrollIndicator = NO;
            countersScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            countersScroll.tag = 606;
            [cell.contentView addSubview:countersScroll];
            
            // Разделитель
            UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(0, 155, cell.contentView.bounds.size.width, 0.5)];
            sep2.backgroundColor = [UIColor colorWithRed:220.0/255.0 green:223.0/255.0 blue:228.0/255.0 alpha:1.0];
            sep2.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep2];
            
            // Панель действий [Запись] [Фото] [Место] или кнопка [Вступить]
            UIView *actionsBar = [[UIView alloc] initWithFrame:CGRectMake(0, 156, cell.contentView.bounds.size.width, 48)];
            actionsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            actionsBar.tag = 607;
            [cell.contentView addSubview:actionsBar];
            
            // Разделитель снизу
            UIView *sep3 = [[UIView alloc] initWithFrame:CGRectMake(0, 204, cell.contentView.bounds.size.width, 6)];
            sep3.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:243.0/255.0 alpha:1.0];
            sep3.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:sep3];
        }
        
        UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:601];
        UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:602];
        UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:603];
        UILabel *cityLabel = (UILabel *)[cell.contentView viewWithTag:604];
        UIScrollView *countersScroll = (UIScrollView *)[cell.contentView viewWithTag:606];
        UIView *actionsBar = [cell.contentView viewWithTag:607];
        
        NSInteger myId = [[VKAuthService sharedService] currentUserId];
        BOOL isMyProfile = (self.user.uid == myId || self.user.uid == 0 || [self.user isCurrentUser]);
        
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:72.0];
        avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
        avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
        avatar.image = nil;
        avatar.userInteractionEnabled = YES;
        for (UIGestureRecognizer *gr in avatar.gestureRecognizers) {
            [avatar removeGestureRecognizer:gr];
        }
        [avatar addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(profileAvatarTapped:)]];
        if (self.user.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:self.user.avatarURL completion:^(UIImage *img) {
                if (img) avatar.image = img;
            }];
        }
        
        if (self.user.isOfficial) {
            nameLabel.text = [NSString stringWithFormat:@"%@ ✓", self.user.displayName];
        } else {
            nameLabel.text = self.user.displayName;
        }
        
        if (self.user.isGroup) {
            if ([self.user.groupType isEqualToString:@"page"]) {
                statusLabel.text = @"публичная страница";
            } else if ([self.user.groupType isEqualToString:@"event"]) {
                statusLabel.text = @"мероприятие";
            } else {
                statusLabel.text = self.user.isClosed ? @"закрытая группа" : @"открытая группа";
            }
            statusLabel.textColor = [UIColor grayColor];
            cityLabel.text = self.user.status.length > 0 ? self.user.status : @"";
        } else {
            BOOL hasStatus = (self.user.status.length > 0);
            NSString *onlText = self.user.isOnline ? @"online" : (self.user.lastSeen ?: @"был(а) недавно");
            if (self.user.isOnline && self.user.onlinePlatform.length > 0) {
                onlText = [NSString stringWithFormat:@"online (%@)", self.user.onlinePlatform];
            }
            if (self.user.city.length > 0) {
                onlText = [NSString stringWithFormat:@"%@ • %@", onlText, self.user.city];
            }
            
            if (hasStatus) {
                statusLabel.text = self.user.status;
                statusLabel.textColor = [UIColor colorWithRed:50.0/255.0 green:50.0/255.0 blue:55.0/255.0 alpha:1.0];
                cityLabel.text = onlText;
                cityLabel.textColor = self.user.isOnline ? [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] : [UIColor grayColor];
            } else {
                statusLabel.text = onlText;
                statusLabel.textColor = self.user.isOnline ? [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] : [UIColor grayColor];
                cityLabel.text = @"";
            }
        }
        
        // Заполняем счетчики
        for (UIView *v in countersScroll.subviews) [v removeFromSuperview];
        
        NSMutableArray *counters = [NSMutableArray array];
        if (self.user.isGroup) {
            NSString *membersTitle = [self.user.groupType isEqualToString:@"page"] ?
                pluralForm(self.user.followersCount, @"подписчик", @"подписчика", @"подписчиков") :
                pluralForm(self.user.followersCount, @"участник", @"участника", @"участников");
            [counters addObject:@{@"count": @(self.user.followersCount), @"title": membersTitle, @"action": @"followers"}];
            if (self.user.photoCount > 0) {
                [counters addObject:@{@"count": @(self.user.photoCount), @"title": pluralForm(self.user.photoCount, @"фото", @"фото", @"фото"), @"action": @"photos"}];
            }
            if (self.user.videoCount > 0) {
                [counters addObject:@{@"count": @(self.user.videoCount), @"title": pluralForm(self.user.videoCount, @"видео", @"видео", @"видео"), @"action": @"videos"}];
            }
            if (self.user.audioCount > 0) {
                [counters addObject:@{@"count": @(self.user.audioCount), @"title": pluralForm(self.user.audioCount, @"аудио", @"аудио", @"аудио"), @"action": @"audios"}];
            }
        } else {
            [counters addObject:@{@"count": @(self.user.friendsCount), @"title": pluralForm(self.user.friendsCount, @"друг", @"друга", @"друзей"), @"action": @"friends"}];
            if (self.user.followersCount > 0) {
                [counters addObject:@{@"count": @(self.user.followersCount), @"title": pluralForm(self.user.followersCount, @"подписчик", @"подписчика", @"подписчиков"), @"action": @"followers"}];
            }
            if (self.user.groupsCount > 0) {
                [counters addObject:@{@"count": @(self.user.groupsCount), @"title": pluralForm(self.user.groupsCount, @"группа", @"группы", @"групп"), @"action": @"groups"}];
            }
            if (self.user.photoCount > 0) {
                [counters addObject:@{@"count": @(self.user.photoCount), @"title": pluralForm(self.user.photoCount, @"фото", @"фото", @"фото"), @"action": @"photos"}];
            }
            if (self.user.videoCount > 0) {
                [counters addObject:@{@"count": @(self.user.videoCount), @"title": pluralForm(self.user.videoCount, @"видео", @"видео", @"видео"), @"action": @"videos"}];
            }
            if (self.user.audioCount > 0) {
                [counters addObject:@{@"count": @(self.user.audioCount), @"title": pluralForm(self.user.audioCount, @"аудио", @"аудио", @"аудио"), @"action": @"audios"}];
            }
        }
        
        CGFloat availW = cell.contentView.bounds.size.width;
        CGFloat itemW = counters.count > 0 ? MAX(76.0, availW / (CGFloat)counters.count) : 76.0;
        for (NSInteger i = 0; i < counters.count; i++) {
            NSDictionary *c = counters[i];
            UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            cBtn.frame = CGRectMake(i * itemW, 0, itemW, 54);
            
            UILabel *countLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, itemW, 20)];
            countLbl.text = [NSString stringWithFormat:@"%@", c[@"count"]];
            countLbl.font = [UIFont boldSystemFontOfSize:16];
            countLbl.textColor = [UIColor colorWithRed:40.0/255.0 green:40.0/255.0 blue:45.0/255.0 alpha:1.0];
            countLbl.textAlignment = NSTextAlignmentCenter;
            [cBtn addSubview:countLbl];
            
            UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, itemW, 16)];
            titleLbl.text = c[@"title"];
            titleLbl.font = [UIFont systemFontOfSize:12];
            titleLbl.textColor = [UIColor grayColor];
            titleLbl.textAlignment = NSTextAlignmentCenter;
            [cBtn addSubview:titleLbl];
            
            if ([c[@"action"] isEqualToString:@"friends"] || [c[@"action"] isEqualToString:@"followers"]) {
                [cBtn addTarget:self action:@selector(openFriendsList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"groups"]) {
                [cBtn addTarget:self action:@selector(openGroupsList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"photos"]) {
                [cBtn addTarget:self action:@selector(openPhotosList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"videos"]) {
                [cBtn addTarget:self action:@selector(openVideosList) forControlEvents:UIControlEventTouchUpInside];
            } else if ([c[@"action"] isEqualToString:@"audios"]) {
                [cBtn addTarget:self action:@selector(openAudiosList) forControlEvents:UIControlEventTouchUpInside];
            }
            [countersScroll addSubview:cBtn];
        }
        countersScroll.contentSize = CGSizeMake(MAX(availW, counters.count * itemW), 54);
        
        // Заполняем панель быстрых действий (Скриншот 2)
        for (UIView *v in actionsBar.subviews) [v removeFromSuperview];
        
        if (self.user.isGroup) {
            UIButton *joinBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            joinBtn.frame = CGRectMake(16, 6, cell.contentView.bounds.size.width - 32, 36);
            joinBtn.layer.cornerRadius = 4.0;
            joinBtn.clipsToBounds = YES;
            joinBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            
            if (self.user.isFriend) {
                joinBtn.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:245.0/255.0 alpha:1.0];
                [joinBtn setTitleColor:[UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                [joinBtn setTitle:@"Вы состоите в группе ✓" forState:UIControlStateNormal];
            } else {
                joinBtn.backgroundColor = [UIColor colorWithRed:81.0/255.0 green:129.0/255.0 blue:184.0/255.0 alpha:1.0];
                [joinBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                [joinBtn setTitle:@"Вступить" forState:UIControlStateNormal];
            }
            [joinBtn addTarget:self action:@selector(toggleGroupAction) forControlEvents:UIControlEventTouchUpInside];
            [actionsBar addSubview:joinBtn];
        } else if (isMyProfile) {
            CGFloat actW = cell.contentView.bounds.size.width / 3.0;
            NSArray *acts = @[
                @{@"title": @"Запись", @"image": @"7_profile_post_text"},
                @{@"title": @"Фото", @"image": @"7_profile_post_photo"},
                @{@"title": @"Место", @"image": @"7_profile_post_place"}
            ];
            for (NSInteger i = 0; i < 3; i++) {
                UIButton *actBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                actBtn.frame = CGRectMake(i * actW, 0, actW, 44);
                [actBtn setTitle:acts[i][@"title"] forState:UIControlStateNormal];
                [actBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                actBtn.titleLabel.font = [UIFont systemFontOfSize:14];
                
                UIImage *img = [UIImage imageNamed:acts[i][@"image"]];
                if (img) {
                    [actBtn setImage:img forState:UIControlStateNormal];
                    actBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 6);
                    actBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
                }
                
                if (i == 0) [actBtn addTarget:self action:@selector(newPostAction) forControlEvents:UIControlEventTouchUpInside];
                else if (i == 1) [actBtn addTarget:self action:@selector(postPhotoAction) forControlEvents:UIControlEventTouchUpInside];
                else if (i == 2) [actBtn addTarget:self action:@selector(newPostAction) forControlEvents:UIControlEventTouchUpInside];
                [actionsBar addSubview:actBtn];
                
                if (i < 2) {
                    UIView *div = [[UIView alloc] initWithFrame:CGRectMake((i + 1) * actW, 10, 0.5, 24)];
                    div.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:232.0/255.0 blue:236.0/255.0 alpha:1.0];
                    [actionsBar addSubview:div];
                }
            }
        } else {
            // Чужой профиль: кнопки [Сообщение] и [Добавить в друзья]
            CGFloat btnW = (cell.contentView.bounds.size.width - 32 - 10) / 2.0;
            
            UIButton *msgBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            msgBtn.frame = CGRectMake(16, 6, btnW, 36);
            msgBtn.layer.cornerRadius = 4.0;
            msgBtn.clipsToBounds = YES;
            msgBtn.backgroundColor = [UIColor colorWithRed:81.0/255.0 green:129.0/255.0 blue:184.0/255.0 alpha:1.0];
            [msgBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            msgBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            [msgBtn setTitle:@"Сообщение" forState:UIControlStateNormal];
            [msgBtn addTarget:self action:@selector(writeMessageAction) forControlEvents:UIControlEventTouchUpInside];
            [actionsBar addSubview:msgBtn];
            
            UIButton *frBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            frBtn.frame = CGRectMake(16 + btnW + 10, 6, btnW, 36);
            frBtn.layer.cornerRadius = 4.0;
            frBtn.clipsToBounds = YES;
            frBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            if (self.user.isFriend) {
                frBtn.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:245.0/255.0 alpha:1.0];
                [frBtn setTitleColor:[UIColor colorWithRed:40.0/255.0 green:40.0/255.0 blue:40.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                [frBtn setTitle:@"У вас в друзьях ✓" forState:UIControlStateNormal];
            } else {
                frBtn.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:242.0/255.0 blue:250.0/255.0 alpha:1.0];
                [frBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
                [frBtn setTitle:@"Добавить в друзья" forState:UIControlStateNormal];
            }
            [frBtn addTarget:self action:@selector(toggleFriendAction) forControlEvents:UIControlEventTouchUpInside];
            [actionsBar addSubview:frBtn];
        }
        return cell;
    } else {
        if (self.isShowingArchive && self.wallPosts.count == 0 && !self.isLoading) {
            static NSString *EmptyArchiveCellId = @"VKProfileEmptyArchiveCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EmptyArchiveCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EmptyArchiveCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor clearColor];
                
                UILabel *msgLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, tableView.bounds.size.width - 32, 44)];
                msgLabel.tag = 910;
                msgLabel.font = [UIFont systemFontOfSize:13];
                msgLabel.textColor = [UIColor grayColor];
                msgLabel.numberOfLines = 0;
                msgLabel.textAlignment = NSTextAlignmentCenter;
                msgLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
                msgLabel.text = @"Архив записей пуст или не поддерживается мобильным API данного сервера OpenVK.\nВы можете открыть веб-архив в браузере:";
                [cell.contentView addSubview:msgLabel];
                
                UIButton *webBtn = [UIButton buttonWithType:UIButtonTypeCustom];
                webBtn.tag = 911;
                webBtn.frame = CGRectMake((tableView.bounds.size.width - 240) / 2.0, 68, 240, 36);
                webBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                webBtn.layer.cornerRadius = 6.0;
                webBtn.clipsToBounds = YES;
                webBtn.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
                webBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
                [webBtn setTitle:@"🌐 Открыть веб-архив в Safari" forState:UIControlStateNormal];
                [webBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                [webBtn addTarget:self action:@selector(openWebArchive) forControlEvents:UIControlEventTouchUpInside];
                [cell.contentView addSubview:webBtn];
            }
            return cell;
        }
        
        static NSString *CellId = @"VKFeedPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        }
        
        if (indexPath.row < (NSInteger)self.wallPosts.count) {
            VKPost *post = self.wallPosts[indexPath.row];
            BOOL isRevealed = [self.revealedPostIds containsObject:@(post.vkID)] || ([VKAppConfig nsfwDisplayMode] == VKNSFWDisplayModeShowAlways);
            [cell configureWithPost:post isRevealed:isRevealed width:tableView.bounds.size.width];
            
            __weak typeof(self) weakSelf = self;
            cell.onRevealSpoilerTapped = ^(VKPost *p) {
                [weakSelf.revealedPostIds addObject:@(p.vkID)];
                [weakSelf.tableView reloadData];
            };
            cell.onOptionsTapped = ^(VKPost *p) {
                [weakSelf showPostOptions:p];
            };
            cell.onShowLikesTapped = ^(VKPost *p, NSInteger filter) {
                VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post"
                                                                                             ownerId:p.ownerID
                                                                                              itemId:p.vkID
                                                                                       initialFilter:filter];
                [weakSelf.navigationController pushViewController:likesVC animated:YES];
            };
            cell.onLikeTapped = ^(VKPost *p) {
                [[VKFeedService sharedService] likePost:p completion:nil];
            };
            cell.onCommentTapped = ^(VKPost *p) {
                VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:p];
                [weakSelf.navigationController pushViewController:detailVC animated:YES];
            };
            cell.onRepostTapped = ^(VKPost *p) {
                [[VKShareManager sharedManager] presentShareSheetForPost:p fromViewController:weakSelf completion:^{
                    [weakSelf.tableView reloadData];
                }];
            };
            cell.onToggleTextExpanded = ^(VKPost *p) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.tableView beginUpdates];
                    [weakSelf.tableView endUpdates];
                });
            };
            cell.onToggleRepostTextExpanded = ^(VKPost *p) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.tableView beginUpdates];
                    [weakSelf.tableView endUpdates];
                });
            };
            cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
                VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
                [weakSelf presentViewController:viewer animated:YES completion:nil];
            };
            cell.onPhotoTapped = ^(NSString *url, UIImage *img) {
                VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:url initialImage:img];
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
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([self shouldDisplayKateHub]) {
        if (indexPath.section == 0) {
            [self openFullProfile];
            return;
        }
        if (indexPath.section == 1) {
            switch (indexPath.row) {
                case 0:
                    [self openFriendsList];
                    break;
                case 1:
                    [self openFullProfileAndScrollToWall];
                    break;
                case 2:
                    [self openGroupsList];
                    break;
                case 3:
                    [self openPhotosList];
                    break;
                case 4:
                    [self openAudiosList];
                    break;
                case 5:
                    [self openVideosList];
                    break;
                case 6:
                    [self openBookmarksList];
                    break;
                case 7:
                    [self openRepliesList];
                    break;
                case 8:
                    [self openFullProfile];
                    break;
                default:
                    break;
            }
            return;
        }
    }
    
    if (indexPath.section == 1 && indexPath.row < (NSInteger)self.wallPosts.count) {
        VKPost *post = self.wallPosts[indexPath.row];
        VKPostDetailViewController *detailVC = [[VKPostDetailViewController alloc] initWithPost:post];
        [self.navigationController pushViewController:detailVC animated:YES];
    }
}

- (void)scrollToWallAction {
    if (self.wallPosts.count > 0) {
        [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1] atScrollPosition:UITableViewScrollPositionTop animated:YES];
    } else {
        [self.tableView setContentOffset:CGPointMake(0, 790.0) animated:YES];
    }
}

- (void)openFullProfile {
    VKProfileViewController *vc = [[VKProfileViewController alloc] initWithUser:self.user];
    vc.isFullProfileMode = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openFullProfileAndScrollToWall {
    VKProfileViewController *vc = [[VKProfileViewController alloc] initWithUser:self.user];
    vc.isFullProfileMode = YES;
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openBookmarksList {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Закладки"
                                                    message:@"Раздел закладок будет доступен в следующем обновлении OpenVK."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)openRepliesList {
    VKNotificationsViewController *vc = [[VKNotificationsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openFriendsList {
    VKFriendsListViewController *vc = [[VKFriendsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openGroupsList {
    VKGroupsListViewController *vc = [[VKGroupsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openPhotosList {
    VKAlbumsListViewController *vc = [[VKAlbumsListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openVideosList {
    VKVideosListViewController *vc = [[VKVideosListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openAudiosList {
    VKAudioListViewController *vc = [[VKAudioListViewController alloc] initWithUserId:self.user.uid];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
