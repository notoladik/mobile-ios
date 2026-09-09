#import <Foundation/Foundation.h>

@interface VKAppConfig : NSObject

+ (NSString *)currentHost;
+ (void)setCurrentHost:(NSString *)host;
+ (NSURL *)apiBaseURL;
+ (NSArray<NSString *> *)availableInstances;
+ (void)addCustomInstance:(NSString *)host;
+ (void)removeCustomInstance:(NSString *)host;
+ (NSString *)cleanHostString:(NSString *)host;

@end
