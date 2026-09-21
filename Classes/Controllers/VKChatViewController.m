#import "VKChatViewController.h"
#import "VKChatAttachmentsViewController.h"
#import "VKChatMembersViewController.h"
#import "VKChatSettingsViewController.h"
#import "VKMessagesService.h"
#import "VKStickersPickerView.h"
#import "VKStickersStoreViewController.h"
#import "VKStickersService.h"
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
#import "VKAudioPlayer.h"
#import "VKAudioPlayerViewController.h"
#import "VKAudioTrack.h"
#import "VKMessageViewersViewController.h"
#import "VKVideoPlayerViewController.h"
#import "VKGifViewerViewController.h"
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

@interface VKChatAttachmentTapGesture : UITapGestureRecognizer
@property (nonatomic, strong) VKAttachment *attachment;
@property (nonatomic, strong) NSArray<VKAttachment *> *attachments;
@property (nonatomic, assign) NSInteger initialIndex;
@end

@implementation VKChatAttachmentTapGesture
@end

@interface VKChatSwipeReplyGesture : UIPanGestureRecognizer
@property (nonatomic, strong) VKMessage *message;
@property (nonatomic, weak) UIView *bubbleView;
@property (nonatomic, weak) UIView *replyIndicator;
@end

@implementation VKChatSwipeReplyGesture
@end

static UIBezierPath *VKMakeBubblePath(CGRect rect, CGFloat tl, CGFloat tr, CGFloat bl, CGFloat br) {
    CGFloat maxR = MIN(rect.size.width, rect.size.height) / 2.0;
    tl = MIN(tl, maxR);
    tr = MIN(tr, maxR);
    bl = MIN(bl, maxR);
    br = MIN(br, maxR);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(rect.origin.x + tl, rect.origin.y)];
    [path addLineToPoint:CGPointMake(rect.origin.x + rect.size.width - tr, rect.origin.y)];
    if (tr > 0) {
        [path addArcWithCenter:CGPointMake(rect.origin.x + rect.size.width - tr, rect.origin.y + tr)
                        radius:tr
                    startAngle:(CGFloat)(-M_PI_2)
                      endAngle:0
                     clockwise:YES];
    }
    [path addLineToPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - br)];
    if (br > 0) {
        [path addArcWithCenter:CGPointMake(rect.origin.x + rect.size.width - br, rect.origin.y + rect.size.height - br)
                        radius:br
                    startAngle:0
                      endAngle:(CGFloat)(M_PI_2)
                     clockwise:YES];
    }
    [path addLineToPoint:CGPointMake(rect.origin.x + bl, rect.origin.y + rect.size.height)];
    if (bl > 0) {
        [path addArcWithCenter:CGPointMake(rect.origin.x + bl, rect.origin.y + rect.size.height - bl)
                        radius:bl
                    startAngle:(CGFloat)(M_PI_2)
                      endAngle:(CGFloat)(M_PI)
                     clockwise:YES];
    }
    [path addLineToPoint:CGPointMake(rect.origin.x, rect.origin.y + tl)];
    if (tl > 0) {
        [path addArcWithCenter:CGPointMake(rect.origin.x + tl, rect.origin.y + tl)
                        radius:tl
                    startAngle:(CGFloat)(M_PI)
                      endAngle:(CGFloat)(-M_PI_2)
                     clockwise:YES];
    }
    [path closePath];
    return path;
}

static UIImage *VKCheckboxImage(BOOL checked) {
    CGFloat s = 22.0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectMake(1.0, 1.0, s - 2.0, s - 2.0);
    if (checked) {
        UIColor *blueColor = [UIColor colorWithRed:43.0/255.0 green:115.0/255.0 blue:195.0/255.0 alpha:1.0];
        [blueColor setFill];
        CGContextFillEllipseInRect(ctx, rect);
        
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(6.0, 11.5)];
        [path addLineToPoint:CGPointMake(9.5, 15.0)];
        [path addLineToPoint:CGPointMake(16.0, 7.5)];
        path.lineWidth = 2.2;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;
        [[UIColor whiteColor] setStroke];
        [path stroke];
    } else {
        UIColor *borderColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        [borderColor setStroke];
        CGContextSetLineWidth(ctx, 1.8);
        CGContextStrokeEllipseInRect(ctx, CGRectMake(2.0, 2.0, s - 4.0, s - 4.0));
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@interface VKChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UITextField *messageTextField;
@property (nonatomic, strong) UIButton *sendButton;

// Поиск сообщений в диалоге
@property (nonatomic, assign) BOOL isSearchingMessages;
@property (nonatomic, strong) UIView *searchBarContainer;
@property (nonatomic, strong) UISearchBar *messageSearchBar;
@property (nonatomic, strong) UILabel *searchMatchesLabel;
@property (nonatomic, strong) UIButton *searchPrevButton;
@property (nonatomic, strong) UIButton *searchNextButton;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *searchMatchingIndices;
@property (nonatomic, assign) NSInteger currentSearchMatchIndex;

// Режим выбора нескольких сообщений (Selection Mode)
@property (nonatomic, assign) BOOL isSelectionMode;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selectedMessageIds;
@property (nonatomic, strong) UIView *selectionTopBar;
@property (nonatomic, strong) UILabel *selectionCountLabel;
@property (nonatomic, strong) UIButton *selectionDeleteButton;
@property (nonatomic, strong) UIButton *selectionForwardButton;
@property (nonatomic, strong) UIButton *selectionCancelButton;

// Панель возвращения в беседу
@property (nonatomic, strong) UIView *leaveReturnBannerView;
@property (nonatomic, strong) UILabel *leaveReturnLabel;
@property (nonatomic, strong) UIButton *returnToChatButton;
@property (nonatomic, assign) BOOL isLeftOrKicked;

// Закрепленное сообщение
@property (nonatomic, strong) UIView *pinnedBannerView;
@property (nonatomic, strong) UILabel *pinnedSenderLabel;
@property (nonatomic, strong) UILabel *pinnedTextLabel;
@property (nonatomic, strong) UIButton *pinnedCloseButton;
@property (nonatomic, strong) VKMessage *pinnedMessage;

// Панель ответа / пересылки над строкой ввода
@property (nonatomic, strong) UIView *replyForwardBarView;
@property (nonatomic, strong) UILabel *replyAuthorLabel;
@property (nonatomic, strong) UILabel *replyTextLabel;
@property (nonatomic, strong) UIButton *replyCancelButton;
@property (nonatomic, strong) VKMessage *replyingMessage;
@property (nonatomic, strong) NSMutableArray<VKMessage *> *forwardingMessages;

// Панель редактирования сообщения
@property (nonatomic, strong) UIView *editingBarView;
@property (nonatomic, strong) UILabel *editingTextLabel;
@property (nonatomic, strong) UIButton *editingCancelButton;
@property (nonatomic, strong) VKMessage *editingMessage;

// Прикрепленное изображение перед отправкой
@property (nonatomic, strong) UIView *attachedPhotoBarView;
@property (nonatomic, strong) UIImageView *attachedPhotoThumbView;
@property (nonatomic, strong) UIButton *attachedPhotoCancelButton;
@property (nonatomic, strong) UIImage *pendingImageToSend;
@property (nonatomic, copy) NSString *pendingAttachmentString;

// Контекстное меню сообщения
@property (nonatomic, strong) VKMessage *selectedMessageForAction;

@property (nonatomic, assign) CGFloat currentKeyboardHeight;

@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isLoadingOlderMessages;
@property (nonatomic, assign) BOOL canLoadMoreOlderMessages;
@property (nonatomic, strong) UIActivityIndicatorView *historyLoadingSpinner;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, assign) NSTimeInterval lastTypingTime;
@property (nonatomic, strong) NSMutableDictionary *usersCache;
@property (nonatomic, strong) NSMutableDictionary *pendingUserFetches;
@property (nonatomic, strong) UIImageView *navAvatarView;
@property (nonatomic, strong) UIView *navAvatarContainer;
@property (nonatomic, strong) VKStickersPickerView *stickersPickerView;
@property (nonatomic, strong) UIButton *stickersButton;
@end

@implementation VKChatViewController

- (instancetype)initWithPeerId:(NSInteger)peerId peerUser:(VKUser *)peerUser title:(NSString *)title {
    self = [super init];
    if (self) {
        _peerId = peerId;
        _peerUser = peerUser;
        _chatTitle = title ?: peerUser.displayName ?: @"Чат";
        _messages = [NSMutableArray array];
        _selectedMessageIds = [NSMutableSet set];
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
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMessageLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.tableView addGestureRecognizer:longPress];
    
    [self.view addSubview:self.tableView];
    
    // 1. Панель ввода сообщения
    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 48.0, width, 48.0)];
    self.inputContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    BOOL isModern = [[VKThemeManager sharedManager] isModern];
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        self.inputContainerView.backgroundColor = [UIColor colorWithRed:225.0/255.0 green:228.0/255.0 blue:234.0/255.0 alpha:1.0];
    } else if (isModern) {
        self.inputContainerView.backgroundColor = [UIColor colorWithWhite:0.98 alpha:0.95];
    } else {
        self.inputContainerView.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:250.0/255.0 alpha:1.0];
    }
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    sep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : (isModern ? [UIColor colorWithWhite:0.88 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0]);
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
    CGFloat tfW = isModern ? (width - 96) : (width - 110);
    self.messageTextField = [[UITextField alloc] initWithFrame:CGRectMake(48, 7, tfW, 34)];
    self.messageTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageTextField.placeholder = isModern ? @"Сообщение" : @"Написать сообщение...";
    self.messageTextField.font = [UIFont systemFontOfSize:14];
    self.messageTextField.delegate = self;
    [self.messageTextField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    if (isSkeuomorph) {
        self.messageTextField.borderStyle = UITextBorderStyleRoundedRect;
    } else if (isModern) {
        self.messageTextField.borderStyle = UITextBorderStyleNone;
        self.messageTextField.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:244.0/255.0 blue:247.0/255.0 alpha:1.0];
        self.messageTextField.layer.cornerRadius = 17.0;
        self.messageTextField.layer.borderWidth = 0.0;
        self.messageTextField.clipsToBounds = YES;
        UIView *leftPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 34)];
        self.messageTextField.leftView = leftPad;
        self.messageTextField.leftViewMode = UITextFieldViewModeAlways;
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
    
    // Кнопка смайла/стикеров
    UIView *rightPad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 32, 34)];
    UIButton *stBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    stBtn.frame = CGRectMake(0, 0, 32, 34);
    [stBtn setTitle:@"😊" forState:UIControlStateNormal];
    stBtn.titleLabel.font = [UIFont systemFontOfSize:19];
    [stBtn addTarget:self action:@selector(toggleStickersPicker) forControlEvents:UIControlEventTouchUpInside];
    [rightPad addSubview:stBtn];
    self.stickersButton = stBtn;
    self.messageTextField.rightView = rightPad;
    self.messageTextField.rightViewMode = UITextFieldViewModeAlways;
    
    [self.inputContainerView addSubview:self.messageTextField];
    
    // Кнопка «Отпр.»
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    if (isModern) {
        self.sendButton.frame = CGRectMake(width - 42, 7, 34, 34);
        self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        self.sendButton.backgroundColor = [[VKThemeManager sharedManager] accentColor];
        self.sendButton.layer.cornerRadius = 17.0;
        self.sendButton.clipsToBounds = YES;
        [self.sendButton setTitle:@"↑" forState:UIControlStateNormal];
        [self.sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        self.sendButton.alpha = 0.4;
    } else {
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
    }
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
    
    [self setupSelectionTopBar];
    [self setupPinnedBannerView];
    [self setupReplyForwardBarView];
    [self setupAttachedPhotoBarView];
    [self setupEditingBarView];
    [self fetchPinnedMessage];
    
    // Уведомления клавиатуры
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // Real-time LongPoll события
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveNewMessageNotification:) name:VKLongPollDidReceiveNewMessageNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReadMessagesNotification:) name:VKLongPollDidReadMessagesNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTypingNotification:) name:VKLongPollUserTypingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userPresenceDidChangeNotification:) name:VKLongPollUserPresenceDidChangeNotification object:nil];
    
    // Подгрузка метаданных диалога или беседы
    if (self.peerId > 2000000000) {
        [self loadChatInfo];
    } else if (self.peerId > 0 && (!self.peerUser || self.peerUser.avatarURL.length == 0)) {
        NSDictionary *params = @{
            @"user_ids": @(self.peerId),
            @"fields": @"photo_50,photo_100,photo_200,photo_max_orig,photo_400_orig,online,last_seen,sex,verified"
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

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isSelectionMode) {
        [self exitSelectionMode];
    }
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
    } else if ([[VKThemeManager sharedManager] isModern] && self.peerUser.isOnline && self.peerId <= 2000000000) {
        statusLabel.textColor = [[VKThemeManager sharedManager] accentColor];
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
    
    [self updateRightBarButtonItems];
    if (self.peerUser && self.peerUser.avatarURL.length > 0 && self.peerId <= 2000000000) {
        [self updateHeaderAvatarWithURL:self.peerUser.avatarURL];
    }
}

- (void)updateRightBarButtonItems {
    if (self.isSelectionMode) {
        self.navigationItem.rightBarButtonItems = nil;
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }
    
    UIBarButtonItem *searchItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(toggleSearchMode)];
    
    if (self.peerId > 2000000000) {
        UIImage *settingsImg = [UIImage imageNamed:@"chat_settings"];
        UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:settingsImg style:UIBarButtonItemStylePlain target:self action:@selector(openChatSettings)];
        self.navigationItem.rightBarButtonItems = @[settingsItem, searchItem];
    } else if (self.navAvatarContainer) {
        UIBarButtonItem *avatarItem = [[UIBarButtonItem alloc] initWithCustomView:self.navAvatarContainer];
        self.navigationItem.rightBarButtonItems = @[avatarItem, searchItem];
    } else {
        self.navigationItem.rightBarButtonItems = @[searchItem];
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
    
    UITapGestureRecognizer *avTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTapped)];
    [container addGestureRecognizer:avTap];
    
    self.navAvatarView = navAvatar;
    self.navAvatarContainer = container;
    
    [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
        if (img) navAvatar.image = img;
    }];
    
    [self updateRightBarButtonItems];
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

