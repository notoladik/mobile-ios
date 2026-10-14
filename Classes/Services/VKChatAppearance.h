#import <UIKit/UIKit.h>
#import "VKBackgroundVisualizerManager.h"

extern NSString *const VKChatAppearanceDidChangeNotification;
typedef NS_ENUM(NSInteger, VKChatBackgroundMode) {
    VKChatBackgroundModeDefault = 0, // inherit globally, or use the theme for peer 0
    VKChatBackgroundModeNone = 1,
    VKChatBackgroundModePhoto = 2,
    VKChatBackgroundModeVisualizer = 3
};

/* peerId == 0 edits defaults; other IDs override them. Local settings only. */
@interface VKChatAppearance : NSObject
+ (NSDictionary *)settingsForPeerId:(NSInteger)peerId;
+ (NSDictionary *)effectiveSettingsForPeerId:(NSInteger)peerId;
+ (void)setValue:(id)value forSetting:(NSString *)key peerId:(NSInteger)peerId;
+ (void)resetPeerId:(NSInteger)peerId;
+ (BOOL)hasOwnWallpaperForPeerId:(NSInteger)peerId;
+ (UIImage *)wallpaperForPeerId:(NSInteger)peerId;
+ (BOOL)saveWallpaper:(UIImage *)image peerId:(NSInteger)peerId error:(NSError **)error;
+ (void)removeWallpaperForPeerId:(NSInteger)peerId;
@end
