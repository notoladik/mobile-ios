#import <UIKit/UIKit.h>

@interface VKLoginViewController : UIViewController <UITextFieldDelegate, UIActionSheetDelegate>

@property (nonatomic, strong) UITextField *usernameField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *serverButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@end
