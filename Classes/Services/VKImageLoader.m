#import "VKImageLoader.h"
#import "VKCrashLogger.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *VKMD5String(NSString *str) {
    if (!str || str.length == 0) return @"";
    const char *cStr = [str UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cStr, (CC_LONG)strlen(cStr), result);
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", result[i]];
    }
    return hash;
}

@interface VKImageLoader ()
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, copy) NSString *diskCachePath;
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSMutableDictionary *inFlightCallbacks;
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
        _memoryCache = [[NSCache alloc] init];
        _memoryCache.countLimit = 300;
        _memoryCache.totalCostLimit = 40 * 1024 * 1024; // 40 MB
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDir = (paths.count > 0) ? paths[0] : NSTemporaryDirectory();
        _diskCachePath = [cacheDir stringByAppendingPathComponent:@"ImageCache"];
        
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_diskCachePath isDirectory:&isDir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 4;
        
        _ioQueue = dispatch_queue_create("org.openvk.imageloader.io", DISPATCH_QUEUE_SERIAL);
        _inFlightCallbacks = [[NSMutableDictionary alloc] init];
        
        _maxDiskCacheBytes = 250ULL * 1024ULL * 1024ULL; // 250 MB
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleMemoryWarning)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
        
        // Фоновая очистка старых файлов при старте
        dispatch_async(_ioQueue, ^{
            [self pruneCacheIfNeeded];
        });
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleMemoryWarning {
    [self.memoryCache removeAllObjects];
}

- (NSString *)diskPathForURL:(NSString *)urlString {
    if (!urlString || urlString.length == 0) return nil;
    NSString *md5 = VKMD5String(urlString);
    return [self.diskCachePath stringByAppendingPathComponent:md5];
}

- (UIImage *)cachedImageInMemoryForURL:(NSString *)urlString {
    if (!urlString || urlString.length == 0) return nil;
    return [self.memoryCache objectForKey:urlString];
}

- (BOOL)isImageCachedOnDiskForURL:(NSString *)urlString {
    NSString *path = [self diskPathForURL:urlString];
    if (!path) return NO;
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (void)loadImageWithURL:(NSString *)urlString completion:(void (^)(UIImage *image))completion {
    if (!urlString || urlString.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
        return;
    }
    
    // 1. Проверка оперативной памяти (мгновенно)
    UIImage *memCached = [self.memoryCache objectForKey:urlString];
    if (memCached) {
        if (completion) {
            completion(memCached);
        }
        return;
    }
    
    // 2. Дедупликация: если этот URL уже качается, подписываемся на результат
    @synchronized (self.inFlightCallbacks) {
        NSMutableArray *callbacks = self.inFlightCallbacks[urlString];
        if (callbacks) {
            if (completion) {
                [callbacks addObject:[completion copy]];
            }
            return;
        }
        callbacks = [NSMutableArray array];
        if (completion) {
            [callbacks addObject:[completion copy]];
        }
        self.inFlightCallbacks[urlString] = callbacks;
    }
    
    // 3. Проверка дискового кэша на очереди I/O
    dispatch_async(self.ioQueue, ^{
        NSString *diskPath = [self diskPathForURL:urlString];
        if (diskPath && [[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
            NSData *diskData = [NSData dataWithContentsOfFile:diskPath];
            if (diskData && diskData.length > 0) {
                UIImage *diskImage = [UIImage imageWithData:diskData];
                if (diskImage) {
                    NSUInteger cost = (NSUInteger)(diskImage.size.width * diskImage.size.height * 4);
                    [self.memoryCache setObject:diskImage forKey:urlString cost:cost];
                    
                    // Обновляем дату доступа для LRU
                    [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: [NSDate date]}
                                                     ofItemAtPath:diskPath
                                                            error:nil];
                    
                    [self notifyCompletionForURL:urlString image:diskImage];
                    return;
                } else {
                    // Файл повреждён — удаляем
                    [[NSFileManager defaultManager] removeItemAtPath:diskPath error:nil];
                }
            }
        }
        
        // 4. Картинки нет ни в памяти, ни на диске — добавляем задачу в очередь загрузок
        [self.downloadQueue addOperationWithBlock:^{
            NSURL *url = [NSURL URLWithString:urlString];
            if (!url) {
                [self notifyCompletionForURL:urlString image:nil];
                return;
            }
            
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                               timeoutInterval:25.0];
            [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Mobile/10B141" forHTTPHeaderField:@"User-Agent"];
            
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSData *downloadedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            
            if (downloadedData && downloadedData.length > 0 && !error) {
                // Атомарно сохраняем на диск
                if (diskPath) {
                    [downloadedData writeToFile:diskPath atomically:YES];
                }
                
                UIImage *loadedImage = [UIImage imageWithData:downloadedData];
                if (loadedImage) {
                    NSUInteger cost = (NSUInteger)(loadedImage.size.width * loadedImage.size.height * 4);
                    [self.memoryCache setObject:loadedImage forKey:urlString cost:cost];
                    [self notifyCompletionForURL:urlString image:loadedImage];
                    return;
                }
            }
            
            [self notifyCompletionForURL:urlString image:nil];
        }];
    });
}

- (void)notifyCompletionForURL:(NSString *)urlString image:(UIImage *)image {
    NSArray *callbacks = nil;
    @synchronized (self.inFlightCallbacks) {
        callbacks = [self.inFlightCallbacks[urlString] copy];
        [self.inFlightCallbacks removeObjectForKey:urlString];
    }
    
    if (callbacks.count > 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            for (void (^cb)(UIImage *) in callbacks) {
                cb(image);
            }
        });
    }
}

