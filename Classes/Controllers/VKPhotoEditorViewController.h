#import <UIKit/UIKit.h>

typedef void(^VKPhotoEditorCompletionBlock)(UIImage *editedImage);

@interface VKPhotoEditorViewController : UIViewController

@property (nonatomic, copy) VKPhotoEditorCompletionBlock onImageEdited;

- (instancetype)initWithImage:(UIImage *)image;

@end
