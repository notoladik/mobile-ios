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
        [self ensureDefaultPacksInstalled];
    }
    return self;
}

- (void)ensureDefaultPacksInstalled {
    NSArray *installed = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"];
    if (!installed || installed.count == 0) {
        // По умолчанию активируем Персика, Спотти и Сеню
        [[NSUserDefaults standardUserDefaults] setObject:@[@(1), @(2), @(3)] forKey:@"VKActiveStickerPackIds"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSString *)stickerURLForId:(NSInteger)stickerId {
    NSString *host = [VKAppConfig currentHost];
    if (host.length == 0) host = @"openvk.su";
    return [NSString stringWithFormat:@"https://%@/stickers/%ld/256.png", host, (long)stickerId];
}

- (VKSticker *)stickerWithId:(NSInteger)stickerId {
    for (VKStickerPack *pack in [self activeStickerPacks]) {
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

// Создание базового пака стикеров
- (VKStickerPack *)createDefaultPackWithId:(NSInteger)packId
                                     title:(NSString *)title
                               description:(NSString *)desc
                               startSticker:(NSInteger)start
                                 count:(NSInteger)count {
    VKStickerPack *pack = [[VKStickerPack alloc] init];
    pack.packId = packId;
    pack.title = title;
    pack.packDescription = desc;
    pack.isFree = YES;
    pack.previewURL = [self stickerURLForId:start];
    
    NSMutableArray<VKSticker *> *stList = [NSMutableArray array];
    for (NSInteger i = 0; i < count; i++) {
        VKSticker *st = [[VKSticker alloc] init];
        st.stickerId = start + i;
        st.imageURL = [self stickerURLForId:st.stickerId];
        [stList addObject:st];
    }
    pack.stickers = stList;
    return pack;
}

- (NSArray<VKStickerPack *> *)fallbackPacks {
    NSMutableArray<VKStickerPack *> *packs = [NSMutableArray array];
    [packs addObject:[self createDefaultPackWithId:1 title:@"Персик" description:@"Рыжий кот Персик полон эмоций." startSticker:1 count:48]];
    [packs addObject:[self createDefaultPackWithId:2 title:@"Спотти" description:@"Знаменитый пес Спотти." startSticker:49 count:48]];
    [packs addObject:[self createDefaultPackWithId:3 title:@"Сеня" description:@"Озорной хомяк Сеня." startSticker:97 count:32]];
    [packs addObject:[self createDefaultPackWithId:4 title:@"Колобки" description:@"Классические желтые колобки." startSticker:129 count:32]];
    return packs;
}

- (BOOL)isPackActive:(NSInteger)packId {
    NSArray *installed = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"];
    return [installed containsObject:@(packId)];
}

- (void)activatePack:(VKStickerPack *)pack {
    if (!pack) return;
    NSMutableArray *installed = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"] ?: @[]];
    if (![installed containsObject:@(pack.packId)]) {
        [installed addObject:@(pack.packId)];
        [[NSUserDefaults standardUserDefaults] setObject:installed forKey:@"VKActiveStickerPackIds"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)deactivatePackId:(NSInteger)packId {
    NSMutableArray *installed = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"] ?: @[]];
    [installed removeObject:@(packId)];
    [[NSUserDefaults standardUserDefaults] setObject:installed forKey:@"VKActiveStickerPackIds"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray<VKStickerPack *> *)activeStickerPacks {
    NSArray *installedIds = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKActiveStickerPackIds"] ?: @[@(1), @(2), @(3)];
    
    // Сначала ищем в кэшированных из магазина
    NSMutableArray<VKStickerPack *> *result = [NSMutableArray array];
    NSMutableSet<NSNumber *> *foundIds = [NSMutableSet set];
    
    for (NSNumber *pid in installedIds) {
        for (VKStickerPack *p in self.cachedStorePacks) {
            if (p.packId == [pid integerValue]) {
                [result addObject:p];
                [foundIds addObject:pid];
                break;
            }
        }
    }
    
    // Если каких-то паков нет в кэше магазина, берем из fallback
    NSArray *fallbacks = [self fallbackPacks];
    for (NSNumber *pid in installedIds) {
        if (![foundIds containsObject:pid]) {
            for (VKStickerPack *p in fallbacks) {
                if (p.packId == [pid integerValue]) {
                    [result addObject:p];
                    break;
                }
            }
        }
    }
    
    if (result.count == 0) {
        return fallbacks;
    }
    
    return result;
}

- (void)fetchStorePacksWithCompletion:(void (^)(NSArray<VKStickerPack *> *packs, NSError *error))completion {
    // Вызываем store.getStockItems с типом stickers
    NSDictionary *params = @{
        @"type": @"stickers"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"store.getStockItems" parameters:params completionHandler:^(id response, NSError *error) {
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
                pack.packId = [product[@"id"] integerValue];
                pack.title = product[@"title"] ?: @"Стикеры";
                pack.packDescription = product[@"description"] ?: @"";
                pack.isFree = [product[@"free"] boolValue] || ([product[@"price"] integerValue] == 0);
                pack.isPurchased = [it[@"purchased"] boolValue];
                
                // Превью
                NSArray *previews = product[@"previews"];
                if ([previews isKindOfClass:[NSArray class]] && previews.count > 0) {
                    NSDictionary *prev = [previews lastObject];
                    pack.previewURL = prev[@"url"];
                } else {
                    pack.previewURL = product[@"photo_256"] ?: product[@"photo_128"];
                }
                
                // Стикеры
                NSArray *rawStickers = product[@"stickers"];
                if ([rawStickers isKindOfClass:[NSArray class]]) {
                    NSMutableArray<VKSticker *> *stList = [NSMutableArray array];
                    for (NSDictionary *stDict in rawStickers) {
                        if (![stDict isKindOfClass:[NSDictionary class]]) continue;
                        VKSticker *st = [[VKSticker alloc] init];
                        st.stickerId = [stDict[@"sticker_id"] integerValue] ?: [stDict[@"id"] integerValue];
                        
                        NSArray *images = stDict[@"images"];
                        if ([images isKindOfClass:[NSArray class]] && images.count > 0) {
                            NSDictionary *best = [images lastObject];
                            st.imageURL = best[@"url"];
                        } else {
                            st.imageURL = stDict[@"photo_256"] ?: stDict[@"photo_128"] ?: [self stickerURLForId:st.stickerId];
                        }
                        if (st.stickerId != 0) {
                            [stList addObject:st];
                        }
                    }
                    pack.stickers = stList;
                }
                
                if (pack.packId != 0) {
                    [parsedPacks addObject:pack];
                }
            }
        }
        
        // Объединяем с дефолтными паками (если сервер вернул пустоту или мало)
        if (parsedPacks.count == 0) {
            [parsedPacks addObjectsFromArray:[self fallbackPacks]];
        } else {
            // Добавляем fallback паки, которых нет в ответе
            for (VKStickerPack *fb in [self fallbackPacks]) {
                BOOL exists = NO;
                for (VKStickerPack *p in parsedPacks) {
                    if (p.packId == fb.packId) {
                        exists = YES;
                        break;
                    }
                }
                if (!exists) {
                    [parsedPacks addObject:fb];
                }
            }
        }
        
        [self.cachedStorePacks removeAllObjects];
        [self.cachedStorePacks addObjectsFromArray:parsedPacks];
        
        if (completion) {
            completion(parsedPacks, nil);
        }
    }];
}

@end
