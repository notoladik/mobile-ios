#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

extern NSString *const VKNetworkStatusDidChangeNotification;

typedef NS_ENUM(NSInteger, VKNetworkReachabilityStatus) {
    VKNetworkReachabilityStatusUnknown          = -1,
    VKNetworkReachabilityStatusNotReachable     = 0,
    VKNetworkReachabilityStatusReachableViaWWAN  = 1,
    VKNetworkReachabilityStatusReachableViaWiFi  = 2
};

typedef NS_ENUM(NSInteger, VKServerStatus) {
    VKServerStatusUnknown,
    VKServerStatusReachable,
    VKServerStatusUnreachable
};

@interface VKNetworkStatusManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, assign, readonly) VKNetworkReachabilityStatus currentNetworkStatus;
@property (nonatomic, assign, readonly) VKServerStatus currentServerStatus;
@property (nonatomic, assign, readonly) BOOL isNetworkReachable;
@property (nonatomic, assign, readonly) BOOL isServerReachable;

- (void)startMonitoring;
- (void)stopMonitoring;

- (void)reportRequestFailedWithError:(NSError *)error;
- (void)reportRequestSucceeded;
- (void)checkServerStatusWithCompletion:(void(^)(BOOL reachable))completion;

@end
