#import "VKOfflinePlaceholderView.h"
#import "VKThemeManager.h"
#import <QuartzCore/QuartzCore.h>

@interface VKOfflinePlaceholderView ()

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *iconLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end

@implementation VKOfflinePlaceholderView

+ (instancetype)offlinePlaceholderWithFrame:(CGRect)frame onRetry:(void(^)(void))onRetry {
    VKOfflinePlaceholderView *v = [[self alloc] initWithFrame:frame];
    v.iconText = @"📡";
    v.titleText = @"Нет подключения";
    v.messageText = @"Проверьте подключение к интернету\nи повторите попытку";
    v.buttonTitle = @"Повторить попытку";
    v.onRetryTapped = onRetry;
    [v reloadData];
    return v;
}

+ (instancetype)serverErrorPlaceholderWithFrame:(CGRect)frame onRetry:(void(^)(void))onRetry {
    VKOfflinePlaceholderView *v = [[self alloc] initWithFrame:frame];
    v.iconText = @"☁️";
    v.titleText = @"Сервер недоступен";
    v.messageText = @"Не удалось связаться с сервером.\nПопробуйте позже";
    v.buttonTitle = @"Повторить попытку";
    v.onRetryTapped = onRetry;
    [v reloadData];
    return v;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundColor = [UIColor clearColor];
        
        _containerView = [[UIView alloc] initWithFrame:CGRectZero];
        _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                          UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:_containerView];
        
        _iconLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _iconLabel.font = [UIFont systemFontOfSize:46];
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        _iconLabel.backgroundColor = [UIColor clearColor];
        [_containerView addSubview:_iconLabel];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:17];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.backgroundColor = [UIColor clearColor];
        [_containerView addSubview:_titleLabel];
        
        _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _messageLabel.font = [UIFont systemFontOfSize:13];
        _messageLabel.textAlignment = NSTextAlignmentCenter;
        _messageLabel.numberOfLines = 3;
        _messageLabel.backgroundColor = [UIColor clearColor];
        [_containerView addSubview:_messageLabel];
        
        _retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _retryButton.layer.cornerRadius = 8.0;
        _retryButton.clipsToBounds = YES;
        _retryButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [_retryButton addTarget:self action:@selector(retryButtonAction) forControlEvents:UIControlEventTouchUpInside];
        [_containerView addSubview:_retryButton];
        
        _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicator.hidesWhenStopped = YES;
        [_retryButton addSubview:_activityIndicator];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
        
        [self applyThemeStyle];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    
    CGFloat containerW = MIN(280.0, w - 40.0);
    CGFloat containerH = 220.0;
    _containerView.frame = CGRectMake((w - containerW) / 2.0, (h - containerH) / 2.0, containerW, containerH);
    
    _iconLabel.frame = CGRectMake(0, 0, containerW, 54.0);
    _titleLabel.frame = CGRectMake(0, 60.0, containerW, 24.0);
    _messageLabel.frame = CGRectMake(0, 88.0, containerW, 40.0);
    
    CGFloat btnW = MIN(180.0, containerW);
    _retryButton.frame = CGRectMake((containerW - btnW) / 2.0, 148.0, btnW, 38.0);
    _activityIndicator.center = CGPointMake(btnW / 2.0, 19.0);
}

- (void)applyThemeStyle {
    BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    if (isSkeuo) {
        _titleLabel.textColor = [UIColor colorWithRed:60.0/255.0 green:70.0/255.0 blue:85.0/255.0 alpha:1.0];
        _messageLabel.textColor = [UIColor colorWithRed:120.0/255.0 green:130.0/255.0 blue:145.0/255.0 alpha:1.0];
        
        _retryButton.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        [_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _retryButton.layer.borderWidth = 1.0;
        _retryButton.layer.borderColor = [UIColor colorWithRed:55.0/255.0 green:90.0/255.0 blue:135.0/255.0 alpha:1.0].CGColor;
    } else {
        _titleLabel.textColor = [UIColor colorWithWhite:0.15 alpha:1.0];
        _messageLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        
        _retryButton.backgroundColor = [[VKThemeManager sharedManager] accentColor];
        [_retryButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _retryButton.layer.borderWidth = 0.0;
    }
}

- (void)reloadData {
    _iconLabel.text = _iconText ?: @"📡";
    _titleLabel.text = _titleText ?: @"Нет подключения";
    _messageLabel.text = _messageText ?: @"Проверьте соединение с интернетом";
    [_retryButton setTitle:(_buttonTitle ?: @"Повторить попытку") forState:UIControlStateNormal];
    [self setNeedsLayout];
}

- (void)setIconText:(NSString *)iconText {
    _iconText = [iconText copy];
    _iconLabel.text = _iconText;
}

- (void)setTitleText:(NSString *)titleText {
    _titleText = [titleText copy];
    _titleLabel.text = _titleText;
}

- (void)setMessageText:(NSString *)messageText {
    _messageText = [messageText copy];
    _messageLabel.text = _messageText;
}

- (void)setButtonTitle:(NSString *)buttonTitle {
    _buttonTitle = [buttonTitle copy];
    [_retryButton setTitle:_buttonTitle forState:UIControlStateNormal];
}

- (void)retryButtonAction {
    [self setLoading:YES];
    if (self.onRetryTapped) {
        self.onRetryTapped();
    }
}

- (void)setLoading:(BOOL)loading {
    if (loading) {
        [_activityIndicator startAnimating];
        [_retryButton setTitle:@"" forState:UIControlStateNormal];
        _retryButton.userInteractionEnabled = NO;
    } else {
        [_activityIndicator stopAnimating];
        [_retryButton setTitle:(_buttonTitle ?: @"Повторить попытку") forState:UIControlStateNormal];
        _retryButton.userInteractionEnabled = YES;
    }
}

@end
