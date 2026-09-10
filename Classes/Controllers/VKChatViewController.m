#import "VKChatViewController.h"
#import "VKChatMembersViewController.h"
#import "VKChatSettingsViewController.h"
#import "VKMessagesService.h"
#import "VKProfileViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"
#import "VKAPIClient.h"
#import "VKAttachment.h"
#import "VKPhotoEditorViewController.h"
#import "VKLongPollService.h"
#import "VKAuthService.h"
#import "VKPostDetailViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface VKChatUserButton : UIButton
@property (nonatomic, strong) VKUser *user;
@end

@implementation VKChatUserButton
@end

@interface VKChatAuthorTapGesture : UITapGestureRecognizer
@property (nonatomic, strong) VKUser *user;
@end

@implementation VKChatAuthorTapGesture
@end

@interface VKChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UITextField *messageTextField;
@property (nonatomic, strong) UIButton *sendButton;

// Панель возвращения в беседу
@property (nonatomic, strong) UIView *leaveReturnBannerView;
@property (nonatomic, strong) UILabel *leaveReturnLabel;
@property (nonatomic, strong) UIButton *returnToChatButton;
@property (nonatomic, assign) BOOL isLeftOrKicked;

@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) NSTimeInterval lastTypingTime;
@property (nonatomic, strong) NSMutableDictionary *usersCache;
@property (nonatomic, strong) NSMutableDictionary *pendingUserFetches;
@property (nonatomic, strong) UIImageView *navAvatarView;
@property (nonatomic, strong) UIView *navAvatarContainer;
@end

@implementation VKChatViewController

- (instancetype)initWithPeerId:(NSInteger)peerId peerUser:(VKUser *)peerUser title:(NSString *)title {
    self = [super init];
    if (self) {
        _peerId = peerId;
        _peerUser = peerUser;
        _chatTitle = title ?: peerUser.displayName ?: @"Чат";
        _messages = [NSMutableArray array];
        _usersCache = [NSMutableDictionary dictionary];
        _pendingUserFetches = [NSMutableDictionary dictionary];
        if (peerUser && peerUser.uid != 0) {
            _usersCache[@(peerUser.uid)] = peerUser;
        }
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKChatViewController] viewDidLoad peerId=%ld", (long)self.peerId];
    
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = YES;
    }
    
    [self setupNavigationHeader];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, width, height - 48.0) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    if ([self.tableView respondsToSelector:@selector(setKeyboardDismissMode:)]) {
        self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
    
    [self.view addSubview:self.tableView];
    
    // 1. Панель ввода сообщения
    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 48.0, width, 48.0)];
    self.inputContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        self.inputContainerView.backgroundColor = [UIColor colorWithRed:225.0/255.0 green:228.0/255.0 blue:234.0/255.0 alpha:1.0];
    } else {
        self.inputContainerView.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:250.0/255.0 alpha:1.0];
    }
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    sep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:sep];
    
    // Кнопка прикрепления фото (+)
    self.attachButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.attachButton.frame = CGRectMake(8, 7, 34, 34);
    if (isSkeuomorph) {
        self.attachButton.backgroundColor = [UIColor colorWithRed:90.0/255.0 green:115.0/255.0 blue:150.0/255.0 alpha:1.0];
        self.attachButton.layer.cornerRadius = 17.0;
        self.attachButton.layer.borderWidth = 1.0;
        self.attachButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
        [self.attachButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        self.attachButton.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:243.0/255.0 alpha:1.0];
        self.attachButton.layer.cornerRadius = 17.0;
        [self.attachButton setTitleColor:[UIColor colorWithWhite:0.45 alpha:1.0] forState:UIControlStateNormal];
    }
    [self.attachButton setTitle:@"+" forState:UIControlStateNormal];
    self.attachButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.attachButton addTarget:self action:@selector(attachPhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.attachButton];
    
    // Поле ввода сообщения
    self.messageTextField = [[UITextField alloc] initWithFrame:CGRectMake(48, 7, width - 110, 34)];
    self.messageTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageTextField.placeholder = @"Написать сообщение...";
    self.messageTextField.font = [UIFont systemFontOfSize:14];
    self.messageTextField.delegate = self;
    
    if (isSkeuomorph) {
        self.messageTextField.borderStyle = UITextBorderStyleRoundedRect;
    } else {
        self.messageTextField.borderStyle = UITextBorderStyleNone;
        self.messageTextField.backgroundColor = [UIColor whiteColor];
        self.messageTextField.layer.cornerRadius = 16.0;
        self.messageTextField.layer.borderWidth = 0.5;
        self.messageTextField.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:222.0/255.0 alpha:1.0].CGColor;
        self.messageTextField.clipsToBounds = YES;
        UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 34)];
        self.messageTextField.leftView = leftPad;
        self.messageTextField.leftViewMode = UITextFieldViewModeAlways;
    }
    [self.inputContainerView addSubview:self.messageTextField];
    
    // Кнопка «Отпр.»
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(width - 58, 7, 52, 34);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
    
    if (isSkeuomorph) {
        self.sendButton.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:110.0/255.0 blue:210.0/255.0 alpha:1.0];
        self.sendButton.layer.cornerRadius = 6.0;
        self.sendButton.layer.borderWidth = 1.0;
        self.sendButton.layer.borderColor = [UIColor colorWithRed:25.0/255.0 green:60.0/255.0 blue:130.0/255.0 alpha:1.0].CGColor;
        [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        self.sendButton.backgroundColor = [UIColor clearColor];
        [self.sendButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
    }
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.sendButton addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.sendButton];
    
    [self.view addSubview:self.inputContainerView];
    
    // 2. Панель «Вы покинули беседу / Вернуться»
    self.leaveReturnBannerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 48.0, width, 48.0)];
    self.leaveReturnBannerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.leaveReturnBannerView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0] : [UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:250.0/255.0 alpha:1.0];
    self.leaveReturnBannerView.hidden = YES;
    
    UIView *leaveSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    leaveSep.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:222.0/255.0 alpha:1.0];
    leaveSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.leaveReturnBannerView addSubview:leaveSep];
    
    self.returnToChatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.returnToChatButton.frame = CGRectMake(12, 6, width - 24, 36);
    self.returnToChatButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.returnToChatButton.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    self.returnToChatButton.layer.cornerRadius = 6.0;
    self.returnToChatButton.clipsToBounds = YES;
    [self.returnToChatButton setTitle:@"Вернуться в беседу" forState:UIControlStateNormal];
    [self.returnToChatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.returnToChatButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.returnToChatButton addTarget:self action:@selector(returnToChatAction) forControlEvents:UIControlEventTouchUpInside];
    [self.leaveReturnBannerView addSubview:self.returnToChatButton];
    
    [self.view addSubview:self.leaveReturnBannerView];
    
    // Уведомления клавиатуры
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // Real-time LongPoll события
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewMessageNotification:) name:VKLongPollDidReceiveNewMessageNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReadMessagesNotification:) name:VKLongPollDidReadMessagesNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTypingNotification:) name:VKLongPollUserTypingNotification object:nil];
    
    // Подгрузка метаданных диалога или беседы
    if (self.peerId > 2000000000) {
        [self loadChatInfo];
    } else if (self.peerId > 0 && (!self.peerUser || self.peerUser.avatarURL.length == 0)) {
        NSDictionary *params = @{
            @"user_ids": @(self.peerId),
            @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
        };
        [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:params completionHandler:^(id response, NSError *error) {
            if (!error && [response isKindOfClass:[NSDictionary class]]) {
                NSArray *items = response[@"response"] ?: response;
                if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                    self.peerUser = [VKUser userFromDictionary:items[0]];
                    self.chatTitle = self.peerUser.displayName;
                    self.usersCache[@(self.peerUser.uid)] = self.peerUser;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self setupNavigationHeader];
                    });
                }
            }
        }];
    }
    
    [self loadHistory];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationHeader];
}