- (void)avatarTapped {
    NSString *avatarURL = nil;
    NSString *avatarURLFull = nil;
    if (self.peerId > 2000000000) {
        avatarURL = self.chatPhotoURL;
        avatarURLFull = self.chatPhotoURL;
    } else {
        avatarURL = self.peerUser.avatarURL;
        avatarURLFull = self.peerUser.avatarURLFull ?: avatarURL;
    }
    
    if (avatarURL.length == 0 && avatarURLFull.length == 0) {
        [self headerTapped];
        return;
    }
    
    VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:avatarURL fullImageURL:avatarURLFull initialImage:self.navAvatarView.image];
    [self presentViewController:viewer animated:YES completion:nil];
}

- (void)headerTapped {
    if (self.peerId <= 2000000000) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Перейти в профиль", @"Материалы диалога", nil];
        sheet.tag = 5099;
        [sheet showInView:self.view];
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

#pragma mark - Message Selection Mode

- (void)setupSelectionTopBar {
    CGFloat width = self.view.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.selectionTopBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40.0)];
    self.selectionTopBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (isSkeuomorph) {
        self.selectionTopBar.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:0.98];
    } else {
        self.selectionTopBar.backgroundColor = [UIColor colorWithRed:246.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98];
    }
    self.selectionTopBar.hidden = YES;
    self.selectionTopBar.userInteractionEnabled = YES;
    
    // Кнопка выхода из режима выбора "✕"
    self.selectionCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.selectionCancelButton.frame = CGRectMake(4, 5, 30, 30);
    [self.selectionCancelButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.selectionCancelButton setTitleColor:isSkeuomorph ? [UIColor colorWithWhite:0.3 alpha:1.0] : [UIColor colorWithWhite:0.4 alpha:1.0] forState:UIControlStateNormal];
    self.selectionCancelButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.selectionCancelButton addTarget:self action:@selector(exitSelectionMode) forControlEvents:UIControlEventTouchUpInside];
    [self.selectionTopBar addSubview:self.selectionCancelButton];
    
    // Лейбл счетчика: "Выбрано: 2"
    self.selectionCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 5, width - 180, 30)];
    self.selectionCountLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.selectionCountLabel.font = [UIFont boldSystemFontOfSize:12.5];
    self.selectionCountLabel.textColor = isSkeuomorph ? [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:30.0/255.0 alpha:1.0];
    self.selectionCountLabel.backgroundColor = [UIColor clearColor];
    self.selectionCountLabel.text = @"Выбрано 0 сообщений";
    [self.selectionTopBar addSubview:self.selectionCountLabel];
    
    // Кнопка "Переслать"
    self.selectionForwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.selectionForwardButton.frame = CGRectMake(width - 76 - 8, 6, 76, 28);
    self.selectionForwardButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.selectionForwardButton.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    self.selectionForwardButton.layer.cornerRadius = 4.0;
    self.selectionForwardButton.clipsToBounds = YES;
    [self.selectionForwardButton setTitle:@"Переслать" forState:UIControlStateNormal];
    [self.selectionForwardButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectionForwardButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [self.selectionForwardButton addTarget:self action:@selector(selectionForwardButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.selectionTopBar addSubview:self.selectionForwardButton];
    
    // Кнопка "Удалить"
    self.selectionDeleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.selectionDeleteButton.frame = CGRectMake(width - 76 - 8 - 66 - 6, 6, 66, 28);
    self.selectionDeleteButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.selectionDeleteButton.backgroundColor = [UIColor colorWithRed:255.0/255.0 green:238.0/255.0 blue:238.0/255.0 alpha:1.0];
    self.selectionDeleteButton.layer.cornerRadius = 4.0;
    self.selectionDeleteButton.clipsToBounds = YES;
    [self.selectionDeleteButton setTitle:@"Удалить" forState:UIControlStateNormal];
    [self.selectionDeleteButton setTitleColor:[UIColor colorWithRed:210.0/255.0 green:45.0/255.0 blue:45.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.selectionDeleteButton.titleLabel.font = [UIFont systemFontOfSize:12.0];
    [self.selectionDeleteButton addTarget:self action:@selector(selectionDeleteButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.selectionTopBar addSubview:self.selectionDeleteButton];
    
    UIView *botSep = [[UIView alloc] initWithFrame:CGRectMake(0, 39.5, width, 0.5)];
    botSep.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    botSep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    [self.selectionTopBar addSubview:botSep];
    
    [self.view addSubview:self.selectionTopBar];
}

- (void)enterSelectionModeWithMessage:(VKMessage *)msg {
    if (self.isSearchingMessages) {
        [self closeSearchMode];
    }
    self.isSelectionMode = YES;
    [self.selectedMessageIds removeAllObjects];
    if (msg) {
        NSInteger mid = msg.messageId ?: msg.vkID;
        if (mid > 0) {
            [self.selectedMessageIds addObject:@(mid)];
        }
    }
    [self.view endEditing:YES];
    [self updateRightBarButtonItems];
    [self updateSelectionUI];
    [self updateLayoutAnimated:YES];
    [self.tableView reloadData];
}

- (void)exitSelectionMode {
    self.isSelectionMode = NO;
    [self.selectedMessageIds removeAllObjects];
    [self updateRightBarButtonItems];
    [self updateLayoutAnimated:YES];
    [self.tableView reloadData];
}

- (void)updateSelectionUI {
    NSUInteger count = self.selectedMessageIds.count;
    NSString *word = @"сообщений";
    NSUInteger rem100 = count % 100;
    NSUInteger rem10 = count % 10;
    if (rem100 < 11 || rem100 > 19) {
        if (rem10 == 1) word = @"сообщение";
        else if (rem10 >= 2 && rem10 <= 4) word = @"сообщения";
    }
    self.selectionCountLabel.text = [NSString stringWithFormat:@"Выбрано %lu %@", (unsigned long)count, word];
    
    BOOL hasSelected = (count > 0);
    self.selectionDeleteButton.enabled = hasSelected;
    self.selectionForwardButton.enabled = hasSelected;
    self.selectionDeleteButton.alpha = hasSelected ? 1.0 : 0.4;
    self.selectionForwardButton.alpha = hasSelected ? 1.0 : 0.4;
}

- (void)selectionDeleteButtonTapped {
    if (self.selectedMessageIds.count == 0) return;
    
    NSString *title = [NSString stringWithFormat:@"Удалить выбранные сообщения (%lu)?", (unsigned long)self.selectedMessageIds.count];
    UIActionSheet *delSheet = [[UIActionSheet alloc] initWithTitle:title
                                                          delegate:self
                                                 cancelButtonTitle:@"Отмена"
                                            destructiveButtonTitle:@"Удалить для всех"
                                                 otherButtonTitles:@"Удалить только у меня", nil];
    delSheet.tag = 5007;
    [delSheet showInView:self.view];
}

- (void)selectionForwardButtonTapped {
    if (self.selectedMessageIds.count == 0) return;
    
    NSString *title = [NSString stringWithFormat:@"Переслать сообщения (%lu)", (unsigned long)self.selectedMessageIds.count];
    UIActionSheet *fwdSheet = [[UIActionSheet alloc] initWithTitle:title
                                                          delegate:self
                                                 cancelButtonTitle:@"Отмена"
                                            destructiveButtonTitle:nil
                                                 otherButtonTitles:@"В этот диалог", @"В другой диалог...", nil];
    fwdSheet.tag = 5008;
    [fwdSheet showInView:self.view];
}

#pragma mark - Pinned Message & Attachment Bars

- (void)setupPinnedBannerView {
    CGFloat width = self.view.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.pinnedBannerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 40.0)];
    self.pinnedBannerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (isSkeuomorph) {
        self.pinnedBannerView.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:242.0/255.0 blue:246.0/255.0 alpha:0.97];
    } else {
        self.pinnedBannerView.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:249.0/255.0 blue:251.0/255.0 alpha:0.97];
    }
    self.pinnedBannerView.hidden = YES;
    self.pinnedBannerView.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pinnedBannerTapped)];
    [self.pinnedBannerView addGestureRecognizer:tap];
    
    UIView *accentLine = [[UIView alloc] initWithFrame:CGRectMake(10, 6, 2.5, 28)];
    accentLine.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    accentLine.layer.cornerRadius = 1.25;
    accentLine.clipsToBounds = YES;
    [self.pinnedBannerView addSubview:accentLine];
    
    self.pinnedSenderLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 4, width - 64, 15)];
    self.pinnedSenderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pinnedSenderLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.pinnedSenderLabel.textColor = [[VKThemeManager sharedManager] accentColor];
    self.pinnedSenderLabel.backgroundColor = [UIColor clearColor];
    self.pinnedSenderLabel.text = @"Закрепленное сообщение";
    [self.pinnedBannerView addSubview:self.pinnedSenderLabel];
    
    self.pinnedTextLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, width - 64, 15)];
    self.pinnedTextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pinnedTextLabel.font = [UIFont systemFontOfSize:11.5];
    self.pinnedTextLabel.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    self.pinnedTextLabel.backgroundColor = [UIColor clearColor];
    [self.pinnedBannerView addSubview:self.pinnedTextLabel];
    
    self.pinnedCloseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.pinnedCloseButton.frame = CGRectMake(width - 36, 4, 32, 32);
    self.pinnedCloseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.pinnedCloseButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.pinnedCloseButton setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
    self.pinnedCloseButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.pinnedCloseButton addTarget:self action:@selector(unpinBannerAction) forControlEvents:UIControlEventTouchUpInside];
    [self.pinnedBannerView addSubview:self.pinnedCloseButton];
    
    UIView *botSep = [[UIView alloc] initWithFrame:CGRectMake(0, 39.5, width, 0.5)];
    botSep.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    botSep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    [self.pinnedBannerView addSubview:botSep];
    
    [self.view addSubview:self.pinnedBannerView];
}

- (void)setupReplyForwardBarView {
    CGFloat width = self.view.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.replyForwardBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 38.0)];
    self.replyForwardBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.replyForwardBarView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0] : [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
    self.replyForwardBarView.hidden = YES;
    
    UIView *topSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    topSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topSep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    [self.replyForwardBarView addSubview:topSep];
    
    UIView *accentLine = [[UIView alloc] initWithFrame:CGRectMake(10, 5, 2.5, 28)];
    accentLine.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    accentLine.layer.cornerRadius = 1.25;
    accentLine.clipsToBounds = YES;
    [self.replyForwardBarView addSubview:accentLine];
    
    self.replyAuthorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 3, width - 62, 16)];
    self.replyAuthorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.replyAuthorLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.replyAuthorLabel.textColor = [[VKThemeManager sharedManager] accentColor];
    self.replyAuthorLabel.backgroundColor = [UIColor clearColor];
    [self.replyForwardBarView addSubview:self.replyAuthorLabel];
    
    self.replyTextLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 19, width - 62, 15)];
    self.replyTextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.replyTextLabel.font = [UIFont systemFontOfSize:11.5];
    self.replyTextLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    self.replyTextLabel.backgroundColor = [UIColor clearColor];
    [self.replyForwardBarView addSubview:self.replyTextLabel];
    
    self.replyCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.replyCancelButton.frame = CGRectMake(width - 34, 4, 30, 30);
    self.replyCancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.replyCancelButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.replyCancelButton setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
    self.replyCancelButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.replyCancelButton addTarget:self action:@selector(cancelReplyForwardAction) forControlEvents:UIControlEventTouchUpInside];
    [self.replyForwardBarView addSubview:self.replyCancelButton];
    
    [self.inputContainerView addSubview:self.replyForwardBarView];
}

- (void)setupAttachedPhotoBarView {
    CGFloat width = self.view.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.attachedPhotoBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 48.0)];
    self.attachedPhotoBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.attachedPhotoBarView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0] : [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
    self.attachedPhotoBarView.hidden = YES;
    
    UIView *topSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    topSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topSep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    [self.attachedPhotoBarView addSubview:topSep];
    
    self.attachedPhotoThumbView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 4, 40, 40)];
    self.attachedPhotoThumbView.contentMode = UIViewContentModeScaleAspectFill;
    self.attachedPhotoThumbView.layer.cornerRadius = 4.0;
    self.attachedPhotoThumbView.clipsToBounds = YES;
    self.attachedPhotoThumbView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    [self.attachedPhotoBarView addSubview:self.attachedPhotoThumbView];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(58, 14, width - 100, 20)];
    lbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    lbl.font = [UIFont systemFontOfSize:13];
    lbl.textColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    lbl.text = @"Прикрепленное фото";
    lbl.backgroundColor = [UIColor clearColor];
    [self.attachedPhotoBarView addSubview:lbl];
    
    self.attachedPhotoCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.attachedPhotoCancelButton.frame = CGRectMake(width - 34, 9, 30, 30);
    self.attachedPhotoCancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.attachedPhotoCancelButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.attachedPhotoCancelButton setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
    self.attachedPhotoCancelButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.attachedPhotoCancelButton addTarget:self action:@selector(cancelAttachedPhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.attachedPhotoBarView addSubview:self.attachedPhotoCancelButton];
    
    [self.inputContainerView addSubview:self.attachedPhotoBarView];
}

- (void)setupEditingBarView {
    CGFloat width = self.view.bounds.size.width;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    self.editingBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 38.0)];
    self.editingBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.editingBarView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:235.0/255.0 green:238.0/255.0 blue:242.0/255.0 alpha:1.0] : [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
    self.editingBarView.hidden = YES;
    
    UIView *topSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    topSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topSep.backgroundColor = isSkeuomorph ? [UIColor colorWithWhite:0.75 alpha:1.0] : [UIColor colorWithRed:220.0/255.0 green:222.0/255.0 blue:226.0/255.0 alpha:1.0];
    [self.editingBarView addSubview:topSep];
    
    UIView *accentLine = [[UIView alloc] initWithFrame:CGRectMake(10, 5, 2.5, 28)];
    accentLine.backgroundColor = [[VKThemeManager sharedManager] accentColor];
    accentLine.layer.cornerRadius = 1.25;
    accentLine.clipsToBounds = YES;
    [self.editingBarView addSubview:accentLine];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(20, 3, width - 62, 16)];
    titleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLbl.font = [UIFont boldSystemFontOfSize:11.5];
    titleLbl.textColor = [[VKThemeManager sharedManager] accentColor];
    titleLbl.text = @"Редактирование";
    titleLbl.backgroundColor = [UIColor clearColor];
    [self.editingBarView addSubview:titleLbl];
    
    self.editingTextLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 19, width - 62, 15)];
    self.editingTextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.editingTextLabel.font = [UIFont systemFontOfSize:11.5];
    self.editingTextLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
    self.editingTextLabel.backgroundColor = [UIColor clearColor];
    [self.editingBarView addSubview:self.editingTextLabel];
    
    self.editingCancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.editingCancelButton.frame = CGRectMake(width - 34, 4, 30, 30);
    self.editingCancelButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.editingCancelButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.editingCancelButton setTitleColor:[UIColor colorWithWhite:0.55 alpha:1.0] forState:UIControlStateNormal];
    self.editingCancelButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.editingCancelButton addTarget:self action:@selector(cancelEditingAction) forControlEvents:UIControlEventTouchUpInside];
    [self.editingBarView addSubview:self.editingCancelButton];
    
    [self.inputContainerView addSubview:self.editingBarView];
}

