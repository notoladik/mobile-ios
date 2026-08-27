#import <UIKit/UIKit.h>

/**
 * VKAnimatedImageView — UIImageView subclass that decodes and plays animated GIFs
 * using Apple's ImageIO framework. No third-party dependencies.
 */
@interface VKAnimatedImageView : UIImageView

@property (nonatomic, readonly) BOOL isAnimatingGIF;
@property (nonatomic, readonly) BOOL isGIFLoaded;

- (void)loadGIFFromURL:(NSString *)gifURL previewURL:(NSString *)previewURL;
- (void)loadGIFFromData:(NSData *)data;
- (void)startGIFAnimation;
- (void)pauseGIFAnimation;
- (void)stopGIFAnimation;
- (void)resetGIF;

@end
