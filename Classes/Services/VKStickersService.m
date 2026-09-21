#import "VKStickersService.h"
#import "VKAPIClient.h"
#import "VKAppConfig.h"

@implementation VKSticker
@end

@implementation VKStickerPack
@end

@interface VKStickersService ()
@property (nonatomic, strong) NSMutableArray<VKStickerPack *> *cachedStorePacks;
@end

@implementation VKStickersService

+ (instancetype)sharedService {
    static VKStickersService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[VKStickersService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cachedStorePacks = [NSMutableArray array];
    }
    return self;
}

- (NSString *)normalizeURL:(NSString *)urlStr {
    if (!urlStr || ![urlStr isKindOfClass:[NSString class]] || urlStr.length == 0) return nil;
    if ([urlStr hasPrefix:@"http://"] || [urlStr hasPrefix:@"https://"]) {
        return urlStr;
    }
    if ([urlStr hasPrefix:@"//"]) {
        return [NSString stringWithFormat:@"https:%@", urlStr];
    }
    NSString *host = [VKAppConfig currentHost];
    if (host.length == 0) host = @"openvk.su";
    if (![urlStr hasPrefix:@"/"]) {
        urlStr = [@"/" stringByAppendingString:urlStr];
    }
    return [NSString stringWithFormat:@"https://%@%@", host, urlStr];
}

- (NSString *)stickerURLForId:(NSInteger)stickerId packId:(NSInteger)packId {
    NSString *host = [VKAppConfig currentHost];
    if (host.length == 0) host = @"openvk.su";
    // В OpenVK маршрут к растровому PNG стикера:
    // /images/stickers/{id}/256.png
    return [NSString stringWithFormat:@"https://%@/images/stickers/%ld/256.png", host, (long)stickerId];
}

- (NSString *)stickerURLForId:(NSInteger)stickerId {
    return [self stickerURLForId:stickerId packId:0];
}

- (VKSticker *)stickerWithId:(NSInteger)stickerId {
    for (VKStickerPack *pack in self.cachedStorePacks) {
        for (VKSticker *st in pack.stickers) {
            if (st.stickerId == stickerId) {
                return st;
            }
        }
    }
    VKSticker *st = [[VKSticker alloc] init];
    st.stickerId = stickerId;
    st.imageURL = [self stickerURLForId:stickerId];
    return st;
}

- (BOOL)isPackActive:(NSInteger)packId {
    NSArray *installed = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"];
    if (installed) {
        return [installed containsObject:@(packId)];
    }
    for (VKStickerPack *p in self.cachedStorePacks) {
        if (p.packId == packId) {
            return p.isPurchased || p.isFree;
        }
    }
    return NO;
}

- (void)activatePack:(VKStickerPack *)pack {
    if (!pack) return;
    NSMutableArray *installed = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"] ?: @[]];
    if (![installed containsObject:@(pack.packId)]) {
        [installed addObject:@(pack.packId)];
        [[NSUserDefaults standardUserDefaults] setObject:installed forKey:@"VKActiveStickerPackIds"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    pack.isPurchased = YES;
    
    // Оповещаем бэкенд OpenVK
    NSDictionary *params = @{@"product_id": @(pack.packId)};
    [[VKAPIClient sharedClient] callMethod:@"store.activateProduct" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            [[VKAPIClient sharedClient] callMethod:@"store.buy" parameters:params completionHandler:nil];
        }
    }];
}

