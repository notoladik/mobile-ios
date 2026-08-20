#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface VKMilkdropView : UIView

@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) NSInteger currentPresetIndex;

- (void)startAnimation;
- (void)stopAnimation;
- (void)nextPreset;
- (void)previousPreset;
- (NSString *)currentPresetName;

@end
