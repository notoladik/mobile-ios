#import <UIKit/UIKit.h>

@interface VKImageLoader : NSObject

+ (instancetype)sharedLoader;
- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion;
- (void)clearCache;

@end
