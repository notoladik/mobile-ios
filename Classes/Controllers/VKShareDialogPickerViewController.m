#import "VKShareDialogPickerViewController.h"
#import "VKMessagesService.h"
#import "VKMessage.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"
#import <QuartzCore/QuartzCore.h>

@interface VKShareDialogPickerViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) NSMutableArray<VKConversation *> *conversations;
@property (nonatomic, strong) NSMutableArray<VKConversation *> *filteredConversations;
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, strong) VKConversation *selectedConversation;

@end

@implementation VKShareDialogPickerViewController

- (instancetype)initWithPost:(VKPost *)post {
    self = [super init];
    if (self) {
        _post = post;
        _conversations = [NSMutableArray array];
        _filteredConversations = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Отправить в диалог";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Отмена"
                                                                                            target:self
                                                                                            action:@selector(cancelAction)
                                                                                            isBack:NO];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64.0;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    if ([self.tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        self.tableView.separatorInset = UIEdgeInsetsMake(0, 68, 0, 0);
    }
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.placeholder = @"Поиск диалогов";
    self.searchBar.delegate = self;
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.searchBar.tintColor = [UIColor colorWithRed:80.0/255.0 green:110.0/255.0 blue:145.0/255.0 alpha:1.0];
    }
    self.tableView.tableHeaderView = self.searchBar;
    
    [self.view addSubview:self.tableView];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:
                              [[VKThemeManager sharedManager] isSkeuomorphic] ? UIActivityIndicatorViewStyleGray : UIActivityIndicatorViewStyleGray];
    self.activityIndicator.center = self.view.center;
    self.activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [self loadConversations];
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadConversations {
    [self.activityIndicator startAnimating];
    
    __weak typeof(self) weakSelf = self;
    [[VKMessagesService sharedService] fetchConversationsWithOffset:0 count:50 completion:^(NSArray *conversations, NSInteger unreadCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicator stopAnimating];
            if (!error && conversations) {
                weakSelf.conversations = [NSMutableArray arrayWithArray:conversations];
                [weakSelf.tableView reloadData];
            }
        });
    }];
}

#pragma mark - Search

- (NSArray<VKConversation *> *)currentList {
    return self.isSearching ? self.filteredConversations : self.conversations;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *query = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.isSearching = NO;
        [self.filteredConversations removeAllObjects];
    } else {
        self.isSearching = YES;
        [self.filteredConversations removeAllObjects];
        for (VKConversation *c in self.conversations) {
            if ([c.displayTitle rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [self.filteredConversations addObject:c];
            }
        }
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self currentList].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKShareDialogCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.backgroundColor = [UIColor clearColor];
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 44, 44)];
        avatar.tag = 101;
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        [cell.contentView addSubview:avatar];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        titleLabel.tag = 102;
        titleLabel.font = [UIFont boldSystemFontOfSize:15];
        titleLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:25.0/255.0 alpha:1.0];
        [cell.contentView addSubview:titleLabel];
        
        UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        subLabel.tag = 103;
        subLabel.font = [UIFont systemFontOfSize:13];
        subLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [cell.contentView addSubview:subLabel];
    }
    
    NSArray<VKConversation *> *list = [self currentList];
    if (indexPath.row >= (NSInteger)list.count) return cell;
    VKConversation *conv = list[indexPath.row];
    
    CGFloat width = tableView.bounds.size.width;
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:101];
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:44.0];
    
    if (conv.isChat) {
        avatar.image = [UIImage imageNamed:isSkeuo ? @"MessagesGroup" : @"7_messages_group"];
    } else if (conv.isGroup) {
        avatar.image = [UIImage imageNamed:@"7_group_placeholder"];
    } else {
        avatar.image = [UIImage imageNamed:isSkeuo ? @"user_placeholder" : @"7_user_placeholder"];
    }
    
    NSString *avatarURL = [conv displayAvatarURL];
    if (avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:102];
    titleLabel.text = [conv displayTitle];
    titleLabel.frame = CGRectMake(68, 12, width - 80, 20);
    if (isSkeuo) {
        titleLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        titleLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
    }
    
    UILabel *subLabel = (UILabel *)[cell.contentView viewWithTag:103];
    if (conv.isChat) {
        subLabel.text = conv.membersCount > 0 ? [NSString stringWithFormat:@"Беседа, %ld участников", (long)conv.membersCount] : @"Беседа";
    } else if (conv.isGroup) {
        subLabel.text = @"Сообщество";
    } else {
        subLabel.text = conv.peerUser.isOnline ? @"В сети" : @"Личный диалог";
    }
    subLabel.frame = CGRectMake(68, 34, width - 80, 16);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray<VKConversation *> *list = [self currentList];
    if (indexPath.row >= (NSInteger)list.count) return;
    
    self.selectedConversation = list[indexPath.row];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Отправить в «%@»?", [self.selectedConversation displayTitle]]
                                                    message:@"Комментарий (необязательно):"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Отправить", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.placeholder = @"Ваш комментарий...";
    [alert show];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1 && self.selectedConversation) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *comment = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        NSString *attachment = [NSString stringWithFormat:@"wall%ld_%ld", (long)self.post.ownerID, (long)self.post.vkID];
        
        [VKCrashLogger log:@"[VKShareDialogPicker] Sending post %@ to peerId=%ld", attachment, (long)self.selectedConversation.peerId];
        
        __weak typeof(self) weakSelf = self;
        [[VKMessagesService sharedService] sendMessageToPeerId:self.selectedConversation.peerId
                                                          text:comment
                                                    attachment:attachment
                                                    completion:^(BOOL success, NSInteger messageId, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    weakSelf.post.repostsCount += 1;
                    if (weakSelf.onPostShared) weakSelf.onPostShared();
                    
                    UIAlertView *okAlert = [[UIAlertView alloc] initWithTitle:@"Запись отправлена"
                                                                      message:[NSString stringWithFormat:@"Запись отправлена в диалог «%@»", [weakSelf.selectedConversation displayTitle]]
                                                                     delegate:nil
                                                            cancelButtonTitle:@"OK"
                                                            otherButtonTitles:nil];
                    [okAlert show];
                    [weakSelf dismissViewControllerAnimated:YES completion:nil];
                } else {
                    UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Ошибка отправки"
                                                                       message:error.localizedDescription ?: @"Не удалось отправить запись"
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