- (void)fetchPinnedMessage {
    [[VKMessagesService sharedService] fetchConversationWithPeerId:self.peerId completion:^(VKConversation *conversation, VKMessage *pinnedMessage, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (pinnedMessage) {
                self.pinnedMessage = pinnedMessage;
                if (pinnedMessage.fromId > 0 && !pinnedMessage.senderUser) {
                    pinnedMessage.senderUser = [self senderUserForMessage:pinnedMessage];
                }
            } else {
                self.pinnedMessage = nil;
            }
            [self updateLayoutAnimated:YES];
        });
    }];
}

- (void)pinnedBannerTapped {
    if (!self.pinnedMessage) return;
    NSInteger targetId = self.pinnedMessage.messageId;
    for (NSInteger i = 0; i < self.messages.count; i++) {
        VKMessage *m = self.messages[i];
        if (m.messageId == targetId) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
            [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
            return;
        }
    }
    // Если сообщение еще не подгружено в текущих сообщениях
    NSString *preview = [self previewTextForMessage:self.pinnedMessage];
    VKUser *author = [self senderUserForMessage:self.pinnedMessage];
    NSString *authorName = author ? author.displayName : @"Закрепленное сообщение";
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:authorName message:preview delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [av show];
}

- (void)unpinBannerAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Открепить сообщение?"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:@"Открепить"
                                              otherButtonTitles:nil];
    sheet.tag = 5005;
    [sheet showInView:self.view];
}

- (void)cancelReplyForwardAction {
    self.replyingMessage = nil;
    self.forwardingMessages = nil;
    [self updateLayoutAnimated:YES];
}

- (void)cancelAttachedPhotoAction {
    self.pendingImageToSend = nil;
    self.attachedPhotoThumbView.image = nil;
    [self updateLayoutAnimated:YES];
}

- (void)cancelEditingAction {
    self.editingMessage = nil;
    self.messageTextField.text = @"";
    [self updateLayoutAnimated:YES];
}

- (void)handleMessageLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (self.isSelectionMode) return;
    CGPoint pt = [gesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:pt];
    if (!indexPath || indexPath.row >= (NSInteger)self.messages.count) return;
    
    VKMessage *msg = self.messages[indexPath.row];
    if ([msg isServiceAction]) return;
    
    self.selectedMessageForAction = msg;
    
    BOOL isPinned = (self.pinnedMessage && self.pinnedMessage.messageId == msg.messageId);
    NSString *pinTitle = isPinned ? @"Открепить сообщение" : @"Закрепить сообщение";
    
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:@"Удалить"
                                              otherButtonTitles:nil];
    
    [sheet addButtonWithTitle:@"Ответить"];
    [sheet addButtonWithTitle:@"Переслать"];
    [sheet addButtonWithTitle:@"Выбрать"];
    if (msg.isOutgoing && ![self isStickerMessage:msg]) {
        [sheet addButtonWithTitle:@"Редактировать"];
    }
    if (self.peerId > 2000000000 || msg.isOutgoing) {
        [sheet addButtonWithTitle:@"Кто прочитал"];
    }
    [sheet addButtonWithTitle:pinTitle];
    if (msg.text.length > 0) {
        [sheet addButtonWithTitle:@"Копировать текст"];
    }
    
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    sheet.tag = 5004;
    [sheet showInView:self.view];
}

- (void)updateLayoutAnimated:(BOOL)animated {
    [self updateLayoutWithKeyboardHeight:self.currentKeyboardHeight duration:animated ? 0.25 : 0 curve:0 animated:animated];
}

- (void)updateLayoutWithKeyboardHeight:(CGFloat)kbHeight duration:(NSTimeInterval)duration curve:(UIViewAnimationOptions)curve animated:(BOOL)animated {
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    BOOL hasSelection = self.isSelectionMode;
    CGFloat selectH = hasSelection ? 40.0 : 0.0;
    
    BOOL hasPin = (self.pinnedMessage != nil);
    CGFloat pinH = hasPin ? 40.0 : 0.0;
    
    BOOL hasReply = (self.replyingMessage != nil || self.forwardingMessages.count > 0);
    CGFloat replyH = hasReply ? 38.0 : 0.0;
    
    BOOL hasPhoto = (self.pendingImageToSend != nil);
    CGFloat photoH = hasPhoto ? 48.0 : 0.0;
    
    BOOL hasEdit = (self.editingMessage != nil);
    CGFloat editH = hasEdit ? 38.0 : 0.0;
    
    CGFloat inputBaseH = 48.0;
    CGFloat totalInputH = inputBaseH + replyH + photoH + editH;
    
    CGFloat topOffset = selectH + pinH;
    
    void (^layoutBlock)(void) = ^{
        // 0. Selection top bar
        self.selectionTopBar.hidden = !hasSelection;
        self.selectionTopBar.frame = CGRectMake(0, 0, width, selectH);
        
        // 1. Pinned banner
        self.pinnedBannerView.hidden = !hasPin;
        self.pinnedBannerView.frame = CGRectMake(0, selectH, width, pinH);
        if (hasPin) {
            VKUser *u = [self senderUserForMessage:self.pinnedMessage];
            NSString *authorStr = u ? u.displayName : (self.pinnedMessage.fromId > 0 ? [NSString stringWithFormat:@"id%ld", (long)self.pinnedMessage.fromId] : @"Сообщение");
            self.pinnedSenderLabel.text = [NSString stringWithFormat:@"Закрепленное сообщение · %@", authorStr];
            self.pinnedTextLabel.text = [self previewTextForMessage:self.pinnedMessage];
        }
        
        // 2. Input container & its subviews
        if (self.peerId > 2000000000 && self.isLeftOrKicked) {
            self.inputContainerView.hidden = YES;
            self.leaveReturnBannerView.hidden = NO;
            self.leaveReturnBannerView.frame = CGRectMake(0, height - 48.0, width, 48.0);
            self.tableView.frame = CGRectMake(0, topOffset, width, height - 48.0 - topOffset);
        } else {
            self.inputContainerView.hidden = NO;
            self.leaveReturnBannerView.hidden = YES;
            self.inputContainerView.frame = CGRectMake(0, height - kbHeight - totalInputH, width, totalInputH);
            self.tableView.frame = CGRectMake(0, topOffset, width, height - kbHeight - totalInputH - topOffset);
            
            // Subsections of inputContainerView
            CGFloat currentY = 0.0;
            if (hasEdit) {
                self.editingBarView.hidden = NO;
                self.editingBarView.frame = CGRectMake(0, currentY, width, editH);
                self.editingTextLabel.text = [self previewTextForMessage:self.editingMessage];
                currentY += editH;
                [self.sendButton setTitle:@"Сохр." forState:UIControlStateNormal];
            } else {
                self.editingBarView.hidden = YES;
                [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
            }
            
            if (hasReply) {
                self.replyForwardBarView.hidden = NO;
                self.replyForwardBarView.frame = CGRectMake(0, currentY, width, replyH);
                if (self.replyingMessage) {
                    VKUser *ru = [self senderUserForMessage:self.replyingMessage];
                    NSString *name = ru ? ru.displayName : (self.replyingMessage.fromId > 0 ? [NSString stringWithFormat:@"id%ld", (long)self.replyingMessage.fromId] : @"");
                    self.replyAuthorLabel.text = name.length > 0 ? [NSString stringWithFormat:@"Ответ для %@", name] : @"Ответ на сообщение";
                    self.replyTextLabel.text = [self previewTextForMessage:self.replyingMessage];
                } else if (self.forwardingMessages.count > 0) {
                    self.replyAuthorLabel.text = [NSString stringWithFormat:@"Пересылаемых сообщений: %lu", (unsigned long)self.forwardingMessages.count];
                    self.replyTextLabel.text = [self previewTextForMessage:self.forwardingMessages[0]];
                }
                currentY += replyH;
            } else {
                self.replyForwardBarView.hidden = YES;
            }
            
            if (hasPhoto) {
                self.attachedPhotoBarView.hidden = NO;
                self.attachedPhotoBarView.frame = CGRectMake(0, currentY, width, photoH);
                currentY += photoH;
            } else {
                self.attachedPhotoBarView.hidden = YES;
            }
            
            // Controls inside input container
            self.attachButton.frame = CGRectMake(8, currentY + 7, 34, 34);
            self.messageTextField.frame = CGRectMake(48, currentY + 7, width - 110, 34);
            self.sendButton.frame = CGRectMake(width - 58, currentY + 7, 52, 34);
        }
    };
    
    if (animated && duration > 0.0) {
        [UIView animateWithDuration:duration delay:0 options:curve animations:layoutBlock completion:nil];
    } else {
        layoutBlock();
    }
}

#pragma mark - Keyboard Handling

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    
    self.currentKeyboardHeight = kbFrame.size.height;
    [self updateLayoutWithKeyboardHeight:self.currentKeyboardHeight duration:duration curve:curve animated:YES];
    
    if (self.messages.count > 0) {
        NSIndexPath *lastPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:lastPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions curve = [[info objectForKey:UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
    
    self.currentKeyboardHeight = 0.0;
    [self updateLayoutWithKeyboardHeight:0.0 duration:duration curve:curve animated:YES];
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
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.statusLabel.textColor = [UIColor colorWithRed:180.0/255.0 green:210.0/255.0 blue:245.0/255.0 alpha:1.0];
    } else if ([[VKThemeManager sharedManager] isModern] && self.peerUser.isOnline && self.peerId <= 2000000000) {
        self.statusLabel.textColor = [[VKThemeManager sharedManager] accentColor];
    } else {
        self.statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    }
}

- (void)userPresenceDidChangeNotification:(NSNotification *)note {
    NSInteger userId = [note.userInfo[@"user_id"] integerValue];
    if (self.peerId > 2000000000) return;
    if (self.peerUser && (self.peerUser.uid == userId || self.peerId == userId)) {
        BOOL online = [note.userInfo[@"online"] boolValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.peerUser.isOnline = online;
            if (!online) {
                self.peerUser.lastSeen = @"был(а) только что";
            }
            [self resetTypingStatus];
        });
    }
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
    } else if (actionSheet.tag == 5004) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        
        VKMessage *msg = self.selectedMessageForAction;
        if (!msg) return;
        
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            UIActionSheet *delSheet = [[UIActionSheet alloc] initWithTitle:@"Удалить сообщение?"
                                                                  delegate:self
                                                         cancelButtonTitle:@"Отмена"
                                                    destructiveButtonTitle:@"Удалить для всех"
                                                         otherButtonTitles:@"Удалить только у меня", nil];
            delSheet.tag = 5006;
            [delSheet showInView:self.view];
            return;
        }
        
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([title isEqualToString:@"Ответить"]) {
            self.replyingMessage = msg;
            self.forwardingMessages = nil;
            self.editingMessage = nil;
            [self updateLayoutAnimated:YES];
            [self.messageTextField becomeFirstResponder];
        } else if ([title isEqualToString:@"Переслать"]) {
            self.selectedMessageForAction = msg;
            UIActionSheet *fwdSheet = [[UIActionSheet alloc] initWithTitle:@"Переслать сообщение"
                                                                  delegate:self
                                                         cancelButtonTitle:@"Отмена"
                                                    destructiveButtonTitle:nil
                                                         otherButtonTitles:@"В этот диалог", @"В другой диалог...", nil];
            fwdSheet.tag = 5009;
            [fwdSheet showInView:self.view];
        } else if ([title isEqualToString:@"Выбрать"]) {
            [self enterSelectionModeWithMessage:msg];
        } else if ([title isEqualToString:@"Редактировать"]) {
            self.editingMessage = msg;
            self.replyingMessage = nil;
            self.forwardingMessages = nil;
            self.messageTextField.text = msg.text ?: @"";
            [self updateLayoutAnimated:YES];
            [self.messageTextField becomeFirstResponder];
        } else if ([title isEqualToString:@"Кто прочитал"]) {
            VKMessageViewersViewController *viewersVC = [[VKMessageViewersViewController alloc] initWithPeerId:self.peerId messageId:msg.messageId];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:viewersVC];
            [self presentViewController:nav animated:YES completion:nil];
        } else if ([title hasPrefix:@"Закрепить"] || [title hasPrefix:@"Открепить"]) {
            if (self.pinnedMessage && self.pinnedMessage.messageId == msg.messageId) {
                [[VKMessagesService sharedService] unpinMessageWithPeerId:self.peerId completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            self.pinnedMessage = nil;
                            [self updateLayoutAnimated:YES];
                        } else if (error) {
                            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [av show];
                        }
                    });
                }];
            } else {
                [[VKMessagesService sharedService] pinMessageWithPeerId:self.peerId messageId:msg.messageId completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            self.pinnedMessage = msg;
                            [self updateLayoutAnimated:YES];
                        } else if (error) {
                            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [av show];
                        }
                    });
                }];
            }
        } else if ([title isEqualToString:@"Копировать текст"]) {
            if (msg.text.length > 0) {
                [UIPasteboard generalPasteboard].string = msg.text;
            }
        }
    } else if (actionSheet.tag == 5005) {
        // Подтверждение открепления из плашки закрепа
        if (buttonIndex == 0) {
            [[VKMessagesService sharedService] unpinMessageWithPeerId:self.peerId completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        self.pinnedMessage = nil;
                        [self updateLayoutAnimated:YES];
                    } else if (error) {
                        UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [av show];
                    }
                });
            }];
        }
    } else if (actionSheet.tag == 5006) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        BOOL deleteForAll = (buttonIndex == actionSheet.destructiveButtonIndex);
        VKMessage *msg = self.selectedMessageForAction;
        if (!msg) return;
        NSInteger mid = msg.messageId;
        [[VKMessagesService sharedService] deleteMessagesWithIds:@[@(mid)] deleteForAll:deleteForAll peerId:self.peerId completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSInteger idx = [self.messages indexOfObject:msg];
                    if (idx != NSNotFound) {
                        [self.messages removeObjectAtIndex:idx];
                        [self.tableView reloadData];
                    }
                    if (self.pinnedMessage && self.pinnedMessage.messageId == mid) {
                        self.pinnedMessage = nil;
                        [self updateLayoutAnimated:YES];
                    }
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка удаления" message:error.localizedDescription ?: @"Не удалось удалить сообщение" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
    } else if (actionSheet.tag == 5007) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        BOOL deleteForAll = (buttonIndex == actionSheet.destructiveButtonIndex);
        NSArray<NSNumber *> *mids = [self.selectedMessageIds allObjects];
        if (mids.count == 0) return;
        
        __weak typeof(self) weakSelf = self;
        [[VKMessagesService sharedService] deleteMessagesWithIds:mids
                                                    deleteForAll:deleteForAll
                                                          peerId:self.peerId
                                                      completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSMutableSet *deletedSet = [NSMutableSet setWithArray:mids];
                    NSMutableArray *toKeep = [NSMutableArray array];
                    for (VKMessage *m in weakSelf.messages) {
                        NSNumber *midNum = @(m.messageId ?: m.vkID);
                        if (![deletedSet containsObject:midNum]) {
                            [toKeep addObject:m];
                        }
                    }
                    weakSelf.messages = toKeep;
                    if (weakSelf.pinnedMessage && [deletedSet containsObject:@(weakSelf.pinnedMessage.messageId)]) {
                        weakSelf.pinnedMessage = nil;
                    }
                    [weakSelf exitSelectionMode];
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка удаления"
                                                                  message:error.localizedDescription ?: @"Не удалось удалить сообщения"
                                                                 delegate:nil
                                                        cancelButtonTitle:@"OK"
                                                        otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
    } else if (actionSheet.tag == 5008) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        NSMutableArray<VKMessage *> *fwdList = [NSMutableArray array];
        for (VKMessage *m in self.messages) {
            NSNumber *midNum = @(m.messageId ?: m.vkID);
            if ([self.selectedMessageIds containsObject:midNum]) {
                [fwdList addObject:m];
            }
        }
        if (fwdList.count == 0) return;
        
        if (buttonIndex == 0) {
            // В этот диалог
            self.forwardingMessages = fwdList;
            self.replyingMessage = nil;
            self.editingMessage = nil;
            [self exitSelectionMode];
            [self updateLayoutAnimated:YES];
            [self.messageTextField becomeFirstResponder];
        } else if (buttonIndex == 1) {
            // В другой диалог...
            [self exitSelectionMode];
            VKShareDialogPickerViewController *picker = [[VKShareDialogPickerViewController alloc] initWithForwardMessages:fwdList];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
            [self presentViewController:nav animated:YES completion:nil];
        }
    } else if (actionSheet.tag == 5009) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        VKMessage *msg = self.selectedMessageForAction;
        if (!msg) return;
        
        if (buttonIndex == 0) {
            // В этот диалог
            self.replyingMessage = nil;
            self.forwardingMessages = [NSMutableArray arrayWithObject:msg];
            self.editingMessage = nil;
            [self updateLayoutAnimated:YES];
            [self.messageTextField becomeFirstResponder];
        } else if (buttonIndex == 1) {
            // В другой диалог...
            VKShareDialogPickerViewController *picker = [[VKShareDialogPickerViewController alloc] initWithForwardMessages:@[msg]];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
            [self presentViewController:nav animated:YES completion:nil];
        }
    } else if (actionSheet.tag == 5099) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        if (buttonIndex == 0) {
            [self openPeerProfile];
        } else if (buttonIndex == 1) {
            VKChatAttachmentsViewController *attVC = [[VKChatAttachmentsViewController alloc] initWithPeerId:self.peerId chatTitle:self.chatTitle];
            [self.navigationController pushViewController:attVC animated:YES];
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
    UIImage *chosenImage = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (chosenImage) {
            self.pendingImageToSend = chosenImage;
            self.attachedPhotoThumbView.image = chosenImage;
            [self updateLayoutAnimated:YES];
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

- (void)toggleStickersPicker {
    if (self.messageTextField.inputView != nil) {
        // Переключаемся обратно на обычную клавиатуру
        self.messageTextField.inputView = nil;
        [self.stickersButton setTitle:@"😊" forState:UIControlStateNormal];
        [self.messageTextField reloadInputViews];
    } else {
        // Переключаемся на пикер стикеров
        if (!self.stickersPickerView) {
            self.stickersPickerView = [[VKStickersPickerView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 216.0)];
            __weak typeof(self) weakSelf = self;
            self.stickersPickerView.onStickerSelected = ^(NSInteger stickerId) {
                [weakSelf sendStickerWithId:stickerId];
            };
            self.stickersPickerView.onOpenStore = ^{
                [weakSelf openStickersStore];
            };
        }
        [self.stickersPickerView reloadPacks];
        self.messageTextField.inputView = self.stickersPickerView;
        [self.stickersButton setTitle:@"⌨️" forState:UIControlStateNormal];
        [self.messageTextField becomeFirstResponder];
        [self.messageTextField reloadInputViews];
    }
}

- (void)openStickersStore {
    VKStickersStoreViewController *storeVC = [[VKStickersStoreViewController alloc] init];
    __weak typeof(self) weakSelf = self;
    storeVC.onPacksUpdated = ^{
        [weakSelf.stickersPickerView reloadPacks];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:storeVC];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)sendOptimisticMessageWithText:(NSString *)text stickerId:(NSInteger)stickerId {
    VKMessage *tempMsg = [[VKMessage alloc] init];
    tempMsg.messageId = -(NSInteger)(arc4random_uniform(1000000) + 1);
    tempMsg.peerId = self.peerId;
    tempMsg.fromId = [VKAuthService sharedService].currentUserId;
    tempMsg.isOutgoing = YES;
    tempMsg.text = text ?: @"";
    tempMsg.date = [NSDate date];
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"HH:mm"];
    tempMsg.timeString = [df stringFromDate:tempMsg.date];
    tempMsg.isRead = NO;
    
    if (stickerId > 0) {
        VKAttachment *stAtt = [[VKAttachment alloc] init];
        stAtt.type = VKAttachmentTypeSticker;
        stAtt.stickerId = stickerId;
        VKSticker *stObj = [[VKStickersService sharedService] stickerWithId:stickerId];
        stAtt.stickerURL = stObj ? stObj.imageURL : nil;
        tempMsg.attachments = @[stAtt];
    }
    
    [self.messages addObject:tempMsg];
    [self.tableView reloadData];
    if (self.messages.count > 0) {
        NSIndexPath *lastPath = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:lastPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
}

- (void)sendStickerWithId:(NSInteger)stickerId {
    [self sendOptimisticMessageWithText:nil stickerId:stickerId];
    __weak typeof(self) weakSelf = self;
    [[VKMessagesService sharedService] sendSticker:stickerId peerId:self.peerId completion:^(BOOL success, NSInteger messageId, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (!success && error) {
                for (NSInteger i = (NSInteger)strongSelf.messages.count - 1; i >= 0; i--) {
                    VKMessage *m = strongSelf.messages[i];
                    if (m.messageId < 0) {
                        [strongSelf.messages removeObjectAtIndex:i];
                        break;
                    }
                }
                [strongSelf.tableView reloadData];
                UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                             message:error.localizedDescription ?: @"Не удалось отправить стикер"
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
                [av show];
            } else {
                [strongSelf loadHistory];
            }
        });
    }];
}

