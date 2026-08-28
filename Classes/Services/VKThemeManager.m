#import "VKThemeManager.h"

NSString *const VKThemeDidChangeNotification = @"VKThemeDidChangeNotification";
static NSString *const kOpenVKThemeKey = @"openvk.app_theme";

@implementation VKThemeManager

+ (instancetype)sharedManager {
    static VKThemeManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSInteger saved = [[NSUserDefaults standardUserDefaults] integerForKey:kOpenVKThemeKey];
        if (saved >= 0 && saved <= 2) {
            _currentTheme = (VKThemeType)saved;
        } else {
            _currentTheme = VKThemeTypeModernSwift;
        }
    }
    return self;
}

- (NSString *)nameForTheme:(VKThemeType)type {
    switch (type) {
        case VKThemeTypeModernSwift: return @"Swift";
        case VKThemeTypeClassicUIKit: return @"UIKit";
        case VKThemeTypeiOS6Legacy: return @"iOS 6";
    }
}

- (NSString *)eraDescriptionForTheme:(VKThemeType)type {
    switch (type) {
        case VKThemeTypeModernSwift: return @"жесть навайбкожено";
        case VKThemeTypeClassicUIKit: return @"Артёмий Лебедев.";
        case VKThemeTypeiOS6Legacy: return @"Стиф жопс.";
    }
}

- (void)applyTheme:(VKThemeType)type {
    _currentTheme = type;
    [[NSUserDefaults standardUserDefaults] setInteger:type forKey:kOpenVKThemeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    BOOL hasBarTintColor = [[UINavigationBar appearance] respondsToSelector:@selector(setBarTintColor:)];
    BOOL isIOS7 = ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0);
    
    if (type == VKThemeTypeClassicUIKit) {
        if (isIOS7) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
        } else {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
        }
        [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
        [[UINavigationBar appearance] setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
            [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        } else {
            [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
        }
        if ([[UINavigationBar appearance] respondsToSelector:@selector(setTranslucent:)]) {
            [[UINavigationBar appearance] setTranslucent:NO];
        }
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        }];
        if ([UIBarButtonItem respondsToSelector:@selector(appearanceWhenContainedIn:)]) {
            [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil] setTintColor:[UIColor whiteColor]];
        }
        [[UITabBar appearance] setBackgroundImage:nil];
        if (hasBarTintColor) {
            [[UITabBar appearance] setBarTintColor:[UIColor colorWithWhite:0.98 alpha:1.0]];
        }
        [[UITabBar appearance] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
    } else if (type == VKThemeTypeiOS6Legacy) {
        if (isIOS7) {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
        } else {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
        }
        [[UINavigationBar appearance] setBarStyle:UIBarStyleBlack];
        UIImage *navImg = [self navBarBackgroundImageForHeight:64.0];
        [[UINavigationBar appearance] setBackgroundImage:navImg forBarMetrics:UIBarMetricsDefault];
        [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];
        
        NSShadow *navShadow = [[NSShadow alloc] init];
        navShadow.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        navShadow.shadowOffset = CGSizeMake(0, -1);
        
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18],
            NSShadowAttributeName: navShadow
        }];
        [[UITabBar appearance] setBackgroundImage:[self tabBarBackgroundImage]];
        [[UITabBar appearance] setTintColor:[UIColor colorWithRed:120.0/255.0 green:165.0/255.0 blue:235.0/255.0 alpha:1.0]];
    } else {
        // Modern Swift
        [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
        [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
        [[UINavigationBar appearance] setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (hasBarTintColor) {
            [[UINavigationBar appearance] setBarTintColor:[UIColor whiteColor]];
            [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
        } else {
            [[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
        }
        [[UINavigationBar appearance] setTitleTextAttributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        }];
        if ([UIBarButtonItem respondsToSelector:@selector(appearanceWhenContainedIn:)]) {
            [[UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
        }
        [[UITabBar appearance] setBackgroundImage:nil];
        if (hasBarTintColor) {
            [[UITabBar appearance] setBarTintColor:[UIColor whiteColor]];
        }
        [[UITabBar appearance] setTintColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VKThemeDidChangeNotification object:nil];
    });
}

#pragma mark - Colors & Metrics

- (UIColor *)accentColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            return [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0]; // #2B587A
    }
}

- (UIColor *)backgroundColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:240.0/255.0 green:242.0/255.0 blue:245.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            // Аутентичный полосатый льняной фон!
            return [UIColor colorWithPatternImage:[self stripedLinenPatternImage]];
    }
}

- (UIColor *)cardBackgroundColor {
    return [UIColor whiteColor];
}

- (UIColor *)cardBorderColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor clearColor];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:225.0/255.0 green:227.0/255.0 blue:232.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            return [UIColor colorWithRed:185.0/255.0 green:190.0/255.0 blue:198.0/255.0 alpha:1.0];
    }
}

