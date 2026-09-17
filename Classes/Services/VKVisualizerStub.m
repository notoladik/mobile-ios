#import "VKAVSGLView.h"
#import "VKProjectMGLView.h"

#if !defined(ENABLE_AVS_VISUALIZER) || !ENABLE_AVS_VISUALIZER
@implementation VKAVSGLView
- (void)startAnimation {}
- (void)stopAnimation {}
- (void)nextPreset {}
- (void)previousPreset {}
- (void)randomPreset {}
- (NSString *)currentPresetName { return @""; }
- (void)showPresetBadge {}
- (void)loadPresetFromFile:(NSString *)filePath {}
@end
#endif

#if !defined(ENABLE_MILKDROP_VISUALIZER) || !ENABLE_MILKDROP_VISUALIZER
@implementation VKProjectMGLView
- (void)startAnimation {}
- (void)stopAnimation {}
- (void)nextPreset {}
- (void)previousPreset {}
- (void)randomPreset {}
- (NSString *)currentPresetName { return @""; }
- (void)showPresetBadge {}
- (void)loadPresetFromFile:(NSString *)filePath {}
@end
#endif