- (void)dismissKeyboard {
    if (self.messageTextField.inputView != nil) {
        self.messageTextField.inputView = nil;
        [self.stickersButton setTitle:@"😊" forState:UIControlStateNormal];
        [self.messageTextField reloadInputViews];
    }
    [self.view endEditing:YES];
}

- (void)textFieldDidChange:(UITextField *)tf {
    BOOL hasText = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length > 0;
    if ([[VKThemeManager sharedManager] isModern]) {
        [UIView animateWithDuration:0.15 animations:^{
            self.sendButton.alpha = (hasText || self.pendingImageToSend || self.forwardingMessages.count > 0) ? 1.0 : 0.4;
        }];
    }
}

- (void)loadHistory {
    if (self.isLoading) return;
    self.isLoading = YES;
    self.canLoadMoreOlderMessages = YES;
    
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
                
                if (messages.count < 50) {
                    self.canLoadMoreOlderMessages = NO;
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

- (void)loadOlderMessages {
    if (self.isLoading || self.isLoadingOlderMessages || !self.canLoadMoreOlderMessages) return;
    
    self.isLoadingOlderMessages = YES;
    NSInteger offset = self.messages.count;
    [VKCrashLogger log:@"[VKChatViewController] Loading older messages, offset=%ld...", (long)offset];
    
    if (!self.historyLoadingSpinner) {
        self.historyLoadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.historyLoadingSpinner.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 36.0);
    }
    [self.historyLoadingSpinner startAnimating];
    self.tableView.tableHeaderView = self.historyLoadingSpinner;
    
    __weak typeof(self) weakSelf = self;
    [[VKMessagesService sharedService] fetchHistoryForPeerId:self.peerId offset:offset count:50 completion:^(NSArray *olderMessages, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            strongSelf.isLoadingOlderMessages = NO;
            [strongSelf.historyLoadingSpinner stopAnimating];
            strongSelf.tableView.tableHeaderView = nil;
            
            if (error) {
                [VKCrashLogger log:@"[VKChatViewController] Failed to load older messages: %@", error.localizedDescription];
                return;
            }
            
            if (olderMessages.count == 0) {
                strongSelf.canLoadMoreOlderMessages = NO;
                [VKCrashLogger log:@"[VKChatViewController] No more older messages available."];
                return;
            }
            
            if (olderMessages.count < 50) {
                strongSelf.canLoadMoreOlderMessages = NO;
            }
            
            // Проверяем существующие ID сообщений для дедупликации
            NSMutableSet *existingIds = [NSMutableSet set];
            for (VKMessage *m in strongSelf.messages) {
                [existingIds addObject:@(m.messageId)];
            }
            
            NSMutableArray *newOlderUnique = [NSMutableArray array];
            NSEnumerator *enumerator = [olderMessages reverseObjectEnumerator];
            for (VKMessage *m in enumerator) {
                if (![existingIds containsObject:@(m.messageId)]) {
                    [newOlderUnique addObject:m];
                    if (m.senderUser && m.senderUser.uid != 0) {
                        strongSelf.usersCache[@(m.senderUser.uid)] = m.senderUser;
                    }
                }
            }
            
            if (newOlderUnique.count == 0) {
                strongSelf.canLoadMoreOlderMessages = NO;
                return;
            }
            
            // Фиксируем смещение скролла, чтобы интерфейс не дергался при добавлении сообщений сверху!
            CGFloat oldContentHeight = strongSelf.tableView.contentSize.height;
            CGFloat oldOffsetY = strongSelf.tableView.contentOffset.y;
            
            NSRange insertRange = NSMakeRange(0, newOlderUnique.count);
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndexesInRange:insertRange];
            [strongSelf.messages insertObjects:newOlderUnique atIndexes:indexSet];
            
            [strongSelf.tableView reloadData];
            [strongSelf.tableView layoutIfNeeded];
            
            CGFloat newContentHeight = strongSelf.tableView.contentSize.height;
            CGFloat deltaHeight = newContentHeight - oldContentHeight;
            strongSelf.tableView.contentOffset = CGPointMake(0, oldOffsetY + deltaHeight);
            
            [VKCrashLogger log:@"[VKChatViewController] Loaded %lu older messages, total: %lu", (unsigned long)newOlderUnique.count, (unsigned long)strongSelf.messages.count];
        });
    }];
}

#pragma mark - UIScrollViewDelegate (Top Pagination)

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // Если пользователь прокрутил к началу диалога (offset <= 60), подгружаем более старые сообщения
    if (scrollView.contentOffset.y <= 60.0 && self.messages.count > 0 && !self.isLoading && !self.isLoadingOlderMessages && self.canLoadMoreOlderMessages) {
        [self loadOlderMessages];
    }
}

