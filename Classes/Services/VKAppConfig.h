#import <Foundation/Foundation.h>

@interface VKAppConfig : NSObject

+ (NSString *)currentHost;
+ (void)setCurrentHost:(NSString *)host;
+ (NSURL *)apiBaseURL;
+ (NSArray *)availableInstances;

@end
