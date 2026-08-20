#import "VKMessagesViewController.h"
#import "VKMessagesService.h"
#import "VKMessage.h"
#import "VKChatViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKThemeManager.h"
#import "VKSideMenuManager.h"
#import "VKCrashLogger.h"
#import <QuartzCore/QuartzCore.h>

@interface VKMessagesViewController ()
@property (nonatomic, strong) NSMutableArray *conversations;
@property (nonatomic, assign) BOOL isLoading;

// Пасхалка: разбитое окно
@property (nonatomic, strong) UIView *shatteredOverlayView;
@property (nonatomic, strong) UIView *behindGlassView;
@property (nonatomic, strong) UIView *glassView;
@property (nonatomic, assign) BOOL hasShattered;
@end

@implementation VKMessagesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKMessagesViewController] viewDidLoad started."];
    
    self.title = @"Сообщения";
    self.conversations = [NSMutableArray array];
    self.tableView.rowHeight = 74.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 72, 0, 0);
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    [self setupNavigationItems];
    [self applyThemeStyle];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupNavigationItems) name:VKSideMenuStateDidChangeNotification object:nil];
    
    if (NSClassFromString(@"UIRefreshControl")) {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        [refreshControl addTarget:self action:@selector(loadDialogs) forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
    
    [self loadDialogs];
    [self setupShatteredGlassOverlay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.hasShattered) {
        [self performSelector:@selector(triggerGlassBreakAnimation) withObject:nil afterDelay:0.35];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
}

- (void)setupNavigationItems {
    if ([[VKSideMenuManager sharedManager] isSideMenuEnabled]) {
        self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] navBarMenuBarButtonItemWithTarget:self action:@selector(leftMenuButtonAction)];
    } else {
        self.navigationItem.leftBarButtonItem = nil;
    }
    
    // Кнопка для повторного разбития окна для прикола
    if (self.hasShattered) {
        self.navigationItem.rightBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"🔨" target:self action:@selector(resetAndBreakGlass) isBack:NO];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
}

- (void)leftMenuButtonAction {
    [[VKSideMenuManager sharedManager] toggleMenu];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    [self.tableView reloadData];
}

#pragma mark - 💥 Пасхалка: Разбитое окно

- (void)setupShatteredGlassOverlay {
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
    self.shatteredOverlayView = [[UIView alloc] initWithFrame:bounds];
    self.shatteredOverlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.shatteredOverlayView.clipsToBounds = YES;
    
    // 1. Задний фон за стеклом (темная кирпичная стена / стройка)
    self.behindGlassView = [[UIView alloc] initWithFrame:bounds];
    self.behindGlassView.backgroundColor = [UIColor colorWithRed:24.0/255.0 green:28.0/255.0 blue:36.0/255.0 alpha:1.0];
    
    // Предупреждающая плашка ровно по центру экрана
    CGFloat cardW = bounds.size.width - 40.0;
    CGFloat cardH = 260.0;
    CGFloat cardY = (bounds.size.height - cardH) / 2.0;
    
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(20, cardY, cardW, cardH)];
    card.backgroundColor = [UIColor colorWithRed:34.0/255.0 green:40.0/255.0 blue:52.0/255.0 alpha:0.98];
    card.layer.cornerRadius = 12.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithRed:235.0/255.0 green:87.0/255.0 blue:87.0/255.0 alpha:0.7].CGColor;
    card.clipsToBounds = YES;
    
    // Иконка опасности / стройки
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 16, cardW, 40)];
    iconLabel.text = @"⚠️ 🔨 💥";
    iconLabel.font = [UIFont systemFontOfSize:30];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    [card addSubview:iconLabel];
    
    // Заголовок
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(16, 60, cardW - 32, 50)];
    titleLbl.text = @"Нормальные диалоги\nещё не вышли в ОВК";
    titleLbl.font = [UIFont boldSystemFontOfSize:17];
    titleLbl.textColor = [UIColor colorWithRed:255.0/255.0 green:215.0/255.0 blue:0.0/255.0 alpha:1.0];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.numberOfLines = 2;
    [card addSubview:titleLbl];
    
    // Описание
    UILabel *descLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, cardW - 40, 55)];
    descLbl.text = @"Разработчики OpenVK усердно переписывают протокол сообщений. Ведутся ремонтные работы.";
    descLbl.font = [UIFont systemFontOfSize:13];
    descLbl.textColor = [UIColor colorWithRed:180.0/255.0 green:190.0/255.0 blue:205.0/255.0 alpha:1.0];
    descLbl.textAlignment = NSTextAlignmentCenter;
    descLbl.numberOfLines = 3;
    [card addSubview:descLbl];
    
    // Кнопка склеить скотчем
    UIButton *tapeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    tapeBtn.frame = CGRectMake(24, 185, cardW - 48, 44);
    tapeBtn.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    tapeBtn.layer.cornerRadius = 6.0;
    tapeBtn.clipsToBounds = YES;
    [tapeBtn setTitle:@"🔧 Заклеить скотчем (Диалоги)" forState:UIControlStateNormal];
    [tapeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    tapeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [tapeBtn addTarget:self action:@selector(fixGlassAction) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:tapeBtn];
    
    [self.behindGlassView addSubview:card];
    [self.shatteredOverlayView addSubview:self.behindGlassView];
    
    // 2. Стеклянная панель с имитацией окна диалогов
    self.glassView = [[UIView alloc] initWithFrame:bounds];
    self.glassView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98];
    
    for (NSInteger i = 0; i < 8; i++) {
        UIView *fakeRow = [[UIView alloc] initWithFrame:CGRectMake(0, i * 74.0, bounds.size.width, 74.0)];
        fakeRow.backgroundColor = [UIColor whiteColor];
        
        UIView *fakeAvatar = [[UIView alloc] initWithFrame:CGRectMake(12, 13, 48, 48)];
        fakeAvatar.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0];
        fakeAvatar.layer.cornerRadius = 24.0;
        [fakeRow addSubview:fakeAvatar];
        
        UIView *fakeName = [[UIView alloc] initWithFrame:CGRectMake(72, 18, 120, 14)];
        fakeName.backgroundColor = [UIColor colorWithRed:200.0/255.0 green:205.0/255.0 blue:215.0/255.0 alpha:1.0];
        fakeName.layer.cornerRadius = 3.0;
        [fakeRow addSubview:fakeName];
        
        UIView *fakeText = [[UIView alloc] initWithFrame:CGRectMake(72, 40, bounds.size.width - 120, 12)];
        fakeText.backgroundColor = [UIColor colorWithRed:230.0/255.0 green:234.0/255.0 blue:240.0/255.0 alpha:1.0];
        fakeText.layer.cornerRadius = 3.0;
        [fakeRow addSubview:fakeText];
        
        UIView *fakeLine = [[UIView alloc] initWithFrame:CGRectMake(72, 73.5, bounds.size.width - 72, 0.5)];
        fakeLine.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
        [fakeRow addSubview:fakeLine];
        
        [self.glassView addSubview:fakeRow];
    }
    
    [self.shatteredOverlayView addSubview:self.glassView];
    
    UIView *container = self.navigationController.view ?: self.view;
    [container addSubview:self.shatteredOverlayView];
}

