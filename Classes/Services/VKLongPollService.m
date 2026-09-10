#import "VKLongPollService.h"
#import "VKAPIClient.h"
#import "VKAuthService.h"
#import "VKAppConfig.h"
#import "VKCrashLogger.h"
#import "VKAttachment.h"

NSString *const VKLongPollDidReceiveNewMessageNotification   = @"VKLongPollDidReceiveNewMessageNotification";
NSString *const VKLongPollDidReadMessagesNotification       = @"VKLongPollDidReadMessagesNotification";
NSString *const VKLongPollUserTypingNotification             = @"VKLongPollUserTypingNotification";
NSString *const VKLongPollUnreadCountDidChangeNotification   = @"VKLongPollUnreadCountDidChangeNotification";

@interface VKLongPollService ()

@property (nonatomic, assign, readwrite) BOOL isRunning;
@property (nonatomic, copy, readwrite) NSString *server;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign, readwrite) NSInteger currentTS;
@property (nonatomic, assign) NSInteger pts;
@property (nonatomic, strong) dispatch_queue_t pollQueue;
@property (nonatomic, assign) BOOL shouldStop;
@property (nonatomic, strong) id currentTask;

@end

@implementation VKLongPollService

+ (instancetype)sharedService {
    static VKLongPollService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _pollQueue = dispatch_queue_create("org.openvk.longpoll", DISPATCH_QUEUE_SERIAL);
        _shouldStop = NO;
        _isRunning = NO;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authStatusChanged:) name:VKAuthStatusDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stop];
}

#pragma mark - Notifications

- (void)authStatusChanged:(NSNotification *)note {
    if ([[VKAuthService sharedService] isAuthenticated]) {
        [self restart];
    } else {
        [self stop];
    }
}

- (void)appDidEnterBackground:(NSNotification *)note {
    [self stop];
}

- (void)appWillEnterForeground:(NSNotification *)note {
    if ([[VKAuthService sharedService] isAuthenticated]) {
        [self start];
    }
}

#pragma mark - Public API

- (void)start {
    if (self.isRunning) return;
    if (![[VKAuthService sharedService] isAuthenticated]) return;
    
    self.shouldStop = NO;
    self.isRunning = YES;
    [VKCrashLogger log:@"[VKLongPollService] Starting service..."];
    
    dispatch_async(self.pollQueue, ^{
        [self fetchServerCredentialsAndStartLoop];
    });
}

- (void)stop {
    self.shouldStop = YES;
    self.isRunning = NO;
    
    if (self.currentTask) {
        if ([self.currentTask respondsToSelector:@selector(cancel)]) {
            [self.currentTask cancel];
        }
        self.currentTask = nil;
    }
    [VKCrashLogger log:@"[VKLongPollService] Stopped."];
}

- (void)restart {
    [self stop];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self start];
    });
}

#pragma mark - Long Poll Server Credentials

- (void)fetchServerCredentialsAndStartLoop {
    if (self.shouldStop) return;
    
    NSDictionary *params = @{
        @"lp_version": @"3",
        @"need_pts": @"0"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getLongPollServer" parameters:params completionHandler:^(id response, NSError *error) {
        if (self.shouldStop) return;
        
        if (error) {
            [VKCrashLogger log:@"[VKLongPollService] Error getting LP server: %@", error.localizedDescription];
            // Повторная попытка через 5 секунд при ошибке сети
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), self.pollQueue, ^{
                if (!self.shouldStop) [self fetchServerCredentialsAndStartLoop];
            });
            return;
        }
        
        NSDictionary *dict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (!dict || !dict[@"server"] || !dict[@"key"]) {
            [VKCrashLogger log:@"[VKLongPollService] Invalid LP server response: %@", response];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), self.pollQueue, ^{
                if (!self.shouldStop) [self fetchServerCredentialsAndStartLoop];
            });
            return;
        }
        
        self.server = [dict[@"server"] description];
        self.key = [dict[@"key"] description];
        self.currentTS = [dict[@"ts"] integerValue];
        self.pts = [dict[@"pts"] integerValue];
        
        [VKCrashLogger log:@"[VKLongPollService] Got LP server: %@, ts: %ld", self.server, (long)self.currentTS];
        
        // Запускаем цикл опроса
        [self performLongPollRequest];
    }];
}

#pragma mark - Poll Request