#pragma mark - Navigation Header & Banner

- (void)setupNavigationHeader {
    CGFloat maxW = self.view.bounds.size.width - 120.0;
    if (maxW < 140) maxW = 140;
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, maxW, 36)];
    headerView.userInteractionEnabled = YES;
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped)];
    [headerView addGestureRecognizer:tap];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, maxW, 18)];
    nameLabel.text = self.chatTitle ?: @"Чат";
    nameLabel.font = [[VKThemeManager sharedManager] titleFontOfSize:15];
    nameLabel.textColor = [[VKThemeManager sharedManager] navBarTitleColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.85;
    [headerView addSubview:nameLabel];
    self.nameLabel = nameLabel;
    
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 19, maxW, 14)];
    if (self.peerId > 2000000000) {
        if (self.isLeftOrKicked) {
            statusLabel.text = @"вы покинули беседу";
        } else if (self.membersCount > 0) {
            statusLabel.text = [self membersCountString:self.membersCount];
        } else {
            statusLabel.text = @"беседа";
        }
    } else {
        statusLabel.text = self.peerUser.isOnline ? @"в сети" : (self.peerUser.lastSeen ?: @"был(а) недавно");
    }
    statusLabel.font = [UIFont systemFontOfSize:11];
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        statusLabel.textColor = [UIColor colorWithRed:180.0/255.0 green:210.0/255.0 blue:245.0/255.0 alpha:1.0];
    } else {
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    }
    statusLabel.textAlignment = NSTextAlignmentCenter;
    statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    statusLabel.adjustsFontSizeToFitWidth = YES;
    statusLabel.minimumScaleFactor = 0.85;
    [headerView addSubview:statusLabel];
    self.statusLabel = statusLabel;
    
    self.navigationItem.titleView = headerView;
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    
    // В официальном VK 2.x/3.x: для бесед всегда отображается иконка chat_settings справа!
    if (self.peerId > 2000000000) {
        UIImage *settingsImg = [UIImage imageNamed:@"chat_settings"];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:settingsImg style:UIBarButtonItemStylePlain target:self action:@selector(openChatSettings)];
    } else if (self.peerUser && self.peerUser.avatarURL.length > 0) {
        [self updateHeaderAvatarWithURL:self.peerUser.avatarURL];
    }
}

- (void)updateHeaderAvatarWithURL:(NSString *)url {
    if (url.length == 0) return;
    
    // Оборачиваем аватарку в контейнер фиксированного размера 32x32,
    // чтобы iOS 11+ не растягивал изображение на всю высоту навбара!
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    container.clipsToBounds = YES;
    container.backgroundColor = [UIColor clearColor];
    
    UIImageView *navAvatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    navAvatar.contentMode = UIViewContentModeScaleAspectFill;
    navAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
    navAvatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    navAvatar.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    navAvatar.clipsToBounds = YES;
    navAvatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    navAvatar.userInteractionEnabled = YES;
    [container addSubview:navAvatar];
    
    // Фиксируем AutoLayout ограничения для iOS 9+
    if ([container respondsToSelector:@selector(widthAnchor)]) {
        [container.widthAnchor constraintEqualToConstant:32.0].active = YES;
        [container.heightAnchor constraintEqualToConstant:32.0].active = YES;
    }
    if ([navAvatar respondsToSelector:@selector(widthAnchor)]) {
        [navAvatar.widthAnchor constraintEqualToConstant:32.0].active = YES;
        [navAvatar.heightAnchor constraintEqualToConstant:32.0].active = YES;
    }
    
    UITapGestureRecognizer *avTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped)];
    [container addGestureRecognizer:avTap];
    
    self.navAvatarView = navAvatar;
    self.navAvatarContainer = container;
    
    [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
        if (img) navAvatar.image = img;
    }];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:container];
}

- (void)updateInputBarVisibility {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.peerId > 2000000000 && self.isLeftOrKicked) {
            self.inputContainerView.hidden = YES;
            self.leaveReturnBannerView.hidden = NO;
            self.statusLabel.text = @"вы покинули беседу";
            [self dismissKeyboard];
        } else {
            self.inputContainerView.hidden = NO;
            self.leaveReturnBannerView.hidden = YES;
            if (self.peerId > 2000000000) {
                self.statusLabel.text = (self.membersCount > 0) ? [self membersCountString:self.membersCount] : @"беседа";
            }
        }
    });
}

#pragma mark - Group Chat Info & Actions