- (void)triggerGlassBreakAnimation {
    if (self.hasShattered) return;
    self.hasShattered = YES;
    [self setupNavigationItems];
    
    // 1. Тряска экрана (Землетрясение / Удар)
    CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    shake.duration = 0.35;
    shake.values = @[@(-12), @(12), @(-8), @(8), @(-4), @(4), @(0)];
    [self.glassView.layer addAnimation:shake forKey:@"shake"];
    
    // 2. Рисуем паутину трещин стекла
    CAShapeLayer *crackLayer = [CAShapeLayer layer];
    crackLayer.frame = self.glassView.bounds;
    UIBezierPath *path = [UIBezierPath bezierPath];
    
    CGPoint center = CGPointMake(self.glassView.bounds.size.width / 2.0, self.glassView.bounds.size.height / 2.0 - 30);
    
    // Линии трещин от центра
    for (NSInteger i = 0; i < 12; i++) {
        CGFloat angle = (M_PI * 2.0 / 12.0) * i + (arc4random_uniform(20) - 10) * 0.02;
        CGFloat len = 120.0 + arc4random_uniform(160);
        CGPoint endPoint = CGPointMake(center.x + cosf(angle) * len, center.y + sinf(angle) * len);
        
        [path moveToPoint:center];
        CGPoint midPoint = CGPointMake((center.x + endPoint.x)/2.0 + (arc4random_uniform(30) - 15), (center.y + endPoint.y)/2.0 + (arc4random_uniform(30) - 15));
        [path addLineToPoint:midPoint];
        [path addLineToPoint:endPoint];
    }
    
    crackLayer.path = path.CGPath;
    crackLayer.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
    crackLayer.lineWidth = 1.8;
    crackLayer.fillColor = [UIColor clearColor].CGColor;
    [self.glassView.layer addSublayer:crackLayer];
    
    // 3. Через мгновение осколки разлетаются и падают вниз
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.75 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.glassView.transform = CGAffineTransformMakeScale(1.15, 1.15);
            self.glassView.alpha = 0.0;
            self.glassView.frame = CGRectMake(-40, self.view.bounds.size.height + 50, self.view.bounds.size.width + 80, self.view.bounds.size.height);
        } completion:^(BOOL finished) {
            [self.glassView removeFromSuperview];
        }];
    });
}

- (void)fixGlassAction {
    // Анимация заклеивания скотчем и открытия диалогов
    [UIView animateWithDuration:0.35 animations:^{
        self.shatteredOverlayView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.shatteredOverlayView removeFromSuperview];
    }];
}

- (void)resetAndBreakGlass {
    [self.shatteredOverlayView removeFromSuperview];
    self.hasShattered = NO;
    [self setupShatteredGlassOverlay];
    [self triggerGlassBreakAnimation];
}

#pragma mark - Загрузка диалогов

