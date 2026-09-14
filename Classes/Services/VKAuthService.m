#import "VKAuthService.h"
#import "VKAPIClient.h"
#import "VKAppConfig.h"
#import "VKCrashLogger.h"
#import <Security/Security.h>

NSString *const VKAuthStatusDidChangeNotification = @"VKAuthStatusDidChangeNotification";
NSString *const VKCountersDidUpdateNotification = @"VKCountersDidUpdateNotification";

static NSString *const kOpenVKTokenKey = @"openvk.token";
static NSString *const kOpenVKCurrentUserJSONKey = @"openvk.current_user_json";
static NSString *const kOpenVKAccountsJSONKey = @"openvk.accounts_json";
static NSString *const kOpenVKKeychainService = @"org.openvk.legacy.auth";

static NSString *VKKeychainAccount(NSString *username, NSString *host) {
    return [NSString stringWithFormat:@"%@|%@", host ?: @"", username ?: @""];
}

static NSString *VKKeychainLoadToken(NSString *username, NSString *host) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kOpenVKKeychainService,
        (__bridge id)kSecAttrAccount: VKKeychainAccount(username, host),
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void VKKeychainSaveToken(NSString *token, NSString *username, NSString *host) {
    if (token.length == 0 || username.length == 0) return;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kOpenVKKeychainService,
        (__bridge id)kSecAttrAccount: VKKeychainAccount(username, host)
    };
    NSData *data = [token dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *attributes = @{(__bridge id)kSecValueData: data};
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributes);
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        item[(__bridge id)kSecValueData] = data;
        SecItemAdd((__bridge CFDictionaryRef)item, NULL);
    }
}

static void VKKeychainDeleteToken(NSString *username, NSString *host) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kOpenVKKeychainService,
        (__bridge id)kSecAttrAccount: VKKeychainAccount(username, host)
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@implementation VKAuthAccount

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.user forKey:@"user"];
    [coder encodeObject:self.token forKey:@"token"];
    [coder encodeObject:self.instanceHost forKey:@"instanceHost"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        self.user = [coder decodeObjectForKey:@"user"];
        self.token = [coder decodeObjectForKey:@"token"];
        self.instanceHost = [coder decodeObjectForKey:@"instanceHost"];
    }
    return self;
}

@end

@interface VKAuthService ()
@property (nonatomic, copy, readwrite) NSString *accessToken;
@property (nonatomic, strong, readwrite) VKUser *currentUserModel;
@property (nonatomic, strong, readwrite) NSMutableArray *accountsList;
@property (nonatomic, assign, readwrite) BOOL requiresTwoFactor;
@property (nonatomic, copy) NSString *draftUsername;
@property (nonatomic, copy) NSString *draftPassword;
@end

@implementation VKAuthService

static VKAuthService *_sharedInstance = nil;