- (NSString *)membersCountString:(NSInteger)count {
    if (count <= 0) return @"беседа";
    NSInteger rem100 = count % 100;
    NSInteger rem10 = count % 10;
    if (rem100 >= 11 && rem100 <= 19) {
        return [NSString stringWithFormat:@"%ld участников", (long)count];
    }
    if (rem10 == 1) {
        return [NSString stringWithFormat:@"%ld участник", (long)count];
    }
    if (rem10 >= 2 && rem10 <= 4) {
        return [NSString stringWithFormat:@"%ld участника", (long)count];
    }
    return [NSString stringWithFormat:@"%ld участников", (long)count];
}

- (void)loadChatInfo {
    if (self.peerId <= 2000000000) return;
    NSInteger chatId = self.peerId - 2000000000;
    
    NSDictionary *params = @{
        @"chat_id": @(chatId),
        @"fields": @"photo_50,photo_100,photo_200,users"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getChat" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            [VKCrashLogger log:@"[VKChatViewController] messages.getChat error: %@", error.localizedDescription];
            return;
        }
        
        NSDictionary *dict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return;
        
        NSString *title = dict[@"title"];
        NSInteger count = [dict[@"members_count"] integerValue];
        NSArray *users = dict[@"users"];
        if (count == 0 && [users isKindOfClass:[NSArray class]]) {
            count = users.count;
        }
        NSString *photo = dict[@"photo_100"] ?: dict[@"photo_50"] ?: dict[@"photo_200"];
        NSInteger adminId = [dict[@"admin_id"] integerValue];
        
        // Проверяем, состоит ли текущий пользователь в беседе
        NSInteger myId = [[VKAuthService sharedService] currentUserId];
        BOOL isMember = NO;
        if ([users isKindOfClass:[NSArray class]]) {
            for (id u in users) {
                NSInteger uid = [u isKindOfClass:[NSDictionary class]] ? ([u[@"id"] integerValue] ?: [u[@"uid"] integerValue]) : [u integerValue];
                if (uid == myId) {
                    isMember = YES;
                    break;
                }
            }
        }
        NSInteger leftState = [dict[@"left"] integerValue];
        NSInteger kickedState = [dict[@"kicked"] integerValue];
        if (leftState == 1 || kickedState == 1) {
            isMember = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.adminId = adminId;
            self.isLeftOrKicked = !isMember;
            if (title.length > 0) {
                self.chatTitle = title;
                self.nameLabel.text = title;
            }
            if (count > 0) {
                self.membersCount = count;
            }
            if (photo.length > 0 && ![photo isEqualToString:self.chatPhotoURL]) {
                self.chatPhotoURL = photo;
                [self updateHeaderAvatarWithURL:photo];
            }
            [self updateInputBarVisibility];
        });
    }];
}

- (void)headerTapped {
    if (self.peerId <= 2000000000) {
        [self openPeerProfile];
        return;
    }
    [self openChatSettings];
}

- (void)openChatSettings {
    NSInteger chatId = self.peerId - 2000000000;
    VKChatSettingsViewController *settingsVC = [[VKChatSettingsViewController alloc] initWithChatId:chatId
                                                                                            adminId:self.adminId
                                                                                              title:self.chatTitle
                                                                                           photoURL:self.chatPhotoURL
                                                                                       membersCount:self.membersCount
                                                                                           isMember:!self.isLeftOrKicked];
    __weak typeof(self) wSelf = self;
    settingsVC.onChatUpdated = ^(NSString *newTitle, NSString *newPhoto, BOOL isMember) {
        __strong typeof(wSelf) sSelf = wSelf;
        if (!sSelf) return;
        sSelf.chatTitle = newTitle;
        sSelf.chatPhotoURL = newPhoto;
        sSelf.isLeftOrKicked = !isMember;
        [sSelf setupNavigationHeader];
        [sSelf updateInputBarVisibility];
        [sSelf loadHistory];
    };
    [self.navigationController pushViewController:settingsVC animated:YES];
}

- (void)leaveChatAction {
    NSInteger chatId = self.peerId - 2000000000;
    [VKCrashLogger log:@"[VKChatViewController] Leaving chat %ld", (long)chatId];
    
    [[VKMessagesService sharedService] leaveChatWithChatId:chatId completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                self.isLeftOrKicked = YES;
                [self updateInputBarVisibility];
                [self loadChatInfo];
                [self loadHistory];
            } else {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось покинуть беседу" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [a show];
            }
        });
    }];
}

- (void)returnToChatAction {
    NSInteger chatId = self.peerId - 2000000000;
    [VKCrashLogger log:@"[VKChatViewController] Returning to chat %ld", (long)chatId];
    
    self.returnToChatButton.enabled = NO;
    [[VKMessagesService sharedService] returnToChatWithChatId:chatId completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.returnToChatButton.enabled = YES;
            if (success) {
                self.isLeftOrKicked = NO;
                [self updateInputBarVisibility];
                [self loadChatInfo];
                [self loadHistory];
            } else {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось вернуться в беседу" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [a show];
            }
        });
    }];
}

- (void)openMembersList {
    NSInteger chatId = self.peerId - 2000000000;
    VKChatMembersViewController *membersVC = [[VKChatMembersViewController alloc] initWithChatId:chatId adminId:self.adminId];
    [self.navigationController pushViewController:membersVC animated:YES];
}

#pragma mark - User Cache & Resolving

- (VKUser *)senderUserForMessage:(VKMessage *)msg {
    if (!msg) return nil;
    if (msg.senderUser) {
        self.usersCache[@(msg.senderUser.uid)] = msg.senderUser;
        return msg.senderUser;
    }
    if (msg.fromId != 0 && self.usersCache[@(msg.fromId)]) {
        return self.usersCache[@(msg.fromId)];
    }
    if (msg.fromId > 0 && !self.pendingUserFetches[@(msg.fromId)]) {
        self.pendingUserFetches[@(msg.fromId)] = @YES;
        NSDictionary *params = @{
            @"user_ids": @(msg.fromId),
            @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
        };
        [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:params completionHandler:^(id response, NSError *error) {
            if (!error && [response isKindOfClass:[NSDictionary class]]) {
                NSArray *items = response[@"response"] ?: response;
                if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                    VKUser *u = [VKUser userFromDictionary:items[0]];
                    if (u) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.usersCache[@(u.uid)] = u;
                            [self.tableView reloadData];
                        });
                    }
                }
            }
        }];
    }
    return nil;
}

