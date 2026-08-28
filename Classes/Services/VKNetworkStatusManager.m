#import "VKNetworkStatusManager.h"
#import "VKAppConfig.h"
#import "VKCrashLogger.h"
#import <netinet/in.h>

NSString *const VKNetworkStatusDidChangeNotification = @"VKNetworkStatusDidChangeNotification";

@interface VKNetworkStatusManager ()
@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;
@property (nonatomic, assign, readwrite) VKNetworkReachabilityStatus currentNetworkStatus;
@property (nonatomic, assign, readwrite) VKServerStatus currentServerStatus;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, assign) NSInteger consecutiveFailures;

- (void)reachabilityChangedWithFlags:(SCNetworkReachabilityFlags)flags;
@end

static void VKReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    @autoreleasepool {
        VKNetworkStatusManager *manager = (__bridge VKNetworkStatusManager *)info;
        [manager reachabilityChangedWithFlags:flags];
    }
}

@implementation VKNetworkStatusManager

+ (instancetype)sharedManager {
    static VKNetworkStatusManager *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentNetworkStatus = VKNetworkReachabilityStatusUnknown;
        _currentServerStatus = VKServerStatusReachable;
        _consecutiveFailures = 0;
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
}

#pragma mark - Monitoring

- (void)startMonitoring {
    if (self.isMonitoring) return;
    
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    self.reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    if (!self.reachabilityRef) return;
    
    SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, VKReachabilityCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes)) {
            self.isMonitoring = YES;
            
            // Получаем начальные флаги
            SCNetworkReachabilityFlags flags;
            if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
                [self reachabilityChangedWithFlags:flags];
            }
        }
    }
    
    [VKCrashLogger log:@"[VKNetworkStatusManager] Started monitoring network reachability."];
}

- (void)stopMonitoring {
    if (!self.isMonitoring) return;
    if (self.reachabilityRef) {
        SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease(self.reachabilityRef);
        self.reachabilityRef = NULL;
    }
    self.isMonitoring = NO;
}

- (void)reachabilityChangedWithFlags:(SCNetworkReachabilityFlags)flags {
    VKNetworkReachabilityStatus status = VKNetworkReachabilityStatusNotReachable;
    
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
                                       ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
    BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically &&
                                             (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
    
    if (isNetworkReachable) {
#if TARGET_OS_IPHONE
        if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
            status = VKNetworkReachabilityStatusReachableViaWWAN;
        } else {
            status = VKNetworkReachabilityStatusReachableViaWiFi;
        }
#else
        status = VKNetworkReachabilityStatusReachableViaWiFi;
#endif
    }
    
    BOOL wasNetworkReachable = [self isNetworkReachable];
    self.currentNetworkStatus = status;
    
    // Если сеть восстановилась, сбрасываем счетчик ошибок и проверяем сервер
    if (!wasNetworkReachable && [self isNetworkReachable]) {
        self.consecutiveFailures = 0;
        self.currentServerStatus = VKServerStatusReachable;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VKNetworkStatusDidChangeNotification object:self];
    });
}

#pragma mark - Getters

- (BOOL)isNetworkReachable {
    return (self.currentNetworkStatus == VKNetworkReachabilityStatusReachableViaWiFi ||
            self.currentNetworkStatus == VKNetworkReachabilityStatusReachableViaWWAN);
}

- (BOOL)isServerReachable {
    return [self isNetworkReachable] && (self.currentServerStatus != VKServerStatusUnreachable);
}

#pragma mark - Request Reporting

- (void)reportRequestFailedWithError:(NSError *)error {
    if (!error) return;
    
    NSInteger code = error.code;
    BOOL isNetworkOrServerError = (code == NSURLErrorNotConnectedToInternet ||
                                   code == NSURLErrorTimedOut ||
                                   code == NSURLErrorCannotConnectToHost ||
                                   code == NSURLErrorCannotFindHost ||
                                   code == NSURLErrorNetworkConnectionLost ||
                                   code == NSURLErrorDNSLookupFailed ||
                                   code == 502 || code == 503 || code == 504);
    
    if (isNetworkOrServerError) {
        self.consecutiveFailures++;
        if (self.consecutiveFailures >= 1) {
            self.currentServerStatus = VKServerStatusUnreachable;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:VKNetworkStatusDidChangeNotification object:self];
            });
        }
    }
}

- (void)reportRequestSucceeded {
    if (self.consecutiveFailures > 0 || self.currentServerStatus == VKServerStatusUnreachable) {
        self.consecutiveFailures = 0;
        self.currentServerStatus = VKServerStatusReachable;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:VKNetworkStatusDidChangeNotification object:self];
        });
    }
}

- (void)checkServerStatusWithCompletion:(void(^)(BOOL reachable))completion {
    NSString *host = [VKAppConfig currentHost];
    if (host.length == 0) host = @"openvk.su";
    
    NSString *urlStr = [NSString stringWithFormat:@"https://%@/api", host];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO);
        return;
    }
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:8.0];
    req.HTTPMethod = @"HEAD";
    
    if (NSClassFromString(@"NSURLSession")) {
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            BOOL ok = (error == nil);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ok) [self reportRequestSucceeded];
                else [self reportRequestFailedWithError:error];
                if (completion) completion(ok);
            });
        }];
        [task resume];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *err = nil;
            NSURLResponse *resp = nil;
            [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
            BOOL ok = (err == nil);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (ok) [self reportRequestSucceeded];
                else [self reportRequestFailedWithError:err];
                if (completion) completion(ok);
            });
        });
    }
}

@end
