#import <UIKit/UIKit.h>

extern NSString *const VKSideMenuStateDidChangeNotification;

@class VKSideMenuViewController;

@interface VKSideMenuManager : NSObject

@property (nonatomic, assign) BOOL isSideMenuEnabled;
@property (nonatomic, assign, readonly) BOOL isMenuOpen;
@property (nonatomic, strong, readonly) VKSideMenuViewController *sideMenuViewController;

+ (instancetype)sharedManager;

- (void)setupWithRootWindow:(UIWindow *)window;
- (void)toggleMenu;
- (void)openMenu;
- (void)closeMenuAnimated:(BOOL)animated completion:(void (^)(void))completion;
- (void)navigateToIndex:(NSInteger)index;

@end
