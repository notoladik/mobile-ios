#import "VKChatViewController.h"
#import "VKMessagesService.h"
#import "VKProfileViewController.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"
#import "VKAPIClient.h"
#import "VKAttachment.h"
#import "VKPhotoEditorViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface VKChatViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UITextField *messageTextField;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKChatViewController

- (instancetype)initWithPeerId:(NSInteger)peerId peerUser:(VKUser *)peerUser title:(NSString *)title {
    self = [super init];
    if (self) {
        _peerId = peerId;
        _peerUser = peerUser;
        _chatTitle = title ?: peerUser.displayName ?: @"Чат";
        _messages = [NSMutableArray array];
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
    
    // Панель ввода сообщения
    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 48.0, width, 48.0)];
    self.inputContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.inputContainerView.backgroundColor = [UIColor colorWithRed:225.0/255.0 green:228.0/255.0 blue:234.0/255.0 alpha:1.0];
    } else {
        self.inputContainerView.backgroundColor = [UIColor whiteColor];
    }
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:sep];
    
    // Круглая кнопка прикрепления фото
    self.attachButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.attachButton.frame = CGRectMake(8, 7, 34, 34);
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        self.attachButton.backgroundColor = [UIColor colorWithRed:90.0/255.0 green:115.0/255.0 blue:150.0/255.0 alpha:1.0];
        self.attachButton.layer.cornerRadius = 17.0;
        self.attachButton.layer.borderWidth = 1.0;
        self.attachButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
    } else {
        self.attachButton.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        self.attachButton.layer.cornerRadius = 17.0;
    }
    [self.attachButton setTitle:@"+" forState:UIControlStateNormal];
    [self.attachButton setTitleColor:([[VKThemeManager sharedManager] isSkeuomorphic] ? [UIColor whiteColor] : [UIColor colorWithWhite:0.4 alpha:1.0]) forState:UIControlStateNormal];
    self.attachButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.attachButton addTarget:self action:@selector(attachPhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.attachButton];
    
    // Поле ввода
    self.messageTextField = [[UITextField alloc] initWithFrame:CGRectMake(50, 7, width - 118, 34)];
    self.messageTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.messageTextField.placeholder = @"Написать сообщение";
    self.messageTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.messageTextField.font = [UIFont systemFontOfSize:14];
    self.messageTextField.delegate = self;
    [self.inputContainerView addSubview:self.messageTextField];
    
    // Кнопка «Отпр.»
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(width - 62, 7, 54, 34);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
    
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
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
    
    // Уведомления клавиатуры
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    // Подгрузка профиля собеседника, если аватарки или статуса не хватает
    if (self.peerId > 0 && (!self.peerUser || self.peerUser.avatarURL.length == 0)) {
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

- (void)setupNavigationHeader {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 36)];
    headerView.userInteractionEnabled = YES;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPeerProfile)];
    [headerView addGestureRecognizer:tap];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 180, 18)];
    nameLabel.text = self.chatTitle;
    nameLabel.font = [[VKThemeManager sharedManager] titleFontOfSize:15];
    nameLabel.textColor = [[VKThemeManager sharedManager] navBarTitleColor];
    nameLabel.textAlignment = NSTextAlignmentCenter;
    [headerView addSubview:nameLabel];
    
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 19, 180, 14)];
    statusLabel.text = self.peerUser.isOnline ? @"в сети" : (self.peerUser.lastSeen ?: @"был(а) недавно");
    statusLabel.font = [UIFont systemFontOfSize:11];
    if ([[VKThemeManager sharedManager] isSkeuomorphic]) {
        statusLabel.textColor = [UIColor colorWithRed:180.0/255.0 green:210.0/255.0 blue:245.0/255.0 alpha:1.0];
    } else {
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    }
    statusLabel.textAlignment = NSTextAlignmentCenter;
    [headerView addSubview:statusLabel];
    
    self.navigationItem.titleView = headerView;
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    
    // Аватарка в правом углу навигационной панели
    if (self.peerUser) {
        UIImageView *navAvatar = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
        navAvatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:32.0];
        navAvatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
        navAvatar.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.4].CGColor;
        navAvatar.clipsToBounds = YES;
        navAvatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        navAvatar.userInteractionEnabled = YES;
        UITapGestureRecognizer *avTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPeerProfile)];
        [navAvatar addGestureRecognizer:avTap];
        
        if (self.peerUser.avatarURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:self.peerUser.avatarURL completion:^(UIImage *img) {
                if (img) navAvatar.image = img;
            }];
        }
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:navAvatar];
    }
}

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
                for (id element in enumerator) {
                    [self.messages addObject:element];
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
            }
        });
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (NSString *)textForMessage:(VKMessage *)msg {
    if (msg.text.length > 0) return msg.text;
    if (msg.attachments.count > 0) {
        VKAttachment *att = msg.attachments[0];
        if (att.type == VKAttachmentTypePhoto) return @"[Фотография]";
        if (att.type == VKAttachmentTypeGif) return @"[GIF]";
        if (att.type == VKAttachmentTypeAudio) return [NSString stringWithFormat:@"🎵 %@ — %@", att.audioArtist ?: @"", att.audioTitle ?: @"Трек"];
        if (att.type == VKAttachmentTypeDoc) return [NSString stringWithFormat:@"📄 %@", att.docTitle ?: @"Документ"];
        if (att.type == VKAttachmentTypeVideo) return [NSString stringWithFormat:@"🎬 %@", att.videoTitle ?: @"Видео"];
        return @"[Вложение]";
    }
    return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.messages.count) return 44.0;
    VKMessage *msg = self.messages[indexPath.row];
    NSString *displayText = [self textForMessage:msg];
    CGSize size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(tableView.bounds.size.width - 100, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    return MAX(44.0, ceilf(size.height) + 26.0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKChatMessageBubbleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor clearColor];
        
        UIImageView *bubble = [[UIImageView alloc] initWithFrame:CGRectZero];
        bubble.tag = 1001;
        bubble.userInteractionEnabled = YES;
        [cell.contentView addSubview:bubble];
        
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        textLabel.tag = 1002;
        textLabel.font = [UIFont systemFontOfSize:15];
        textLabel.numberOfLines = 0;
        textLabel.backgroundColor = [UIColor clearColor];
        [bubble addSubview:textLabel];
        
        UILabel *timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        timeLabel.tag = 1003;
        timeLabel.font = [UIFont systemFontOfSize:10];
        timeLabel.backgroundColor = [UIColor clearColor];
        [bubble addSubview:timeLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.messages.count) return cell;
    
    VKMessage *msg = self.messages[indexPath.row];
    UIImageView *bubble = (UIImageView *)[cell.contentView viewWithTag:1001];
    UILabel *textLabel = (UILabel *)[bubble viewWithTag:1002];
    UILabel *timeLabel = (UILabel *)[bubble viewWithTag:1003];
    
    NSString *displayText = [self textForMessage:msg];
    textLabel.text = displayText;
    timeLabel.text = msg.timeString ?: @"";
    
    CGFloat width = tableView.bounds.size.width;
    CGSize size = [displayText sizeWithFont:[UIFont systemFontOfSize:15] constrainedToSize:CGSizeMake(width - 100, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
    CGFloat bubbleWidth = MAX(76.0, ceilf(size.width) + 26.0);
    CGFloat bubbleHeight = ceilf(size.height) + 22.0;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    if (msg.isOutgoing) {
        // Исходящие (справа)
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
                // В плоском стиле iOS 7 исходящий бабл светло-голубой, текст ТЁМНЫЙ для идеальной читаемости
                textLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
                timeLabel.textColor = [UIColor colorWithRed:120.0/255.0 green:135.0/255.0 blue:155.0/255.0 alpha:1.0];
            } else {
                bubble.backgroundColor = [[VKThemeManager sharedManager] accentColor];
                bubble.layer.cornerRadius = 14.0;
                textLabel.textColor = [UIColor whiteColor];
                timeLabel.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
            }
        }
        textLabel.frame = CGRectMake(12, 6, ceilf(size.width), ceilf(size.height));
        timeLabel.frame = CGRectMake(bubbleWidth - 44, bubbleHeight - 16, 34, 12);
    } else {
        // Входящие (слева)
        bubble.frame = CGRectMake(10.0, 3.0, bubbleWidth, bubbleHeight);
        
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
        textLabel.frame = CGRectMake(16, 6, ceilf(size.width), ceilf(size.height));
        timeLabel.frame = CGRectMake(bubbleWidth - 40, bubbleHeight - 16, 34, 12);
    }
    
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return YES;
}

@end
