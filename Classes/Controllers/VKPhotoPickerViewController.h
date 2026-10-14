#import <UIKit/UIKit.h>

@class VKPhotoPickerViewController;

@protocol VKPhotoPickerDelegate <NSObject>
- (void)photoPicker:(VKPhotoPickerViewController *)picker didSelectAttachments:(NSArray<NSDictionary *> *)attachments;
@end

@interface VKPhotoPickerViewController : UIViewController

@property (nonatomic, weak) id<VKPhotoPickerDelegate> delegate;
@property (nonatomic, assign) NSInteger maxSelectionCount;

- (instancetype)initWithUserId:(NSInteger)userId;

@end
