#import "VKProjectMGLView.h"
#import <QuartzCore/QuartzCore.h>
#include "projectM-4/projectM.h"
#include "projectM-4/render_opengl.h"
#include <new>
#include <cstdlib>

extern "C" void* glad_eglGetProcAddress(const char* name) {
    return nullptr;
}

void* operator new(std::size_t size, std::align_val_t alignment) {
    void* ptr = nullptr;
    if (posix_memalign(&ptr, static_cast<size_t>(alignment), size) != 0) {
        throw std::bad_alloc();
    }
    return ptr;
}

void operator delete(void* ptr, std::align_val_t alignment) noexcept {
    free(ptr);
}

void operator delete(void* ptr, std::size_t size, std::align_val_t alignment) noexcept {
    free(ptr);
}

@interface VKProjectMGLView () {
    projectm_handle _pm;
    GLuint _defaultFramebuffer;
    GLuint _colorRenderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;
}
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) NSMutableArray<NSString *> *presetPaths;
@property (nonatomic, assign) NSInteger currentPresetIndex;
@property (nonatomic, strong) UILabel *presetBadgeLabel;
@property (nonatomic, strong) UILabel *debugStatusLabel;
@end

@implementation VKProjectMGLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isPlaying = YES;
        _currentPresetIndex = 0;
        _presetPaths = [NSMutableArray array];
        
        self.contentScaleFactor = [UIScreen mainScreen].scale;
        
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.contentsScale = [UIScreen mainScreen].scale;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = @{
            kEAGLDrawablePropertyRetainedBacking: @(NO),
            kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
        };
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if (!_context) {
            _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        }
        
        if (_context && [EAGLContext setCurrentContext:_context]) {
            [self setupBuffers];
            [self initProjectM];
        }
        
        self.layer.cornerRadius = 6.0;
        self.clipsToBounds = YES;
        self.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(nextPreset)];
        [self addGestureRecognizer:tap];
        
        _presetBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 240, 24)];
        _presetBadgeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _presetBadgeLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:220.0/255.0 blue:255.0/255.0 alpha:1.0];
        _presetBadgeLabel.font = [UIFont boldSystemFontOfSize:11];
        _presetBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _presetBadgeLabel.layer.cornerRadius = 4.0;
        _presetBadgeLabel.clipsToBounds = YES;
        _presetBadgeLabel.alpha = 0.0;
        [self addSubview:_presetBadgeLabel];
        
        _debugStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 5, 310, 115)];
        _debugStatusLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
        _debugStatusLabel.textColor = [UIColor yellowColor];
        _debugStatusLabel.font = [UIFont fontWithName:@"Courier" size:9] ?: [UIFont systemFontOfSize:9];
        _debugStatusLabel.numberOfLines = 0;
        _debugStatusLabel.text = @"Initializing MilkDrop Telemetry...";
        [self addSubview:_debugStatusLabel];
        
        [self loadPresetsList];
        [self startAnimation];
    }
    return self;
}

- (void)destroyBuffers {
    if (_defaultFramebuffer) {
        glDeleteFramebuffers(1, &_defaultFramebuffer);
        _defaultFramebuffer = 0;
    }
    if (_colorRenderbuffer) {
        glDeleteRenderbuffers(1, &_colorRenderbuffer);
        _colorRenderbuffer = 0;
    }
}

