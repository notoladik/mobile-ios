#import "VKNavigationController.h"
#import "VKThemeManager.h"

@implementation VKNavigationController
- (UIStatusBarStyle)preferredStatusBarStyle {
    VKThemeManager *tm = [VKThemeManager sharedManager];
    if ([tm isKateTheme] || [tm isAndroidTheme]) {
        CGFloat white = 1.0, alpha = 1.0;
        [tm.navBarTitleColor getWhite:&white alpha:&alpha];
        return white > 0.5 ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
    }
    return [super preferredStatusBarStyle];
}


- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.interactivePopGestureRecognizer.delegate = self;
    }
    [self updateNavBarTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNavBarTheme) name:VKThemeDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateNavBarTheme];
}

- (void)updateNavBarTheme {
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) [self setNeedsStatusBarAppearanceUpdate];
    VKThemeManager *tm = [VKThemeManager sharedManager];
    UINavigationBar *bar = self.navigationBar;
    if (!bar) return;
    
    BOOL hasBarTintColor = [bar respondsToSelector:@selector(setBarTintColor:)];
    if ([tm isSkeuomorphic]) {
        bar.barStyle = UIBarStyleBlack;
        UIImage *navImg = [tm navBarBackgroundImageForHeight:64.0];
        [bar setBackgroundImage:navImg forBarMetrics:UIBarMetricsDefault];
        bar.tintColor = [UIColor whiteColor];
        
        NSShadow *navShadow = [[NSShadow alloc] init];
        navShadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        navShadow.shadowOffset = CGSizeMake(0, -1);
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18],
            NSShadowAttributeName: navShadow
        };
    } else if ([tm isClassicFlat]) {
        bar.barStyle = UIBarStyleDefault;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            bar.barTintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            bar.tintColor = [UIColor whiteColor];
        } else {
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        }
        if ([bar respondsToSelector:@selector(setTranslucent:)]) {
            bar.translucent = NO;
        }
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    } else if ([tm isAndroidTheme]) {
        self.navigationBar.barStyle = UIBarStyleBlack;
        [self.navigationBar setBackgroundImage:[tm navBarBackgroundImageForHeight:44] forBarMetrics:UIBarMetricsDefault];
        self.navigationBar.tintColor = [UIColor whiteColor];
        if ([self.navigationBar respondsToSelector:@selector(setBarTintColor:)]) self.navigationBar.barTintColor = tm.navBarBackgroundColor;
        self.navigationBar.translucent = NO;
        self.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName:[UIColor whiteColor], NSFontAttributeName:[UIFont systemFontOfSize:18]};
    } else if ([tm isKateTheme]) {
        UIColor *titleColor = tm.navBarTitleColor;
        CGFloat white = 1.0, alpha = 1.0;
        [titleColor getWhite:&white alpha:&alpha];
        bar.barStyle = white > 0.5 ? UIBarStyleBlack : UIBarStyleDefault;
        BOOL isIOS7 = [[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0;
        [[UIApplication sharedApplication] setStatusBarStyle:(isIOS7 ? (white > 0.5 ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault) : UIStatusBarStyleBlackOpaque) animated:NO];
        // A generated solid image preserves the palette on iOS 6 as well.
        [bar setBackgroundImage:[tm navBarBackgroundImageForHeight:44] forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            bar.barTintColor = tm.navBarBackgroundColor;
            bar.tintColor = tm.navBarTintColor;
        } else {
            bar.tintColor = tm.navBarBackgroundColor;
        }
        if ([bar respondsToSelector:@selector(setTranslucent:)]) bar.translucent = NO;
        if ([bar respondsToSelector:@selector(setShadowImage:)]) bar.shadowImage = [[UIImage alloc] init];
        bar.titleTextAttributes = @{NSForegroundColorAttributeName:titleColor, NSFontAttributeName:[UIFont systemFontOfSize:18]};
    } else {
        // Modern Swift
        bar.barStyle = UIBarStyleDefault;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            bar.barTintColor = [UIColor whiteColor];
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        } else {
            bar.tintColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        }
        if ([bar respondsToSelector:@selector(setTranslucent:)]) {
            bar.translucent = NO;
        }
        bar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
    }
}

@end
