#import "VKAppConfig.h"

static NSString *const kOpenVKInstanceKey = @"openvk.instance_host";
static NSString *const kDefaultInstance = @"openvk.su";

@implementation VKAppConfig

+ (NSArray *)availableInstances {
    return @[
        @"openvk.su",
        @"openvk.xyz",
        @"api.openvk.org",
        @"vepurovk.xyz",
        @"api.vepurovk.fun"
    ];
}

+ (NSString *)currentHost {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kOpenVKInstanceKey];
    if (saved && saved.length > 0) {
        return saved;
    }
    return kDefaultInstance;
}

+ (void)setCurrentHost:(NSString *)host {
    if (!host || host.length == 0) {
        host = kDefaultInstance;
    }
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kOpenVKInstanceKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSURL *)apiBaseURL {
    NSString *host = [self currentHost];
    if (![host hasPrefix:@"http://"] && ![host hasPrefix:@"https://"]) {
        host = [NSString stringWithFormat:@"https://%@", host];
    }
    if (![host hasSuffix:@"/"]) {
        host = [NSString stringWithFormat:@"%@/", host];
    }
    return [NSURL URLWithString:host];
}

@end