+ (instancetype)sharedService {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _accountsList = [NSMutableArray array];
        NSString *legacyToken = [[NSUserDefaults standardUserDefaults] stringForKey:kOpenVKTokenKey];
        
        // Загрузка пользователя из JSON
        NSData *userData = [[NSUserDefaults standardUserDefaults] dataForKey:kOpenVKCurrentUserJSONKey];
        if (userData && userData.length > 0) {
            @try {
                NSDictionary *userDict = [NSJSONSerialization JSONObjectWithData:userData options:0 error:nil];
                if ([userDict isKindOfClass:[NSDictionary class]]) {
                    _currentUserModel = [VKUser userFromDictionary:userDict];
                }
            } @catch (NSException *e) {
                [VKCrashLogger log:@"[VKAuthService] Exception reading cached user: %@", e];
            }
        }
        
        // Загрузка аккаунтов из JSON
        NSData *accountsData = [[NSUserDefaults standardUserDefaults] dataForKey:kOpenVKAccountsJSONKey];
        if (accountsData && accountsData.length > 0) {
            @try {
                NSArray *accountsArray = [NSJSONSerialization JSONObjectWithData:accountsData options:0 error:nil];
                if ([accountsArray isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *accDict in accountsArray) {
                        if ([accDict isKindOfClass:[NSDictionary class]]) {
                            VKAuthAccount *account = [[VKAuthAccount alloc] init];
                            account.instanceHost = accDict[@"instanceHost"];
                            NSDictionary *uDict = accDict[@"user"];
                            if ([uDict isKindOfClass:[NSDictionary class]]) {
                                account.user = [VKUser userFromDictionary:uDict];
                            }
                            account.token = VKKeychainLoadToken(account.user.username, account.instanceHost);
                            // One-time migration from the old plaintext JSON store.
                            if (account.token.length == 0 && [accDict[@"token"] isKindOfClass:[NSString class]]) {
                                account.token = accDict[@"token"];
                                VKKeychainSaveToken(account.token, account.user.username, account.instanceHost);
                            }
                            if (account.token.length > 0 && account.user) {
                                [_accountsList addObject:account];
                            }
                        }
                    }
                }
            } @catch (NSException *e) {
                [VKCrashLogger log:@"[VKAuthService] Exception reading cached accounts: %@", e];
            }
        }

        NSString *keychainToken = VKKeychainLoadToken(_currentUserModel.username, [VKAppConfig currentHost]);
        _accessToken = keychainToken.length > 0 ? keychainToken : legacyToken;
        if (legacyToken.length > 0 && _currentUserModel.username.length > 0) {
            VKKeychainSaveToken(legacyToken, _currentUserModel.username, [VKAppConfig currentHost]);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOpenVKTokenKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        [VKCrashLogger log:@"[VKAuthService] Initialized. token=%@, user=%@", (_accessToken.length > 0 ? @"YES" : @"NO"), _currentUserModel.displayName];
        
        // Запускаем запросы строго асинхронно после полной инициализации
        if (_accessToken.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self fetchCounters];
                [self fetchCurrentUser:nil];
            });
        }
    }
    return self;
}

- (BOOL)isAuthenticated {
    return (self.accessToken != nil && self.accessToken.length > 0);
}

- (NSArray *)accounts {
    return self.accountsList;
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                     code:(NSString *)code
               completion:(void (^)(BOOL success, NSString *errorMsg, BOOL need2FA))completion {
    
    self.draftUsername = username;
    self.draftPassword = password;
    
    [[VKAPIClient sharedClient] requestTokenWithUsername:username password:password code:code completionHandler:^(id response, NSError *error) {
        if (error) {
            if (completion) completion(NO, [error localizedDescription], NO);
            return;
        }
        
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)response;
            NSString *err = dict[@"error"];
            if ([err isEqualToString:@"need_validation"] || [dict[@"error_type"] isEqualToString:@"need_validation"]) {
                self.requiresTwoFactor = YES;
                if (completion) completion(NO, @"Требуется код 2FA", YES);
                return;
            }
            
            if (err) {
                NSString *desc = dict[@"error_description"] ?: err;
                if (completion) completion(NO, desc, NO);
                return;
            }
            
            NSString *token = dict[@"access_token"];
            if (token.length > 0) {
                self.accessToken = token;
                self.requiresTwoFactor = NO;
                VKKeychainSaveToken(token, username, [VKAppConfig currentHost]);
                
                [self fetchCurrentUser:^(BOOL success) {
                    VKAuthAccount *account = [[VKAuthAccount alloc] init];
                    account.user = self.currentUserModel;
                    account.token = token;
                    account.instanceHost = [VKAppConfig currentHost];
                    
                    // Удаляем дубликат по username если был
                    [self.accountsList filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VKAuthAccount *evaluatedObject, NSDictionary *bindings) {
                        return ![evaluatedObject.user.username isEqualToString:account.user.username];
                    }]];
                    [self.accountsList addObject:account];
                    [self saveAccounts];
                    
                    [self fetchCounters];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKAuthStatusDidChangeNotification object:nil];
                    });
                    if (completion) completion(YES, nil, NO);
                }];
                return;
            }
        }
        
        if (completion) completion(NO, @"Неизвестный ответ сервера", NO);
    }];
}

