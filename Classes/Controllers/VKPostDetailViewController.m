#import "VKPostDetailViewController.h"
#import "VKCommentsService.h"
#import "VKFeedService.h"
#import "VKAuthService.h"
#import "VKFeedPostCell.h"
#import "VKProfileViewController.h"
#import "VKPhotoViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "VKAudioPlayer.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"

#pragma mark - VKCommentCell (Идентично скриншоту VK iOS)

@interface VKCommentCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *commentTextLabel;
@property (nonatomic, strong) UIButton *replyButton;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, copy) void (^onAvatarTapped)(void);
@property (nonatomic, copy) void (^onReplyTapped)(void);
@property (nonatomic, copy) void (^onMoreTapped)(void);
@property (nonatomic, copy) void (^onLikeTapped)(void);
@end

@implementation VKCommentCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor whiteColor];
        
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 36, 36)];
        _avatarImageView.layer.cornerRadius = 18.0;
        _avatarImageView.clipsToBounds = YES;
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        _avatarImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarClicked)];
        [_avatarImageView addGestureRecognizer:tap];
        [self.contentView addSubview:_avatarImageView];
        
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont boldSystemFontOfSize:14];
        _nameLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]; // #4A76A8
        [self.contentView addSubview:_nameLabel];
        
        _commentTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _commentTextLabel.font = [UIFont systemFontOfSize:14];
        _commentTextLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
        _commentTextLabel.numberOfLines = 0;
        [self.contentView addSubview:_commentTextLabel];
        
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.font = [UIFont systemFontOfSize:11.5];
        _dateLabel.textColor = [UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0];
        [self.contentView addSubview:_dateLabel];
        
        _replyButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_replyButton setTitle:@"Ответить" forState:UIControlStateNormal];
        [_replyButton setTitleColor:[UIColor colorWithRed:125.0/255.0 green:135.0/255.0 blue:148.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _replyButton.titleLabel.font = [UIFont systemFontOfSize:11.5];
        _replyButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_replyButton addTarget:self action:@selector(replyClicked) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_replyButton];
        
        _moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButton setTitle:@"•••" forState:UIControlStateNormal];
        [_moreButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _moreButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [_moreButton addTarget:self action:@selector(moreClicked) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_moreButton];
        
        _likeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _likeButton.frame = CGRectMake(self.contentView.bounds.size.width - 50, 10, 44, 22);
        _likeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_likeButton setTitle:@"♡" forState:UIControlStateNormal];
        [_likeButton setTitleColor:[UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _likeButton.titleLabel.font = [UIFont systemFontOfSize:12.5];
        _likeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_likeButton addTarget:self action:@selector(likeClicked) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_likeButton];
    }
    return self;
}

- (void)avatarClicked {
    if (self.onAvatarTapped) self.onAvatarTapped();
}

- (void)replyClicked {
    if (self.onReplyTapped) self.onReplyTapped();
}

- (void)moreClicked {
    if (self.onMoreTapped) self.onMoreTapped();
}

- (void)likeClicked {
    if (_likeButton) {
        [UIView animateWithDuration:0.1 animations:^{
            self.likeButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.12 animations:^{
                self.likeButton.transform = CGAffineTransformIdentity;
            }];
        }];
    }
    if (self.onLikeTapped) self.onLikeTapped();
}

+ (NSAttributedString *)attributedTextForComment:(NSString *)rawText {
    if (!rawText || rawText.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:rawText attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0]
    }];
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(id|club)(\\d+)\\|([^\\]]+)\\]" options:0 error:&error];
    if (!error) {
        NSArray *matches = [regex matchesInString:attr.string options:0 range:NSMakeRange(0, attr.string.length)];
        for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
            NSRange fullRange = [match rangeAtIndex:0];
            NSRange nameRange = [match rangeAtIndex:3];
            NSString *name = [attr.string substringWithRange:nameRange];
            
            NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:name attributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:14],
                NSForegroundColorAttributeName: [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]
            }];
            [attr replaceCharactersInRange:fullRange withAttributedString:replacement];
        }
    }
    return attr;
}

