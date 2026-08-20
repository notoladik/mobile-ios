#import "VKNewPostViewController.h"
#import "VKFeedService.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"

@interface VKNewPostViewController ()
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@end

@implementation VKNewPostViewController

- (instancetype)initWithOwnerId:(NSInteger)ownerId {
    self = [super init];
    if (self) {
        _ownerId = ownerId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Новая запись";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Опубликовать" style:UIBarButtonItemStyleDone target:self action:@selector(publishAction)];
    
    CGFloat width = self.view.bounds.size.width;
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(16, 16, width - 32, 220)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textView.font = [UIFont systemFontOfSize:17];
    self.textView.delegate = self;
    [self.view addSubview:self.textView];
    
    self.placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(22, 24, width - 44, 22)];
    self.placeholderLabel.text = @"Что у вас нового?";
    self.placeholderLabel.font = [UIFont systemFontOfSize:17];
    self.placeholderLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    [self.view addSubview:self.placeholderLabel];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.center = CGPointMake(width / 2.0, 120);
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [self.textView becomeFirstResponder];
}

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
}

- (void)cancelAction {
    [self.textView resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)publishAction {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.activityIndicator startAnimating];
    
    NSInteger targetOwner = self.ownerId;
    if (targetOwner == 0) {
        targetOwner = [[VKAuthService sharedService] currentUserModel].uid;
    }
    
    [VKCrashLogger log:@"[VKNewPostViewController] Publishing post to ownerId=%ld...", (long)targetOwner];
    
    [[VKFeedService sharedService] createPostWithText:text ownerId:targetOwner fromGroup:NO completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.navigationItem.rightBarButtonItem.enabled = YES;
            
            if (success) {
                [VKCrashLogger log:@"[VKNewPostViewController] Post published successfully!"];
                if (self.onPostCreated) self.onPostCreated();
                [self.textView resignFirstResponder];
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Не удалось опубликовать запись" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
        });
    }];
}

@end