- (BOOL)isStickerMessage:(VKMessage *)msg {
    if (msg.attachments.count > 0 && [msg.attachments[0] isKindOfClass:[VKAttachment class]]) {
        VKAttachment *att = (VKAttachment *)msg.attachments[0];
        return att.type == VKAttachmentTypeSticker;
    }
    return NO;
}

- (void)userButtonTapped:(VKChatUserButton *)sender {
    if (sender.user) {
        [self openUserProfile:sender.user];
    }
}

- (void)authorLabelTapped:(VKChatAuthorTapGesture *)gesture {
    if (gesture.user) {
        [self openUserProfile:gesture.user];
    }
}

- (void)openUserProfile:(VKUser *)user {
    if (user && user.uid != 0) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:user];
        [self.navigationController pushViewController:profVC animated:YES];
    }
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    
    CGFloat kbHeight = kbFrame.size.height;
    CGFloat viewHeight = self.view.bounds.size.height;
    
    [UIView animateWithDuration:duration delay:0 options:curve animations:^{
        self.inputContainerView.frame = CGRectMake(0, viewHeight - kbHeight - 48.0, self.view.bounds.size.width, 48.0);
        self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, viewHeight - kbHeight - 48.0);
    } completion:^(BOOL finished) {
        if (self.messages.count > 0) {
            NSIndexPath *lastPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
            [self.tableView scrollToRowAtIndexPath:lastPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    
    CGFloat viewHeight = self.view.bounds.size.height;
    
    [UIView animateWithDuration:duration delay:0 options:curve animations:^{
        self.inputContainerView.frame = CGRectMake(0, viewHeight - 48.0, self.view.bounds.size.width, 48.0);
        self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, viewHeight - 48.0);
    } completion:nil];
}

#pragma mark - LongPoll Handlers

- (void)didReceiveNewMessageNotification:(NSNotification *)note {
    VKMessage *msg = note.userInfo[@"message"];
    if (!msg || msg.peerId != self.peerId) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSInteger i = 0; i < self.messages.count; i++) {
            VKMessage *m = self.messages[i];
            if (m.messageId == msg.messageId) {
                // Обновляем существующее сообщение
                [self.messages replaceObjectAtIndex:i withObject:msg];
                [self.tableView reloadData];
                return;
            }
        }
        [self.messages addObject:msg];
        [self.tableView reloadData];
        if (self.messages.count > 0) {
            NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
            [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
        if (!msg.isOutgoing) {
            [[VKMessagesService sharedService] markAsReadForPeerId:self.peerId messageId:msg.messageId completion:nil];
        }
    });
}

- (void)didReadMessagesNotification:(NSNotification *)note {
    NSInteger peerId = [note.userInfo[@"peer_id"] integerValue];
    BOOL isOutgoing = [note.userInfo[@"is_outgoing"] boolValue];
    if (peerId == self.peerId && isOutgoing) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (VKMessage *m in self.messages) {
                if (m.isOutgoing) m.isRead = YES;
            }
            [self.tableView reloadData];
        });
    }
}

- (void)userTypingNotification:(NSNotification *)note {
    NSInteger peerId = [note.userInfo[@"peer_id"] integerValue];
    if (peerId == self.peerId) {
        NSInteger userId = [note.userInfo[@"user_id"] integerValue];
        VKUser *user = (userId != 0) ? self.usersCache[@(userId)] : nil;
        NSString *typingStr = (user && self.peerId > 2000000000) ? [NSString stringWithFormat:@"%@ печатает...", user.displayName] : @"печатает...";
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = typingStr;
            self.statusLabel.textColor = [[VKThemeManager sharedManager] accentColor];
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(resetTypingStatus) object:nil];
            [self performSelector:@selector(resetTypingStatus) withObject:nil afterDelay:5.0];
        });
    }
}

- (void)resetTypingStatus {
    if (self.peerId > 2000000000) {
        if (self.isLeftOrKicked) {
            self.statusLabel.text = @"вы покинули беседу";
        } else if (self.membersCount > 0) {
            self.statusLabel.text = [self membersCountString:self.membersCount];
        } else {
            self.statusLabel.text = @"беседа";
        }
    } else {
        self.statusLabel.text = self.peerUser.isOnline ? @"в сети" : (self.peerUser.lastSeen ?: @"был(а) недавно");
    }
    self.statusLabel.textColor = [[VKThemeManager sharedManager] isSkeuomorphic] ? [UIColor colorWithRed:180.0/255.0 green:210.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.6 alpha:1.0];
}

#pragma mark - Attach & ActionSheet

