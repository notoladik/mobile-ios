#import <UIKit/UIKit.h>
#import "VKAttachment.h"

/**
 * VKGifViewerViewController — fullscreen GIF viewer with swipe-down dismiss.
 * Shows an animated GIF loaded from a VKAttachment or plain URL.
 */
@interface VKGifViewerViewController : UIViewController

- (instancetype)initWithAttachment:(VKAttachment *)attachment;
- (instancetype)initWithGIFURL:(NSString *)gifURL previewURL:(NSString *)previewURL title:(NSString *)title;

@end
