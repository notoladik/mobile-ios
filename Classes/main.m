#import <UIKit/UIKit.h>
#import "VKAppDelegate.h"
#import "VKCrashLogger.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        [VKCrashLogger setupCrashHandler];
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([VKAppDelegate class]));
    }
}