- (void)sendMessage {
    NSString *text = [self.messageTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (self.editingMessage) {
        if (text.length == 0) return;
        self.sendButton.userInteractionEnabled = NO;
        VKMessage *msgToEdit = self.editingMessage;
        [[VKMessagesService sharedService] editMessageWithPeerId:self.peerId messageId:msgToEdit.messageId text:text completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sendButton.userInteractionEnabled = YES;
                if (success) {
                    msgToEdit.text = text;
                    self.editingMessage = nil;
                    self.messageTextField.text = @"";
                    [self updateLayoutAnimated:YES];
                    [self.tableView reloadData];
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка изменения" message:error.localizedDescription ?: @"Не удалось изменить сообщение" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
        return;
    }
    
    if (text.length == 0 && !self.pendingImageToSend && self.forwardingMessages.count == 0) return;
    
    self.sendButton.userInteractionEnabled = NO;
    [VKCrashLogger log:@"[VKChatViewController] Sending message to peerId=%ld", (long)self.peerId];
    
    NSInteger replyTo = self.replyingMessage ? self.replyingMessage.messageId : 0;
    NSString *fwdStr = nil;
    if (self.forwardingMessages.count > 0) {
        NSMutableArray *ids = [NSMutableArray array];
        for (VKMessage *m in self.forwardingMessages) {
            NSInteger mid = m.messageId ?: m.vkID;
            if (mid > 0) {
                [ids addObject:@(mid)];
            }
        }
        fwdStr = [ids componentsJoinedByString:@","];
    }
    
    if (self.pendingImageToSend) {
        UIImage *imgToSend = self.pendingImageToSend;
        [[VKMessagesService sharedService] uploadMessagePhoto:imgToSend peerId:self.peerId completion:^(NSString *attachmentString, NSError *uploadError) {
            if (uploadError || !attachmentString) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.sendButton.userInteractionEnabled = YES;
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка загрузки фото" message:uploadError.localizedDescription ?: @"Не удалось загрузить изображение" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                });
                return;
            }
            
            [[VKMessagesService sharedService] sendMessageToPeerId:self.peerId text:text attachment:attachmentString replyTo:replyTo forwardMsgs:fwdStr completion:^(BOOL success, NSInteger messageId, NSError *sendError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.sendButton.userInteractionEnabled = YES;
                    if (success) {
                        self.messageTextField.text = @"";
                        self.pendingImageToSend = nil;
                        self.attachedPhotoThumbView.image = nil;
                        self.replyingMessage = nil;
                        self.forwardingMessages = nil;
                        [self updateLayoutAnimated:YES];
                        [self loadHistory];
                    } else {
                        UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Не удалось отправить" message:sendError.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [err show];
                    }
                });
            }];
        }];
    } else {
        NSString *sentText = text;
        [self sendOptimisticMessageWithText:sentText stickerId:0];
        self.messageTextField.text = @"";
        self.replyingMessage = nil;
        self.forwardingMessages = nil;
        [self updateLayoutAnimated:YES];
        
        [[VKMessagesService sharedService] sendMessageToPeerId:self.peerId text:sentText attachment:nil replyTo:replyTo forwardMsgs:fwdStr completion:^(BOOL success, NSInteger messageId, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sendButton.userInteractionEnabled = YES;
                if (success) {
                    [self loadHistory];
                } else if (error) {
                    for (NSInteger i = (NSInteger)self.messages.count - 1; i >= 0; i--) {
                        VKMessage *m = self.messages[i];
                        if (m.messageId < 0) {
                            [self.messages removeObjectAtIndex:i];
                            break;
                        }
                    }
                    [self.tableView reloadData];
                    self.messageTextField.text = sentText;
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
}

- (BOOL)isMessageAtIndex:(NSInteger)index joinedWithIndex:(NSInteger)neighborIndex {
    if (index < 0 || index >= (NSInteger)self.messages.count) return NO;
    if (neighborIndex < 0 || neighborIndex >= (NSInteger)self.messages.count) return NO;
    VKMessage *msg = self.messages[index];
    VKMessage *neighbor = self.messages[neighborIndex];
    if (!msg || !neighbor) return NO;
    if ([msg isServiceAction] || [neighbor isServiceAction]) return NO;
    if ([self isStickerMessage:msg] || [self isStickerMessage:neighbor]) return NO;
    if (msg.isOutgoing != neighbor.isOutgoing) return NO;
    if (msg.fromId != neighbor.fromId) return NO;
    
    NSTimeInterval t1 = [msg.date timeIntervalSince1970];
    NSTimeInterval t2 = [neighbor.date timeIntervalSince1970];
    if (fabs(t1 - t2) > 300.0) return NO;
    return YES;
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (NSString *)previewTextForMessage:(VKMessage *)msg {
    if (!msg) return @"";
    if (msg.text.length > 0) return msg.text;
    
    if (msg.attachments.count > 0) {
        VKAttachment *first = msg.attachments[0];
        if ([first isKindOfClass:[VKAttachment class]]) {
            if (first.type == VKAttachmentTypePhoto) {
                return (msg.attachments.count > 1) ? [NSString stringWithFormat:@"%lu фотографии", (unsigned long)msg.attachments.count] : @"[Фотография]";
            } else if (first.type == VKAttachmentTypeVideo) {
                return first.videoTitle.length > 0 ? [NSString stringWithFormat:@"🎬 %@", first.videoTitle] : @"[Видеозапись]";
            } else if (first.type == VKAttachmentTypeSticker) {
                return @"[Стикер]";
            } else if (first.type == VKAttachmentTypeGif) {
                return @"[GIF-анимация]";
            } else if (first.type == VKAttachmentTypeAudio) {
                return [NSString stringWithFormat:@"🎵 %@ — %@", first.audioArtist ?: @"", first.audioTitle ?: @"Трек"];
            } else if (first.type == VKAttachmentTypeDoc) {
                return [NSString stringWithFormat:@"📄 %@", first.docTitle ?: @"Документ"];
            } else if (first.type == VKAttachmentTypeWall) {
                return @"[Запись на стене]";
            } else if (first.type == VKAttachmentTypeLink) {
                return [NSString stringWithFormat:@"🔗 %@", first.linkTitle ?: @"Ссылка"];
            } else if (first.type == VKAttachmentTypePoll) {
                return [NSString stringWithFormat:@"📊 %@", first.pollQuestion ?: @"Опрос"];
            }
        }
        return @"[Вложение]";
    }
    return @"";
}

- (NSString *)textForMessage:(VKMessage *)msg {
    if (!msg) return @"";
    return msg.text ?: @"";
}

- (NSArray<VKAttachment *> *)photoAttachmentsInMessage:(VKMessage *)msg {
    NSMutableArray *arr = [NSMutableArray array];
    for (VKAttachment *att in msg.attachments) {
        if ([att isKindOfClass:[VKAttachment class]] && att.type == VKAttachmentTypePhoto) {
            [arr addObject:att];
        }
    }
    return arr;
}

- (CGFloat)heightForAttachmentsInMessage:(VKMessage *)msg contentWidth:(CGFloat)contentWidth {
    if (!msg || msg.attachments.count == 0) return 0.0;
    
    CGFloat totalH = 0.0;
    NSArray *photos = [self photoAttachmentsInMessage:msg];
    if (photos.count == 1) {
        VKAttachment *p = photos[0];
        CGFloat pH = (p.photoWidth > 0 && p.photoHeight > 0) ? (contentWidth * p.photoHeight / p.photoWidth) : 140.0;
        pH = MAX(90.0, MIN(160.0, pH));
        totalH += pH;
    } else if (photos.count == 2) {
        totalH += 110.0;
    } else if (photos.count == 3) {
        totalH += 194.0;
    } else if (photos.count >= 4) {
        totalH += 176.0;
    }
    
    for (VKAttachment *att in msg.attachments) {
        if (![att isKindOfClass:[VKAttachment class]]) continue;
        if (att.type == VKAttachmentTypePhoto || att.type == VKAttachmentTypeSticker) continue;
        
        if (att.type == VKAttachmentTypeVideo) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 130.0;
        } else if (att.type == VKAttachmentTypeGif) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 130.0;
        } else if (att.type == VKAttachmentTypeDoc) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 46.0;
        } else if (att.type == VKAttachmentTypeWall) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 68.0;
        } else if (att.type == VKAttachmentTypeAudio) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 42.0;
        } else if (att.type == VKAttachmentTypeLink) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + 48.0;
        } else if (att.type == VKAttachmentTypePoll) {
            totalH += (totalH > 0 ? 6.0 : 0.0) + (34.0 + att.pollOptions.count * 30.0 + 20.0);
        }
    }
    return totalH;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.messages.count) return 44.0;
    VKMessage *msg = self.messages[indexPath.row];
    CGFloat width = tableView.bounds.size.width;
    BOOL isModern = [[VKThemeManager sharedManager] isModern];
    
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
    BOOL joinsPrevious = [self isMessageAtIndex:indexPath.row joinedWithIndex:indexPath.row - 1];
    BOOL joinsNext = [self isMessageAtIndex:indexPath.row joinedWithIndex:indexPath.row + 1];
    
    // Имя автора в беседах показывается только у первого сообщения серии
    BOOL showAuthor = isGroupChat && !msg.isOutgoing && !joinsPrevious;
    CGFloat authorHeaderH = showAuthor ? 18.0 : 0.0;
    
    CGFloat selOffset = self.isSelectionMode ? 32.0 : 0.0;
    CGFloat maxTextW = width - (isGroupChat && !msg.isOutgoing ? 46.0 : 10.0) - 50.0 - selOffset;
    CGFloat attContentW = MAX(200.0, maxTextW - 20.0);
    CGFloat attH = [self heightForAttachmentsInMessage:msg contentWidth:attContentW];
    BOOL hasReply = (msg.replyMessage != nil || (msg.fwdMessages && msg.fwdMessages.count > 0));
    CGFloat replyExtraH = hasReply ? 34.0 : 0.0;
    CGFloat extraH = (attH > 0 ? attH + 8.0 : 0.0) + authorHeaderH + replyExtraH;
    
    NSString *displayText = [self textForMessage:msg];
    CGFloat textH = 0.0;
    if (displayText.length > 0) {
        CGSize size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(maxTextW, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
        textH = ceilf(size.height);
    }
    
    CGFloat bubbleH = textH + 22.0 + extraH;
    CGFloat gap = (isModern && joinsNext) ? 3.0 : 6.0;
    return MAX(38.0 + extraH, bubbleH + gap);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKChatMessageCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        
        // Чекбокс режима выбора (мультивыбор)
        UIButton *checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
        checkbox.tag = 1020;
        checkbox.userInteractionEnabled = NO;
        checkbox.hidden = YES;
        [cell.contentView addSubview:checkbox];
        
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
        
        // Контейнер вложений
        UIView *attachmentsView = [[UIView alloc] initWithFrame:CGRectZero];
        attachmentsView.tag = 1004;
        attachmentsView.clipsToBounds = YES;
        attachmentsView.userInteractionEnabled = YES;
        attachmentsView.hidden = YES;
        [bubble addSubview:attachmentsView];
        
        // Индикатор Swipe-to-Reply
        UIView *replyIndicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 30.0, 30.0)];
        replyIndicator.tag = 1030;
        replyIndicator.backgroundColor = [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:0.9];
        replyIndicator.layer.cornerRadius = 15.0;
        replyIndicator.clipsToBounds = YES;
        replyIndicator.alpha = 0.0;
        replyIndicator.transform = CGAffineTransformMakeScale(0.5, 0.5);
        UILabel *arrowLbl = [[UILabel alloc] initWithFrame:replyIndicator.bounds];
        arrowLbl.text = @"↩";
        arrowLbl.textColor = [UIColor whiteColor];
        arrowLbl.font = [UIFont boldSystemFontOfSize:17.0];
        arrowLbl.textAlignment = NSTextAlignmentCenter;
        [replyIndicator addSubview:arrowLbl];
        [cell.contentView addSubview:replyIndicator];
        
        // Цитата ответа / пересылки
        UIView *quoteView = [[UIView alloc] initWithFrame:CGRectZero];
        quoteView.tag = 1011;
        quoteView.clipsToBounds = YES;
        quoteView.hidden = YES;
        [bubble addSubview:quoteView];
        
        UIView *quoteBar = [[UIView alloc] initWithFrame:CGRectMake(0, 1, 2.5, 28)];
        quoteBar.tag = 1012;
        quoteBar.layer.cornerRadius = 1.25;
        quoteBar.clipsToBounds = YES;
        [quoteView addSubview:quoteBar];
        
        UILabel *quoteAuthorLabel = [[UILabel alloc] initWithFrame:CGRectMake(7, 0, 180, 14)];
        quoteAuthorLabel.tag = 1013;
        quoteAuthorLabel.font = [UIFont boldSystemFontOfSize:11.5];
        quoteAuthorLabel.backgroundColor = [UIColor clearColor];
        [quoteView addSubview:quoteAuthorLabel];
        
        UILabel *quoteTextLabel = [[UILabel alloc] initWithFrame:CGRectMake(7, 14, 180, 14)];
        quoteTextLabel.tag = 1014;
        quoteTextLabel.font = [UIFont systemFontOfSize:11];
        quoteTextLabel.backgroundColor = [UIColor clearColor];
        [quoteView addSubview:quoteTextLabel];
        
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
    UIView *attachmentsView = [bubble viewWithTag:1004];
    UIView *replyIndicator = [cell.contentView viewWithTag:1030];
    UIView *quoteView = [bubble viewWithTag:1011];
    UIView *quoteBar = [quoteView viewWithTag:1012];
    UILabel *quoteAuthorLabel = (UILabel *)[quoteView viewWithTag:1013];
    UILabel *quoteTextLabel = (UILabel *)[quoteView viewWithTag:1014];
    UILabel *textLabel = (UILabel *)[bubble viewWithTag:1002];
    UILabel *timeLabel = (UILabel *)[bubble viewWithTag:1003];
    
    UIButton *checkbox = (UIButton *)[cell.contentView viewWithTag:1020];
    if (!checkbox) {
        checkbox = [UIButton buttonWithType:UIButtonTypeCustom];
        checkbox.tag = 1020;
        checkbox.userInteractionEnabled = NO;
        checkbox.hidden = YES;
        [cell.contentView addSubview:checkbox];
    }
    
    CGFloat width = tableView.bounds.size.width;
    BOOL isModern = [[VKThemeManager sharedManager] isModern];
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isGroupChat = (self.peerId > 2000000000);
    
    BOOL joinsPrevious = [self isMessageAtIndex:indexPath.row joinedWithIndex:indexPath.row - 1];
    BOOL joinsNext = [self isMessageAtIndex:indexPath.row joinedWithIndex:indexPath.row + 1];
    
    // 1. Сервисное сообщение
    if ([msg isServiceAction]) {
        checkbox.hidden = YES;
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
        
        if (isModern) {
            servicePill.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.06];
            servicePill.layer.cornerRadius = pillH / 2.0;
            serviceLabel.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
            serviceLabel.font = [UIFont systemFontOfSize:12];
        } else {
            servicePill.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.08];
            servicePill.layer.cornerRadius = MIN(12.0, pillH / 2.0);
            serviceLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
            serviceLabel.font = [UIFont systemFontOfSize:12];
        }
        
        serviceLabel.frame = CGRectMake(9.0, 4.0, ceilf(sz.width), ceilf(sz.height));
        serviceLabel.text = svcText;
        return cell;
    }
    
    CGFloat selOffset = self.isSelectionMode ? 32.0 : 0.0;
    BOOL isRowSelected = [self.selectedMessageIds containsObject:@(msg.messageId ?: msg.vkID)];
    if (self.isSelectionMode) {
        checkbox.hidden = NO;
        [checkbox setImage:VKCheckboxImage(isRowSelected) forState:UIControlStateNormal];
        bubble.userInteractionEnabled = NO;
        attachmentsView.userInteractionEnabled = NO;
        stickerIV.userInteractionEnabled = NO;
        authorNameLabel.userInteractionEnabled = NO;
        authorAvatar.userInteractionEnabled = NO;
    } else {
        checkbox.hidden = YES;
        bubble.userInteractionEnabled = YES;
        attachmentsView.userInteractionEnabled = YES;
        stickerIV.userInteractionEnabled = YES;
        authorNameLabel.userInteractionEnabled = YES;
        authorAvatar.userInteractionEnabled = YES;
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
                authorAvatar.frame = CGRectMake(8.0 + selOffset, 138.0 - 36.0, 32, 32);
                authorAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
                VKUser *author = [self senderUserForMessage:msg];
                authorAvatar.user = author;
                [self loadAvatarForButton:authorAvatar url:author.avatarURL];
                stX = 46.0 + selOffset;
            } else {
                authorAvatar.hidden = YES;
                stX = 12.0 + selOffset;
            }
        }
        stickerIV.frame = CGRectMake(stX, 4.0, stSize, stSize);
        if (self.isSelectionMode) {
            checkbox.frame = CGRectMake(8.0, 4.0 + (stSize - 22.0) / 2.0, 22.0, 22.0);
        }
        
        NSString *statusText = msg.isOutgoing ? [NSString stringWithFormat:@"%@%@", msg.timeString ?: @"", (msg.isRead ? @" ✓✓" : @" ✓")] : (msg.timeString ?: @"");
        stickerTimeLabel.text = statusText;
        stickerTimeLabel.frame = CGRectMake(stX + stSize - 48.0, 4.0 + stSize - 16.0, 44.0, 14.0);
        return cell;
    }
    
    // 3. Обычное сообщение / вложения / ответ
    servicePill.hidden = YES;
    stickerIV.hidden = YES;
    stickerTimeLabel.hidden = YES;
    bubble.hidden = NO;
    
    BOOL hasPhoto = (msg.attachments.count > 0 && [msg.attachments[0] isKindOfClass:[VKAttachment class]] && ((VKAttachment *)msg.attachments[0]).type == VKAttachmentTypePhoto);
    VKAttachment *photoAtt = hasPhoto ? (VKAttachment *)msg.attachments[0] : nil;
    
    // Имя автора показывается только у первого сообщения подряд в беседе
    BOOL showAuthor = (isGroupChat && !msg.isOutgoing && !joinsPrevious);
    VKUser *author = (isGroupChat && !msg.isOutgoing) ? [self senderUserForMessage:msg] : nil;
    NSString *authorNameStr = author ? author.displayName : (msg.fromId != 0 ? [NSString stringWithFormat:@"id%ld", (long)msg.fromId] : @"");
    
    BOOL hasReply = (msg.replyMessage != nil || (msg.fwdMessages && msg.fwdMessages.count > 0));
    if (hasReply) {
        quoteView.hidden = NO;
        if (msg.replyMessage) {
            VKUser *ru = [self senderUserForMessage:msg.replyMessage];
            NSString *authorName = ru ? ru.displayName : (msg.replyMessage.fromId > 0 ? [NSString stringWithFormat:@"id%ld", (long)msg.replyMessage.fromId] : @"Сообщение");
            quoteAuthorLabel.text = authorName;
            quoteTextLabel.text = [self previewTextForMessage:msg.replyMessage];
        } else if (msg.fwdMessages.count > 0) {
            VKMessage *fwd = msg.fwdMessages[0];
            VKUser *fu = [self senderUserForMessage:fwd];
            NSString *fwdAuthor = fu ? fu.displayName : (fwd.fromId > 0 ? [NSString stringWithFormat:@"id%ld", (long)fwd.fromId] : @"Сообщение");
            quoteAuthorLabel.text = msg.fwdMessages.count > 1 ? [NSString stringWithFormat:@"%@ (+%lu)", fwdAuthor, (unsigned long)(msg.fwdMessages.count - 1)] : fwdAuthor;
            quoteTextLabel.text = [self previewTextForMessage:fwd];
        }
    } else {
        quoteView.hidden = YES;
    }
    
    NSString *displayText = [self textForMessage:msg];
    textLabel.text = displayText;
    
    CGFloat maxTextW = width - (isGroupChat && !msg.isOutgoing ? 46.0 : 10.0) - 50.0 - selOffset;
    CGSize size = CGSizeZero;
    if (displayText.length > 0) {
        size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(maxTextW, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    }
    
    CGFloat attContentW = MAX(200.0, maxTextW - 20.0);
    CGFloat attH = [self heightForAttachmentsInMessage:msg contentWidth:attContentW];
    
    // Расчет ширины пузыря
    CGFloat bubbleWidth = MAX(86.0, ceilf(size.width) + 28.0);
    if (attH > 0) {
        bubbleWidth = MAX(bubbleWidth, 220.0);
    }
    if (hasReply) {
        bubbleWidth = MAX(bubbleWidth, 190.0);
    }
    
    // Если исходящее однострочное: обеспечиваем место для времени и галочек прочтения
    if (msg.isOutgoing && size.height <= 22.0 && attH == 0) {
        bubbleWidth = MAX(bubbleWidth, ceilf(size.width) + 72.0);
    }
    
    // Учитываем имя автора в беседах с запасом
    if (showAuthor && authorNameStr.length > 0) {
        CGSize authorNameSz = [authorNameStr sizeWithFont:[UIFont boldSystemFontOfSize:12.5]];
        bubbleWidth = MAX(bubbleWidth, ceilf(authorNameSz.width) + 38.0);
    }
    bubbleWidth = MIN(bubbleWidth, maxTextW + 36.0);
    bubbleWidth = MIN(bubbleWidth, width - 20.0 - (self.isSelectionMode ? 36.0 : 0.0));
    
    CGFloat authorHeaderH = showAuthor ? 18.0 : 0.0;
    CGFloat replyExtraH = hasReply ? 34.0 : 0.0;
    CGFloat textH = displayText.length > 0 ? ceilf(size.height) : 0.0;
    CGFloat bubbleHeight = textH + 22.0 + (attH > 0 ? attH + 8.0 : 0.0) + authorHeaderH + replyExtraH;
    
    if (msg.isOutgoing) {
        authorAvatar.hidden = YES;
        authorNameLabel.hidden = YES;
        bubble.frame = CGRectMake(width - bubbleWidth - 10.0, 2.0, bubbleWidth, bubbleHeight);
        if (self.isSelectionMode) {
            checkbox.frame = CGRectMake(8.0, 2.0 + (bubbleHeight - 22.0) / 2.0, 22.0, 22.0);
        }
        
        if (isModern) {
            bubble.image = nil;
            bubble.layer.cornerRadius = 0.0;
            bubble.clipsToBounds = YES;
            
            CGFloat tl = 18.0;
            CGFloat bl = 18.0;
            CGFloat tr = joinsPrevious ? 6.0 : 18.0;
            CGFloat br = joinsNext ? 6.0 : 18.0;
            
            CAShapeLayer *maskLayer = (CAShapeLayer *)bubble.layer.mask;
            if (![maskLayer isKindOfClass:[CAShapeLayer class]]) {
                maskLayer = [CAShapeLayer layer];
                bubble.layer.mask = maskLayer;
            }
            maskLayer.frame = CGRectMake(0, 0, bubbleWidth, bubbleHeight);
            maskLayer.path = VKMakeBubblePath(CGRectMake(0, 0, bubbleWidth, bubbleHeight), tl, tr, bl, br).CGPath;
            
            bubble.backgroundColor = [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0];
            textLabel.textColor = [UIColor whiteColor];
            timeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        } else {
            bubble.layer.mask = nil;
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
        }
        
        CGFloat topY = 6.0;
        if (hasReply) {
            if (isModern) {
                quoteBar.backgroundColor = [UIColor whiteColor];
                quoteAuthorLabel.textColor = [UIColor whiteColor];
                quoteTextLabel.textColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            } else {
                quoteBar.backgroundColor = isSkeuomorph ? [UIColor whiteColor] : [UIColor colorWithRed:80.0/255.0 green:140.0/255.0 blue:210.0/255.0 alpha:1.0];
                quoteAuthorLabel.textColor = isSkeuomorph ? [UIColor whiteColor] : [UIColor colorWithRed:80.0/255.0 green:140.0/255.0 blue:210.0/255.0 alpha:1.0];
                quoteTextLabel.textColor = isSkeuomorph ? [UIColor colorWithWhite:0.9 alpha:1.0] : [UIColor colorWithWhite:0.35 alpha:1.0];
            }
            quoteView.frame = CGRectMake(12, topY, bubbleWidth - 24, 30);
            quoteAuthorLabel.frame = CGRectMake(7, 0, bubbleWidth - 32, 14);
            quoteTextLabel.frame = CGRectMake(7, 14, bubbleWidth - 32, 14);
            topY += 34.0;
        }
        
        if (attH > 0) {
            attachmentsView.hidden = NO;
            CGFloat attW = bubbleWidth - 20.0;
            attachmentsView.frame = CGRectMake(10.0, topY, attW, attH);
            [self configureAttachmentsView:attachmentsView forMessage:msg width:attW isOutgoing:YES];
            topY += attH + 6.0;
        } else {
            attachmentsView.hidden = YES;
            [attachmentsView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
        
        if (displayText.length > 0) {
            textLabel.hidden = NO;
            textLabel.frame = CGRectMake(12, topY, ceilf(size.width), ceilf(size.height));
        } else {
            textLabel.hidden = YES;
            textLabel.frame = CGRectZero;
        }
        
        // Время и статус прочтения (достаточная ширина 54pt для «16:18 ✓✓»)
        timeLabel.text = [NSString stringWithFormat:@"%@ %@", msg.timeString ?: @"", (msg.isRead ? @"✓✓" : @"✓")];
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.frame = CGRectMake(bubbleWidth - 60, bubbleHeight - 16, 54, 13);
        
    } else {
        // Входящие сообщения
        CGFloat bubbleX = 10.0 + selOffset;
        if (isGroupChat) {
            if (!joinsNext) {
                authorAvatar.hidden = NO;
                CGFloat avatarY = bubbleHeight + 2.0 - 32.0;
                authorAvatar.frame = CGRectMake(8.0 + selOffset, avatarY, 32.0, 32.0);
                authorAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
                VKUser *author = [self senderUserForMessage:msg];
                authorAvatar.user = author;
                [self loadAvatarForButton:authorAvatar url:author.avatarURL];
            } else {
                authorAvatar.hidden = YES;
            }
            bubbleX = 46.0 + selOffset;
        } else {
            authorAvatar.hidden = YES;
        }
        
        bubble.frame = CGRectMake(bubbleX, 2.0, bubbleWidth, bubbleHeight);
        if (self.isSelectionMode) {
            checkbox.frame = CGRectMake(8.0, 2.0 + (bubbleHeight - 22.0) / 2.0, 22.0, 22.0);
        }
        
        if (isModern) {
            bubble.image = nil;
            bubble.layer.cornerRadius = 0.0;
            bubble.clipsToBounds = YES;
            
            CGFloat tr = 18.0;
            CGFloat br = 18.0;
            CGFloat tl = joinsPrevious ? 6.0 : 18.0;
            CGFloat bl = joinsNext ? 6.0 : 18.0;
            
            CAShapeLayer *maskLayer = (CAShapeLayer *)bubble.layer.mask;
            if (![maskLayer isKindOfClass:[CAShapeLayer class]]) {
                maskLayer = [CAShapeLayer layer];
                bubble.layer.mask = maskLayer;
            }
            maskLayer.frame = CGRectMake(0, 0, bubbleWidth, bubbleHeight);
            maskLayer.path = VKMakeBubblePath(CGRectMake(0, 0, bubbleWidth, bubbleHeight), tl, tr, bl, br).CGPath;
            
            bubble.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:242.0/255.0 blue:245.0/255.0 alpha:1.0];
            textLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
            timeLabel.textColor = [UIColor colorWithRed:140.0/255.0 green:145.0/255.0 blue:155.0/255.0 alpha:1.0];
        } else {
            bubble.layer.mask = nil;
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
        }
        
        CGFloat topY = 6.0;
        if (showAuthor) {
            authorNameLabel.hidden = NO;
            authorNameLabel.frame = CGRectMake(16, topY, bubbleWidth - 32, 16);
            authorNameLabel.text = authorNameStr;
            authorNameLabel.textColor = isModern ? [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithRed:60.0/255.0 green:112.0/255.0 blue:164.0/255.0 alpha:1.0];
            if (authorNameLabel.gestureRecognizers.count > 0 && [authorNameLabel.gestureRecognizers[0] isKindOfClass:[VKChatAuthorTapGesture class]]) {
                ((VKChatAuthorTapGesture *)authorNameLabel.gestureRecognizers[0]).user = author;
            }
            topY += 18.0;
        } else {
            authorNameLabel.hidden = YES;
        }
        
        if (hasReply) {
            UIColor *quoteColor = isModern ? [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0] : [[VKThemeManager sharedManager] accentColor];
            quoteBar.backgroundColor = quoteColor;
            quoteAuthorLabel.textColor = quoteColor;
            quoteTextLabel.textColor = [UIColor colorWithWhite:0.35 alpha:1.0];
            quoteView.frame = CGRectMake(14, topY, bubbleWidth - 28, 30);
            quoteAuthorLabel.frame = CGRectMake(7, 0, bubbleWidth - 36, 14);
            quoteTextLabel.frame = CGRectMake(7, 14, bubbleWidth - 36, 14);
            topY += 34.0;
        }
        
        if (attH > 0) {
            attachmentsView.hidden = NO;
            CGFloat attW = bubbleWidth - 22.0;
            attachmentsView.frame = CGRectMake(12.0, topY, attW, attH);
            [self configureAttachmentsView:attachmentsView forMessage:msg width:attW isOutgoing:NO];
            topY += attH + 6.0;
        } else {
            attachmentsView.hidden = YES;
            [attachmentsView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
        
        if (displayText.length > 0) {
            textLabel.hidden = NO;
            textLabel.frame = CGRectMake(16, topY, ceilf(size.width), ceilf(size.height));
        } else {
            textLabel.hidden = YES;
            textLabel.frame = CGRectZero;
        }
        
        timeLabel.text = msg.timeString ?: @"";
        timeLabel.textAlignment = NSTextAlignmentRight;
        timeLabel.frame = CGRectMake(bubbleWidth - 46, bubbleHeight - 16, 38, 12);
    }
    
    // Настраиваем жест Swipe-to-Reply
    VKChatSwipeReplyGesture *swipe = nil;
    for (UIGestureRecognizer *gr in cell.gestureRecognizers) {
        if ([gr isKindOfClass:[VKChatSwipeReplyGesture class]]) {
            swipe = (VKChatSwipeReplyGesture *)gr;
            break;
        }
    }
    if (!swipe) {
        swipe = [[VKChatSwipeReplyGesture alloc] initWithTarget:self action:@selector(handleCellPan:)];
        swipe.delegate = self;
        [cell addGestureRecognizer:swipe];
    }
    swipe.message = msg;
    swipe.bubbleView = bubble;
    swipe.replyIndicator = replyIndicator;
    bubble.transform = CGAffineTransformIdentity;
    replyIndicator.alpha = 0.0;
    replyIndicator.center = CGPointMake(bubble.frame.origin.x + bubble.frame.size.width + 20.0, bubble.frame.origin.y + bubble.frame.size.height / 2.0);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.messages.count) return;
    
    VKMessage *msg = self.messages[indexPath.row];
    
    if (self.isSelectionMode) {
        if ([msg isServiceAction]) return;
        NSNumber *mid = @(msg.messageId ?: msg.vkID);
        if ([self.selectedMessageIds containsObject:mid]) {
            [self.selectedMessageIds removeObject:mid];
        } else {
            [self.selectedMessageIds addObject:mid];
        }
        [self updateSelectionUI];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        return;
    }
    
    // 1. Если сообщение содержит ответ — скроллим к исходному сообщению при наличии в истории
    if (msg.replyMessage) {
        NSInteger targetMid = msg.replyMessage.messageId;
        for (NSInteger i = 0; i < self.messages.count; i++) {
            VKMessage *m = self.messages[i];
            if (m.messageId == targetMid) {
                NSIndexPath *targetPath = [NSIndexPath indexPathForRow:i inSection:0];
                [self.tableView scrollToRowAtIndexPath:targetPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
                return;
            }
        }
    }
    
    // 2. Взаимодействие со вложениями
    for (VKAttachment *att in msg.attachments) {
        if (![att isKindOfClass:[VKAttachment class]]) continue;
        if (att.type == VKAttachmentTypeWall && att.wallPostId != 0) {
            VKPost *dummyPost = [[VKPost alloc] init];
            dummyPost.vkID = att.wallPostId;
            dummyPost.ownerID = att.wallOwnerId;
            dummyPost.text = att.wallText;
            VKPostDetailViewController *postVC = [[VKPostDetailViewController alloc] initWithPost:dummyPost];
            [self.navigationController pushViewController:postVC animated:YES];
            return;
        } else if (att.type == VKAttachmentTypeAudio && (att.audioURL.length > 0 || att.audioId != 0)) {
            VKAudioTrack *track = [[VKAudioTrack alloc] init];
            track.audioId = att.audioId;
            track.trackId = att.audioId;
            track.ownerId = att.audioOwnerId;
            track.artist = att.audioArtist ?: @"";
            track.title = att.audioTitle ?: @"";
            track.streamURL = att.audioURL;
            track.url = att.audioURL;
            [[VKAudioPlayer sharedPlayer] playTrack:track];
            VKAudioPlayerViewController *pvc = [[VKAudioPlayerViewController alloc] init];
            [self presentViewController:pvc animated:YES completion:nil];
            return;
        } else if (att.type == VKAttachmentTypeLink && att.linkURL.length > 0) {
            NSURL *u = [NSURL URLWithString:att.linkURL];
            if (u) [[UIApplication sharedApplication] openURL:u];
            return;
        } else if (att.type == VKAttachmentTypeDoc && att.docURL.length > 0) {
            NSURL *u = [NSURL URLWithString:att.docURL];
            if (u) [[UIApplication sharedApplication] openURL:u];
            return;
        } else if (att.type == VKAttachmentTypeVideo) {
            VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:att];
            [self presentViewController:player animated:YES completion:nil];
            return;
        } else if (att.type == VKAttachmentTypeGif) {
            VKGifViewerViewController *viewer = [[VKGifViewerViewController alloc] initWithAttachment:att];
            [self presentViewController:viewer animated:YES completion:nil];
            return;
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

#pragma mark - Attachments Configuration & Taps

- (void)configureAttachmentsView:(UIView *)container forMessage:(VKMessage *)msg width:(CGFloat)width isOutgoing:(BOOL)isOutgoing {
    [container.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    if (!msg || msg.attachments.count == 0) return;
    
    CGFloat curY = 0.0;
    NSArray *photos = [self photoAttachmentsInMessage:msg];
    
    // 1. Сетка фотографий
    if (photos.count == 1) {
        VKAttachment *p = photos[0];
        CGFloat pH = (p.photoWidth > 0 && p.photoHeight > 0) ? (width * p.photoHeight / p.photoWidth) : 140.0;
        pH = MAX(90.0, MIN(160.0, pH));
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, curY, width, pH)];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 8.0;
        iv.userInteractionEnabled = YES;
        [container addSubview:iv];
        
        VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatPhotoAttachmentTapped:)];
        tap.attachments = photos;
        tap.initialIndex = 0;
        [iv addGestureRecognizer:tap];
        
        if (p.photoURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:p.photoURL completion:^(UIImage *img) {
                if (img) iv.image = img;
            }];
        }
        curY += pH + 6.0;
    } else if (photos.count == 2) {
        CGFloat colW = (width - 4.0) / 2.0;
        CGFloat pH = 110.0;
        for (NSInteger i = 0; i < 2; i++) {
            VKAttachment *p = photos[i];
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(i * (colW + 4.0), curY, colW, pH)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.layer.cornerRadius = 6.0;
            iv.userInteractionEnabled = YES;
            [container addSubview:iv];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatPhotoAttachmentTapped:)];
            tap.attachments = photos;
            tap.initialIndex = i;
            [iv addGestureRecognizer:tap];
            
            if (p.photoURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:p.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
            }
        }
        curY += pH + 6.0;
    } else if (photos.count == 3) {
        VKAttachment *p0 = photos[0];
        UIImageView *iv0 = [[UIImageView alloc] initWithFrame:CGRectMake(0, curY, width, 110.0)];
        iv0.contentMode = UIViewContentModeScaleAspectFill;
        iv0.clipsToBounds = YES;
        iv0.layer.cornerRadius = 6.0;
        iv0.userInteractionEnabled = YES;
        [container addSubview:iv0];
        VKChatAttachmentTapGesture *tap0 = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatPhotoAttachmentTapped:)];
        tap0.attachments = photos;
        tap0.initialIndex = 0;
        [iv0 addGestureRecognizer:tap0];
        if (p0.photoURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:p0.photoURL completion:^(UIImage *img) {
                if (img) iv0.image = img;
            }];
        }
        curY += 114.0;
        
        CGFloat colW = (width - 4.0) / 2.0;
        for (NSInteger i = 1; i < 3; i++) {
            VKAttachment *p = photos[i];
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake((i - 1) * (colW + 4.0), curY, colW, 80.0)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.layer.cornerRadius = 6.0;
            iv.userInteractionEnabled = YES;
            [container addSubview:iv];
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatPhotoAttachmentTapped:)];
            tap.attachments = photos;
            tap.initialIndex = i;
            [iv addGestureRecognizer:tap];
            if (p.photoURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:p.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
            }
        }
        curY += 80.0 + 6.0;
    } else if (photos.count >= 4) {
        CGFloat itemW = (width - 4.0) / 2.0;
        CGFloat itemH = 86.0;
        for (NSInteger i = 0; i < 4; i++) {
            VKAttachment *p = photos[i];
            CGFloat rX = (i % 2) * (itemW + 4.0);
            CGFloat rY = curY + (i / 2) * (itemH + 4.0);
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(rX, rY, itemW, itemH)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.layer.cornerRadius = 6.0;
            iv.userInteractionEnabled = YES;
            [container addSubview:iv];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatPhotoAttachmentTapped:)];
            tap.attachments = photos;
            tap.initialIndex = i;
            [iv addGestureRecognizer:tap];
            
            if (p.photoURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:p.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
            }
            
            if (i == 3 && photos.count > 4) {
                UIView *ov = [[UIView alloc] initWithFrame:iv.bounds];
                ov.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
                UILabel *cLbl = [[UILabel alloc] initWithFrame:ov.bounds];
                cLbl.text = [NSString stringWithFormat:@"+%lu", (unsigned long)(photos.count - 3)];
                cLbl.textColor = [UIColor whiteColor];
                cLbl.font = [UIFont boldSystemFontOfSize:19.0];
                cLbl.textAlignment = NSTextAlignmentCenter;
                [ov addSubview:cLbl];
                [iv addSubview:ov];
            }
        }
        curY += (itemH * 2.0 + 4.0) + 6.0;
    }
    
    // 2. Другие типы вложений
    for (VKAttachment *att in msg.attachments) {
        if (![att isKindOfClass:[VKAttachment class]]) continue;
        if (att.type == VKAttachmentTypePhoto || att.type == VKAttachmentTypeSticker) continue;
        
        if (att.type == VKAttachmentTypeVideo) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, curY, width, 130.0)];
            card.clipsToBounds = YES;
            card.layer.cornerRadius = 8.0;
            card.backgroundColor = [UIColor blackColor];
            
            UIImageView *tiv = [[UIImageView alloc] initWithFrame:card.bounds];
            tiv.contentMode = UIViewContentModeScaleAspectFill;
            tiv.clipsToBounds = YES;
            [card addSubview:tiv];
            if (att.videoImageURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.videoImageURL completion:^(UIImage *img) {
                    if (img) tiv.image = img;
                }];
            }
            
            UIView *dark = [[UIView alloc] initWithFrame:card.bounds];
            dark.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
            [card addSubview:dark];
            
            UIView *playCirc = [[UIView alloc] initWithFrame:CGRectMake((width - 40.0)/2.0, (130.0 - 40.0)/2.0, 40.0, 40.0)];
            playCirc.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
            playCirc.layer.cornerRadius = 20.0;
            playCirc.clipsToBounds = YES;
            UILabel *pArrow = [[UILabel alloc] initWithFrame:CGRectMake(3, 0, 40, 40)];
            pArrow.text = @"▶";
            pArrow.textColor = [UIColor whiteColor];
            pArrow.font = [UIFont boldSystemFontOfSize:17];
            pArrow.textAlignment = NSTextAlignmentCenter;
            [playCirc addSubview:pArrow];
            [card addSubview:playCirc];
            
            if (att.videoDuration.length > 0) {
                UILabel *dur = [[UILabel alloc] initWithFrame:CGRectMake(width - 56, 130 - 24, 48, 16)];
                dur.text = att.videoDuration;
                dur.textColor = [UIColor whiteColor];
                dur.font = [UIFont boldSystemFontOfSize:10.5];
                dur.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
                dur.textAlignment = NSTextAlignmentCenter;
                dur.layer.cornerRadius = 4.0;
                dur.clipsToBounds = YES;
                [card addSubview:dur];
            }
            
            UIView *tBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 26)];
            tBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 3, width - 16, 20)];
            tLbl.text = att.videoTitle ?: @"Видеозапись";
            tLbl.textColor = [UIColor whiteColor];
            tLbl.font = [UIFont boldSystemFontOfSize:11.5];
            [tBar addSubview:tLbl];
            [card addSubview:tBar];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatVideoAttachmentTapped:)];
            tap.attachment = att;
            [card addGestureRecognizer:tap];
            [container addSubview:card];
            curY += 130.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeGif) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, curY, width, 130.0)];
            card.clipsToBounds = YES;
            card.layer.cornerRadius = 8.0;
            card.backgroundColor = [UIColor blackColor];
            
            UIImageView *tiv = [[UIImageView alloc] initWithFrame:card.bounds];
            tiv.contentMode = UIViewContentModeScaleAspectFill;
            tiv.clipsToBounds = YES;
            [card addSubview:tiv];
            if (att.gifPreviewURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.gifPreviewURL completion:^(UIImage *img) {
                    if (img) tiv.image = img;
                }];
            }
            
            UILabel *gifBadge = [[UILabel alloc] initWithFrame:CGRectMake((width - 50.0)/2.0, (130.0 - 28.0)/2.0, 50.0, 28.0)];
            gifBadge.text = @"GIF";
            gifBadge.textColor = [UIColor whiteColor];
            gifBadge.font = [UIFont boldSystemFontOfSize:14.0];
            gifBadge.textAlignment = NSTextAlignmentCenter;
            gifBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
            gifBadge.layer.cornerRadius = 14.0;
            gifBadge.clipsToBounds = YES;
            [card addSubview:gifBadge];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatGifAttachmentTapped:)];
            tap.attachment = att;
            [card addGestureRecognizer:tap];
            [container addSubview:card];
            curY += 130.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeDoc) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, curY, width, 46.0)];
            card.layer.cornerRadius = 7.0;
            card.clipsToBounds = YES;
            card.backgroundColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.22] : [UIColor colorWithWhite:0.0 alpha:0.06];
            
            UIView *iconBox = [[UIView alloc] initWithFrame:CGRectMake(6, 6, 34, 34)];
            iconBox.backgroundColor = [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:0.85];
            iconBox.layer.cornerRadius = 5.0;
            iconBox.clipsToBounds = YES;
            UILabel *extLbl = [[UILabel alloc] initWithFrame:iconBox.bounds];
            extLbl.text = att.docExt.length > 0 ? (att.docExt.length > 4 ? [att.docExt substringToIndex:4] : att.docExt) : @"DOC";
            extLbl.textColor = [UIColor whiteColor];
            extLbl.font = [UIFont boldSystemFontOfSize:9.5];
            extLbl.textAlignment = NSTextAlignmentCenter;
            [iconBox addSubview:extLbl];
            [card addSubview:iconBox];
            
            UILabel *docTitle = [[UILabel alloc] initWithFrame:CGRectMake(46, 6, width - 52, 18)];
            docTitle.text = att.docTitle ?: @"Документ";
            docTitle.font = [UIFont boldSystemFontOfSize:12.0];
            docTitle.textColor = isOutgoing ? [UIColor whiteColor] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
            [card addSubview:docTitle];
            
            UILabel *docSub = [[UILabel alloc] initWithFrame:CGRectMake(46, 24, width - 52, 16)];
            docSub.text = att.docSize.length > 0 ? att.docSize : @"Файл";
            docSub.font = [UIFont systemFontOfSize:10.5];
            docSub.textColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.8] : [UIColor colorWithWhite:0.5 alpha:1.0];
            [card addSubview:docSub];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatDocAttachmentTapped:)];
            tap.attachment = att;
            [card addGestureRecognizer:tap];
            [container addSubview:card];
            curY += 46.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeWall) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, curY, width, 68.0)];
            card.layer.cornerRadius = 6.0;
            card.clipsToBounds = YES;
            card.backgroundColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.18] : [UIColor colorWithWhite:0.0 alpha:0.05];
            
            UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(4, 6, 3, 56)];
            bar.backgroundColor = isOutgoing ? [UIColor whiteColor] : [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0];
            bar.layer.cornerRadius = 1.5;
            [card addSubview:bar];
            
            UILabel *wHead = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, width - 18, 16)];
            wHead.text = @"📋 Запись на стене";
            wHead.font = [UIFont boldSystemFontOfSize:11.5];
            wHead.textColor = isOutgoing ? [UIColor whiteColor] : [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0];
            [card addSubview:wHead];
            
            UILabel *wBody = [[UILabel alloc] initWithFrame:CGRectMake(12, 24, width - 18, 38)];
            wBody.text = att.wallText.length > 0 ? att.wallText : @"(без текста)";
            wBody.font = [UIFont systemFontOfSize:11.0];
            wBody.numberOfLines = 2;
            wBody.textColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.9] : [UIColor colorWithWhite:0.3 alpha:1.0];
            [card addSubview:wBody];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatWallAttachmentTapped:)];
            tap.attachment = att;
            [card addGestureRecognizer:tap];
            [container addSubview:card];
            curY += 68.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeAudio) {
            UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, curY, width, 42.0)];
            card.layer.cornerRadius = 6.0;
            card.clipsToBounds = YES;
            card.backgroundColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.2] : [UIColor colorWithWhite:0.0 alpha:0.06];
            
            UILabel *audIcon = [[UILabel alloc] initWithFrame:CGRectMake(6, 6, 30, 30)];
            audIcon.text = @"▶";
            audIcon.textColor = isOutgoing ? [UIColor whiteColor] : [UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0];
            audIcon.font = [UIFont boldSystemFontOfSize:15];
            audIcon.textAlignment = NSTextAlignmentCenter;
            [card addSubview:audIcon];
            
            UILabel *audTitle = [[UILabel alloc] initWithFrame:CGRectMake(42, 4, width - 85, 17)];
            audTitle.text = att.audioTitle ?: @"Аудиозапись";
            audTitle.font = [UIFont boldSystemFontOfSize:11.5];
            audTitle.textColor = isOutgoing ? [UIColor whiteColor] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
            [card addSubview:audTitle];
            
            UILabel *audArtist = [[UILabel alloc] initWithFrame:CGRectMake(42, 21, width - 85, 16)];
            audArtist.text = att.audioArtist ?: @"";
            audArtist.font = [UIFont systemFontOfSize:10.5];
            audArtist.textColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.8] : [UIColor colorWithWhite:0.5 alpha:1.0];
            [card addSubview:audArtist];
            
            UILabel *audDur = [[UILabel alloc] initWithFrame:CGRectMake(width - 46, 12, 40, 16)];
            audDur.text = att.audioDuration ?: @"";
            audDur.font = [UIFont systemFontOfSize:10.5];
            audDur.textAlignment = NSTextAlignmentRight;
            audDur.textColor = isOutgoing ? [UIColor colorWithWhite:1.0 alpha:0.8] : [UIColor colorWithWhite:0.5 alpha:1.0];
            [card addSubview:audDur];
            
            VKChatAttachmentTapGesture *tap = [[VKChatAttachmentTapGesture alloc] initWithTarget:self action:@selector(chatAudioAttachmentTapped:)];
            tap.attachment = att;
            [card addGestureRecognizer:tap];
            [container addSubview:card];
            curY += 42.0 + 6.0;
        }
    }
}