- (unsigned long long)diskCacheSizeBytes {
    __block unsigned long long total = 0;
    dispatch_sync(self.ioQueue, ^{
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.diskCachePath error:nil];
        for (NSString *file in files) {
            NSString *fp = [self.diskCachePath stringByAppendingPathComponent:file];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fp error:nil];
            total += [attrs fileSize];
        }
    });
    return total;
}

- (NSUInteger)diskCacheFilesCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.diskCachePath error:nil];
        count = files.count;
    });
    return count;
}

- (void)clearMemoryCache {
    [self.memoryCache removeAllObjects];
}

- (void)clearDiskCache {
    dispatch_async(self.ioQueue, ^{
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.diskCachePath error:nil];
        for (NSString *file in files) {
            NSString *fp = [self.diskCachePath stringByAppendingPathComponent:file];
            [[NSFileManager defaultManager] removeItemAtPath:fp error:nil];
        }
    });
}

- (void)clearCache {
    [self clearMemoryCache];
    [self clearDiskCache];
}

- (void)pruneCacheIfNeeded {
    unsigned long long currentSize = 0;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.diskCachePath error:nil];
    if (!files || files.count == 0) return;
    
    NSMutableArray *fileDetails = [NSMutableArray arrayWithCapacity:files.count];
    NSDate *now = [NSDate date];
    NSTimeInterval maxAge = 30 * 24 * 60 * 60; // 30 дней
    
    for (NSString *f in files) {
        NSString *fp = [self.diskCachePath stringByAppendingPathComponent:f];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fp error:nil];
        if (!attrs) continue;
        
        NSDate *modDate = [attrs fileModificationDate] ?: [NSDate distantPast];
        unsigned long long size = [attrs fileSize];
        
        // Удаляем файлы старше 30 дней
        if ([now timeIntervalSinceDate:modDate] > maxAge) {
            [[NSFileManager defaultManager] removeItemAtPath:fp error:nil];
            continue;
        }
        
        currentSize += size;
        [fileDetails addObject:@{@"path": fp, @"date": modDate, @"size": @(size)}];
    }
    
    if (currentSize > self.maxDiskCacheBytes) {
        // Сортируем от самых старых к новым (LRU)
        [fileDetails sortUsingComparator:^NSComparisonResult(NSDictionary *d1, NSDictionary *d2) {
            return [d1[@"date"] compare:d2[@"date"]];
        }];
        
        unsigned long long targetSize = (unsigned long long)(self.maxDiskCacheBytes * 0.75); // до 75%
        for (NSDictionary *d in fileDetails) {
            if (currentSize <= targetSize) break;
            NSString *path = d[@"path"];
            unsigned long long size = [d[@"size"] unsignedLongLongValue];
            if ([[NSFileManager defaultManager] removeItemAtPath:path error:nil]) {
                currentSize = (currentSize > size) ? (currentSize - size) : 0;
            }
        }
    }
}

@end