- (void)setupBuffers {
    [self destroyBuffers];
    
    glGenFramebuffers(1, &_defaultFramebuffer);
    glGenRenderbuffers(1, &_colorRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
}

static void projectMLogCallback(const char* message, projectm_log_level log_level, void* user_data) {
    if (log_level >= PROJECTM_LOG_LEVEL_WARN) {
        NSLog(@"[libprojectM log lvl=%d] %s", (int)log_level, message);
    }
}

- (void)initProjectM {
    if (_pm) return;
    if (!_context) return;
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    
    projectm_set_log_level(PROJECTM_LOG_LEVEL_DEBUG, false);
    projectm_set_log_callback(projectMLogCallback, false, nullptr);
    
    _pm = projectm_create();
    NSLog(@"[VKProjectMGLView] projectm_create -> %p (w=%d, h=%d)", _pm, _backingWidth, _backingHeight);
    if (_pm) {
        projectm_set_window_size(_pm, (size_t)MAX(64, _backingWidth), (size_t)MAX(64, _backingHeight));
        projectm_set_fps(_pm, 60);
        projectm_set_mesh_size(_pm, 24, 18);
        projectm_set_aspect_correction(_pm, false);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_context) return;
    
    if ([EAGLContext currentContext] != _context) {
        [EAGLContext setCurrentContext:_context];
    }
    
    [self setupBuffers];
    
    if (!_pm && _backingWidth > 0 && _backingHeight > 0) {
        [self initProjectM];
        [self loadPresetsList];
    } else if (_pm && _backingWidth > 0 && _backingHeight > 0) {
        projectm_set_window_size(_pm, (size_t)_backingWidth, (size_t)_backingHeight);
    }
}

static const char* kDefaultMilkdropPreset = 
"[preset00]\n"
"fRating=3.000000\n"
"fGammaAdj=1.000000\n"
"fDecay=0.980000\n"
"fVideoEchoZoom=1.006596\n"
"fVideoEchoAlpha=0.500000\n"
"nVideoEchoOrientation=3\n"
"nWaveMode=0\n"
"bAdditiveWaves=0\n"
"bWaveDots=0\n"
"bWaveThick=1\n"
"bModWaveAlphaByVolume=0\n"
"bMaximizeWaveColor=1\n"
"fWaveAlpha=0.800000\n"
"fWaveScale=1.000000\n"
"fWaveSmoothing=0.750000\n"
"fWaveParam=0.000000\n"
"fModWaveAlphaStart=0.750000\n"
"fModWaveAlphaEnd=0.950000\n"
"fWarpAnimSpeed=1.000000\n"
"fWarpScale=1.331000\n"
"fZoomExponent=1.000000\n"
"fShader=0.000000\n"
"zoom=1.010000\n"
"rot=0.020000\n"
"cx=0.500000\n"
"cy=0.500000\n"
"dx=0.000000\n"
"dy=0.000000\n"
"warp=0.050000\n"
"sx=1.000000\n"
"sy=1.000000\n"
"wave_r=0.650000\n"
"wave_g=0.850000\n"
"wave_b=1.000000\n"
"wave_x=0.500000\n"
"wave_y=0.500000\n"
"ob_size=0.010000\n"
"ob_r=0.000000\n"
"ob_g=0.000000\n"
"ob_b=0.000000\n"
"ob_a=0.000000\n"
"ib_size=0.010000\n"
"ib_r=0.250000\n"
"ib_g=0.250000\n"
"ib_b=0.250000\n"
"ib_a=0.000000\n"
"nMotionVectorsX=12.000000\n"
"nMotionVectorsY=9.000000\n"
"mv_l=0.900000\n"
"mv_r=1.000000\n"
"mv_g=1.000000\n"
"mv_b=1.000000\n"
"mv_a=0.000000\n"
"per_frame_1=wave_r = wave_r + 0.350*( 0.60*sin(0.980*time) + 0.40*sin(1.047*time) );\n"
"per_frame_2=wave_g = wave_g + 0.350*( 0.60*sin(0.835*time) + 0.40*sin(1.081*time) );\n"
"per_frame_3=wave_b = wave_b + 0.350*( 0.60*sin(0.814*time) + 0.40*sin(1.011*time) );\n"
"per_frame_4=rot = rot + 0.030*( 0.60*sin(0.381*time) + 0.40*sin(0.579*time) );\n"
"per_frame_5=cx = cx + 0.110*( 0.60*sin(0.374*time) + 0.40*sin(0.294*time) );\n"
"per_frame_6=cy = cy + 0.110*( 0.60*sin(0.393*time) + 0.40*sin(0.223*time) );\n"
"per_frame_7=zoom = zoom + 0.050*( 0.60*sin(0.150*time) + 0.40*sin(0.432*time) );\n"
"per_pixel_1=rad_custom = rad*rad;\n"
"per_pixel_2=zoom = zoom + 0.03*sin(rad_custom*6.28 + time*2.0);\n";

- (void)loadPresetsList {
    if (self.presetPaths.count > 0) return;
    
    NSString *bundleRes = [[NSBundle mainBundle] resourcePath];
    NSArray *searchDirs = @[
        [bundleRes stringByAppendingPathComponent:@"Presets"],
        bundleRes,
        [[NSBundle mainBundle] bundlePath],
        [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Presets"]
    ];
    for (NSString *dir in searchDirs) {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
            NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
            for (NSString *file in files) {
                if ([[[file pathExtension] lowercaseString] isEqualToString:@"milk"]) {
                    NSString *full = [dir stringByAppendingPathComponent:file];
                    if (![self.presetPaths containsObject:full]) {
                        [self.presetPaths addObject:full];
                    }
                }
            }
        }
    }
    NSLog(@"[VKProjectMGLView] Loaded %lu milkdrop presets", (unsigned long)self.presetPaths.count);
    if (self.presetPaths.count > 0) {
        self.currentPresetIndex = 0;
        [self loadPresetFromFile:self.presetPaths.firstObject];
    } else if (_pm) {
        projectm_load_preset_data(_pm, kDefaultMilkdropPreset, true);
        [self showPresetBadge];
    }
}

- (void)loadPresetFromFile:(NSString *)filePath {
    if (!_pm || !filePath) return;
    NSLog(@"[VKProjectMGLView] Loading preset: %@", filePath.lastPathComponent);
    projectm_load_preset_file(_pm, [filePath UTF8String], true);
    [self showPresetBadge];
}

- (void)nextPreset {
    if (self.presetPaths.count == 0) return;
    self.currentPresetIndex = (self.currentPresetIndex + 1) % self.presetPaths.count;
    if (self.currentPresetIndex < self.presetPaths.count) {
        [self loadPresetFromFile:self.presetPaths[self.currentPresetIndex]];
    }
}

- (void)previousPreset {
    if (self.presetPaths.count == 0) return;
    self.currentPresetIndex = (self.currentPresetIndex - 1 + self.presetPaths.count) % self.presetPaths.count;
    if (self.currentPresetIndex < self.presetPaths.count) {
        [self loadPresetFromFile:self.presetPaths[self.currentPresetIndex]];
    }
}

- (NSString *)currentPresetName {
    if (self.presetPaths.count == 0 || self.currentPresetIndex >= self.presetPaths.count) {
        return @"MilkDrop 2 (projectM)";
    }
    NSString *path = self.presetPaths[self.currentPresetIndex];
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

- (void)showPresetBadge {
    self.presetBadgeLabel.text = [self currentPresetName];
    [self.presetBadgeLabel sizeToFit];
    CGRect f = self.presetBadgeLabel.frame;
    f.size.width += 18.0;
    f.size.height = 24.0;
    f.origin.x = 10.0;
    f.origin.y = 10.0;
    self.presetBadgeLabel.frame = f;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.presetBadgeLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.4 delay:1.8 options:0 animations:^{
            self.presetBadgeLabel.alpha = 0.0;
        } completion:nil];
    }];
}