- (void)attachPhotoAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Сделать снимок", @"Выбрать из галереи", nil];
    sheet.tag = 5001;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 5001) {
        // Фотокамера / Галерея
        if (buttonIndex == 0) {
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                UIImagePickerController *picker = [[UIImagePickerController alloc] init];
                picker.sourceType = UIImagePickerControllerSourceTypeCamera;
                picker.delegate = self;
                [self presentViewController:picker animated:YES completion:nil];
            } else {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Камера недоступна" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [a show];
            }
        } else if (buttonIndex == 1) {
            UIImagePickerController *picker = [[UIImagePickerController alloc] init];
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            picker.delegate = self;
            [self presentViewController:picker animated:YES completion:nil];
        }
    } else if (actionSheet.tag == 5002) {
        // Меню покинутой беседы
        if (buttonIndex == 0) {
            // Информация о беседе
            NSString *infoStr = [NSString stringWithFormat:@"%@\n%@", self.chatTitle ?: @"Беседа", [self membersCountString:self.membersCount]];
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Беседа" message:infoStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        } else if (buttonIndex == 1) {
            // Список участников
            [self openMembersList];
        } else if (buttonIndex == 2) {
            // Вернуться в беседу
            [self returnToChatAction];
        }
    } else if (actionSheet.tag == 5003) {
        // Меню активного участника
        if (buttonIndex == 0) {
            // Покинуть беседу (destructive)
            UIAlertView *confirmAlert = [[UIAlertView alloc] initWithTitle:@"Покинуть беседу?"
                                                                   message:@"Покинув беседу, Вы не будете получать новых сообщений от участников. Вы сможете вернуться при наличии свободных мест."
                                                                  delegate:self
                                                         cancelButtonTitle:@"Отмена"
                                                         otherButtonTitles:@"Покинуть", nil];
            confirmAlert.tag = 7001;
            [confirmAlert show];
        } else if (buttonIndex == 1) {
            // Информация о беседе
            NSString *infoStr = [NSString stringWithFormat:@"%@\n%@", self.chatTitle ?: @"Беседа", [self membersCountString:self.membersCount]];
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Беседа" message:infoStr delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [av show];
        } else if (buttonIndex == 2) {
            // Список участников
            [self openMembersList];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 7001 && buttonIndex == 1) {
        [self leaveChatAction];
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *chosenImage = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (chosenImage) {
            VKPhotoEditorViewController *editor = [[VKPhotoEditorViewController alloc] initWithImage:chosenImage];
            editor.onImageEdited = ^(UIImage *editedImage) {
                if (editedImage) {
                    UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Фото отредактировано" message:@"Фотография обработана в редакторе" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [a show];
                }
            };
            [self presentViewController:editor animated:YES completion:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)openPeerProfile {
    if (self.peerUser && self.peerUser.uid != 0) {
        VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:self.peerUser];
        [self.navigationController pushViewController:profVC animated:YES];
    }
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)loadHistory {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [VKCrashLogger log:@"[VKChatViewController] Loading message history..."];
    
    [[VKMessagesService sharedService] fetchHistoryForPeerId:self.peerId offset:0 count:50 completion:^(NSArray *messages, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (!error && messages) {
                [self.messages removeAllObjects];
                NSEnumerator *enumerator = [messages reverseObjectEnumerator];
                for (VKMessage *m in enumerator) {
                    [self.messages addObject:m];
                    if (m.senderUser && m.senderUser.uid != 0) {
                        self.usersCache[@(m.senderUser.uid)] = m.senderUser;
                    }
                }
                [self.tableView reloadData];
                if (self.messages.count > 0) {
                    NSIndexPath *lastPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
                    [self.tableView scrollToRowAtIndexPath:lastPath atScrollPosition:UITableViewScrollPositionBottom animated:NO];
                }
                [VKCrashLogger log:@"[VKChatViewController] Messages loaded: %lu", (unsigned long)self.messages.count];
                [[VKMessagesService sharedService] markAsReadForPeerId:self.peerId messageId:0 completion:nil];
            }
        });
    }];
}

