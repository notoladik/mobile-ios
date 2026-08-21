#import <UIKit/UIKit.h>

@interface VKAudioListViewController : UIViewController

- (instancetype)initWithUserId:(NSInteger)userId;
- (instancetype)initWithUserId:(NSInteger)userId albumId:(NSInteger)albumId albumTitle:(NSString *)albumTitle;

@end