- (UIColor *)navBarBackgroundColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor whiteColor];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            return [UIColor colorWithRed:55.0/255.0 green:80.0/255.0 blue:125.0/255.0 alpha:1.0];
    }
}

- (UIColor *)navBarTitleColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor whiteColor];
        case VKThemeTypeiOS6Legacy:
            return [UIColor whiteColor];
    }
}

- (UIColor *)navBarTintColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor whiteColor];
        case VKThemeTypeiOS6Legacy:
            return [UIColor whiteColor];
    }
}

- (UIColor *)tabBarTintColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            return [UIColor colorWithRed:120.0/255.0 green:165.0/255.0 blue:235.0/255.0 alpha:1.0];
    }
}

- (UIColor *)secondaryTextColor {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift:
            return [UIColor colorWithRed:128.0/255.0 green:134.0/255.0 blue:144.0/255.0 alpha:1.0];
        case VKThemeTypeClassicUIKit:
            return [UIColor colorWithRed:140.0/255.0 green:145.0/255.0 blue:155.0/255.0 alpha:1.0];
        case VKThemeTypeiOS6Legacy:
            return [UIColor colorWithRed:135.0/255.0 green:140.0/255.0 blue:150.0/255.0 alpha:1.0];
    }
}

- (UIColor *)separatorColor {
    return [UIColor colorWithRed:220.0/255.0 green:223.0/255.0 blue:228.0/255.0 alpha:1.0];
}

- (CGFloat)cardCornerRadius {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift: return 14.0;
        case VKThemeTypeClassicUIKit: return 0.0;
        case VKThemeTypeiOS6Legacy: return 0.0;
    }
}

- (CGFloat)cardHorizontalMargin {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift: return 10.0;
        case VKThemeTypeClassicUIKit: return 0.0;
        case VKThemeTypeiOS6Legacy: return 0.0;
    }
}

- (CGFloat)avatarCornerRadiusForSize:(CGFloat)size {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift: return size / 2.0;
        case VKThemeTypeClassicUIKit: return size / 2.0;
        case VKThemeTypeiOS6Legacy: return 4.0;
    }
}

- (CGFloat)avatarBorderWidth {
    switch (self.currentTheme) {
        case VKThemeTypeModernSwift: return 0.0;
        case VKThemeTypeClassicUIKit: return 0.0;
        case VKThemeTypeiOS6Legacy: return 0.5;
    }
}

- (UIColor *)avatarBorderColor {
    return [UIColor colorWithWhite:0.0 alpha:0.2];
}

- (BOOL)isSkeuomorphic { return self.currentTheme == VKThemeTypeiOS6Legacy; }
- (BOOL)isClassicFlat { return self.currentTheme == VKThemeTypeClassicUIKit; }
- (BOOL)isModern { return self.currentTheme == VKThemeTypeModernSwift; }

- (UIFont *)titleFontOfSize:(CGFloat)size {
    return [UIFont boldSystemFontOfSize:size];
}

- (UIFont *)bodyFontOfSize:(CGFloat)size {
    return [UIFont systemFontOfSize:size];
}