+ (CGFloat)heightForComment:(VKComment *)comment width:(CGFloat)width {
    if (!comment) return 44.0;
    CGFloat textWidth = MAX(50.0, width - 68.0);
    NSAttributedString *attr = [self attributedTextForComment:comment.text];
    
    CGRect rect = [attr boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    return MAX(54.0, ceilf(rect.size.height) + 44.0);
}

- (void)configureWithComment:(VKComment *)comment width:(CGFloat)width {
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    self.avatarImageView.layer.cornerRadius = isSkeuomorph ? 3.0 : 18.0;
    self.avatarImageView.image = nil;
    
    if (comment.author.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:comment.author.avatarURL completion:^(UIImage *img) {
            if (img) self.avatarImageView.image = img;
        }];
    }
    
    self.nameLabel.text = comment.author.displayName ?: @"Пользователь";
    if (isSkeuomorph) {
        self.nameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        self.nameLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    }
    
    CGSize nameSize = [self.nameLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:14]];
    self.nameLabel.frame = CGRectMake(58, 8, MIN(nameSize.width, width - 130), 18);
    
    NSAttributedString *attr = [VKCommentCell attributedTextForComment:comment.text];
    self.commentTextLabel.attributedText = attr;
    
    CGFloat textWidth = MAX(50.0, width - 68.0);
    CGRect rect = [attr boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
    self.commentTextLabel.frame = CGRectMake(58, 28, textWidth, ceilf(rect.size.height));
    
    CGFloat bottomY = 28 + ceilf(rect.size.height) + 4.0;
    NSString *dateStr = comment.timeAgo ?: @"сегодня";
    CGSize dateSize = [dateStr sizeWithFont:[UIFont systemFontOfSize:11.5]];
    self.dateLabel.text = dateStr;
    self.dateLabel.frame = CGRectMake(58, bottomY, dateSize.width + 4.0, 16);
    
    self.replyButton.frame = CGRectMake(58 + dateSize.width + 10.0, bottomY, 56, 16);
    self.moreButton.frame = CGRectMake(58 + dateSize.width + 70.0, bottomY, 26, 16);
    
    // Кнопка Лайка
    self.likeButton.frame = CGRectMake(width - 64, bottomY - 2, 54, 20);
    NSString *likeText = (comment.likesCount > 0) ? [NSString stringWithFormat:@"%ld", (long)comment.likesCount] : @"";
    [self.likeButton setTitle:likeText forState:UIControlStateNormal];
    UIColor *heartColor = comment.isLiked ? [UIColor colorWithRed:235.0/255.0 green:45.0/255.0 blue:70.0/255.0 alpha:1.0] : [UIColor colorWithRed:155.0/255.0 green:165.0/255.0 blue:175.0/255.0 alpha:1.0];
    [self.likeButton setImage:[[VKThemeManager sharedManager] reactionHeartIconWithColor:heartColor filled:comment.isLiked] forState:UIControlStateNormal];
    self.likeButton.imageEdgeInsets = (likeText.length > 0) ? UIEdgeInsetsMake(0, 0, 0, 4) : UIEdgeInsetsZero;
    self.likeButton.titleEdgeInsets = (likeText.length > 0) ? UIEdgeInsetsMake(0, 4, 0, 0) : UIEdgeInsetsZero;
    [self.likeButton setTitleColor:heartColor forState:UIControlStateNormal];
}

@end

#pragma mark - VKPostDetailViewController

@interface VKPostDetailViewController () <UIActionSheetDelegate, UIAlertViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *comments;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UITextField *commentTextField;
@property (nonatomic, strong) UIButton *smileyButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) VKComment *selectedCommentForAction;
@property (nonatomic, assign) NSInteger replyingToCommentId;
@end

@implementation VKPostDetailViewController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.tableView reloadData];
}

- (instancetype)initWithPost:(VKPost *)post {
    self = [super init];
    if (self) {
        _post = post;
        _comments = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Запись";
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    
    [self applyThemeStyle];
    [self setupTableView];
    [self setupInputBar];
    [self setupNavigationItems];
    [self loadComments];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
}

- (void)setupNavigationItems {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(postOptionsAction)];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
}

- (void)setupTableView {
    CGFloat inputH = 46.0;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - inputH) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
    [self.view addSubview:self.tableView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
}

