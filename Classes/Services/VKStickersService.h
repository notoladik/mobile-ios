#import <Foundation/Foundation.h>

@interface VKSticker : NSObject
@property (nonatomic, assign) NSInteger stickerId;
@property (nonatomic, copy) NSString *imageURL;
@end

@interface VKStickerPack : NSObject
@property (nonatomic, assign) NSInteger packId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *packDescription;
@property (nonatomic, copy) NSString *previewURL;
@property (nonatomic, strong) NSArray<VKSticker *> *stickers;
@property (nonatomic, assign) BOOL isFree;
@property (nonatomic, assign) BOOL isPurchased;
@end

@interface VKStickersService : NSObject

+ (instancetype)sharedService;

// Получение URL стикера по его ID
- (NSString *)stickerURLForId:(NSInteger)stickerId;
- (NSString *)stickerURLForId:(NSInteger)stickerId packId:(NSInteger)packId;

// Преобразование относительного URL в абсолютный с учетом текущего хоста
- (NSString *)normalizeURL:(NSString *)urlStr;

// Поиск или создание объекта стикера по ID
- (VKSticker *)stickerWithId:(NSInteger)stickerId;

// Получение списка активных (установленных) паков для пикера
- (NSArray<VKStickerPack *> *)activeStickerPacks;

// Загрузка всех доступных паков (для магазина стикеров)
- (void)fetchStorePacksWithCompletion:(void (^)(NSArray<VKStickerPack *> *packs, NSError *error))completion;

// Активация/деактивация пака
- (BOOL)isPackActive:(NSInteger)packId;
- (void)activatePack:(VKStickerPack *)pack;
- (void)deactivatePackId:(NSInteger)packId;

@end