- (UIColor *)textShadowColor {
    if (self.isSkeuomorphic) {
        return [UIColor colorWithWhite:1.0 alpha:0.8];
    }
    return [UIColor clearColor];
}

- (CGSize)textShadowOffset {
    if (self.isSkeuomorphic) {
        return CGSizeMake(0, 1);
    }
    return CGSizeZero;
}

#pragma mark - Epoch Visual Generators

- (UIImage *)stripedLinenPatternImage {
    CGSize size = CGSizeMake(16, 16);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [[UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, 16, 16));
    
    [[UIColor colorWithRed:207.0/255.0 green:210.0/255.0 blue:217.0/255.0 alpha:1.0] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, 8, 16));
    
    [[UIColor colorWithWhite:1.0 alpha:0.18] setFill];
    CGContextFillRect(ctx, CGRectMake(0, 0, 1, 16));
    CGContextFillRect(ctx, CGRectMake(8, 0, 1, 16));
    
    [[UIColor colorWithWhite:0.0 alpha:0.06] setFill];
    CGContextFillRect(ctx, CGRectMake(7, 0, 1, 16));
    CGContextFillRect(ctx, CGRectMake(15, 0, 1, 16));
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)navBarBackgroundImageForHeight:(CGFloat)height {
    if (height <= 0) height = 64.0;
    CGSize size = CGSizeMake(320, height);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[4] = {0.0, 0.49, 0.50, 1.0};
    CGFloat components[16] = {
        0.36, 0.48, 0.68, 1.0,
        0.26, 0.38, 0.58, 1.0,
        0.20, 0.32, 0.52, 1.0,
        0.16, 0.27, 0.46, 1.0
    };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 4);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.30].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 320, 1.0));
    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithRed:0.08 green:0.16 blue:0.28 alpha:1.0].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, height - 1.0, 320, 1.0));
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)tabBarBackgroundImage {
    CGSize size = CGSizeMake(320, 49);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[2] = {0.0, 1.0};
    CGFloat components[8] = {
        0.18, 0.18, 0.20, 1.0,
        0.08, 0.08, 0.09, 1.0
    };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, locations, 2);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, 49), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.2].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, 320, 1.0));
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)tabBarIconForIndex:(NSInteger)index {
    CGSize size = CGSizeMake(26, 26);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    if (self.isSkeuomorphic) {
        [[UIColor whiteColor] setStroke];
        [[UIColor whiteColor] setFill];
        CGContextSetLineWidth(ctx, 2.0);
    } else {
        [[UIColor grayColor] setStroke];
        [[UIColor grayColor] setFill];
        CGContextSetLineWidth(ctx, 1.5);
    }
    
    if (index == 0) {
        UIBezierPath *roof = [UIBezierPath bezierPath];
        [roof moveToPoint:CGPointMake(13, 3)];
        [roof addLineToPoint:CGPointMake(3, 12)];
        [roof addLineToPoint:CGPointMake(6, 12)];
        [roof addLineToPoint:CGPointMake(6, 22)];
        [roof addLineToPoint:CGPointMake(20, 22)];
        [roof addLineToPoint:CGPointMake(20, 12)];
        [roof addLineToPoint:CGPointMake(23, 12)];
        [roof closePath];
        if (self.isSkeuomorphic) [roof fill]; else [roof stroke];
    } else if (index == 1) {
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 14, 14)];
        [circle stroke];
        CGContextSetLineWidth(ctx, self.isSkeuomorphic ? 3.0 : 2.0);
        CGContextMoveToPoint(ctx, 15, 15);
        CGContextAddLineToPoint(ctx, 23, 23);
        CGContextStrokePath(ctx);
    } else if (index == 2) {
        UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, 22, 16) cornerRadius:5];
        if (self.isSkeuomorphic) {
            [bubble fill];
            UIBezierPath *tail = [UIBezierPath bezierPath];
            [tail moveToPoint:CGPointMake(6, 19)];
            [tail addLineToPoint:CGPointMake(3, 24)];
            [tail addLineToPoint:CGPointMake(12, 19)];
            [tail closePath];
            [tail fill];
        } else {
            [bubble stroke];
            CGContextMoveToPoint(ctx, 6, 19);
            CGContextAddLineToPoint(ctx, 4, 23);
            CGContextAddLineToPoint(ctx, 11, 19);
            CGContextStrokePath(ctx);
        }
    } else if (index == 3) {
        CGFloat r = self.isSkeuomorphic ? 2.0 : 1.5;
        UIBezierPath *b1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 3, 8, 8) cornerRadius:r];
        UIBezierPath *b2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(15, 3, 8, 8) cornerRadius:r];
        UIBezierPath *b3 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 15, 8, 8) cornerRadius:r];
        UIBezierPath *b4 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(15, 15, 8, 8) cornerRadius:r];
        if (self.isSkeuomorphic) {
            [b1 fill]; [b2 fill]; [b3 fill]; [b4 fill];
        } else {
            [b1 stroke]; [b2 stroke]; [b3 stroke]; [b4 stroke];
        }
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)skeuomorphicButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted {
    if (width <= 0) width = 60;
    if (height <= 0) height = 28;
    CGSize size = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectMake(0.5, 0.5, width - 1.0, height - 1.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:4.0];
    [path addClip];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[2] = {0.0, 1.0};
    CGFloat componentsNormal[8] = {
        0.98, 0.98, 0.99, 1.0,
        0.89, 0.91, 0.93, 1.0
    };
    CGFloat componentsPressed[8] = {
        0.80, 0.82, 0.86, 1.0,
        0.90, 0.92, 0.95, 1.0
    };
    
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, highlighted ? componentsPressed : componentsNormal, locations, 2);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    [[UIColor colorWithRed:0.72 green:0.75 blue:0.80 alpha:1.0] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6) resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)skeuomorphicNavBarButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted {
    if (width <= 0) width = 50;
    if (height <= 0) height = 30;
    CGSize size = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectMake(0.5, 0.5, width - 1.0, height - 1.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:4.5];
    [path addClip];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[4] = {0.0, 0.49, 0.50, 1.0};
    CGFloat componentsNorm[16] = {
        0.42, 0.54, 0.72, 1.0,
        0.30, 0.42, 0.62, 1.0,
        0.24, 0.36, 0.55, 1.0,
        0.20, 0.30, 0.48, 1.0
    };
    CGFloat componentsPress[16] = {
        0.20, 0.30, 0.48, 1.0,
        0.24, 0.36, 0.55, 1.0,
        0.30, 0.42, 0.62, 1.0,
        0.42, 0.54, 0.72, 1.0
    };
    
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, highlighted ? componentsPress : componentsNorm, locations, 4);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha:0.35].CGColor);
    CGContextFillRect(ctx, CGRectMake(0, 0, width, 1.0));
    
    [[UIColor colorWithRed:0.14 green:0.23 blue:0.35 alpha:1.0] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(6, 6, 6, 6) resizingMode:UIImageResizingModeStretch];
}