- (void)setupInputBar {
    CGFloat inputH = 46.0;
    CGFloat y = self.view.bounds.size.height - inputH;
    
    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, inputH)];
    self.inputContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.inputContainerView.backgroundColor = [UIColor colorWithRed:246.0/255.0 green:247.0/255.0 blue:249.0/255.0 alpha:1.0];
    
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 0.5)];
    topLine.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
    topLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:topLine];
    
    // Кнопка + (Вложения)
    self.attachButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.attachButton.frame = CGRectMake(6, 6, 34, 34);
    [self.attachButton setTitle:@"+" forState:UIControlStateNormal];
    [self.attachButton setTitleColor:[UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.attachButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [self.attachButton addTarget:self action:@selector(attachAction) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.attachButton];
    
    // Капсула поля ввода
    CGFloat tfX = 46.0;
    CGFloat tfW = self.view.bounds.size.width - tfX - 58.0;
    UIView *fieldBg = [[UIView alloc] initWithFrame:CGRectMake(tfX, 7, tfW, 32)];
    fieldBg.backgroundColor = [UIColor whiteColor];
    fieldBg.layer.cornerRadius = 16.0;
    fieldBg.layer.borderWidth = 0.5;
    fieldBg.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0].CGColor;
    fieldBg.clipsToBounds = YES;
    fieldBg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:fieldBg];
    
    self.commentTextField = [[UITextField alloc] initWithFrame:CGRectMake(12, 4, tfW - 40, 24)];
    self.commentTextField.placeholder = @"Ваш комментарий...";
    self.commentTextField.font = [UIFont systemFontOfSize:13.5];
    self.commentTextField.returnKeyType = UIReturnKeySend;
    self.commentTextField.delegate = (id<UITextFieldDelegate>)self;
    self.commentTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.commentTextField addTarget:self action:@selector(textFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [fieldBg addSubview:self.commentTextField];
    
    self.smileyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.smileyButton.frame = CGRectMake(tfW - 28, 4, 24, 24);
    [self.smileyButton setTitle:@"☺" forState:UIControlStateNormal];
    [self.smileyButton setTitleColor:[UIColor colorWithRed:150.0/255.0 green:160.0/255.0 blue:170.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.smileyButton.titleLabel.font = [UIFont systemFontOfSize:16];
    self.smileyButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [fieldBg addSubview:self.smileyButton];
    
    // Кнопка "Отпр."
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(self.view.bounds.size.width - 54, 7, 48, 32);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.sendButton addTarget:self action:@selector(sendComment) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.sendButton];
    
    [self.view addSubview:self.inputContainerView];
}

- (void)textFieldChanged {
    NSString *trimmed = [self.commentTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0) {
        [self.sendButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.sendButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        self.replyingToCommentId = 0;
    }
}

- (void)dismissKeyboard {
    [self.commentTextField resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notif {
    NSDictionary *info = [notif userInfo];
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        self.inputContainerView.frame = CGRectMake(0, self.view.bounds.size.height - kbFrame.size.height - 46.0, self.view.bounds.size.width, 46.0);
        self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - kbFrame.size.height - 46.0);
    }];
}

- (void)keyboardWillHide:(NSNotification *)notif {
    NSDictionary *info = [notif userInfo];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    [UIView animateWithDuration:duration animations:^{
        self.inputContainerView.frame = CGRectMake(0, self.view.bounds.size.height - 46.0, self.view.bounds.size.width, 46.0);
        self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 46.0);
    }];
}

- (void)postOptionsAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Поделиться", @"Скопировать ссылку", nil];
    sheet.tag = 1001;
    [sheet showInView:self.view];
}

- (void)attachAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Прикрепить к комментарию"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Фотография", @"Документ", nil];
    sheet.tag = 1002;
    [sheet showInView:self.view];
}

- (void)loadComments {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [[VKCommentsService sharedService] fetchCommentsForOwnerId:self.post.ownerID postId:self.post.vkID offset:0 count:50 completion:^(NSArray *comments, NSInteger totalCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.isLoading = NO;
            if (!error && comments) {
                [self.comments removeAllObjects];
                [self.comments addObjectsFromArray:comments];
                [self.tableView reloadData];
            }
        });
    }];
}

