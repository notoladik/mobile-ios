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
    
    // Logo
    self.logoImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.logoImageView.image = [UIImage imageNamed:@"logo.png"] ?: [UIImage imageNamed:@"Icon.png"];
    self.logoImageView.layer.cornerRadius = 16.0;
    self.logoImageView.clipsToBounds = YES;
    [self.scrollView addSubview:self.logoImageView];
    
    // Title & Subtitle
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"Welcome to OpenVK";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:26];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
    [self.scrollView addSubview:self.titleLabel];
    
    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.text = @"Not-yet-federated open source\nsocial network inspired by VK.";
    self.subtitleLabel.font = [UIFont systemFontOfSize:14];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    self.subtitleLabel.numberOfLines = 2;
    [self.scrollView addSubview:self.subtitleLabel];
    
    // Card Form
    self.cardView = [[UIView alloc] initWithFrame:CGRectZero];
    self.cardView.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:245.0/255.0 blue:247.0/255.0 alpha:1.0];
    self.cardView.layer.cornerRadius = 12.0;
    self.cardView.clipsToBounds = YES;
    [self.scrollView addSubview:self.cardView];
    
    // Instance button
    self.instanceButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.instanceButton setTitleColor:[UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.instanceButton.titleLabel.font = [UIFont systemFontOfSize:15];
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
    self.usernameField.font = [UIFont systemFontOfSize:16];
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
    self.passwordField.font = [UIFont systemFontOfSize:16];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.returnKeyType = UIReturnKeyGo;
    self.passwordField.delegate = self;
    [self.cardView addSubview:self.passwordField];
    
    // Login Button
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
    
    // Disclaimer
    self.disclaimerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.disclaimerLabel.text = @"OpenVK — любительский проект, никак не связанный с ВКонтакте и компанией VK LLC.";
    self.disclaimerLabel.font = [UIFont systemFontOfSize:11];
    self.disclaimerLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    self.disclaimerLabel.textAlignment = NSTextAlignmentCenter;
    self.disclaimerLabel.numberOfLines = 2;
    [self.scrollView addSubview:self.disclaimerLabel];
}

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

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat cardWidth = width - 48.0;
    
    self.logoImageView.frame = CGRectMake((width - 72) / 2.0, 36, 72, 72);
    self.titleLabel.frame = CGRectMake(24, 120, cardWidth, 32);
    self.subtitleLabel.frame = CGRectMake(24, 156, cardWidth, 40);
    
    self.cardView.frame = CGRectMake(24, 210, cardWidth, 140);
    
    self.instanceButton.frame = CGRectMake(16, 0, cardWidth - 32, 46);
    [self.cardView viewWithTag:101].frame = CGRectMake(16, 46, cardWidth - 16, 1);
    
    self.usernameField.frame = CGRectMake(16, 47, cardWidth - 32, 46);
    [self.cardView viewWithTag:102].frame = CGRectMake(16, 93, cardWidth - 16, 1);
    
    self.passwordField.frame = CGRectMake(16, 94, cardWidth - 32, 46);
    
    self.loginButton.frame = CGRectMake(24, 366, cardWidth, 50);
    self.activityIndicator.center = CGPointMake(cardWidth / 2.0, 25);
    
    self.codeField.frame = CGRectMake(24, 426, cardWidth, 44);
    self.disclaimerLabel.frame = CGRectMake(24, 480, cardWidth, 36);
    
    self.scrollView.contentSize = CGSizeMake(width, 540);
}

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