- (void)chatPhotoAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    if (gesture.attachments.count > 0) {
        VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithAttachments:gesture.attachments initialIndex:gesture.initialIndex];
        [self presentViewController:viewer animated:YES completion:nil];
    }
}

- (void)chatVideoAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    if (gesture.attachment) {
        VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:gesture.attachment];
        [self presentViewController:player animated:YES completion:nil];
    }
}

- (void)chatGifAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    if (gesture.attachment) {
        VKGifViewerViewController *viewer = [[VKGifViewerViewController alloc] initWithAttachment:gesture.attachment];
        [self presentViewController:viewer animated:YES completion:nil];
    }
}

- (void)chatDocAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    if (gesture.attachment.docURL.length > 0) {
        NSURL *u = [NSURL URLWithString:gesture.attachment.docURL];
        if (u) [[UIApplication sharedApplication] openURL:u];
    }
}

- (void)chatWallAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    if (gesture.attachment && gesture.attachment.wallPostId != 0) {
        VKPost *dummyPost = [[VKPost alloc] init];
        dummyPost.vkID = gesture.attachment.wallPostId;
        dummyPost.ownerID = gesture.attachment.wallOwnerId;
        dummyPost.text = gesture.attachment.wallText;
        VKPostDetailViewController *postVC = [[VKPostDetailViewController alloc] initWithPost:dummyPost];
        [self.navigationController pushViewController:postVC animated:YES];
    }
}

