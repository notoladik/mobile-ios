#import "VKAnimatedImageView.h"
#import "VKImageLoader.h"
#import <ImageIO/ImageIO.h>

@interface VKGIFFrame : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) NSTimeInterval delay;
@end
@implementation VKGIFFrame @end

@interface VKAnimatedImageView ()
@property (nonatomic, strong) NSArray<VKGIFFrame *> *frames;
@property (nonatomic, assign) NSInteger currentFrameIndex;
@property (nonatomic, assign) NSTimeInterval accumulatedTime;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) BOOL _isAnimatingGIF;
@property (nonatomic, assign) BOOL _isGIFLoaded;
@property (nonatomic, copy) NSString *pendingGIFURL;
@property (nonatomic, strong) NSURLSessionDataTask *downloadTask;
@end

@implementation VKAnimatedImageView

- (BOOL)isAnimatingGIF { return self._isAnimatingGIF; }
- (BOOL)isGIFLoaded    { return self._isGIFLoaded; }

#pragma mark - Public API

- (void)loadGIFFromURL:(NSString *)gifURL previewURL:(NSString *)previewURL {
    [self resetGIF];
    self.pendingGIFURL = gifURL;

    if (previewURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:previewURL completion:^(UIImage *img) {
            if (img) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!self._isGIFLoaded) self.image = img;
                });
            }
        }];
    }

    if (gifURL.length == 0) return;
    NSURL *url = [NSURL URLWithString:gifURL];
    if (!url) return;

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];
    __weak typeof(self) weakSelf = self;
    self.downloadTask = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || data.length == 0) return;
        NSArray<VKGIFFrame *> *frames = [weakSelf framesFromData:data];
        if (frames.count == 0) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(weakSelf) strong = weakSelf;
            if (!strong || ![strong.pendingGIFURL isEqualToString:gifURL]) return;
            strong.frames = frames;
            strong._isGIFLoaded = YES;
            strong.currentFrameIndex = 0;
            strong.image = frames[0].image;
            [strong startGIFAnimation];
        });
    }];
    [self.downloadTask resume];
}

- (void)loadGIFFromData:(NSData *)data {
    [self resetGIF];
    NSArray<VKGIFFrame *> *frames = [self framesFromData:data];
    if (frames.count == 0) return;
    self.frames = frames;
    self._isGIFLoaded = YES;
    self.currentFrameIndex = 0;
    self.image = frames[0].image;
    [self startGIFAnimation];
}

- (void)startGIFAnimation {
    if (self.frames.count < 2 || self._isAnimatingGIF) return;
    self._isAnimatingGIF = YES;
    self.accumulatedTime = 0;
    if (!self.displayLink) {
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    }
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)pauseGIFAnimation {
    if (!self._isAnimatingGIF) return;
    self._isAnimatingGIF = NO;
    [self.displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopGIFAnimation {
    [self pauseGIFAnimation];
    self.displayLink = nil;
    self.currentFrameIndex = 0;
    self.accumulatedTime = 0;
}

- (void)resetGIF {
    [self.downloadTask cancel];
    self.downloadTask = nil;
    [self stopGIFAnimation];
    self.frames = nil;
    self._isGIFLoaded = NO;
    self.pendingGIFURL = nil;
    self.image = nil;
}

#pragma mark - Display Link

- (void)tick:(CADisplayLink *)link {
    if (self.frames.count == 0) return;
    self.accumulatedTime += link.duration;
    VKGIFFrame *cur = self.frames[self.currentFrameIndex];
    if (self.accumulatedTime >= cur.delay) {
        self.accumulatedTime -= cur.delay;
        self.currentFrameIndex = (self.currentFrameIndex + 1) % (NSInteger)self.frames.count;
        self.image = self.frames[self.currentFrameIndex].image;
    }
}

#pragma mark - Decode

- (NSArray<VKGIFFrame *> *)framesFromData:(NSData *)data {
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!src) return @[];
    NSMutableArray<VKGIFFrame *> *frames = [NSMutableArray array];
    NSUInteger count = CGImageSourceGetCount(src);
    for (NSUInteger i = 0; i < count; i++) {
        CGImageRef cgImg = CGImageSourceCreateImageAtIndex(src, i, NULL);
        if (!cgImg) continue;
        NSTimeInterval delay = 0.1;
        NSDictionary *props = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(src, i, NULL);
        NSDictionary *gifProps = props[(NSString *)kCGImagePropertyGIFDictionary];
        if (gifProps) {
            NSNumber *unc = gifProps[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
            NSNumber *cla = gifProps[(NSString *)kCGImagePropertyGIFDelayTime];
            NSNumber *d = (unc && unc.doubleValue > 0.01) ? unc : cla;
            if (d && d.doubleValue > 0.01) delay = d.doubleValue;
        }
        VKGIFFrame *frame = [[VKGIFFrame alloc] init];
        frame.image = [UIImage imageWithCGImage:cgImg];
        frame.delay = delay;
        [frames addObject:frame];
        CGImageRelease(cgImg);
    }
    CFRelease(src);
    return frames;
}

#pragma mark - Lifecycle

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (!newWindow) {
        [self pauseGIFAnimation];
    } else if (self._isGIFLoaded && self.frames.count > 1 && !self._isAnimatingGIF) {
        [self startGIFAnimation];
    }
}

- (void)dealloc {
    [self.downloadTask cancel];
    [self.displayLink invalidate];
}

@end
