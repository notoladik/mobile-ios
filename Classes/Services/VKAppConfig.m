#import "VKAppConfig.h"

static NSString *const kOpenVKInstanceKey = @"openvk.instance_host";
static NSString *const kOpenVKCustomInstancesKey = @"openvk.custom_instances";
static NSString *const kDefaultInstance = @"api.openvk.org";

@implementation VKAppConfig

+ (NSString *)cleanHostString:(NSString *)host {
    if (!host) return @"";
    NSString *cleaned = [host stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Убираем протоколы http:// и https://
    if ([cleaned hasPrefix:@"https://"]) {
        cleaned = [cleaned substringFromIndex:8];
    } else if ([cleaned hasPrefix:@"http://"]) {
        cleaned = [cleaned substringFromIndex:7];
    }
    
    // Убираем хвостовые слеши и /api
    while ([cleaned hasSuffix:@"/"]) {
        cleaned = [cleaned substringToIndex:cleaned.length - 1];
    }
    if ([cleaned hasSuffix:@"/api"]) {
        cleaned = [cleaned substringToIndex:cleaned.length - 4];
    }
    while ([cleaned hasSuffix:@"/"]) {
        cleaned = [cleaned substringToIndex:cleaned.length - 1];
    }
    
    return [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSArray<NSString *> *)availableInstances {
    NSArray *defaultInstances = @[
        @"openvk.xyz",
        @"api.openvk.org",
        @"vepurovk.xyz",
        @"api.vepurovk.fun"
    ];
    
    NSArray *custom = [[NSUserDefaults standardUserDefaults] arrayForKey:kOpenVKCustomInstancesKey];
    if (!custom || custom.count == 0) {
        return defaultInstances;
    }
    
    NSMutableArray *result = [NSMutableArray arrayWithArray:defaultInstances];
    for (NSString *host in custom) {
        if ([host isKindOfClass:[NSString class]] && host.length > 0 && ![result containsObject:host]) {
            [result addObject:host];
        }
    }
    return result;
}

+ (void)addCustomInstance:(NSString *)host {
    NSString *cleaned = [self cleanHostString:host];
    if (cleaned.length == 0) return;
    
    NSMutableArray *custom = [NSMutableArray array];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kOpenVKCustomInstancesKey];
    if (saved) {
        [custom addObjectsFromArray:saved];
    }
    
    if (![custom containsObject:cleaned]) {
        [custom addObject:cleaned];
        [[NSUserDefaults standardUserDefaults] setObject:custom forKey:kOpenVKCustomInstancesKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [self setCurrentHost:cleaned];
}

+ (void)removeCustomInstance:(NSString *)host {
    NSString *cleaned = [self cleanHostString:host];
    if (cleaned.length == 0) return;
    
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:kOpenVKCustomInstancesKey];
    if (saved) {
        NSMutableArray *custom = [NSMutableArray arrayWithArray:saved];
        [custom removeObject:cleaned];
        [[NSUserDefaults standardUserDefaults] setObject:custom forKey:kOpenVKCustomInstancesKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (NSString *)currentHost {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kOpenVKInstanceKey];
    if (saved && saved.length > 0) {
        return saved;
    }
    return kDefaultInstance;
}

+ (void)setCurrentHost:(NSString *)host {
    NSString *cleaned = [self cleanHostString:host];
    if (!cleaned || cleaned.length == 0) {
        cleaned = kDefaultInstance;
    }
    [[NSUserDefaults standardUserDefaults] setObject:cleaned forKey:kOpenVKInstanceKey];
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
