#import <Foundation/Foundation.h>

@interface VKCrashLogger : NSObject

+ (void)setupCrashHandler;
+ (void)log:(NSString *)format, ...;
+ (NSString *)logFilePath;
+ (NSString *)crashLogFilePath;
+ (NSString *)readCrashLog;
+ (NSString *)readAllLogs;

@end
