#import <UIKit/UIKit.h>

@interface VKNewPostViewController : UIViewController <UITextViewDelegate>

@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, copy) void (^onPostCreated)(void);

- (instancetype)initWithOwnerId:(NSInteger)ownerId;

@end
