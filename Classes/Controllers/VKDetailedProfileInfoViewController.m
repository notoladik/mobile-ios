#import "VKDetailedProfileInfoViewController.h"

@interface VKDetailedProfileInfoViewController ()
@property (nonatomic, strong) VKUser *user;
@property (nonatomic, strong) NSMutableArray *sections;
@end

@implementation VKDetailedProfileInfoViewController

- (instancetype)initWithUser:(VKUser *)user {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _user = user;
        _sections = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Информация";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Закрыть" style:UIBarButtonItemStyleDone target:self action:@selector(closeAction)];
    
    [self prepareData];
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prepareData {
    [self.sections removeAllObjects];
    
    // Секция 1: Основная
    NSMutableArray *mainSection = [NSMutableArray array];
    [mainSection addObject:@{@"label": @"Имя", @"val": self.user.displayName ?: @""}];
    if (self.user.username.length > 0) {
        [mainSection addObject:@{@"label": @"Никнейм", @"val": [NSString stringWithFormat:@"@%@", self.user.username]}];
    }
    if (self.user.status.length > 0) {
        [mainSection addObject:@{@"label": @"Статус", @"val": self.user.status}];
    }
    if (!self.user.isGroup) {
        NSString *onlineText = self.user.isOnline ? @"В сети" : (self.user.lastSeen ?: @"Не в сети");
        [mainSection addObject:@{@"label": @"Активность", @"val": onlineText}];
    }
    [self.sections addObject:@{@"title": @"Основная информация", @"rows": mainSection}];
    
    // Секция 2: Контактная
    NSMutableArray *contactSection = [NSMutableArray array];
    if (self.user.city.length > 0) {
        [contactSection addObject:@{@"label": @"Город", @"val": self.user.city}];
    }
    if (self.user.site.length > 0) {
        [contactSection addObject:@{@"label": @"Сайт", @"val": self.user.site}];
    }
    if (contactSection.count > 0) {
        [self.sections addObject:@{@"title": @"Контактная информация", @"rows": contactSection}];
    }
    
    // Секция 3: Личная
    if (self.user.about.length > 0) {
        [self.sections addObject:@{
            @"title": @"Личная информация",
            @"rows": @[@{@"label": @"О себе", @"val": self.user.about}]
        }];
    }
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sections[section][@"title"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *rows = self.sections[section][@"rows"];
    return rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKDetailedInfoCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.textLabel.textColor = [UIColor darkGrayColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:15];
        cell.detailTextLabel.textColor = [UIColor blackColor];
    }
    
    NSDictionary *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    cell.textLabel.text = row[@"label"];
    cell.detailTextLabel.text = row[@"val"];
    return cell;
}

@end
