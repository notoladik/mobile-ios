#import "VKLoginViewController.h"
#import "VKAuthService.h"
#import "VKAppConfig.h"
#import "VKCrashLogger.h"
#import <QuartzCore/QuartzCore.h>

@interface VKLoginViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIButton *instanceButton;
@property (nonatomic, strong) UIButton *togglePasswordButton;

@property (nonatomic, strong) UILabel *disclaimerLabel;
@end

@implementation VKLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [VKCrashLogger log:@"[VKLoginViewController] viewDidLoad started."];
    
    self.title = @"OpenVK";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.scrollView addGestureRecognizer:tap];
    
    // — Компактная шапка: лого + заголовок в одну строку —
    self.logoImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.logoImageView.image = [UIImage imageNamed:@"logo.png"] ?: [UIImage imageNamed:@"Icon.png"];
    self.logoImageView.layer.cornerRadius = 10.0;
    self.logoImageView.clipsToBounds = YES;
    [self.scrollView addSubview:self.logoImageView];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"Welcome to OpenVK";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.titleLabel.textAlignment = NSTextAlignmentLeft;
    self.titleLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
    [self.scrollView addSubview:self.titleLabel];
    
    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.text = @"Open source social network inspired by VK";
    self.subtitleLabel.font = [UIFont systemFontOfSize:12];
    self.subtitleLabel.textAlignment = NSTextAlignmentLeft;
    self.subtitleLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    self.subtitleLabel.numberOfLines = 1;
    [self.scrollView addSubview:self.subtitleLabel];
    
    // — Карточка формы —
    self.cardView = [[UIView alloc] initWithFrame:CGRectZero];
    self.cardView.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:245.0/255.0 blue:247.0/255.0 alpha:1.0];
    self.cardView.layer.cornerRadius = 12.0;
    self.cardView.clipsToBounds = YES;
    [self.scrollView addSubview:self.cardView];
    
    // Instance button
    self.instanceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.instanceButton setTitleColor:[UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.instanceButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.instanceButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.instanceButton addTarget:self action:@selector(selectInstanceAction) forControlEvents:UIControlEventTouchUpInside];
    [self updateInstanceTitle];
    [self.cardView addSubview:self.instanceButton];
    
    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectZero];
    sep1.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    sep1.tag = 101;
    [self.cardView addSubview:sep1];
    
    // Username Field
    self.usernameField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.usernameField.placeholder = @"Email или логин";
    self.usernameField.font = [UIFont systemFontOfSize:15];
    self.usernameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.usernameField.returnKeyType = UIReturnKeyNext;
    self.usernameField.delegate = self;
    [self.cardView addSubview:self.usernameField];
    
    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectZero];
    sep2.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    sep2.tag = 102;
    [self.cardView addSubview:sep2];
    
    // Password Field
    self.passwordField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.passwordField.placeholder = @"Пароль";
    self.passwordField.font = [UIFont systemFontOfSize:15];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    self.passwordField.delegate = self;
    [self.cardView addSubview:self.passwordField];
    
    // Login Button — сразу под карточкой
    self.loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginButton.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    self.loginButton.layer.cornerRadius = 12.0;
    self.loginButton.clipsToBounds = YES;
    [self.loginButton setTitle:@"Войти" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.loginButton addTarget:self action:@selector(loginAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.loginButton];
    
    // 2FA Code Field (hidden by default)
    self.codeField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.codeField.placeholder = @"Код 2FA (если включен)";
    self.codeField.borderStyle = UITextBorderStyleRoundedRect;
    self.codeField.keyboardType = UIKeyboardTypeNumberPad;
    self.codeField.hidden = YES;
    self.codeField.delegate = self;
    [self.scrollView addSubview:self.codeField];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityIndicator.hidesWhenStopped = YES;
    [self.loginButton addSubview:self.activityIndicator];
    
    // Disclaimer — одна строка, внизу
    self.disclaimerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.disclaimerLabel.text = @"OpenVK — любительский проект, не связанный с VK LLC.";
    self.disclaimerLabel.font = [UIFont systemFontOfSize:11];
    self.disclaimerLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    self.disclaimerLabel.textAlignment = NSTextAlignmentCenter;
    self.disclaimerLabel.numberOfLines = 1;
    self.disclaimerLabel.adjustsFontSizeToFitWidth = YES;
    [self.scrollView addSubview:self.disclaimerLabel];
    
    // — Подписка на клавиатуру —
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(keyboardWillShow:)
        name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(keyboardWillHide:)
        name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Keyboard handling

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat kbH = kbFrame.size.height;
    UIEdgeInsets insets = UIEdgeInsetsMake(0, 0, kbH, 0);
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
    // Scroll active field into view
    UIView *activeField = nil;
    if ([self.usernameField isFirstResponder]) activeField = self.usernameField;
    else if ([self.passwordField isFirstResponder]) activeField = self.passwordField;
    else if ([self.codeField isFirstResponder]) activeField = self.codeField;
    if (activeField) {
        CGRect fieldRect = [self.scrollView convertRect:activeField.frame fromView:activeField.superview];
        // Also scroll login button into view
        CGRect btnRect = self.loginButton.frame;
        CGRect targetRect = CGRectUnion(fieldRect, btnRect);
        targetRect = CGRectInset(targetRect, 0, -12);
        [self.scrollView scrollRectToVisible:targetRect animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

#pragma mark - Instance picker

- (void)updateInstanceTitle {
    [self.instanceButton setTitle:[NSString stringWithFormat:@"Инстанция:  %@  ▾", [VKAppConfig currentHost]] forState:UIControlStateNormal];
}

- (void)selectInstanceAction {
    NSArray *instances = [VKAppConfig availableInstances];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Выберите инстанс OpenVK"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    for (NSString *inst in instances) {
        [sheet addButtonWithTitle:inst];
    }
    [sheet addButtonWithTitle:@"Отмена"];
    sheet.cancelButtonIndex = instances.count;
    sheet.tag = 301;
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 301) {
        NSArray *instances = [VKAppConfig availableInstances];
        if (buttonIndex >= 0 && buttonIndex < (NSInteger)instances.count) {
            [VKAppConfig setCurrentHost:instances[buttonIndex]];
            [self updateInstanceTitle];
        }
    }
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat hPad = 20.0;                      // горизонтальный отступ
    CGFloat contentW = width - hPad * 2.0;    // ширина контента
    
    // — Компактная шапка: лого 44pt слева + заголовок справа —
    CGFloat logoSize = 44.0;
    CGFloat headerTop = 14.0;
    self.logoImageView.frame = CGRectMake(hPad, headerTop, logoSize, logoSize);
    
    CGFloat titleX = hPad + logoSize + 10.0;
    CGFloat titleW = width - titleX - hPad;
    self.titleLabel.frame = CGRectMake(titleX, headerTop + 2.0, titleW, 22.0);
    self.subtitleLabel.frame = CGRectMake(titleX, headerTop + 26.0, titleW, 16.0);
    
    // — Карточка формы — сразу под шапкой —
    CGFloat cardTop = headerTop + logoSize + 10.0;
    CGFloat rowH = 46.0;
    CGFloat cardH = rowH * 3.0; // 3 строки: инстанция, логин, пароль
    self.cardView.frame = CGRectMake(hPad, cardTop, contentW, cardH);
    
    self.instanceButton.frame = CGRectMake(14, 0, contentW - 28.0, rowH);
    [self.cardView viewWithTag:101].frame = CGRectMake(14, rowH, contentW - 14.0, 0.5);
    self.usernameField.frame = CGRectMake(14, rowH + 0.5, contentW - 28.0, rowH);
    [self.cardView viewWithTag:102].frame = CGRectMake(14, rowH * 2.0 + 0.5, contentW - 14.0, 0.5);
    self.passwordField.frame = CGRectMake(14, rowH * 2.0 + 1.0, contentW - 28.0, rowH - 1.0);
    
    // — Кнопка «Войти» — сразу под карточкой (10pt отступ) —
    CGFloat btnTop = cardTop + cardH + 10.0;
    CGFloat btnH = 46.0;
    self.loginButton.frame = CGRectMake(hPad, btnTop, contentW, btnH);
    self.activityIndicator.center = CGPointMake(contentW / 2.0, btnH / 2.0);
    
    // — 2FA поле — под кнопкой (показывается при необходимости) —
    self.codeField.frame = CGRectMake(hPad, btnTop + btnH + 10.0, contentW, 40.0);
    
    // — Disclaimer — под 2FA —
    CGFloat disclaimerTop = btnTop + btnH + (self.codeField.hidden ? 14.0 : 62.0);
    self.disclaimerLabel.frame = CGRectMake(hPad, disclaimerTop, contentW, 16.0);
    
    CGFloat totalH = disclaimerTop + 16.0 + 16.0;
    self.scrollView.contentSize = CGSizeMake(width, MAX(totalH, self.view.bounds.size.height));
}

#pragma mark - Actions

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)loginAction:(id)sender {
    NSString *username = [self.usernameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text;
    NSString *code = [self.codeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (username.length == 0 || password.length == 0) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                        message:@"Введите логин и пароль"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    [self.activityIndicator startAnimating];
    [self.loginButton setTitle:@"" forState:UIControlStateNormal];
    self.loginButton.userInteractionEnabled = NO;
    
    [VKCrashLogger log:@"[VKLoginViewController] Logging in username='%@'...", username];
    
    [[VKAuthService sharedService] loginWithUsername:username password:password code:code completion:^(BOOL success, NSString *errorMsg, BOOL need2FA) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            [self.loginButton setTitle:@"Войти" forState:UIControlStateNormal];
            self.loginButton.userInteractionEnabled = YES;
            
            if (need2FA) {
                self.codeField.hidden = NO;
                [self.view setNeedsLayout];
                [self.view layoutIfNeeded];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Двухфакторная защита"
                                                                message:@"Введите полученный код подтверждения в поле ниже"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
                [self.codeField becomeFirstResponder];
                return;
            }
            
            if (!success) {
                [VKCrashLogger log:@"[VKLoginViewController] Login failed: %@", errorMsg];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка входа"
                                                                message:errorMsg ?: @"Не удалось войти"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            } else {
                [VKCrashLogger log:@"[VKLoginViewController] Login successful!"];
            }
        });
    }];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.usernameField) {
        [self.passwordField becomeFirstResponder];
    } else if (textField == self.passwordField) {
        [self loginAction:nil];
    } else {
        [textField resignFirstResponder];
    }
    return YES;
}

@end