- (UIImage *)skeuomorphicBackBarButtonImageWithWidth:(CGFloat)width height:(CGFloat)height highlighted:(BOOL)highlighted {
    if (width <= 0) width = 60;
    if (height <= 0) height = 30;
    CGSize size = CGSizeMake(width, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(12, 1)];
    [path addLineToPoint:CGPointMake(width - 4, 1)];
    [path addArcWithCenter:CGPointMake(width - 4, 5) radius:4 startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(width, height - 5)];
    [path addArcWithCenter:CGPointMake(width - 4, height - 5) radius:4 startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(12, height - 1)];
    [path addLineToPoint:CGPointMake(1, height / 2.0)];
    [path closePath];
    [path addClip];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[4] = {0.0, 0.49, 0.50, 1.0};
    CGFloat componentsNorm[16] = {
        0.42, 0.54, 0.72, 1.0,
        0.30, 0.42, 0.62, 1.0,
        0.24, 0.36, 0.55, 1.0,
        0.20, 0.30, 0.48, 1.0
    };
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, componentsNorm, locations, 4);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(0, height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    
    [[UIColor colorWithRed:0.14 green:0.23 blue:0.35 alpha:1.0] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 14, 0, 6) resizingMode:UIImageResizingModeStretch];
}

- (UIBarButtonItem *)barButtonItemWithTitle:(NSString *)title target:(id)target action:(SEL)action isBack:(BOOL)isBack {
    if (self.isSkeuomorphic) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        CGSize titleSize = [title sizeWithFont:[UIFont boldSystemFontOfSize:12]];
        CGFloat btnW = MAX(44.0, ceilf(titleSize.width) + (isBack ? 24.0 : 16.0));
        btn.frame = CGRectMake(0, 0, btnW, 30);
        
        UIImage *bg = isBack ? [self skeuomorphicBackBarButtonImageWithWidth:btnW height:30 highlighted:NO]
                             : [self skeuomorphicNavBarButtonImageWithWidth:btnW height:30 highlighted:NO];
        UIImage *bgPress = isBack ? [self skeuomorphicBackBarButtonImageWithWidth:btnW height:30 highlighted:YES]
                                  : [self skeuomorphicNavBarButtonImageWithWidth:btnW height:30 highlighted:YES];
        
        [btn setBackgroundImage:bg forState:UIControlStateNormal];
        [btn setBackgroundImage:bgPress forState:UIControlStateHighlighted];
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        btn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
        if (isBack) {
            btn.contentEdgeInsets = UIEdgeInsetsMake(0, 6, 0, 0);
        }
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:btn];
    } else {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action];
        if (self.isClassicFlat) {
            item.tintColor = [UIColor whiteColor];
        }
        return item;
    }
}

