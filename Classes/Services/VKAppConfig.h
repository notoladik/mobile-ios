extern NSString *const VKNSFWSettingDidChangeNotification;

typedef NS_ENUM(NSInteger, VKNSFWDisplayMode) {
    VKNSFWDisplayModeSpoiler = 0,      // Скрывать под плашку (по умолчанию)
    VKNSFWDisplayModeShowAlways = 1,   // Показывать сразу
    VKNSFWDisplayModeHideCompletely = 2 // Полностью скрывать из ленты
};

@interface VKAppConfig : NSObject

+ (NSString *)currentHost;
+ (void)setCurrentHost:(NSString *)host;
+ (NSURL *)apiBaseURL;
+ (NSArray<NSString *> *)availableInstances;
+ (void)addCustomInstance:(NSString *)host;
+ (void)removeCustomInstance:(NSString *)host;
+ (NSString *)cleanHostString:(NSString *)host;

// NSFW / Контент 18+
+ (BOOL)isNSFWFilterEnabled;
+ (void)setNSFWFilterEnabled:(BOOL)enabled;

+ (VKNSFWDisplayMode)nsfwDisplayMode;
+ (void)setNSFWDisplayMode:(VKNSFWDisplayMode)mode;

@end
