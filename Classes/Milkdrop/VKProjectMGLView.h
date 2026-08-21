#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface VKProjectMGLView : UIView

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) BOOL shuffleMode;
@property (nonatomic, assign) NSTimeInterval autoSwitchInterval;

- (void)startAnimation;
- (void)stopAnimation;
- (void)nextPreset;
- (void)previousPreset;
- (void)randomPreset;
- (NSString *)currentPresetName;
- (void)showPresetBadge;

// Загрузка реального .milk файла через официальный projectM API
- (void)loadPresetFromFile:(NSString *)filePath;

@end