- (void)performLongPollRequest {
    if (self.shouldStop) return;
    
    NSString *serverStr = self.server ?: @"";
    if ([serverStr hasPrefix:@"/"]) {
        serverStr = [NSString stringWithFormat:@"https://%@%@", [VKAppConfig currentHost], serverStr];
    } else if (![serverStr hasPrefix:@"http://"] && ![serverStr hasPrefix:@"https://"]) {
        serverStr = [NSString stringWithFormat:@"https://%@", serverStr];
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@?act=a_check&key=%@&ts=%ld&wait=25&mode=2&version=3",
                           serverStr, self.key, (long)self.currentTS];
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        [VKCrashLogger log:@"[VKLongPollService] Invalid LP URL: %@", urlString];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), self.pollQueue, ^{
            if (!self.shouldStop) [self fetchServerCredentialsAndStartLoop];
        });
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:45.0];
    [request setValue:@"okhttp/4.12.0" forHTTPHeaderField:@"User-Agent"];
    
    if (NSClassFromString(@"NSURLSession")) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        config.timeoutIntervalForRequest = 45.0;
        config.timeoutIntervalForResource = 50.0;
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
        
        NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [self handlePollResponseData:data error:error];
        }];
        self.currentTask = task;
        [task resume];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *err = nil;
            NSURLResponse *resp = nil;
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&resp error:&err];
            [self handlePollResponseData:data error:err];
        });
    }
}

- (void)handlePollResponseData:(NSData *)data error:(NSError *)error {
    if (self.shouldStop) return;
    
    if (error) {
        if (error.code == NSURLErrorCancelled) return;
        
        [VKCrashLogger log:@"[VKLongPollService] LP request error: %@", error.localizedDescription];
        // Пауза 3 сек перед ретраем
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), self.pollQueue, ^{
            if (!self.shouldStop) [self performLongPollRequest];
        });
        return;
    }
    
    if (!data || data.length == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), self.pollQueue, ^{
            if (!self.shouldStop) [self performLongPollRequest];
        });
        return;
    }
    
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
        [VKCrashLogger log:@"[VKLongPollService] LP JSON decode error: %@", jsonError];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), self.pollQueue, ^{
            if (!self.shouldStop) [self performLongPollRequest];
        });
        return;
    }
    
    // Проверяем ошибки Long Poll
    if (json[@"failed"]) {
        NSInteger code = [json[@"failed"] integerValue];
        [VKCrashLogger log:@"[VKLongPollService] LP returned failed code: %ld", (long)code];
        
        if (code == 1 && json[@"ts"]) {
            // История устарела, обновляем ts и продолжаем
            self.currentTS = [json[@"ts"] integerValue];
            dispatch_async(self.pollQueue, ^{
                if (!self.shouldStop) [self performLongPollRequest];
            });
            return;
        } else {
            // failed: 2 или 3 — обновляем сессию LP
            dispatch_async(self.pollQueue, ^{
                if (!self.shouldStop) [self fetchServerCredentialsAndStartLoop];
            });
            return;
        }
    }
    
    // Обновляем ts
    if (json[@"ts"]) {
        self.currentTS = [json[@"ts"] integerValue];
    }
    
    // Обрабатываем массив событий
    NSArray *updates = json[@"updates"];
    if ([updates isKindOfClass:[NSArray class]] && updates.count > 0) {
        [self processUpdates:updates];
    }
    
    // Следующий цикл опроса
    dispatch_async(self.pollQueue, ^{
        if (!self.shouldStop) [self performLongPollRequest];
    });
}

#pragma mark - Process Updates