- (void)sendComment {
    NSString *text = [self.commentTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.sendButton.userInteractionEnabled = NO;
    NSInteger replyId = self.replyingToCommentId;
    
    [VKCrashLogger log:@"[VKPostDetailViewController] Sending comment: owner=%ld, post=%ld, text='%@', replyTo=%ld", (long)self.post.ownerID, (long)self.post.vkID, text, (long)replyId];
    
    [[VKCommentsService sharedService] addCommentForOwnerId:self.post.ownerID postId:self.post.vkID message:text replyToCid:replyId completion:^(BOOL success, NSInteger commentId, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.sendButton.userInteractionEnabled = YES;
            if (success) {
                [VKCrashLogger log:@"[VKPostDetailViewController] Comment created successfully with ID=%ld", (long)commentId];
                self.commentTextField.text = @"";
                self.replyingToCommentId = 0;
                [self textFieldChanged];
                [self.commentTextField resignFirstResponder];
                [self loadComments];
            } else {
                NSString *errMsg = error.localizedDescription ?: @"Не удалось отправить комментарий. Проверьте соединение с сервером.";
                [VKCrashLogger log:@"[VKPostDetailViewController] Error creating comment: %@", errMsg];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                                message:errMsg
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 0: Пост, 1: Комментарии
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return self.comments.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = [[UIScreen mainScreen] bounds].size.width;
    if (indexPath.section == 0) {
        return [VKFeedPostCell heightForPost:self.post width:width isRevealed:YES];
    } else {
        if (indexPath.row >= (NSInteger)self.comments.count) return 44.0;
        VKComment *c = self.comments[indexPath.row];
        return [VKCommentCell heightForComment:c width:width];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = [[UIScreen mainScreen] bounds].size.width;
    
    if (indexPath.section == 0) {
        static NSString *PostCellId = @"VKPostDetailPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:PostCellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PostCellId];
        }
        [cell configureWithPost:self.post isRevealed:YES];
        cell.onLikeTapped = ^(VKPost *p) {
            [[VKFeedService sharedService] likePost:p completion:nil];
        };
        
        __weak typeof(self) weakSelf = self;
        cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onPhotoTapped = ^(NSString *photoURL, UIImage *image) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL initialImage:image];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onVideoTapped = ^(VKAttachment *videoAttachment) {
            VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:videoAttachment];
            [weakSelf presentMoviePlayerViewControllerAnimated:player];
        };
        
        cell.onAudioTapped = ^(VKAttachment *audioAttachment) {
            [weakSelf.tableView reloadData];
        };
        
        cell.onPollVoted = ^(VKAttachment *pollAttachment, NSInteger optionId) {
            [weakSelf.tableView reloadData];
        };
        
        cell.onDocTapped = ^(VKAttachment *docAttachment) {
            if (docAttachment.docURL.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:docAttachment.docURL]];
            }
        };
        
        cell.onLinkTapped = ^(NSString *url) {
            if (url.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
        };
        
        cell.onAuthorTapped = ^(VKUser *author) {
            if (author) {
                VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:author];
                [weakSelf.navigationController pushViewController:profVC animated:YES];
            }
        };
        
        cell.onToggleTextExpanded = ^(VKPost *p) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView beginUpdates];
                [weakSelf.tableView endUpdates];
            });
        };
        
        cell.onToggleRepostTextExpanded = ^(VKPost *p) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView beginUpdates];
                [weakSelf.tableView endUpdates];
            });
        };
        
        cell.onCopyrightTapped = ^(NSString *url) {
            if (url.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
        };
        
        return cell;
    } else {
        static NSString *CommentCellId = @"VKCommentCell";
        VKCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:CommentCellId];
        if (!cell) {
            cell = [[VKCommentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CommentCellId];
        }
        if (indexPath.row < (NSInteger)self.comments.count) {
            VKComment *comment = self.comments[indexPath.row];
            [cell configureWithComment:comment width:width];
            
            __weak typeof(self) weakSelf = self;
            
            cell.onAvatarTapped = ^{
                if (comment.author) {
                    VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:comment.author];
                    [weakSelf.navigationController pushViewController:profVC animated:YES];
                }
            };
            
            cell.onReplyTapped = ^{
                weakSelf.replyingToCommentId = comment.commentId;
                NSString *name = comment.author.displayName ?: @"";
                NSString *mention = [NSString stringWithFormat:@"[id%ld|%@], ", (long)comment.fromId, name];
                weakSelf.commentTextField.text = mention;
                [weakSelf textFieldChanged];
                [weakSelf.commentTextField becomeFirstResponder];
            };
            
            cell.onLikeTapped = ^{
                BOOL newLiked = !comment.isLiked;
                comment.isLiked = newLiked;
                comment.likesCount += newLiked ? 1 : -1;
                if (comment.likesCount < 0) comment.likesCount = 0;
                [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                
                [[VKCommentsService sharedService] likeCommentId:comment.commentId ownerId:weakSelf.post.ownerID isLike:newLiked completion:^(BOOL success) {
                    // Лайк обновлен
                }];
            };
            
            cell.onMoreTapped = ^{
                [weakSelf showCommentActionSheetForComment:comment];
            };
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row < (NSInteger)self.comments.count) {
        VKComment *c = self.comments[indexPath.row];
        [self showCommentActionSheetForComment:c];
    }
}

