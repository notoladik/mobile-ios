#import <UIKit/UIKit.h>

@interface VKImageLoader : NSObject

@property (nonatomic, assign) unsigned long long maxDiskCacheBytes;

+ (instancetype)sharedLoader;

- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion;

- (UIImage *)cachedImageInMemoryForURL:(NSString *)urlString;
- (BOOL)isImageCachedOnDiskForURL:(NSString *)urlString;
- (NSString *)diskPathForURL:(NSString *)urlString;

- (unsigned long long)diskCacheSizeBytes;
- (NSUInteger)diskCacheFilesCount;

- (void)clearMemoryCache;
- (void)clearDiskCache;
- (void)clearCache;
- (void)pruneCacheIfNeeded;

@end