- (void)deactivatePackId:(NSInteger)packId {
    NSMutableArray *installed = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"] ?: @[]];
    [installed removeObject:@(packId)];
    [[NSUserDefaults standardUserDefaults] setObject:installed forKey:@"VKActiveStickerPackIds"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    for (VKStickerPack *p in self.cachedStorePacks) {
        if (p.packId == packId) {
            p.isPurchased = NO;
            break;
        }
    }
    
    NSDictionary *params = @{@"product_id": @(packId)};
    [[VKAPIClient sharedClient] callMethod:@"store.deactivateProduct" parameters:params completionHandler:nil];
}

- (NSArray<VKStickerPack *> *)activeStickerPacks {
    NSMutableArray<VKStickerPack *> *result = [NSMutableArray array];
    NSArray *installedIds = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"];
    
    if (installedIds) {
        for (NSNumber *pid in installedIds) {
            for (VKStickerPack *p in self.cachedStorePacks) {
                if (p.packId == [pid integerValue]) {
                    [result addObject:p];
                    break;
                }
            }
        }
    } else {
        for (VKStickerPack *p in self.cachedStorePacks) {
            if (p.isPurchased || p.isFree) {
                [result addObject:p];
            }
        }
    }
    
    return result;
}

- (void)fetchStorePacksWithCompletion:(void (^)(NSArray<VKStickerPack *> *packs, NSError *error))completion {
    NSDictionary *params = @{
        @"type": @"stickers",
        @"extended": @"1"
    };
    
    __weak typeof(self) weakSelf = self;
    [[VKAPIClient sharedClient] callMethod:@"store.getStockItems" parameters:params completionHandler:^(id response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        NSArray *rawItems = nil;
        if ([response isKindOfClass:[NSDictionary class]]) {
            NSDictionary *respDict = response[@"response"] ?: response;
            rawItems = respDict[@"items"];
        }
        
        NSMutableArray<VKStickerPack *> *parsedPacks = [NSMutableArray array];
        
        if ([rawItems isKindOfClass:[NSArray class]] && rawItems.count > 0) {
            for (NSDictionary *it in rawItems) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *product = it[@"product"] ?: it;
                
                VKStickerPack *pack = [[VKStickerPack alloc] init];
                pack.packId = [product[@"id"] integerValue] ?: [it[@"id"] integerValue];
                pack.title = product[@"title"] ?: product[@"name"] ?: it[@"title"] ?: @"Стикеры";
                pack.packDescription = product[@"description"] ?: it[@"description"] ?: @"";
                
                BOOL isFree = [product[@"free"] boolValue] || [it[@"free"] boolValue] ||
                              ([product[@"price"] integerValue] == 0 && [it[@"price"] integerValue] == 0);
                pack.isFree = isFree;
                
                BOOL isPurchased = [it[@"purchased"] boolValue] || [product[@"purchased"] boolValue] || [product[@"active"] boolValue];
                pack.isPurchased = isPurchased;
                
                // base_url
                NSString *baseUrl = product[@"base_url"] ?: it[@"base_url"];
                if (![baseUrl isKindOfClass:[NSString class]] || baseUrl.length == 0) {
                    NSString *host = [VKAppConfig currentHost];
                    if (host.length == 0) host = @"openvk.su";
                    baseUrl = [NSString stringWithFormat:@"https://%@/images/stickers/", host];
                }
                if (![baseUrl hasSuffix:@"/"]) {
                    baseUrl = [baseUrl stringByAppendingString:@"/"];
                }
                
                // Превью
                NSString *preview = nil;
                NSArray *previews = product[@"previews"] ?: it[@"previews"];
                if ([previews isKindOfClass:[NSArray class]] && previews.count > 0) {
                    id firstPrev = [previews firstObject];
                    if ([firstPrev isKindOfClass:[NSDictionary class]]) {
                        NSDictionary *pDict = (NSDictionary *)firstPrev;
                        preview = pDict[@"photo_256"] ?: pDict[@"photo_128"] ?: pDict[@"photo_512"] ?: pDict[@"url"];
                    } else if ([firstPrev isKindOfClass:[NSString class]]) {
                        preview = firstPrev;
                    }
                }
                if (!preview || preview.length == 0) {
                    preview = product[@"photo_256"] ?: product[@"photo_128"] ?: product[@"photo_512"] ?:
                              it[@"photo_256"] ?: it[@"photo_128"] ?: it[@"photo_512"];
                }
                pack.previewURL = [strongSelf normalizeURL:preview];
                
                // Стикеры
                NSMutableArray<VKSticker *> *stList = [NSMutableArray array];
                NSArray *rawStickers = product[@"stickers"] ?: it[@"stickers"];
                if ([rawStickers isKindOfClass:[NSArray class]] && rawStickers.count > 0) {
                    for (id stItem in rawStickers) {
                        NSInteger sid = 0;
                        NSString *stUrl = nil;
                        if ([stItem isKindOfClass:[NSDictionary class]]) {
                            NSDictionary *stDict = (NSDictionary *)stItem;
                            sid = [stDict[@"sticker_id"] integerValue] ?: [stDict[@"id"] integerValue];
                            NSArray *images = stDict[@"images"];
                            if ([images isKindOfClass:[NSArray class]] && images.count > 0) {
                                id best = [images lastObject];
                                if ([best isKindOfClass:[NSDictionary class]]) {
                                    stUrl = best[@"url"];
                                }
                            }
                            if (!stUrl || stUrl.length == 0) {
                                stUrl = stDict[@"photo_256"] ?: stDict[@"photo_128"] ?: stDict[@"photo_512"];
                            }
                        } else if ([stItem respondsToSelector:@selector(integerValue)]) {
                            sid = [stItem integerValue];
                        }
                        if (sid <= 0) continue;
                        
                        if (!stUrl || stUrl.length == 0) {
                            stUrl = [NSString stringWithFormat:@"%@%ld/256.png", baseUrl, (long)sid];
                        }
                        
                        VKSticker *st = [[VKSticker alloc] init];
                        st.stickerId = sid;
                        st.imageURL = [strongSelf normalizeURL:stUrl];
                        [stList addObject:st];
                    }
                } else {
                    NSArray *rawIds = product[@"sticker_ids"] ?: it[@"sticker_ids"];
                    if ([rawIds isKindOfClass:[NSArray class]]) {
                        for (id sidObj in rawIds) {
                            NSInteger sid = [sidObj integerValue];
                            if (sid <= 0) continue;
                            VKSticker *st = [[VKSticker alloc] init];
                            st.stickerId = sid;
                            st.imageURL = [strongSelf normalizeURL:[NSString stringWithFormat:@"%@%ld/256.png", baseUrl, (long)sid]];
                            [stList addObject:st];
                        }
                    }
                }
                
                pack.stickers = stList;
                if ((!pack.previewURL || pack.previewURL.length == 0) && stList.count > 0) {
                    pack.previewURL = stList.firstObject.imageURL;
                }
                
                if (pack.packId != 0) {
                    [parsedPacks addObject:pack];
                }
            }
        }
        
        // Синхронизация активных паков в NSUserDefaults (удаляем несуществующие dummy ID)
        NSArray *savedInstalled = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"];
        NSMutableArray *cleanedInstalled = [NSMutableArray array];
        if (savedInstalled) {
            for (NSNumber *pid in savedInstalled) {
                for (VKStickerPack *p in parsedPacks) {
                    if (p.packId == [pid integerValue]) {
                        [cleanedInstalled addObject:pid];
                        break;
                    }
                }
            }
        }
        
        // Если еще ничего не сохранено или старый дефолтный список содержал только несуществующие ID:
        if (cleanedInstalled.count == 0 && parsedPacks.count > 0) {
            for (VKStickerPack *p in parsedPacks) {
                if (p.isPurchased || p.isFree) {
                    [cleanedInstalled addObject:@(p.packId)];
                }
            }
            if (cleanedInstalled.count == 0) {
                [cleanedInstalled addObject:@(parsedPacks.firstObject.packId)];
            }
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:cleanedInstalled forKey:@"VKActiveStickerPackIds"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [strongSelf.cachedStorePacks removeAllObjects];
        [strongSelf.cachedStorePacks addObjectsFromArray:parsedPacks];
        
        if (completion) {
            completion(parsedPacks, error);
        }
    }];
}

@end