- (void)chatAudioAttachmentTapped:(VKChatAttachmentTapGesture *)gesture {
    VKAttachment *att = gesture.attachment;
    if (att && (att.audioURL.length > 0 || att.audioId != 0)) {
        VKAudioTrack *track = [[VKAudioTrack alloc] init];
        track.audioId = att.audioId;
        track.trackId = att.audioId;
        track.ownerId = att.audioOwnerId;
        track.artist = att.audioArtist ?: @"";
        track.title = att.audioTitle ?: @"";
        track.streamURL = att.audioURL;
        track.url = att.audioURL;
        [[VKAudioPlayer sharedPlayer] playTrack:track];
        VKAudioPlayerViewController *pvc = [[VKAudioPlayerViewController alloc] init];
        [self presentViewController:pvc animated:YES completion:nil];
    }
}

#pragma mark - Swipe to Reply

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[VKChatSwipeReplyGesture class]]) {
        if (self.isSelectionMode) return NO;
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint v = [pan velocityInView:pan.view];
        return (fabs(v.x) > fabs(v.y) * 1.5 && v.x < 0);
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[VKChatSwipeReplyGesture class]]) {
        return NO;
    }
    return YES;
}

- (void)handleCellPan:(VKChatSwipeReplyGesture *)pan {
    if (self.isSelectionMode || !pan.bubbleView) return;
    
    CGPoint translation = [pan translationInView:pan.bubbleView.superview];
    CGFloat tx = translation.x;
    
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        if (tx < 0) {
            CGFloat damped = -powf(-tx, 0.82);
            damped = MAX(damped, -65.0);
            pan.bubbleView.transform = CGAffineTransformMakeTranslation(damped, 0);
            
            CGFloat progress = MIN(1.0, fabs(damped) / 38.0);
            pan.replyIndicator.alpha = progress;
            pan.replyIndicator.transform = CGAffineTransformMakeScale(0.5 + 0.5 * progress, 0.5 + 0.5 * progress);
        } else {
            pan.bubbleView.transform = CGAffineTransformIdentity;
            pan.replyIndicator.alpha = 0.0;
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        BOOL shouldReply = (tx < -45.0);
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            pan.bubbleView.transform = CGAffineTransformIdentity;
            pan.replyIndicator.alpha = 0.0;
            pan.replyIndicator.transform = CGAffineTransformMakeScale(0.5, 0.5);
        } completion:^(BOOL finished) {
            if (shouldReply && pan.message) {
                [self triggerReplyForMessage:pan.message];
            }
        }];
    }
}

