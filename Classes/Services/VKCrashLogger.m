#import "VKCrashLogger.h"
#import <UIKit/UIKit.h>
#include <signal.h>
#include <execinfo.h>

static void HandleException(NSException *exception) {
    NSString *name = [exception name];
    NSString *reason = [exception reason];
    NSArray *symbols = [exception callStackSymbols];
    
    NSString *crashInfo = [NSString stringWithFormat:@"\n=== CRASH EXCEPTION ===\nDate: %@\nName: %@\nReason: %@\nCallStack:\n%@\n=======================\n",
                           [NSDate date], name, reason, [symbols componentsJoinedByString:@"\n"]];
    
    NSLog(@"%@", crashInfo);
    
    NSString *path = [VKCrashLogger crashLogFilePath];
    NSData *data = [crashInfo dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToFile:path atomically:YES];
    }
}

static void HandleSignal(int sig) {
    void *callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    
    NSMutableArray *symbols = [NSMutableArray arrayWithCapacity:frames];
    for (int i = 0; i < frames; ++i) {
        if (strs[i]) {
            [symbols addObject:[NSString stringWithUTF8String:strs[i]]];
        }
    }
    free(strs);
    
    NSString *crashInfo = [NSString stringWithFormat:@"\n=== CRASH SIGNAL %d ===\nDate: %@\nCallStack:\n%@\n=======================\n",
                           sig, [NSDate date], [symbols componentsJoinedByString:@"\n"]];
    
    NSLog(@"%@", crashInfo);
    
    NSString *path = [VKCrashLogger crashLogFilePath];
    NSData *data = [crashInfo dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToFile:path atomically:YES];
    }
    
    signal(sig, SIG_DFL);
    raise(sig);
}

@implementation VKCrashLogger

+ (void)setupCrashHandler {
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT, HandleSignal);
    signal(SIGILL, HandleSignal);
    signal(SIGSEGV, HandleSignal);
    signal(SIGFPE, HandleSignal);
    signal(SIGBUS, HandleSignal);
    signal(SIGPIPE, HandleSignal);
    
    [VKCrashLogger log:@"[VKCrashLogger] Initialized crash handler successfully."];
}

+ (NSString *)logFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = (paths.count > 0) ? paths[0] : NSTemporaryDirectory();
    return [doc stringByAppendingPathComponent:@"app_log.txt"];
}

+ (NSString *)crashLogFilePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *doc = (paths.count > 0) ? paths[0] : NSTemporaryDirectory();
    return [doc stringByAppendingPathComponent:@"crash_log.txt"];
}

+ (void)log:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSLog(@"%@", entry);
    
    NSString *path = [self logFilePath];
    NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } else {
        [data writeToFile:path atomically:YES];
    }
}

+ (NSString *)readCrashLog {
    NSString *path = [self crashLogFilePath];
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

+ (NSString *)readAllLogs {
    NSString *crash = [self readCrashLog];
    NSString *appLog = [NSString stringWithContentsOfFile:[self logFilePath] encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *res = [NSMutableString string];
    if (crash.length > 0) {
        [res appendFormat:@"=== CRASH LOG ===\n%@\n\n", crash];
    }
    if (appLog.length > 0) {
        [res appendFormat:@"=== APP LOG ===\n%@\n", appLog];
    }
    if (res.length == 0) {
        [res appendString:@"Логов сбоев нет. Приложение работает стабильно."];
    }
    return res;
}

@end
