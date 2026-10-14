#import <UIKit/UIKit.h>
#import "VKThemeManager.h"

@interface VKClientDesignSettingsViewController : UITableViewController <UIActionSheetDelegate>
- (instancetype)initWithTheme:(VKThemeType)theme;
@end