- (void)loadDialogs {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [VKCrashLogger log:@"[VKMessagesViewController] Loading conversations..."];
    
    [[VKMessagesService sharedService] fetchConversationsWithOffset:0 count:40 completion:^(NSArray *conversations, NSInteger unreadCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (NSClassFromString(@"UIRefreshControl") && self.refreshControl.isRefreshing) {
                [self.refreshControl endRefreshing];
            }
            
            if (error) {
                [VKCrashLogger log:@"[VKMessagesViewController] Error loading dialogs: %@", error.localizedDescription];
                return;
            }
            
            self.conversations = [NSMutableArray arrayWithArray:conversations ?: @[]];
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKConversationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 13, 48, 48)];
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        avatar.tag = 301;
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:25.0/255.0 alpha:1.0];
        nameLabel.tag = 302;
        [cell.contentView addSubview:nameLabel];
        
        UILabel *badgeVerified = [[UILabel alloc] initWithFrame:CGRectZero];
        badgeVerified.text = @"✓";
        badgeVerified.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        badgeVerified.font = [UIFont boldSystemFontOfSize:12];
        badgeVerified.hidden = YES;
        badgeVerified.tag = 303;
        [cell.contentView addSubview:badgeVerified];
        
        UIImageView *supporterBadge = [[UIImageView alloc] initWithFrame:CGRectZero];
        supporterBadge.contentMode = UIViewContentModeScaleAspectFit;
        supporterBadge.hidden = YES;
        supporterBadge.tag = 304;
        [cell.contentView addSubview:supporterBadge];
        
        UILabel *msgLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        msgLabel.font = [UIFont systemFontOfSize:13];
        msgLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        msgLabel.tag = 305;
        [cell.contentView addSubview:msgLabel];
        
        UILabel *unreadBadge = [[UILabel alloc] initWithFrame:CGRectZero];
        unreadBadge.font = [UIFont boldSystemFontOfSize:12];
        unreadBadge.textColor = [UIColor whiteColor];
        unreadBadge.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        unreadBadge.textAlignment = NSTextAlignmentCenter;
        unreadBadge.layer.cornerRadius = 10.0;
        unreadBadge.clipsToBounds = YES;
        unreadBadge.hidden = YES;
        unreadBadge.tag = 306;
        [cell.contentView addSubview:unreadBadge];
    }
    
    if (indexPath.row >= (NSInteger)self.conversations.count) return cell;
    
    VKConversation *conv = self.conversations[indexPath.row];
    CGFloat width = tableView.bounds.size.width;
    
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:301];
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:48.0];
    avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    avatar.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:302];
    nameLabel.font = [[VKThemeManager sharedManager] titleFontOfSize:16];
    UILabel *badgeVerified = (UILabel *)[cell.contentView viewWithTag:303];
    UIImageView *supporterBadge = (UIImageView *)[cell.contentView viewWithTag:304];
    UILabel *msgLabel = (UILabel *)[cell.contentView viewWithTag:305];
    UILabel *unreadBadge = (UILabel *)[cell.contentView viewWithTag:306];
    
    avatar.image = nil;
    if (conv.peerUser.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:conv.peerUser.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    nameLabel.text = conv.title ?: @"Беседа";
    CGSize nameSize = [nameLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:15]];
    nameLabel.frame = CGRectMake(72, 16, MIN(nameSize.width, width - 150), 20);
    
    CGFloat nextX = CGRectGetMaxX(nameLabel.frame) + 4;
    if (conv.peerUser.isOfficial) {
        badgeVerified.hidden = NO;
        badgeVerified.frame = CGRectMake(nextX, 19, 13, 13);
        nextX += 17;
    } else {
        badgeVerified.hidden = YES;
    }
    
    NSString *badgeURL = [[VKSupportersService sharedService] badgeIconURLForScreenName:conv.peerUser.username];
    if (badgeURL.length > 0) {
        supporterBadge.hidden = NO;
        supporterBadge.frame = CGRectMake(nextX, 18, 14, 14);
        [[VKImageLoader sharedLoader] loadImageWithURL:badgeURL completion:^(UIImage *img) {
            if (img) supporterBadge.image = img;
        }];
    } else {
        supporterBadge.hidden = YES;
    }
    
    NSString *msgPrefix = conv.lastMessage.isOutgoing ? @"Вы: " : @"";
    msgLabel.text = [NSString stringWithFormat:@"%@%@", msgPrefix, conv.lastMessage.text ?: @"[Вложение]"];
    msgLabel.frame = CGRectMake(72, 38, width - 130, 18);
    
    if (conv.unreadCount > 0) {
        unreadBadge.hidden = NO;
        unreadBadge.text = [NSString stringWithFormat:@"%ld", (long)conv.unreadCount];
        unreadBadge.frame = CGRectMake(width - 45, 27, 26, 20);
    } else {
        unreadBadge.hidden = YES;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.conversations.count) {
        VKConversation *conv = self.conversations[indexPath.row];
        VKChatViewController *chatVC = [[VKChatViewController alloc] initWithPeerId:conv.peerId peerUser:conv.peerUser title:conv.title];
        [self.navigationController pushViewController:chatVC animated:YES];
    }
}

@end