- (void)triggerReplyForMessage:(VKMessage *)msg {
    if (!msg || [msg isServiceAction]) return;
    self.replyingMessage = msg;
    self.forwardingMessages = nil;
    self.editingMessage = nil;
    [self updateLayoutAnimated:YES];
    [self.messageTextField becomeFirstResponder];
}

#pragma mark - Chat Search

- (void)toggleSearchMode {
    if (self.isSearchingMessages) {
        [self closeSearchMode];
    } else {
        [self openSearchMode];
    }
}

- (void)openSearchMode {
    self.isSearchingMessages = YES;
    if (!self.searchBarContainer) {
        CGFloat w = self.view.bounds.size.width;
        self.searchBarContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
        self.searchBarContainer.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
        
        self.messageSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w - 100, 44)];
        self.messageSearchBar.delegate = self;
        self.messageSearchBar.placeholder = @"Поиск в сообщениях...";
        if ([self.messageSearchBar respondsToSelector:@selector(setBackgroundImage:)]) {
            [self.messageSearchBar setBackgroundImage:[[UIImage alloc] init]];
        }
        [self.searchBarContainer addSubview:self.messageSearchBar];
        
        self.searchMatchesLabel = [[UILabel alloc] initWithFrame:CGRectMake(w - 98, 4, 30, 36)];
        self.searchMatchesLabel.font = [UIFont systemFontOfSize:11];
        self.searchMatchesLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1.0];
        self.searchMatchesLabel.textAlignment = NSTextAlignmentCenter;
        [self.searchBarContainer addSubview:self.searchMatchesLabel];
        
        self.searchPrevButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.searchPrevButton.frame = CGRectMake(w - 68, 7, 30, 30);
        [self.searchPrevButton setTitle:@"▲" forState:UIControlStateNormal];
        [self.searchPrevButton setTitleColor:[UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        self.searchPrevButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.searchPrevButton addTarget:self action:@selector(searchPrevAction) forControlEvents:UIControlEventTouchUpInside];
        [self.searchBarContainer addSubview:self.searchPrevButton];
        
        self.searchNextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.searchNextButton.frame = CGRectMake(w - 38, 7, 30, 30);
        [self.searchNextButton setTitle:@"▼" forState:UIControlStateNormal];
        [self.searchNextButton setTitleColor:[UIColor colorWithRed:39.0/255.0 green:135.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        self.searchNextButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [self.searchNextButton addTarget:self action:@selector(searchNextAction) forControlEvents:UIControlEventTouchUpInside];
        [self.searchBarContainer addSubview:self.searchNextButton];
    }
    
    self.searchBarContainer.frame = CGRectMake(0, 0, self.view.bounds.size.width, 44);
    [self.view addSubview:self.searchBarContainer];
    
    UIEdgeInsets insets = self.tableView.contentInset;
    insets.top += 44.0;
    self.tableView.contentInset = insets;
    self.tableView.scrollIndicatorInsets = insets;
    
    [self.messageSearchBar becomeFirstResponder];
    [self performMessageSearch:self.messageSearchBar.text];
}

- (void)closeSearchMode {
    self.isSearchingMessages = NO;
    [self.messageSearchBar resignFirstResponder];
    [self.searchBarContainer removeFromSuperview];
    self.searchBarContainer = nil;
    self.searchMatchingIndices = nil;
    self.currentSearchMatchIndex = -1;
    
    UIEdgeInsets insets = self.tableView.contentInset;
    insets.top = MAX(0, insets.top - 44.0);
    self.tableView.contentInset = insets;
    self.tableView.scrollIndicatorInsets = insets;
    
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self performMessageSearch:searchText];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [self closeSearchMode];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)performMessageSearch:(NSString *)query {
    NSString *trimmed = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.searchMatchingIndices = [NSMutableArray array];
    self.currentSearchMatchIndex = -1;
    
    if (trimmed.length == 0) {
        self.searchMatchesLabel.text = @"";
        return;
    }
    
    for (NSInteger i = 0; i < (NSInteger)self.messages.count; i++) {
        VKMessage *m = self.messages[i];
        BOOL match = NO;
        if (m.text.length > 0 && [m.text rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
            match = YES;
        } else {
            for (VKAttachment *att in m.attachments) {
                if ([att isKindOfClass:[VKAttachment class]]) {
                    if (att.videoTitle.length > 0 && [att.videoTitle rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        match = YES; break;
                    }
                    if (att.docTitle.length > 0 && [att.docTitle rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        match = YES; break;
                    }
                    if (att.audioTitle.length > 0 && [att.audioTitle rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        match = YES; break;
                    }
                    if (att.wallText.length > 0 && [att.wallText rangeOfString:trimmed options:NSCaseInsensitiveSearch].location != NSNotFound) {
                        match = YES; break;
                    }
                }
            }
        }
        if (match) {
            [self.searchMatchingIndices addObject:@(i)];
        }
    }
    
    if (self.searchMatchingIndices.count > 0) {
        self.currentSearchMatchIndex = self.searchMatchingIndices.count - 1;
        [self jumpToCurrentSearchMatch];
    } else {
        self.searchMatchesLabel.text = @"0";
    }
}

- (void)jumpToCurrentSearchMatch {
    if (self.currentSearchMatchIndex >= 0 && self.currentSearchMatchIndex < (NSInteger)self.searchMatchingIndices.count) {
        NSInteger row = [self.searchMatchingIndices[self.currentSearchMatchIndex] integerValue];
        self.searchMatchesLabel.text = [NSString stringWithFormat:@"%ld/%lu", (long)(self.currentSearchMatchIndex + 1), (unsigned long)self.searchMatchingIndices.count];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        [self.tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
        [self.tableView selectRowAtIndexPath:ip animated:YES scrollPosition:UITableViewScrollPositionNone];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tableView deselectRowAtIndexPath:ip animated:YES];
        });
    }
}

- (void)searchPrevAction {
    if (self.searchMatchingIndices.count == 0) return;
    if (self.currentSearchMatchIndex > 0) {
        self.currentSearchMatchIndex--;
    } else {
        self.currentSearchMatchIndex = self.searchMatchingIndices.count - 1;
    }
    [self jumpToCurrentSearchMatch];
}

- (void)searchNextAction {
    if (self.searchMatchingIndices.count == 0) return;
    if (self.currentSearchMatchIndex < (NSInteger)self.searchMatchingIndices.count - 1) {
        self.currentSearchMatchIndex++;
    } else {
        self.currentSearchMatchIndex = 0;
    }
    [self jumpToCurrentSearchMatch];
}

@end
