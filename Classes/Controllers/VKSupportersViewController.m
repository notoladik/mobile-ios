#import "VKSupportersViewController.h"
#import "VKSupportersService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"

@interface VKSupportersViewController ()
@end

@implementation VKSupportersViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Другие";
    [self applyThemeStyle];
    [self setupNavigationItems];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    [[VKSupportersService sharedService] fetchSupportersIfNeeded];
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
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 0: Тестеры, 1: Донатеры
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"ТЕСТЕРЫ";
    return @"ДОНАТЕРЫ";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return [[VKSupportersService sharedService] testers].count;
    } else {
        return [[VKSupportersService sharedService] donors].count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    VKSupporter *s = (indexPath.section == 0) ? [[VKSupportersService sharedService] testers][indexPath.row] : [[VKSupportersService sharedService] donors][indexPath.row];
    if (s.message.length > 0) return 64.0;
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKSupporterCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    VKSupporter *s = (indexPath.section == 0) ? [[VKSupportersService sharedService] testers][indexPath.row] : [[VKSupportersService sharedService] donors][indexPath.row];
    
    cell.textLabel.text = [s displayName];
    if (s.amount.length > 0 && s.message.length > 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@", s.amount, s.message];
    } else if (s.amount.length > 0) {
        cell.detailTextLabel.text = s.amount;
    } else if (s.message.length > 0) {
        cell.detailTextLabel.text = s.message;
    } else {
        cell.detailTextLabel.text = s.nick ? [NSString stringWithFormat:@"@%@", s.nick] : @"";
    }
    
    if (s.iconURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:s.iconURL completion:^(UIImage *img) {
            if (img) {
                cell.imageView.image = img;
                [cell setNeedsLayout];
            }
        }];
    } else {
        cell.imageView.image = nil;
    }
    
    return cell;
}

@end
