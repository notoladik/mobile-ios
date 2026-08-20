#import "VKSupportersService.h"

@implementation VKSupporter
- (NSString *)displayName {
    if (self.name.length > 0) return self.name;
    if (self.nick.length > 0) return [NSString stringWithFormat:@"@%@", self.nick];
    return @"Анонимный благотворитель";
}
@end

@interface VKSupportersService ()
@property (nonatomic, strong, readwrite) NSArray<VKSupporter *> *testers;
@property (nonatomic, strong, readwrite) NSArray<VKSupporter *> *donors;
@property (nonatomic, strong) NSMutableDictionary *screenNameToSupporter;
@property (nonatomic, strong) NSDate *lastFetchDate;
@end

@implementation VKSupportersService

+ (instancetype)sharedService {
    static VKSupportersService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _screenNameToSupporter = [NSMutableDictionary dictionary];
        _testers = @[];
        _donors = @[];
        [self loadCachedData];
        [self fetchSupportersIfNeeded];
    }
    return self;
}

- (NSString *)cacheFilePath {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cacheDir stringByAppendingPathComponent:@"openvk_supporters.json"];
}

- (void)loadCachedData {
    NSData *data = [NSData dataWithContentsOfFile:[self cacheFilePath]];
    if (data) {
        [self parseSupportersData:data];
    }
}

- (void)fetchSupportersIfNeeded {
    if (self.lastFetchDate && [[NSDate date] timeIntervalSinceDate:self.lastFetchDate] < 3 * 3600) {
        return;
    }
    
    NSURL *url = [NSURL URLWithString:@"https://files.nikanikoo.com/ovk-ios/supporters.json"];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (data) {
            [data writeToFile:[self cacheFilePath] atomically:YES];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.lastFetchDate = [NSDate date];
                [self parseSupportersData:data];
            });
        }
    });
}

- (void)parseSupportersData:(NSData *)data {
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!error && [json isKindOfClass:[NSDictionary class]]) {
        NSArray *rawTesters = json[@"testers"] ?: @[];
        NSArray *rawDonors = json[@"donors"] ?: @[];
        
        NSMutableArray *testersArr = [NSMutableArray array];
        NSMutableArray *donorsArr = [NSMutableArray array];
        [self.screenNameToSupporter removeAllObjects];
        
        for (NSDictionary *item in rawTesters) {
            VKSupporter *s = [self supporterFromDict:item];
            [testersArr addObject:s];
            [self registerSupporter:s];
        }
        for (NSDictionary *item in rawDonors) {
            VKSupporter *s = [self supporterFromDict:item];
            [donorsArr addObject:s];
            [self registerSupporter:s];
        }
        
        self.testers = [testersArr copy];
        self.donors = [donorsArr copy];
    }
}

- (VKSupporter *)supporterFromDict:(NSDictionary *)item {
    VKSupporter *s = [[VKSupporter alloc] init];
    s.name = item[@"name"];
    s.nick = item[@"nick"];
    s.iconURL = item[@"icon"];
    s.amount = item[@"amount"];
    s.message = item[@"message"];
    s.profiles = item[@"profiles"];
    return s;
}

- (void)registerSupporter:(VKSupporter *)s {
    for (NSString *prof in s.profiles ?: @[]) {
        NSString *clean = [[prof componentsSeparatedByString:@"/"] lastObject];
        clean = [[clean stringByReplacingOccurrencesOfString:@"@" withString:@""] lowercaseString];
        clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (clean.length > 0) {
            self.screenNameToSupporter[clean] = s;
        }
    }
}

- (VKSupporter *)supporterForScreenName:(NSString *)screenName {
    if (!screenName || ![screenName isKindOfClass:[NSString class]] || screenName.length == 0) return nil;
    NSString *clean = [[screenName stringByReplacingOccurrencesOfString:@"@" withString:@""] lowercaseString];
    clean = [clean stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0 || !self.screenNameToSupporter) return nil;
    return self.screenNameToSupporter[clean];
}

- (NSString *)badgeIconURLForScreenName:(NSString *)screenName {
    if (!screenName) return nil;
    VKSupporter *s = [self supporterForScreenName:screenName];
    return s.iconURL;
}

@end
