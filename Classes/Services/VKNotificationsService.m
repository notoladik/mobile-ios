#import "VKNotificationsService.h"
#import "VKAPIClient.h"
#import "VKCrashLogger.h"

@implementation VKNotificationsService

+ (instancetype)sharedService {
    static VKNotificationsService *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[self alloc] init];
    });
    return _shared;
}

- (void)fetchNotificationsWithArchived:(BOOL)archived
                                offset:(NSInteger)offset
                                 count:(NSInteger)count
                            completion:(void (^)(NSArray *notifications, NSError *error))completion {
    // Сначала запрашиваем активные уведомления
    NSDictionary *paramsNew = @{
        @"count": @(count > 0 ? count : 30),
        @"offset": @(offset),
        @"archived": @"0"
    };
    
    [VKCrashLogger log:@"[VKNotificationsService] Fetching notifications (archived=0)..."];
    
    [[VKAPIClient sharedClient] callMethod:@"notifications.get" parameters:paramsNew completionHandler:^(id responseNew, NSError *errorNew) {
        NSMutableArray *allNotifications = [NSMutableArray array];
        
        NSDictionary *dictNew = [responseNew isKindOfClass:[NSDictionary class]] ? (responseNew[@"response"] ?: responseNew) : nil;
        if (dictNew) {
            NSArray *itemsNew = dictNew[@"items"] ?: @[];
            NSArray *profilesArr = dictNew[@"profiles"] ?: @[];
            NSArray *groupsArr = dictNew[@"groups"] ?: @[];
            
            NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
            for (NSDictionary *p in profilesArr) {
                VKUser *u = [VKUser userFromDictionary:p];
                if (u.uid != 0) profiles[@(u.uid)] = u;
            }
            
            NSMutableDictionary *groups = [NSMutableDictionary dictionary];
            for (NSDictionary *g in groupsArr) {
                VKUser *grp = [VKUser groupFromDictionary:g];
                if (grp.uid != 0) groups[@(labs(grp.uid))] = grp;
            }
            
            for (NSDictionary *item in itemsNew) {
                VKNotification *notif = [VKNotification notificationFromDictionary:item profiles:profiles groups:groups isArchived:NO];
                if (notif) [allNotifications addObject:notif];
            }
        }
        
        // Затем запрашиваем архивные уведомления
        NSDictionary *paramsArch = @{
            @"count": @(count > 0 ? count : 30),
            @"offset": @(offset),
            @"archived": @"1"
        };
        
        [VKCrashLogger log:@"[VKNotificationsService] Fetching archived notifications (archived=1)..."];
        
        [[VKAPIClient sharedClient] callMethod:@"notifications.get" parameters:paramsArch completionHandler:^(id responseArch, NSError *errorArch) {
            NSDictionary *dictArch = [responseArch isKindOfClass:[NSDictionary class]] ? (responseArch[@"response"] ?: responseArch) : nil;
            if (dictArch) {
                NSArray *itemsArch = dictArch[@"items"] ?: @[];
                NSArray *profilesArr = dictArch[@"profiles"] ?: @[];
                NSArray *groupsArr = dictArch[@"groups"] ?: @[];
                
                NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
                for (NSDictionary *p in profilesArr) {
                    VKUser *u = [VKUser userFromDictionary:p];
                    if (u.uid != 0) profiles[@(u.uid)] = u;
                }
                
                NSMutableDictionary *groups = [NSMutableDictionary dictionary];
                for (NSDictionary *g in groupsArr) {
                    VKUser *grp = [VKUser groupFromDictionary:g];
                    if (grp.uid != 0) groups[@(labs(grp.uid))] = grp;
                }
                
                for (NSDictionary *item in itemsArch) {
                    VKNotification *notif = [VKNotification notificationFromDictionary:item profiles:profiles groups:groups isArchived:YES];
                    if (notif) [allNotifications addObject:notif];
                }
            }
            
            [VKCrashLogger log:[NSString stringWithFormat:@"[VKNotificationsService] Total notifications loaded: %lu", (unsigned long)allNotifications.count]];
            
            if (completion) {
                completion([allNotifications copy], (allNotifications.count > 0) ? nil : errorNew);
            }
        }];
    }];
}

- (void)markAsReadWithCompletion:(void (^)(BOOL success))completion {
    [[VKAPIClient sharedClient] callMethod:@"notifications.markAsViewed" parameters:@{} completionHandler:^(id response, NSError *error) {
        if (completion) completion(!error);
    }];
}

@end