- (UIBarButtonItem *)navBarMenuBarButtonItemWithTarget:(id)target action:(SEL)action {
    if (self.isSkeuomorphic) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 36, 30);
        UIImage *bg = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:NO];
        UIImage *bgPress = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:YES];
        [btn setBackgroundImage:bg forState:UIControlStateNormal];
        [btn setBackgroundImage:bgPress forState:UIControlStateHighlighted];
        
        UIImage *menuImg = [UIImage imageNamed:@"7_menu_icon"];
        if (menuImg) {
            [btn setImage:menuImg forState:UIControlStateNormal];
        } else {
            [btn setTitle:@"≡" forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
            btn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.6];
            btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
        }
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:btn];
    } else {
        UIImage *menuImg = [UIImage imageNamed:@"7_menu_icon"];
        UIBarButtonItem *item = menuImg ? [[UIBarButtonItem alloc] initWithImage:menuImg style:UIBarButtonItemStylePlain target:target action:action] : [[UIBarButtonItem alloc] initWithTitle:@"≡" style:UIBarButtonItemStylePlain target:target action:action];
        if (self.isClassicFlat) {
            item.tintColor = [UIColor whiteColor];
        }
        return item;
    }
}

- (UIBarButtonItem *)navBarComposeBarButtonItemWithTarget:(id)target action:(SEL)action {
    if (self.isSkeuomorphic) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 36, 30);
        UIImage *bg = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:NO];
        UIImage *bgPress = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:YES];
        [btn setBackgroundImage:bg forState:UIControlStateNormal];
        [btn setBackgroundImage:bgPress forState:UIControlStateHighlighted];
        
        [btn setTitle:@"✎" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        btn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:btn];
    } else {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Запись" style:UIBarButtonItemStylePlain target:target action:action];
        if (self.isClassicFlat) {
            item.tintColor = [UIColor whiteColor];
        }
        return item;
    }
}