- (void)sendMessage {
    NSString *text = [self.messageTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.sendButton.userInteractionEnabled = NO;
    [VKCrashLogger log:@"[VKChatViewController] Sending message to peerId=%ld", (long)self.peerId];
    
    [[VKMessagesService sharedService] sendMessageToPeerId:self.peerId text:text completion:^(BOOL success, NSInteger messageId, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sendButton.userInteractionEnabled = YES;
            if (success) {
                self.messageTextField.text = @"";
                [self loadHistory];
            } else if (error) {
                // Если ошибка доступа к чату (пользователь исключен или вышел)
                if (error.code == 15 || error.code == 917 ||
                    [error.localizedDescription rangeOfString:@"chat" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [error.localizedDescription rangeOfString:@"kicked" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    self.isLeftOrKicked = YES;
                    [self updateInputBarVisibility];
                }
                UIAlertView *errAlert = [[UIAlertView alloc] initWithTitle:@"Не удалось отправить" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errAlert show];
            }
        });
    }];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (NSString *)textForMessage:(VKMessage *)msg {
    NSString *baseText = msg.text ?: @"";
    NSString *attachText = nil;
    if (msg.attachments.count > 0) {
        VKAttachment *att = msg.attachments[0];
        if (att.type == VKAttachmentTypePhoto) attachText = @"[Фотография]";
        else if (att.type == VKAttachmentTypeSticker) attachText = @"[Стикер]";
        else if (att.type == VKAttachmentTypeGif) attachText = @"[GIF]";
        else if (att.type == VKAttachmentTypeAudio) attachText = [NSString stringWithFormat:@"🎵 %@ — %@", att.audioArtist ?: @"", att.audioTitle ?: @"Трек"];
        else if (att.type == VKAttachmentTypeDoc) attachText = [NSString stringWithFormat:@"📄 %@", att.docTitle ?: @"Документ"];
        else if (att.type == VKAttachmentTypeVideo) attachText = [NSString stringWithFormat:@"🎬 %@", att.videoTitle ?: @"Видео"];
        else if (att.type == VKAttachmentTypeWall) attachText = [NSString stringWithFormat:@"📋 Запись на стене%@", att.wallText.length > 0 ? [NSString stringWithFormat:@":\n«%@»", att.wallText] : @""];
        else attachText = @"[Вложение]";
    }
    if (baseText.length > 0 && attachText.length > 0) {
        return [NSString stringWithFormat:@"%@\n%@", baseText, attachText];
    }
    if (baseText.length > 0) return baseText;
    if (attachText.length > 0) return attachText;
    return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.messages.count) return 44.0;
    VKMessage *msg = self.messages[indexPath.row];
    CGFloat width = tableView.bounds.size.width;
    
    // 1. Сервисное сообщение
    if ([msg isServiceAction]) {
        VKUser *author = [self senderUserForMessage:msg];
        NSString *authorName = author ? author.displayName : (msg.fromId != 0 ? [NSString stringWithFormat:@"id%ld", (long)msg.fromId] : @"");
        NSString *svcText = authorName.length > 0 ? [NSString stringWithFormat:@"%@ %@", authorName, [msg serviceActionText]] : [msg serviceActionText];
        CGSize sz = [svcText sizeWithFont:[UIFont systemFontOfSize:12] constrainedToSize:CGSizeMake(width - 60, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
        return ceilf(sz.height) + 16.0;
    }
    
    // 2. Стикер
    if ([self isStickerMessage:msg]) {
        return 138.0;
    }
    
    // 3. Обычное сообщение
    BOOL isGroupChat = (self.peerId > 2000000000);
    BOOL showAuthor = isGroupChat && !msg.isOutgoing;
    CGFloat authorHeaderH = showAuthor ? 18.0 : 0.0;
    
    BOOL hasPhoto = (msg.attachments.count > 0 && [msg.attachments[0] isKindOfClass:[VKAttachment class]] && ((VKAttachment *)msg.attachments[0]).type == VKAttachmentTypePhoto);
    CGFloat extraH = (hasPhoto ? 138.0 : 0.0) + authorHeaderH;
    
    CGFloat maxTextW = width - (showAuthor ? 46.0 : 10.0) - 50.0;
    NSString *displayText = [self textForMessage:msg];
    CGSize size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(maxTextW, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    
    return MAX(44.0 + extraH, ceilf(size.height) + 26.0 + extraH);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKChatMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        
        // Сервисное действие (плашка по центру)
        UIView *servicePill = [[UIView alloc] initWithFrame:CGRectZero];
        servicePill.tag = 1007;
        servicePill.clipsToBounds = YES;
        servicePill.hidden = YES;
        [cell.contentView addSubview:servicePill];
        
        UILabel *serviceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        serviceLabel.tag = 1008;
        serviceLabel.font = [UIFont systemFontOfSize:12];
        serviceLabel.textAlignment = NSTextAlignmentCenter;
        serviceLabel.numberOfLines = 0;
        serviceLabel.backgroundColor = [UIColor clearColor];
        [servicePill addSubview:serviceLabel];
        
        // Аватарка автора в беседах (кнопка)
        VKChatUserButton *authorAvatar = [VKChatUserButton buttonWithType:UIButtonTypeCustom];
        authorAvatar.tag = 1005;
        authorAvatar.clipsToBounds = YES;
        authorAvatar.hidden = YES;
        [authorAvatar addTarget:self action:@selector(userButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [cell.contentView addSubview:authorAvatar];
        
        // Стикер (без пузыря)
        UIImageView *stickerIV = [[UIImageView alloc] initWithFrame:CGRectZero];
        stickerIV.tag = 1009;
        stickerIV.contentMode = UIViewContentModeScaleAspectFit;
        stickerIV.clipsToBounds = YES;
        stickerIV.userInteractionEnabled = YES;
        stickerIV.hidden = YES;
        [cell.contentView addSubview:stickerIV];
        
        UILabel *stickerTimeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        stickerTimeLabel.tag = 1010;
        stickerTimeLabel.font = [UIFont systemFontOfSize:10];
        stickerTimeLabel.textAlignment = NSTextAlignmentCenter;
        stickerTimeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
        stickerTimeLabel.textColor = [UIColor whiteColor];
        stickerTimeLabel.layer.cornerRadius = 6.0;
        stickerTimeLabel.clipsToBounds = YES;
        stickerTimeLabel.hidden = YES;
        [cell.contentView addSubview:stickerTimeLabel];
        
        // Основной пузырь
        UIImageView *bubble = [[UIImageView alloc] initWithFrame:CGRectZero];
        bubble.tag = 1001;
        bubble.userInteractionEnabled = YES;
        [cell.contentView addSubview:bubble];
        
        // Имя автора в беседах (UILabel с тапом, чтобы не обрезалось кнопкой)
        UILabel *authorNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        authorNameLabel.tag = 1006;
        authorNameLabel.font = [UIFont boldSystemFontOfSize:12.5];
        authorNameLabel.textColor = [UIColor colorWithRed:60.0/255.0 green:112.0/255.0 blue:164.0/255.0 alpha:1.0];
        authorNameLabel.backgroundColor = [UIColor clearColor];
        authorNameLabel.userInteractionEnabled = YES;
        authorNameLabel.hidden = YES;
        VKChatAuthorTapGesture *authorTap = [[VKChatAuthorTapGesture alloc] initWithTarget:self action:@selector(authorLabelTapped:)];
        [authorNameLabel addGestureRecognizer:authorTap];
        [bubble addSubview:authorNameLabel];
        
        // Фото во вложении
        UIImageView *photoIV = [[UIImageView alloc] initWithFrame:CGRectZero];
        photoIV.tag = 1004;
        photoIV.contentMode = UIViewContentModeScaleAspectFill;
        photoIV.clipsToBounds = YES;
        photoIV.layer.cornerRadius = 8.0;
        photoIV.userInteractionEnabled = YES;
        photoIV.hidden = YES;
        [bubble addSubview:photoIV];
        
        UITapGestureRecognizer *photoTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(chatPhotoTapped:)];
        [photoIV addGestureRecognizer:photoTap];
        
        // Текст сообщения
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        textLabel.tag = 1002;
        textLabel.font = [UIFont systemFontOfSize:15];
        textLabel.numberOfLines = 0;
        textLabel.backgroundColor = [UIColor clearColor];
        [bubble addSubview:textLabel];
        
        // Время и статус прочтения
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        timeLabel.tag = 1003;
        timeLabel.font = [UIFont systemFontOfSize:10];
        timeLabel.backgroundColor = [UIColor clearColor];
        [bubble addSubview:timeLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.messages.count) return cell;
    
    VKMessage *msg = self.messages[indexPath.row];
    UIView *servicePill = [cell.contentView viewWithTag:1007];
    UILabel *serviceLabel = (UILabel *)[servicePill viewWithTag:1008];
    VKChatUserButton *authorAvatar = (VKChatUserButton *)[cell.contentView viewWithTag:1005];
    UIImageView *stickerIV = (UIImageView *)[cell.contentView viewWithTag:1009];
    UILabel *stickerTimeLabel = (UILabel *)[cell.contentView viewWithTag:1010];
    UIImageView *bubble = (UIImageView *)[cell.contentView viewWithTag:1001];
    UILabel *authorNameLabel = (UILabel *)[bubble viewWithTag:1006];
    UIImageView *photoIV = (UIImageView *)[bubble viewWithTag:1004];
    UILabel *textLabel = (UILabel *)[bubble viewWithTag:1002];
    UILabel *timeLabel = (UILabel *)[bubble viewWithTag:1003];
    
    CGFloat width = tableView.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isGroupChat = (self.peerId > 2000000000);
    
    // 1. Сервисное сообщение
    if ([msg isServiceAction]) {
        bubble.hidden = YES;
        authorAvatar.hidden = YES;
        stickerIV.hidden = YES;
        stickerTimeLabel.hidden = YES;
        servicePill.hidden = NO;
        
        VKUser *author = [self senderUserForMessage:msg];
        NSString *authorNameStr = author ? author.displayName : (msg.fromId != 0 ? [NSString stringWithFormat:@"id%ld", (long)msg.fromId] : @"");
        NSString *svcText = authorNameStr.length > 0 ? [NSString stringWithFormat:@"%@ %@", authorNameStr, [msg serviceActionText]] : [msg serviceActionText];
        
        CGSize sz = [svcText sizeWithFont:[UIFont systemFontOfSize:12] constrainedToSize:CGSizeMake(width - 60, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
        CGFloat pillW = ceilf(sz.width) + 18.0;
        CGFloat pillH = ceilf(sz.height) + 8.0;
        servicePill.frame = CGRectMake((width - pillW) / 2.0, 4.0, pillW, pillH);
        servicePill.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.08];
        servicePill.layer.cornerRadius = MIN(12.0, pillH / 2.0);
        
        serviceLabel.frame = CGRectMake(9.0, 4.0, ceilf(sz.width), ceilf(sz.height));
        serviceLabel.text = svcText;
        serviceLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
        return cell;
    }
    
    // 2. Стикер
    if ([self isStickerMessage:msg]) {
        servicePill.hidden = YES;
        bubble.hidden = YES;
        stickerIV.hidden = NO;
        stickerTimeLabel.hidden = NO;
        
        VKAttachment *stAtt = (VKAttachment *)msg.attachments[0];
        stickerIV.image = nil;
        NSString *url = stAtt.stickerURL;
        if (url.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                if (img) stickerIV.image = img;
            }];
        }
        
        CGFloat stSize = 128.0;
        CGFloat stX = 0;
        if (msg.isOutgoing) {
            authorAvatar.hidden = YES;
            stX = width - stSize - 12.0;
        } else {
            if (isGroupChat) {
                authorAvatar.hidden = NO;
                authorAvatar.frame = CGRectMake(8, 138.0 - 36.0, 32, 32);
                authorAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
                VKUser *author = [self senderUserForMessage:msg];
                authorAvatar.user = author;
                [self loadAvatarForButton:authorAvatar url:author.avatarURL];
                stX = 46.0;
            } else {
                authorAvatar.hidden = YES;
                stX = 12.0;
            }
        }
        stickerIV.frame = CGRectMake(stX, 4.0, stSize, stSize);
        
        NSString *statusText = msg.isOutgoing ? [NSString stringWithFormat:@"%@%@", msg.timeString ?: @"", (msg.isRead ? @" ✓✓" : @" ✓")] : (msg.timeString ?: @"");
        stickerTimeLabel.text = statusText;
        stickerTimeLabel.frame = CGRectMake(stX + stSize - 48.0, 4.0 + stSize - 16.0, 44.0, 14.0);
        return cell;
    }
    
    // 3. Обычное сообщение / вложения
    servicePill.hidden = YES;
    stickerIV.hidden = YES;
    stickerTimeLabel.hidden = YES;
    bubble.hidden = NO;
    
    BOOL hasPhoto = (msg.attachments.count > 0 && [msg.attachments[0] isKindOfClass:[VKAttachment class]] && ((VKAttachment *)msg.attachments[0]).type == VKAttachmentTypePhoto);
    VKAttachment *photoAtt = hasPhoto ? (VKAttachment *)msg.attachments[0] : nil;
    
    BOOL showAuthor = (isGroupChat && !msg.isOutgoing);
    VKUser *author = showAuthor ? [self senderUserForMessage:msg] : nil;
    NSString *authorNameStr = author ? author.displayName : (msg.fromId != 0 ? [NSString stringWithFormat:@"id%ld", (long)msg.fromId] : @"");
    
    NSString *displayText = [self textForMessage:msg];
    textLabel.text = displayText;
    
    CGFloat maxTextW = width - (showAuthor ? 46.0 : 10.0) - 50.0;
    CGSize size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(maxTextW, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    
    CGFloat photoH = hasPhoto ? 130.0 : 0.0;
    
    // Расчет ширины пузыря
    CGFloat bubbleWidth = MAX(hasPhoto ? 196.0 : 86.0, ceilf(size.width) + 28.0);
    
    // Если исходящее однострочное: обеспечиваем место для времени и галочек прочтения, чтобы не накладывались
    if (msg.isOutgoing && size.height <= 22.0) {
        bubbleWidth = MAX(bubbleWidth, ceilf(size.width) + 72.0);
    }
    
    // Учитываем имя автора в беседах с запасом, чтобы никогда не обрезалось
    if (showAuthor && authorNameStr.length > 0) {
        CGSize authorNameSz = [authorNameStr sizeWithFont:[UIFont boldSystemFontOfSize:12.5]];
        bubbleWidth = MAX(bubbleWidth, ceilf(authorNameSz.width) + 38.0);
    }
    bubbleWidth = MIN(bubbleWidth, maxTextW + 36.0);
    
    CGFloat authorHeaderH = showAuthor ? 18.0 : 0.0;
    CGFloat bubbleHeight = ceilf(size.height) + 22.0 + (hasPhoto ? photoH + 8.0 : 0.0) + authorHeaderH;
    
    if (hasPhoto) {
        photoIV.hidden = NO;
        photoIV.image = nil;
        NSString *url = photoAtt.photoURL;
        if (url.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                if (img) photoIV.image = img;
            }];
        }
    } else {
        photoIV.hidden = YES;
    }
    
    if (msg.isOutgoing) {
        authorAvatar.hidden = YES;
        authorNameLabel.hidden = YES;
        bubble.frame = CGRectMake(width - bubbleWidth - 10.0, 3.0, bubbleWidth, bubbleHeight);
        
        if (isSkeuomorph) {
            UIImage *blueImg = [UIImage imageNamed:@"Blue_Bubble"];
            if (blueImg) {
                bubble.image = [blueImg resizableImageWithCapInsets:UIEdgeInsetsMake(14, 14, 14, 20) resizingMode:UIImageResizingModeStretch];
                bubble.backgroundColor = [UIColor clearColor];
            } else {
                bubble.backgroundColor = [UIColor colorWithRed:220.0/255.0 green:245.0/255.0 blue:220.0/255.0 alpha:1.0];
                bubble.layer.cornerRadius = 12.0;
            }
            textLabel.textColor = [UIColor whiteColor];
            timeLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        } else {
            UIImage *outImg = [UIImage imageNamed:@"7_messages_bubble_out"];
            if (outImg) {
                bubble.image = [outImg resizableImageWithCapInsets:UIEdgeInsetsMake(15, 15, 15, 20) resizingMode:UIImageResizingModeStretch];
                bubble.backgroundColor = [UIColor clearColor];
                textLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
                timeLabel.textColor = [UIColor colorWithRed:120.0/255.0 green:135.0/255.0 blue:155.0/255.0 alpha:1.0];
            } else {
                bubble.backgroundColor = [[VKThemeManager sharedManager] accentColor];
                bubble.layer.cornerRadius = 14.0;
                textLabel.textColor = [UIColor whiteColor];
                timeLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
            }
        }
        
        CGFloat topY = 6.0;
        if (hasPhoto) {
            photoIV.frame = CGRectMake(8, topY, bubbleWidth - 20, photoH);
            topY += photoH + 6.0;
        }
        textLabel.frame = CGRectMake(12, topY, ceilf(size.width), ceilf(size.height));
        
        // Время и статус прочтения (достаточная ширина 54pt для «16:18 ✓✓»)
        timeLabel.text = [NSString stringWithFormat:@"%@ %@", msg.timeString ?: @"", (msg.isRead ? @"✓✓" : @"✓")];
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.frame = CGRectMake(bubbleWidth - 60, bubbleHeight - 16, 54, 13);
        
    } else {
        // Входящие сообщения
        CGFloat bubbleX = 10.0;
        if (showAuthor) {
            authorAvatar.hidden = NO;
            // Аватарка внизу сообщения рядом с хвостиком пузыря (по канонам официального VK)
            CGFloat avatarY = bubbleHeight + 3.0 - 32.0;
            authorAvatar.frame = CGRectMake(8.0, avatarY, 32.0, 32.0);
            authorAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
            authorAvatar.user = author;
            [self loadAvatarForButton:authorAvatar url:author.avatarURL];
            bubbleX = 46.0;
        } else {
            authorAvatar.hidden = YES;
        }
        
        bubble.frame = CGRectMake(bubbleX, 3.0, bubbleWidth, bubbleHeight);
        
        if (isSkeuomorph) {
            UIImage *greyImg = [UIImage imageNamed:@"Grey_Bubble"];
            if (greyImg) {
                bubble.image = [greyImg resizableImageWithCapInsets:UIEdgeInsetsMake(14, 20, 14, 14) resizingMode:UIImageResizingModeStretch];
                bubble.backgroundColor = [UIColor clearColor];
            } else {
                bubble.backgroundColor = [UIColor whiteColor];
                bubble.layer.cornerRadius = 12.0;
            }
            textLabel.textColor = [UIColor blackColor];
            timeLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        } else {
            UIImage *incImg = [UIImage imageNamed:@"7_messages_bubble_inc"];
            if (incImg) {
                bubble.image = [incImg resizableImageWithCapInsets:UIEdgeInsetsMake(15, 20, 15, 15) resizingMode:UIImageResizingModeStretch];
                bubble.backgroundColor = [UIColor clearColor];
            } else {
                bubble.backgroundColor = [UIColor whiteColor];
                bubble.layer.cornerRadius = 14.0;
            }
            textLabel.textColor = [UIColor blackColor];
            timeLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        }
        
        CGFloat topY = 6.0;
        if (showAuthor) {
            authorNameLabel.hidden = NO;
            authorNameLabel.frame = CGRectMake(16, topY, bubbleWidth - 32, 16);
            authorNameLabel.text = authorNameStr;
            // Привязываем автора к жесту нажатия
            if (authorNameLabel.gestureRecognizers.count > 0 && [authorNameLabel.gestureRecognizers[0] isKindOfClass:[VKChatAuthorTapGesture class]]) {
                ((VKChatAuthorTapGesture *)authorNameLabel.gestureRecognizers[0]).user = author;
            }
            topY += 18.0;
        } else {
            authorNameLabel.hidden = YES;
        }
        
        if (hasPhoto) {
            photoIV.frame = CGRectMake(14, topY, bubbleWidth - 22, photoH);
            topY += photoH + 6.0;
        }
        textLabel.frame = CGRectMake(16, topY, ceilf(size.width), ceilf(size.height));
        
        timeLabel.text = msg.timeString ?: @"";
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.frame = CGRectMake(bubbleWidth - 46, bubbleHeight - 16, 38, 12);
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < (NSInteger)self.messages.count) {
        VKMessage *msg = self.messages[indexPath.row];
        for (VKAttachment *att in msg.attachments) {
            if (att.type == VKAttachmentTypeWall && att.wallPostId != 0) {
                VKPost *dummyPost = [[VKPost alloc] init];
                dummyPost.vkID = att.wallPostId;
                dummyPost.ownerID = att.wallOwnerId;
                dummyPost.text = att.wallText;
                VKPostDetailViewController *postVC = [[VKPostDetailViewController alloc] initWithPost:dummyPost];
                [self.navigationController pushViewController:postVC animated:YES];
                break;
            }
        }
    }
}

- (void)loadAvatarForButton:(UIButton *)button url:(NSString *)url {
    [button setImage:nil forState:UIControlStateNormal];
    button.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    if (url.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
            if (img) {
                [button setImage:img forState:UIControlStateNormal];
            }
        }];
    }
}

- (void)chatPhotoTapped:(UITapGestureRecognizer *)gesture {
    UIImageView *iv = (UIImageView *)gesture.view;
    if (iv.image) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:nil initialImage:iv.image];
        [self presentViewController:viewer animated:YES completion:nil];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return YES;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastTypingTime > 5.0) {
        self.lastTypingTime = now;
        [[VKAPIClient sharedClient] callMethod:@"messages.setActivity" parameters:@{@"peer_id": @(self.peerId), @"type": @"typing"} completionHandler:nil];
    }
    return YES;
}

@end
