#import "VKPresetManager.h"

NSString *const VKPresetsDidUpdateNotification = @"VKPresetsDidUpdateNotification";

@implementation VKPresetManager

+ (NSString *)documentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
}

+ (NSString *)milkdropDocumentsDirectory {
    return [[self documentsDirectory] stringByAppendingPathComponent:@"Presets"];
}

+ (NSString *)avsDocumentsDirectory {
    return [[self documentsDirectory] stringByAppendingPathComponent:@"AVSPresets"];
}

+ (void)setupPresetDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *milkDir = [self milkdropDocumentsDirectory];
    if (![fm fileExistsAtPath:milkDir]) {
        [fm createDirectoryAtPath:milkDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *readme = [milkDir stringByAppendingPathComponent:@"README.txt"];
        NSString *txt = @"Поместите сюда пользовательские файлы пресетов Milkdrop 2 (.milk).\n";
        [txt writeToFile:readme atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    NSString *avsDir = [self avsDocumentsDirectory];
    if (![fm fileExistsAtPath:avsDir]) {
        [fm createDirectoryAtPath:avsDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *readme = [avsDir stringByAppendingPathComponent:@"README.txt"];
        NSString *txt = @"Поместите сюда пользовательские файлы пресетов Winamp AVS (.avs).\n";
        [txt writeToFile:readme atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

+ (NSArray<NSString *> *)scanDirectory:(NSString *)dir extension:(NSString *)ext {
    if (!dir || dir.length == 0) return @[];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) return @[];
    
    NSMutableArray *results = [NSMutableArray array];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *file in files) {
        if ([[file lowercaseString] hasSuffix:[ext lowercaseString]]) {
            [results addObject:[dir stringByAppendingPathComponent:file]];
        }
    }
    return results;
}

+ (NSArray<NSString *> *)allMilkdropPresetPaths {
    [self setupPresetDirectories];
    NSMutableOrderedSet<NSString *> *allPaths = [NSMutableOrderedSet orderedSet];
    
    // 1. Documents/Presets и Documents/Milkdrop
    [allPaths addObjectsFromArray:[self scanDirectory:[self milkdropDocumentsDirectory] extension:@".milk"]];
    [allPaths addObjectsFromArray:[self scanDirectory:[[self documentsDirectory] stringByAppendingPathComponent:@"Milkdrop"] extension:@".milk"]];
    [allPaths addObjectsFromArray:[self scanDirectory:[self documentsDirectory] extension:@".milk"]];
    
    // 2. Джейлбрейк пути (/var/mobile/Media/Presets, /var/mobile/Media/Milkdrop)
    [allPaths addObjectsFromArray:[self scanDirectory:@"/var/mobile/Media/Presets" extension:@".milk"]];
    [allPaths addObjectsFromArray:[self scanDirectory:@"/var/mobile/Media/Milkdrop" extension:@".milk"]];
    
    // 3. Бандл приложения (Resources/Presets)
    NSString *bundleRes = [[NSBundle mainBundle] resourcePath];
    [allPaths addObjectsFromArray:[self scanDirectory:[bundleRes stringByAppendingPathComponent:@"Presets"] extension:@".milk"]];
    [allPaths addObjectsFromArray:[self scanDirectory:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Presets"] extension:@".milk"]];
    
    NSArray *sorted = [[allPaths array] sortedArrayUsingComparator:^NSComparisonResult(NSString *p1, NSString *p2) {
        return [p1.lastPathComponent localizedStandardCompare:p2.lastPathComponent];
    }];
    return sorted;
}

+ (NSArray<NSString *> *)allAVSPresetPaths {
    [self setupPresetDirectories];
    NSMutableOrderedSet<NSString *> *allPaths = [NSMutableOrderedSet orderedSet];
    
    // 1. Documents/AVSPresets и Documents/AVS
    [allPaths addObjectsFromArray:[self scanDirectory:[self avsDocumentsDirectory] extension:@".avs"]];
    [allPaths addObjectsFromArray:[self scanDirectory:[[self documentsDirectory] stringByAppendingPathComponent:@"AVS"] extension:@".avs"]];
    [allPaths addObjectsFromArray:[self scanDirectory:[self documentsDirectory] extension:@".avs"]];
    
    // 2. Джейлбрейк пути (/var/mobile/Media/AVSPresets, /var/mobile/Media/AVS)
    [allPaths addObjectsFromArray:[self scanDirectory:@"/var/mobile/Media/AVSPresets" extension:@".avs"]];
    [allPaths addObjectsFromArray:[self scanDirectory:@"/var/mobile/Media/AVS" extension:@".avs"]];
    
    // 3. Бандл приложения (Resources/AVSPresets)
    NSString *bundleRes = [[NSBundle mainBundle] resourcePath];
    [allPaths addObjectsFromArray:[self scanDirectory:[bundleRes stringByAppendingPathComponent:@"AVSPresets"] extension:@".avs"]];
    [allPaths addObjectsFromArray:[self scanDirectory:bundleRes extension:@".avs"]];
    
    NSArray *sorted = [[allPaths array] sortedArrayUsingComparator:^NSComparisonResult(NSString *p1, NSString *p2) {
        return [p1.lastPathComponent localizedStandardCompare:p2.lastPathComponent];
    }];
    return sorted;
}

+ (NSArray<NSString *> *)customMilkdropPresetPaths {
    NSArray *all = [self allMilkdropPresetPaths];
    NSMutableArray *custom = [NSMutableArray array];
    for (NSString *p in all) {
        if ([self isCustomPresetPath:p]) {
            [custom addObject:p];
        }
    }
    return custom;
}

+ (NSArray<NSString *> *)customAVSPresetPaths {
    NSArray *all = [self allAVSPresetPaths];
    NSMutableArray *custom = [NSMutableArray array];
    for (NSString *p in all) {
        if ([self isCustomPresetPath:p]) {
            [custom addObject:p];
        }
    }
    return custom;
}

+ (BOOL)isCustomPresetPath:(NSString *)path {
    if (!path) return NO;
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    if ([path hasPrefix:bundlePath]) {
        return NO;
    }
    return YES;
}

+ (BOOL)deleteCustomPresetAtPath:(NSString *)path error:(NSError **)error {
    if (![self isCustomPresetPath:path]) {
        if (error) {
            *error = [NSError errorWithDomain:@"VKPresetManager" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Встроенные пресеты бандла нельзя удалять"}];
        }
        return NO;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ok = [fm removeItemAtPath:path error:error];
    if (ok) {
        [[NSNotificationCenter defaultCenter] postNotificationName:VKPresetsDidUpdateNotification object:nil];
    }
    return ok;
}

+ (BOOL)importPresetFromURL:(NSURL *)url error:(NSError **)error {
    if (!url) return NO;
    [self setupPresetDirectories];
    
    NSString *filename = [url lastPathComponent];
    NSString *ext = [[url pathExtension] lowercaseString];
    
    NSString *destDir = nil;
    if ([ext isEqualToString:@"milk"]) {
        destDir = [self milkdropDocumentsDirectory];
    } else if ([ext isEqualToString:@"avs"]) {
        destDir = [self avsDocumentsDirectory];
    } else {
        if (error) {
            *error = [NSError errorWithDomain:@"VKPresetManager" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Неподдерживаемый формат пресета. Допустимы .milk и .avs"}];
        }
        return NO;
    }
    
    NSString *destPath = [destDir stringByAppendingPathComponent:filename];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:destPath]) {
        [fm removeItemAtPath:destPath error:nil];
    }
    
    BOOL ok = [fm copyItemAtURL:url toURL:[NSURL fileURLWithPath:destPath] error:error];
    if (ok) {
        NSLog(@"[VKPresetManager] Successfully imported preset: %@", filename);
        [[NSNotificationCenter defaultCenter] postNotificationName:VKPresetsDidUpdateNotification object:nil];
    }
    return ok;
}

@end