- (UIBarButtonItem *)navBarRefreshBarButtonItemWithTarget:(id)target action:(SEL)action {
    if (self.isSkeuomorphic) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(0, 0, 36, 30);
        UIImage *bg = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:NO];
        UIImage *bgPress = [self skeuomorphicNavBarButtonImageWithWidth:36 height:30 highlighted:YES];
        [btn setBackgroundImage:bg forState:UIControlStateNormal];
        [btn setBackgroundImage:bgPress forState:UIControlStateHighlighted];
        
        [btn setTitle:@"⟳" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        btn.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.6];
        btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:btn];
    } else {
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Обновить" style:UIBarButtonItemStylePlain target:target action:action];
        if (self.isClassicFlat) {
            item.tintColor = [UIColor whiteColor];
        }
        return item;
    }
}

#pragma mark - Reaction Icons

- (UIImage *)reactionCommentIconWithColor:(UIColor *)color {
    if (!color) color = [UIColor colorWithRed:120.0/255.0 green:125.0/255.0 blue:135.0/255.0 alpha:1.0];
    CGSize size = CGSizeMake(15, 14);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [color setFill];
    
    // Аккуратный диалоговый бабл со скошенным хвостиком
    UIBezierPath *bubble = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, 0.5, 14, 10) cornerRadius:3.0];
    [bubble fill];
    
    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(3, 10)];
    [tail addLineToPoint:CGPointMake(1, 13.5)];
    [tail addLineToPoint:CGPointMake(7, 10)];
    [tail closePath];
    [tail fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)reactionMegaphoneIconWithColor:(UIColor *)color {
    if (!color) color = [UIColor colorWithRed:120.0/255.0 green:125.0/255.0 blue:135.0/255.0 alpha:1.0];
    CGSize size = CGSizeMake(15, 14);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [color setFill];
    
    // Аутентичный силуэт рупора/мегафона (в точности как на скриншоте пользователя!)
    UIBezierPath *horn = [UIBezierPath bezierPath];
    [horn moveToPoint:CGPointMake(5, 4.5)];
    [horn addLineToPoint:CGPointMake(13.5, 1.5)];
    [horn addLineToPoint:CGPointMake(13.5, 12.5)];
    [horn addLineToPoint:CGPointMake(5, 9.5)];
    [horn closePath];
    [horn fill];
    
    UIBezierPath *base = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1, 4.5, 4.5, 5) cornerRadius:1.0];
    [base fill];
    
    UIBezierPath *handle = [UIBezierPath bezierPath];
    [handle moveToPoint:CGPointMake(6.5, 9.5)];
    [handle addLineToPoint:CGPointMake(5, 13.5)];
    [handle addLineToPoint:CGPointMake(7, 13.5)];
    [handle addLineToPoint:CGPointMake(8.5, 9.5)];
    [handle closePath];
    [handle fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)reactionHeartIconWithColor:(UIColor *)color filled:(BOOL)filled {
    if (!color) color = [UIColor colorWithRed:120.0/255.0 green:125.0/255.0 blue:135.0/255.0 alpha:1.0];
    CGSize size = CGSizeMake(15, 14);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    [color setFill];
    [color setStroke];
    
    UIBezierPath *heart = [UIBezierPath bezierPath];
    [heart moveToPoint:CGPointMake(7.5, 13)];
    [heart addCurveToPoint:CGPointMake(0.5, 5) controlPoint1:CGPointMake(4, 9.5) controlPoint2:CGPointMake(0.5, 7.5)];
    [heart addArcWithCenter:CGPointMake(4, 4) radius:3.5 startAngle:M_PI endAngle:0 clockwise:YES];
    [heart addArcWithCenter:CGPointMake(11, 4) radius:3.5 startAngle:M_PI endAngle:0 clockwise:YES];
    [heart addCurveToPoint:CGPointMake(7.5, 13) controlPoint1:CGPointMake(14.5, 7.5) controlPoint2:CGPointMake(11, 9.5)];
    [heart closePath];
    
    if (filled) {
        [heart fill];
    } else {
        [heart setLineWidth:1.5];
        [heart stroke];
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