- (void)startAnimation {
    if (self.displayLink) return;
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame)];
    if ([self.displayLink respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
        [self.displayLink setPreferredFramesPerSecond:60];
    }
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopAnimation {
    if (self.displayLink) {
        [self.displayLink invalidate];
        self.displayLink = nil;
    }
}

- (void)dealloc {
    [self stopAnimation];
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    if (_defaultFramebuffer) {
        glDeleteFramebuffers(1, &_defaultFramebuffer);
    }
    if (_colorRenderbuffer) {
        glDeleteRenderbuffers(1, &_colorRenderbuffer);
    }
    if (_pm) {
        projectm_destroy(_pm);
        _pm = NULL;
    }
}

- (void)renderFrame {
    static NSUInteger frameCounter = 0;
    static NSTimeInterval lastLogTime = 0;
    static NSUInteger fpsCounter = 0;
    static CGFloat currentFps = 0.0;
    
    @try {
        if (!_context) return;
        
        if ([EAGLContext currentContext] != _context) {
            [EAGLContext setCurrentContext:_context];
        }
        
        if (!_pm && _backingWidth > 0 && _backingHeight > 0) {
            [self initProjectM];
            [self loadPresetsList];
        }
        if (!_pm || _backingWidth <= 0 || _backingHeight <= 0) return;
        
        glBindFramebuffer(GL_FRAMEBUFFER, _defaultFramebuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
        glViewport(0, 0, _backingWidth, _backingHeight);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        // Передача аудиоданных (PCM сэмплинг с гармониками)
        float dummyPCM[512];
        static float phase = 0.0f;
        phase += 0.12f;
        float amp = self.isPlaying ? 0.85f : 0.35f;
        for (int i = 0; i < 512; i++) {
            float s1 = sinf(phase + i * 0.04f);
            float s2 = sinf(phase * 2.3f + i * 0.08f) * 0.5f;
            float s3 = sinf(phase * 0.7f + i * 0.02f) * 0.3f;
            dummyPCM[i] = (s1 + s2 + s3) * amp;
        }
        projectm_pcm_add_float(_pm, dummyPCM, 512, PROJECTM_STEREO);
        
        projectm_opengl_render_frame_fbo(_pm, _defaultFramebuffer);
        
        glBindFramebuffer(GL_FRAMEBUFFER, _defaultFramebuffer);
        
        // Probe center and corner pixels from the default framebuffer
        GLubyte centerPx[4] = {0, 0, 0, 0};
        glReadPixels(_backingWidth / 2, _backingHeight / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, centerPx);
        
        GLubyte cornerPx[4] = {0, 0, 0, 0};
        glReadPixels(20, 20, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, cornerPx);
        
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
        BOOL presented = [_context presentRenderbuffer:GL_RENDERBUFFER];
        
        frameCounter++;
        fpsCounter++;
        NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
        if (now - lastLogTime >= 1.0) {
            currentFps = (CGFloat)fpsCounter / (CGFloat)(now - lastLogTime);
            fpsCounter = 0;
            lastLogTime = now;
            
            GLenum fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
            GLenum glErr = glGetError();
            
            const char *glVer = (const char *)glGetString(GL_VERSION);
            const char *glRend = (const char *)glGetString(GL_RENDERER);
            
            NSString *presetName = (self.presetPaths.count > 0 && self.currentPresetIndex < self.presetPaths.count)
                ? [[self.presetPaths[self.currentPresetIndex] lastPathComponent] stringByDeletingPathExtension]
                : @"Default";
            
            NSString *diag = [NSString stringWithFormat:
                              @"FPS: %.1f | Frames: %lu | Size: %dx%d\n"
                              @"API: %s | GPU: %s\n"
                              @"FBO: 0x%x | Err: 0x%x | OK: %d\n"
                              @"Center Px (RGBA): %3d,%3d,%3d,%3d\n"
                              @"Corner Px (RGBA): %3d,%3d,%3d,%3d\n"
                              @"Preset [%ld/%lu]: %@",
                              currentFps, (unsigned long)frameCounter, _backingWidth, _backingHeight,
                              glVer ? glVer : "N/A", glRend ? glRend : "N/A",
                              fboStatus, glErr, presented,
                              centerPx[0], centerPx[1], centerPx[2], centerPx[3],
                              cornerPx[0], cornerPx[1], cornerPx[2], cornerPx[3],
                              (long)(self.currentPresetIndex + 1), (unsigned long)self.presetPaths.count, presetName];
            
            NSLog(@"[VKProjectMGLView] %@", diag);
            self.debugStatusLabel.text = diag;
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[VKProjectMGLView] Exception in renderFrame: %@", exception);
        self.debugStatusLabel.text = [NSString stringWithFormat:@"Exception: %@", exception.reason];
    }
}

@end