- (void)processUpdates:(NSArray *)updates {
    for (id item in updates) {
        if (![item isKindOfClass:[NSArray class]]) continue;
        NSArray *event = (NSArray *)item;
        if (event.count == 0) continue;
        
        NSInteger eventCode = [event[0] integerValue];
        
        switch (eventCode) {
            case 4: {
                // Новое сообщение:
                // v3: [4, message_id, flags, peer_id, timestamp, text, extra, attachments, random_id, cmid]
                // v1/v2: [4, message_id, flags, from_id, timestamp, subject, text, attachments]
                if (event.count >= 6) {
                    NSInteger msgId = [event[1] integerValue];
                    NSInteger flags = [event[2] integerValue];
                    NSInteger peerId = [event[3] integerValue];
                    double timestamp = [event[4] doubleValue];
                    
                    NSString *text = @"";
                    NSDictionary *extra = nil;
                    NSDictionary *attachments = nil;
                    
                    if (event.count >= 7 && [event[5] isKindOfClass:[NSString class]]) {
                        text = event[5];
                        if (event.count >= 7 && [event[6] isKindOfClass:[NSDictionary class]]) {
                            extra = event[6];
                        }
                        if (event.count >= 8 && [event[7] isKindOfClass:[NSDictionary class]]) {
                            attachments = event[7];
                        }
                    } else if (event.count >= 8 && [event[6] isKindOfClass:[NSString class]]) {
                        // v1 format: [4, msg_id, flags, from_id, timestamp, subject, text, attachments]
                        text = event[6];
                        if ([event[7] isKindOfClass:[NSDictionary class]]) {
                            attachments = event[7];
                        }
                    }
                    
                    VKMessage *msg = [[VKMessage alloc] init];
                    msg.messageId = msgId;
                    msg.peerId = peerId;
                    msg.isOutgoing = (flags & 2) != 0;
                    msg.isRead = (flags & 1) == 0;
                    msg.text = text ?: @"";
                    
                    // Реальный автор в беседах
                    if (extra && extra[@"from"]) {
                        msg.fromId = [extra[@"from"] integerValue];
                    } else {
                        msg.fromId = msg.isOutgoing ? [[VKAuthService sharedService] currentUserId] : peerId;
                    }
                    
                    if (timestamp > 0) {
                        msg.date = [NSDate dateWithTimeIntervalSince1970:timestamp];
                        NSDateFormatter *df = [[NSDateFormatter alloc] init];
                        [df setDateFormat:@"HH:mm"];
                        msg.timeString = [df stringFromDate:msg.date];
                    }
                    
                    // Парсим прикрепления если они пришли в аттачах LP
                    if (attachments && attachments.count > 0) {
                        NSMutableArray *atts = [NSMutableArray array];
                        for (NSInteger i = 1; i <= 10; i++) {
                            NSString *typeKey = [NSString stringWithFormat:@"attach%ld_type", (long)i];
                            NSString *itemKey = [NSString stringWithFormat:@"attach%ld", (long)i];
                            NSString *aType = attachments[typeKey];
                            if (aType.length > 0) {
                                NSDictionary *rawAtt = @{@"type": aType, aType: @{@"id": attachments[itemKey] ?: @(0)}};
                                VKAttachment *a = [VKAttachment attachmentFromDictionary:rawAtt];
                                if (a) [atts addObject:a];
                            }
                        }
                        msg.attachments = atts;
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollDidReceiveNewMessageNotification
                                                                            object:self
                                                                          userInfo:@{@"message": msg}];
                    });
                }
                break;
            }
                
            case 6: {
                // Прочтение входящих: [6, peer_id, local_id]
                if (event.count >= 3) {
                    NSInteger peerId = [event[1] integerValue];
                    NSInteger localId = [event[2] integerValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollDidReadMessagesNotification
                                                                            object:self
                                                                          userInfo:@{@"peer_id": @(peerId),
                                                                                     @"local_id": @(localId),
                                                                                     @"is_outgoing": @(NO)}];
                    });
                }
                break;
            }
                
            case 7: {
                // Прочтение исходящих: [7, peer_id, local_id]
                if (event.count >= 3) {
                    NSInteger peerId = [event[1] integerValue];
                    NSInteger localId = [event[2] integerValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollDidReadMessagesNotification
                                                                            object:self
                                                                          userInfo:@{@"peer_id": @(peerId),
                                                                                     @"local_id": @(localId),
                                                                                     @"is_outgoing": @(YES)}];
                    });
                }
                break;
            }
                
            case 61: {
                // Набор текста в ЛС: [61, user_id, flags]
                if (event.count >= 2) {
                    NSInteger userId = [event[1] integerValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollUserTypingNotification
                                                                            object:self
                                                                          userInfo:@{@"user_id": @(userId),
                                                                                     @"peer_id": @(userId)}];
                    });
                }
                break;
            }
                
            case 62: {
                // Набор текста в беседе: [62, user_id, chat_id]
                if (event.count >= 3) {
                    NSInteger userId = [event[1] integerValue];
                    NSInteger chatId = [event[2] integerValue];
                    NSInteger peerId = 2000000000 + chatId;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollUserTypingNotification
                                                                            object:self
                                                                          userInfo:@{@"user_id": @(userId),
                                                                                     @"peer_id": @(peerId)}];
                    });
                }
                break;
            }
                
            case 80: {
                // Счетчик непрочитанных: [80, count]
                if (event.count >= 2) {
                    NSInteger count = [event[1] integerValue];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:VKLongPollUnreadCountDidChangeNotification
                                                                            object:self
                                                                          userInfo:@{@"count": @(count)}];
                    });
                }
                break;
            }
                
            default:
                break;
        }
    }
}

@end
