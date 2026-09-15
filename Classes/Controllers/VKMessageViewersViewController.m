#import "VKMessageViewersViewController.h"
#import "VKMessagesService.h"
#import "VKProfileViewController.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"

@interface VKMessageViewersViewController ()
@property (nonatomic, strong) NSMutableArray<VKUser *> *viewers;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation VKMessageViewersViewController

- (instancetype)initWithPeerId:(NSInteger)peerId messageId:(NSInteger)messageId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _peerId = peerId;
        _messageId = messageId;
        _viewers = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithViewers:(NSArray<VKUser *> *)viewers {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _viewers = [NSMutableArray arrayWithArray:viewers ?: @[]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Просмотрели";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    if (self.navigationController.viewControllers.count > 1) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(closeAction) isBack:YES];
    } else {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Готово" style:UIBarButtonItemStyleDone target:self action:@selector(closeAction)];
    }
    
    if (self.viewers.count == 0 && self.messageId > 0) {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0, 120.0);
        [self.view addSubview:self.spinner];
        [self.spinner startAnimating];
        [self loadViewers];
    }
}

- (void)closeAction {
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)loadViewers {
    [[VKMessagesService sharedService] fetchMessageViewersWithPeerId:self.peerId messageId:self.messageId completion:^(NSArray<VKUser *> *viewers, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];
            [self.spinner removeFromSuperview];
            
            if (viewers.count > 0) {
                [self.viewers removeAllObjects];
                [self.viewers addObjectsFromArray:viewers];
                [self.tableView reloadData];
            } else {
                UILabel *emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, self.view.bounds.size.width - 40, 40)];
                emptyLabel.text = @"Никто еще не прочитал это сообщение";
                emptyLabel.textAlignment = NSTextAlignmentCenter;
                emptyLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
                emptyLabel.font = [UIFont systemFontOfSize:14];
                [self.view addSubview:emptyLabel];
            }
        });
    }];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.viewers.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 56.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKMessageViewerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.backgroundColor = [UIColor clearColor];
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 40, 40)];
        avatar.tag = 4001;
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:40.0];
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        avatar.contentMode = UIViewContentModeScaleAspectFill;
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(62, 8, tableView.bounds.size.width - 74, 20)];
        nameLabel.tag = 4002;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:nameLabel];
        
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(62, 30, tableView.bounds.size.width - 74, 16)];
        statusLabel.tag = 4003;
        statusLabel.font = [UIFont systemFontOfSize:12];
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:statusLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.viewers.count) return cell;
    VKUser *user = self.viewers[indexPath.row];
    
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:4001];
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:4002];
    UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:4003];
    
    nameLabel.text = user.displayName ?: @"Пользователь";
    if (user.isOnline) {
        statusLabel.text = @"в сети";
        statusLabel.textColor = [UIColor colorWithRed:76.0/255.0 green:175.0/255.0 blue:80.0/255.0 alpha:1.0];
    } else {
        statusLabel.text = user.lastSeen ?: @"был(а) недавно";
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    }
    
    avatar.image = nil;
    if (user.avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.viewers.count) return;
    VKUser *user = self.viewers[indexPath.row];
    VKProfileViewController *pvc = [[VKProfileViewController alloc] initWithUser:user];
    [self.navigationController pushViewController:pvc animated:YES];
}

@end
