#import "VKShareManager.h"
#import "VKFeedService.h"
#import "VKProfileService.h"
#import "VKAppConfig.h"
#import "VKShareDialogPickerViewController.h"
#import "VKShareGroupPickerViewController.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"
#import <objc/runtime.h>

@interface VKShareManager ()

@property (nonatomic, strong) VKPost *currentPost;
@property (nonatomic, weak) UIViewController *fromViewController;
@property (nonatomic, copy) void (^onSharedCompletion)(void);

@end

@implementation VKShareManager

+ (instancetype)sharedManager {
    static VKShareManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (void)presentShareSheetForPost:(VKPost *)post
              fromViewController:(UIViewController *)viewController
                      completion:(void (^)(void))completion {
    
    if (!post) return;
    self.currentPost = post;
    self.fromViewController = viewController;
    self.onSharedCompletion = completion;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Поделиться записью"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Рассказать друзьям", @"Опубликовать в сообществе", @"Отправить сообщением", @"Скопировать ссылку", nil];
    
    if (viewController.tabBarController.tabBar) {
        [sheet showFromTabBar:viewController.tabBarController.tabBar];
    } else {
        [sheet showInView:viewController.view];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        // 1. Рассказать друзьям (на своей стене)
        [self shareOnMyWall];
    } else if (buttonIndex == 1) {
        // 2. Опубликовать в сообществе
        [self shareInCommunity];
    } else if (buttonIndex == 2) {
        // 3. Отправить сообщением (в диалог)
        [self shareInMessages];
    } else if (buttonIndex == 3) {
        // 4. Скопировать ссылку
        [self copyPostLink];
    }
}

#pragma mark - Sharing Actions

- (void)shareOnMyWall {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Поделиться на стене"
                                                    message:@"Комментарий к записи (необязательно):"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Опубликовать", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 3001;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.placeholder = @"Ваш комментарий...";
    [alert show];
}

- (void)shareInCommunity {
    __weak typeof(self) weakSelf = self;
    [[VKProfileService sharedService] fetchManagedGroupsWithCompletion:^(NSArray<VKUser *> *groups, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || groups.count == 0) {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Сообщества не найдены"
                                                            message:@"У вас нет сообществ в управлении для публикации записи."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
                [a show];
                return;
            }
            
            if (groups.count == 1) {
                VKUser *onlyGroup = groups[0];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Опубликовать в «%@»?", onlyGroup.displayName]
                                                                message:@"Комментарий к записи (необязательно):"
                                                               delegate:weakSelf
                                                      cancelButtonTitle:@"Отмена"
                                                      otherButtonTitles:@"Опубликовать", nil];
                alert.alertViewStyle = UIAlertViewStylePlainTextInput;
                alert.tag = 3002;
                UITextField *tf = [alert textFieldAtIndex:0];
                tf.placeholder = @"Ваш комментарий...";
                objc_setAssociatedObject(alert, "vk_target_group", onlyGroup, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [alert show];
            } else {
                VKShareGroupPickerViewController *picker = [[VKShareGroupPickerViewController alloc] initWithPost:weakSelf.currentPost groups:groups];
                picker.onPostShared = ^{
                    if (weakSelf.onSharedCompletion) weakSelf.onSharedCompletion();
                };
                UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
                nav.navigationBar.barTintColor = [[VKThemeManager sharedManager] navBarBackgroundColor];
                nav.navigationBar.tintColor = [[VKThemeManager sharedManager] navBarTintColor];
                nav.navigationBar.titleTextAttributes = @{
                    NSForegroundColorAttributeName: [[VKThemeManager sharedManager] navBarTitleColor],
                    NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
                };
                [weakSelf.fromViewController presentViewController:nav animated:YES completion:nil];
            }
        });
    }];
}

- (void)shareInMessages {
    VKShareDialogPickerViewController *picker = [[VKShareDialogPickerViewController alloc] initWithPost:self.currentPost];
    __weak typeof(self) weakSelf = self;
    picker.onPostShared = ^{
        if (weakSelf.onSharedCompletion) weakSelf.onSharedCompletion();
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
    nav.navigationBar.barTintColor = [[VKThemeManager sharedManager] navBarBackgroundColor];
    nav.navigationBar.tintColor = [[VKThemeManager sharedManager] navBarTintColor];
    nav.navigationBar.titleTextAttributes = @{
        NSForegroundColorAttributeName: [[VKThemeManager sharedManager] navBarTitleColor],
        NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
    };
    [self.fromViewController presentViewController:nav animated:YES completion:nil];
}

- (void)copyPostLink {
    NSString *host = [VKAppConfig currentHost];
    NSString *link = [NSString stringWithFormat:@"https://%@/wall%ld_%ld", host, (long)self.currentPost.ownerID, (long)self.currentPost.vkID];
    [UIPasteboard generalPasteboard].string = link;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ссылка скопирована"
                                                    message:link
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex != 1) return;
    
    UITextField *tf = [alertView textFieldAtIndex:0];
    NSString *comment = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (alertView.tag == 3001) {
        // Репост на свою стену
        __weak typeof(self) weakSelf = self;
        [[VKFeedService sharedService] repostPost:self.currentPost
                                          message:comment
                                          groupId:0
                                       completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    weakSelf.currentPost.repostsCount += 1;
                    if (weakSelf.onSharedCompletion) weakSelf.onSharedCompletion();
                    
                    UIAlertView *okAlert = [[UIAlertView alloc] initWithTitle:@"Запись опубликована"
                                                                      message:@"Запись успешно опубликована на вашей стене!"
                                                                     delegate:nil
                                                            cancelButtonTitle:@"OK"
                                                            otherButtonTitles:nil];
                    [okAlert show];
                } else {
                    UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Ошибка публикации"
                                                                       message:error.localizedDescription ?: @"Не удалось сделать репост"
                                                                      delegate:nil
                                                             cancelButtonTitle:@"OK"
                                                             otherButtonTitles:nil];
                    [errAlert show];
                }
            });
        }];
    } else if (alertView.tag == 3002) {
        // Репост в единственное сообщество
        VKUser *targetGroup = objc_getAssociatedObject(alertView, "vk_target_group");
        if (!targetGroup) return;
        
        __weak typeof(self) weakSelf = self;
        [[VKFeedService sharedService] repostPost:self.currentPost
                                          message:comment
                                          groupId:targetGroup.uid
                                       completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    weakSelf.currentPost.repostsCount += 1;
                    if (weakSelf.onSharedCompletion) weakSelf.onSharedCompletion();
                    
                    UIAlertView *okAlert = [[UIAlertView alloc] initWithTitle:@"Запись опубликована"
                                                                      message:[NSString stringWithFormat:@"Запись успешно опубликована на стене сообщества «%@»!", targetGroup.displayName]
                                                                     delegate:nil
                                                            cancelButtonTitle:@"OK"
                                                            otherButtonTitles:nil];
                    [okAlert show];
                } else {
                    UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Ошибка публикации"
                                                                       message:error.localizedDescription ?: @"Не удалось сделать репост"
                                                                      delegate:nil
                                                             cancelButtonTitle:@"OK"
                                                             otherButtonTitles:nil];
                    [errAlert show];
                }
            });
        }];
    }
}

@end
