#import <Foundation/Foundation.h>

extern NSString *const VKPresetsDidUpdateNotification;

typedef NS_ENUM(NSInteger, VKPresetEngine) {
    VKPresetEngineMilkdrop = 0,
    VKPresetEngineAVS = 1
};

@interface VKPresetManager : NSObject

+ (void)setupPresetDirectories;

+ (NSString *)milkdropDocumentsDirectory;
+ (NSString *)avsDocumentsDirectory;

+ (NSArray<NSString *> *)allMilkdropPresetPaths;
+ (NSArray<NSString *> *)allAVSPresetPaths;

+ (NSArray<NSString *> *)customMilkdropPresetPaths;
+ (NSArray<NSString *> *)customAVSPresetPaths;

+ (BOOL)isCustomPresetPath:(NSString *)path;
+ (BOOL)deleteCustomPresetAtPath:(NSString *)path error:(NSError **)error;

+ (BOOL)importPresetFromURL:(NSURL *)url error:(NSError **)error;

@end
