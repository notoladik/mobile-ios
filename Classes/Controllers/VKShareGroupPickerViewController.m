#import "VKShareGroupPickerViewController.h"
#import "VKFeedService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"

@interface VKShareGroupPickerViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) VKUser *selectedGroup;

@end

@implementation VKShareGroupPickerViewController

- (instancetype)initWithPost:(VKPost *)post groups:(NSArray<VKUser *> *)groups {
    self = [super init];
    if (self) {
        _post = post;
        _groups = groups ?: @[];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Опубликовать в группе";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Отмена"
                                                                                            target:self
                                                                                            action:@selector(cancelAction)
                                                                                            isBack:NO];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 60.0;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 0);
    }
    [self.view addSubview:self.tableView];
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.groups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKShareGroupCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.backgroundColor = [UIColor clearColor];
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 44, 44)];
        avatar.tag = 201;
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [cell.contentView addSubview:avatar];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.tag = 202;
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [cell.contentView addSubview:titleLabel];
        
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        subLabel.tag = 203;
        subLabel.font = [UIFont systemFontOfSize:12.5];
        subLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [cell.contentView addSubview:subLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.groups.count) return cell;
    VKUser *group = self.groups[indexPath.row];
    
    CGFloat width = tableView.bounds.size.width;
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:201];
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:44.0];
    avatar.image = [UIImage imageNamed:@"7_group_placeholder"];
    if (group.avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:group.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:202];
    titleLabel.text = group.displayName ?: @"Сообщество";
    titleLabel.frame = CGRectMake(68, 10, width - 80, 20);
    if (isSkeuo) {
        titleLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        titleLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    UILabel *subLabel = (UILabel *)[cell.contentView viewWithTag:203];
    subLabel.text = group.followersCount > 0 ? [NSString stringWithFormat:@"%ld участников", (long)group.followersCount] : @"Сообщество";
    subLabel.frame = CGRectMake(68, 32, width - 80, 16);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.groups.count) return;
    
    self.selectedGroup = self.groups[indexPath.row];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Опубликовать от имени «%@»?", self.selectedGroup.displayName]
                                                    message:@"Комментарий (необязательно):"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Опубликовать", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.placeholder = @"Ваш комментарий...";
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && self.selectedGroup) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *comment = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        [VKCrashLogger log:@"[VKShareGroupPicker] Reposting to group %ld", (long)self.selectedGroup.uid];
        
        __weak typeof(self) weakSelf = self;
        [[VKFeedService sharedService] repostPost:self.post
                                          message:comment
                                          groupId:self.selectedGroup.uid
                                       completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    weakSelf.post.repostsCount += 1;
                    if (weakSelf.onPostShared) weakSelf.onPostShared();
                    
                    UIAlertView *okAlert = [[UIAlertView alloc] initWithTitle:@"Запись опубликована"
                                                                      message:[NSString stringWithFormat:@"Запись успешно опубликована на стене сообщества «%@»!", weakSelf.selectedGroup.displayName]
                                                                     delegate:nil
                                                            cancelButtonTitle:@"OK"
                                                            otherButtonTitles:nil];
                    [okAlert show];
                    [weakSelf dismissViewControllerAnimated:YES completion:nil];
                } else {
                    UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Ошибка публикации"
                                                                       message:error.localizedDescription ?: @"Не удалось опубликовать запись"
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