- (void)switchToAccount:(VKAuthAccount *)account {
    if (!account) return;
    
    [VKAppConfig setCurrentHost:account.instanceHost];
    self.accessToken = account.token;
    self.currentUserModel = account.user;
    
    VKKeychainSaveToken(account.token, account.user.username, account.instanceHost);
    [self saveCurrentUser];
    
    [self fetchCounters];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VKAuthStatusDidChangeNotification object:nil];
    });
}

- (void)removeAccountWithUsername:(NSString *)username {
    VKAuthAccount *target = nil;
    for (VKAuthAccount *acc in self.accountsList) {
        if ([acc.user.username isEqualToString:username]) {
            target = acc;
            break;
        }
    }
    if (target) {
        [self.accountsList removeObject:target];
        [self saveAccounts];
    }
    
    if ([self.currentUserModel.username isEqualToString:username]) {
        if (self.accountsList.count > 0) {
            [self switchToAccount:self.accountsList[0]];
        } else {
            [self logout];
        }
    }
}

- (void)saveCurrentUser {
    if (self.currentUserModel) {
        NSDictionary *dict = [self.currentUserModel dictionaryRepresentation];
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:kOpenVKCurrentUserJSONKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOpenVKCurrentUserJSONKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveAccounts {
    NSMutableArray *rawArr = [NSMutableArray array];
    for (VKAuthAccount *acc in self.accountsList) {
        NSMutableDictionary *accDict = [NSMutableDictionary dictionary];
        if (acc.token.length > 0) {
            VKKeychainSaveToken(acc.token, acc.user.username, acc.instanceHost);
        }
        if (acc.instanceHost) accDict[@"instanceHost"] = acc.instanceHost;
        if (acc.user) accDict[@"user"] = [acc.user dictionaryRepresentation];
        [rawArr addObject:accDict];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:rawArr options:0 error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:kOpenVKAccountsJSONKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)fetchCurrentUser:(void (^)(BOOL success))completion {
    if (!self.isAuthenticated) {
        if (completion) completion(NO);
        return;
    }
    
    [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:@{@"fields": @"photo_100,photo_200,city,online,verified,screen_name,status,about,site,sex,can_write_on_wall,can_post"} completionHandler:^(id response, NSError *error) {
        if (!error && [response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            NSArray *arr = response[@"response"];
            if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
                self.currentUserModel = [VKUser userFromDictionary:arr[0]];
                [self saveCurrentUser];
                if (completion) completion(YES);
                return;
            }
        }
        if (completion) completion(NO);
    }];
}

- (void)fetchCounters {
    if (!self.isAuthenticated) return;
    
    [[VKAPIClient sharedClient] callMethod:@"account.getCounters" parameters:@{} completionHandler:^(id response, NSError *error) {
        if (!error && [response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            NSDictionary *r = response[@"response"];
            self.friendsCount = [r[@"friends"] integerValue];
            self.notificationsCount = [r[@"notifications"] integerValue];
            self.messagesCount = [r[@"messages"] integerValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:VKCountersDidUpdateNotification object:nil];
            });
        }
    }];
}

- (void)fetchBalance {
    if (!self.isAuthenticated) return;
    
    [[VKAPIClient sharedClient] callMethod:@"account.getBalance" parameters:@{} completionHandler:^(id response, NSError *error) {
        if (!error && [response isKindOfClass:[NSDictionary class]] && response[@"response"]) {
            self.balanceVotes = [response[@"response"][@"votes"] integerValue];
        }
    }];
}

- (void)logout {
    NSString *currentUsername = self.currentUserModel.username;
    NSString *currentHost = [VKAppConfig currentHost];
    if (currentUsername.length > 0) {
        VKKeychainDeleteToken(currentUsername, currentHost);
    }
    for (VKAuthAccount *account in self.accountsList) {
        VKKeychainDeleteToken(account.user.username, account.instanceHost);
    }
    self.accessToken = nil;
    self.currentUserModel = nil;
    [self.accountsList removeAllObjects];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOpenVKTokenKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOpenVKCurrentUserJSONKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kOpenVKAccountsJSONKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:VKAuthStatusDidChangeNotification object:nil];
    });
}

- (NSInteger)currentUserId {
    return self.currentUserModel ? self.currentUserModel.uid : 0;
}

@end
