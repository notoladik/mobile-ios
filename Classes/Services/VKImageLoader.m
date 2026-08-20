#import "VKImageLoader.h"

@interface VKImageLoader ()
@property (nonatomic, strong) NSCache *cache;
@end

@implementation VKImageLoader

+ (instancetype)sharedLoader {
    static VKImageLoader *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 150;
    }
    return self;
}

- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion {
    if (!urlString || urlString.length == 0) {
        if (completion) completion(nil);
        return;
    }
    
    UIImage *cached = [self.cache objectForKey:urlString];
    if (cached) {
        if (completion) completion(cached);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (completion) completion(nil);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            UIImage *img = [UIImage imageWithData:data];
            if (img) {
                [self.cache setObject:img forKey:urlString];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(img);
                });
                return;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil);
        });
    });
}

- (void)clearCache {
    [self.cache removeAllObjects];
}

@end