#pragma mark - Comment Actions & Management

- (void)showCommentActionSheetForComment:(VKComment *)comment {
    self.selectedCommentForAction = comment;
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    BOOL isMyComment = (comment.fromId == myId || (comment.author && comment.author.uid == myId));
    
    UIActionSheet *sheet = nil;
    if (isMyComment) {
        sheet = [[UIActionSheet alloc] initWithTitle:nil
                                            delegate:self
                                   cancelButtonTitle:@"Отмена"
                              destructiveButtonTitle:@"Удалить"
                                   otherButtonTitles:@"Ответить", @"Редактировать", @"Скопировать", nil];
        sheet.tag = 2001;
    } else {
        sheet = [[UIActionSheet alloc] initWithTitle:nil
                                            delegate:self
                                   cancelButtonTitle:@"Отмена"
                              destructiveButtonTitle:nil
                                   otherButtonTitles:@"Ответить", @"Скопировать", @"Пожаловаться", nil];
        sheet.tag = 2002;
    }
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 2001) {
        // Меню своего комментария: 0: Удалить, 1: Ответить, 2: Редактировать, 3: Скопировать
        if (buttonIndex == 0) {
            [self deleteSelectedComment];
        } else if (buttonIndex == 1) {
            [self replyToSelectedComment];
        } else if (buttonIndex == 2) {
            [self editSelectedComment];
        } else if (buttonIndex == 3) {
            [self copySelectedComment];
        }
    } else if (actionSheet.tag == 2002) {
        // Меню чужого комментария: 0: Ответить, 1: Скопировать, 2: Пожаловаться
        if (buttonIndex == 0) {
            [self replyToSelectedComment];
        } else if (buttonIndex == 1) {
            [self copySelectedComment];
        }
    } else if (actionSheet.tag == 1001) {
        if (buttonIndex == 0) {
            // Поделиться
        } else if (buttonIndex == 1) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/wall%ld_%ld", (long)self.post.ownerID, (long)self.post.vkID];
        }
    }
}

- (void)replyToSelectedComment {
    if (!self.selectedCommentForAction) return;
    self.replyingToCommentId = self.selectedCommentForAction.commentId;
    NSString *name = self.selectedCommentForAction.author.displayName ?: @"";
    NSString *mention = [NSString stringWithFormat:@"[id%ld|%@], ", (long)self.selectedCommentForAction.fromId, name];
    self.commentTextField.text = mention;
    [self textFieldChanged];
    [self.commentTextField becomeFirstResponder];
}

- (void)copySelectedComment {
    if (!self.selectedCommentForAction) return;
    [UIPasteboard generalPasteboard].string = self.selectedCommentForAction.text ?: @"";
}

- (void)editSelectedComment {
    if (!self.selectedCommentForAction) return;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Редактирование"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сохранить", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.text = self.selectedCommentForAction.text ?: @"";
    alert.tag = 3001;
    [alert show];
}

- (void)deleteSelectedComment {
    if (!self.selectedCommentForAction) return;
    VKComment *c = self.selectedCommentForAction;
    NSInteger idx = [self.comments indexOfObject:c];
    
    [[VKCommentsService sharedService] deleteCommentForOwnerId:self.post.ownerID commentId:c.commentId completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (idx != NSNotFound && idx < (NSInteger)self.comments.count) {
                    [self.comments removeObjectAtIndex:idx];
                    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:1]] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        });
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 3001 && buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *newText = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length == 0 || !self.selectedCommentForAction) return;
        
        VKComment *c = self.selectedCommentForAction;
        [[VKCommentsService sharedService] editCommentForOwnerId:self.post.ownerID commentId:c.commentId message:newText completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    c.text = newText;
                    [self.tableView reloadData];
                }
            });
        }];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendComment];
    return YES;
}

@end
