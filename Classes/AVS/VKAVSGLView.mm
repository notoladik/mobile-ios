#import "VKAVSGLView.h"
#import "VKAudioPlayer.h"
#import "VKPresetManager.h"

#include "Vendor/avs/vis_avs/avs.h"

#include <vector>
#include <string>

static const char* kVertexShaderSource =
    "attribute vec4 a_position;\n"
    "attribute vec2 a_texCoord;\n"
    "varying vec2 v_texCoord;\n"
    "void main() {\n"
    "    gl_Position = a_position;\n"
    "    v_texCoord = a_texCoord;\n"
    "}\n";

static const char* kFragmentShaderSource =
    "precision mediump float;\n"
    "varying vec2 v_texCoord;\n"
    "uniform sampler2D u_texture;\n"
    "void main() {\n"
    "    vec4 c = texture2D(u_texture, v_texCoord);\n"
    "    // Swizzle BGR0 (Win32 RGB0_8) to RGB\n"
    "    gl_FragColor = vec4(c.b, c.g, c.r, 1.0);\n"
    "}\n";

@interface VKAVSGLView () {
    AVS_Handle _avs;
    EAGLContext *_context;
    
    GLuint _defaultFramebuffer;
    GLuint _colorRenderbuffer;
    GLint _backingWidth;
    GLint _backingHeight;
    
    GLuint _program;
    GLuint _texture;
    GLint _posAttrib;
    GLint _texAttrib;
    GLint _samplerUniform;
    
    uint32_t *_avsFramebuffer;
    size_t _fbWidth;
    size_t _fbHeight;
    
    CADisplayLink *_displayLink;
    NSTimer *_autoSwitchTimer;
}

@property (nonatomic, strong) NSMutableArray<NSString *> *presetPaths;
@property (nonatomic, assign) NSInteger currentPresetIndex;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, strong) NSTimer *badgeFadeTimer;

@end

@implementation VKAVSGLView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAnimation];
    [self teardownGL];
    if (_avsFramebuffer) {
        free(_avsFramebuffer);
        _avsFramebuffer = NULL;
    }
    if (_avs) {
        avs_free(_avs);
        _avs = 0;
    }
}

- (void)commonInit {
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = @{
        kEAGLDrawablePropertyRetainedBacking: @(NO),
        kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8
    };
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!_context) {
        NSLog(@"[VKAVSGLView] Failed to create OpenGLES 2.0 context");
        return;
    }
    [EAGLContext setCurrentContext:_context];
    
    _fbWidth = 512;
    _fbHeight = 512;
    _avsFramebuffer = (uint32_t *)calloc(_fbWidth * _fbHeight, sizeof(uint32_t));
    
    self.presetPaths = [NSMutableArray array];
    self.currentPresetIndex = 0;
    self.autoSwitchInterval = 25.0;
    self.shuffleMode = NO;
    self.isPlaying = YES;
    
    [self setupGL];
    [self initAVS];
    [self loadPresetsList];
    [self setupBadge];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loadPresetsList)
                                                 name:VKPresetsDidUpdateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)setupGL {
    if (!_context) return;
    [EAGLContext setCurrentContext:_context];
    
    // 1. Shaders
    GLuint vs = [self compileShader:kVertexShaderSource type:GL_VERTEX_SHADER];
    GLuint fs = [self compileShader:kFragmentShaderSource type:GL_FRAGMENT_SHADER];
    _program = glCreateProgram();
    glAttachShader(_program, vs);
    glAttachShader(_program, fs);
    glLinkProgram(_program);
    
    GLint linkStatus;
    glGetProgramiv(_program, GL_LINK_STATUS, &linkStatus);
    if (!linkStatus) {
        char buffer[512];
        glGetProgramInfoLog(_program, sizeof(buffer), NULL, buffer);
        NSLog(@"[VKAVSGLView] Shader link error: %s", buffer);
    }
    glDeleteShader(vs);
    glDeleteShader(fs);
    
    _posAttrib = glGetAttribLocation(_program, "a_position");
    _texAttrib = glGetAttribLocation(_program, "a_texCoord");
    _samplerUniform = glGetUniformLocation(_program, "u_texture");
    
    // 2. Texture
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)_fbWidth, (GLsizei)_fbHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glBindTexture(GL_TEXTURE_2D, 0);
}

- (GLuint)compileShader:(const char *)source type:(GLenum)type {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (!status) {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        NSLog(@"[VKAVSGLView] Shader compile error: %s", log);
    }
    return shader;
}

- (void)teardownGL {
    if (_context) {
        [EAGLContext setCurrentContext:_context];
        if (_defaultFramebuffer) {
            glDeleteFramebuffers(1, &_defaultFramebuffer);
            _defaultFramebuffer = 0;
        }
        if (_colorRenderbuffer) {
            glDeleteRenderbuffers(1, &_colorRenderbuffer);
            _colorRenderbuffer = 0;
        }
        if (_texture) {
            glDeleteTextures(1, &_texture);
            _texture = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self destroyBuffers];
    [self createBuffers];
    
    if (self.badgeLabel) {
        CGFloat bw = MIN(self.bounds.size.width - 24, 280);
        self.badgeLabel.frame = CGRectMake((self.bounds.size.width - bw)/2.0, 16, bw, 32);
    }
}

- (void)createBuffers {
    if (!_context) return;
    [EAGLContext setCurrentContext:_context];
    
    glGenRenderbuffers(1, &_colorRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
    
    glGenFramebuffers(1, &_defaultFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFramebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderbuffer);
    
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"[VKAVSGLView] Failed to make complete framebuffer object %x", status);
    }
}

- (void)destroyBuffers {
    if (!_context) return;
    [EAGLContext setCurrentContext:_context];
    if (_defaultFramebuffer) {
        glDeleteFramebuffers(1, &_defaultFramebuffer);
        _defaultFramebuffer = 0;
    }
    if (_colorRenderbuffer) {
        glDeleteRenderbuffers(1, &_colorRenderbuffer);
        _colorRenderbuffer = 0;
    }
}

- (void)initAVS {
    NSString *resPath = [[NSBundle mainBundle] resourcePath];
    _avs = avs_init([resPath UTF8String], AVS_AUDIO_EXTERNAL, AVS_BEAT_INTERNAL);
    if (!_avs) {
        NSLog(@"[VKAVSGLView] avs_init failed: %s", avs_error_str(_avs));
    } else {
        NSLog(@"[VKAVSGLView] AVS initialized successfully (handle=%u)", _avs);
    }
}

- (void)loadPresetsList {
    [self.presetPaths removeAllObjects];
    NSArray<NSString *> *all = [VKPresetManager allAVSPresetPaths];
    [self.presetPaths addObjectsFromArray:all];
    NSLog(@"[VKAVSGLView] Loaded %lu AVS presets", (unsigned long)self.presetPaths.count);
    if (self.presetPaths.count > 0) {
        if (self.currentPresetIndex >= (NSInteger)self.presetPaths.count) {
            self.currentPresetIndex = 0;
        }
        [self loadPresetAtIndex:self.currentPresetIndex];
    }
}

- (void)loadPresetAtIndex:(NSInteger)index {
    if (self.presetPaths.count == 0) return;
    if (index < 0) index = self.presetPaths.count - 1;
    if (index >= (NSInteger)self.presetPaths.count) index = 0;
    
    self.currentPresetIndex = index;
    NSString *path = self.presetPaths[index];
    [self loadPresetFromFile:path];
    [self showPresetBadge];
}

- (void)loadPresetFromFile:(NSString *)filePath {
    if (!_avs || !filePath) return;
    
    NSLog(@"[VKAVSGLView] Loading preset: %@", filePath.lastPathComponent);
    BOOL ok = avs_preset_load(_avs, [filePath UTF8String]);
    if (!ok) {
        NSLog(@"[VKAVSGLView] Error loading preset %@: %s", filePath.lastPathComponent, avs_error_str(_avs));
    }
}

- (NSString *)currentPresetName {
    if (self.presetPaths.count == 0) return @"Nullsoft AVS";
    NSString *path = self.presetPaths[self.currentPresetIndex];
    return [[path lastPathComponent] stringByDeletingPathExtension];
}

- (void)nextPreset {
    if (self.presetPaths.count == 0) return;
    if (self.shuffleMode && self.presetPaths.count > 1) {
        [self randomPreset];
    } else {
        [self loadPresetAtIndex:self.currentPresetIndex + 1];
    }
}

- (void)previousPreset {
    if (self.presetPaths.count == 0) return;
    [self loadPresetAtIndex:self.currentPresetIndex - 1];
}

- (void)randomPreset {
    if (self.presetPaths.count == 0) return;
    NSInteger nextIdx = arc4random_uniform((uint32_t)self.presetPaths.count);
    [self loadPresetAtIndex:nextIdx];
}

#pragma mark - Animation & Render Loop

- (void)startAnimation {
    if (_displayLink) return;
    
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderFrame)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    
    [self restartAutoSwitchTimer];
}

- (void)stopAnimation {
    if (_displayLink) {
        [_displayLink invalidate];
        _displayLink = nil;
    }
    if (_autoSwitchTimer) {
        [_autoSwitchTimer invalidate];
        _autoSwitchTimer = nil;
    }
}

- (void)restartAutoSwitchTimer {
    if (_autoSwitchTimer) {
        [_autoSwitchTimer invalidate];
        _autoSwitchTimer = nil;
    }
    if (self.autoSwitchInterval > 0) {
        _autoSwitchTimer = [NSTimer scheduledTimerWithTimeInterval:self.autoSwitchInterval
                                                            target:self
                                                          selector:@selector(autoSwitchTimerFired)
                                                          userInfo:nil
                                                           repeats:YES];
    }
}

- (void)autoSwitchTimerFired {
    if (self.isPlaying && self.window) {
        [self nextPreset];
    }
}

- (void)renderFrame {
    if (!_context || !_avs || !_avsFramebuffer || _backingWidth <= 0 || _backingHeight <= 0) return;
    
    @try {
        [EAGLContext setCurrentContext:_context];
        
        // 1. Подача живых PCM данных из VKAudioPlayer
        float livePCM[512];
        memset(livePCM, 0, sizeof(livePCM));
        [[VKAudioPlayer sharedPlayer] getLatestPCMData:livePCM count:512];
        
        if (self.isPlaying) {
            avs_audio_set(_avs, livePCM, livePCM, 512, 44100, -1);
        }
        
        // 2. Рендеринг кадра AVS в программный буфер 512x512
        bool ok = avs_render_frame(_avs, _avsFramebuffer, _fbWidth, _fbHeight, -1, false, AVS_PIXEL_RGB0_8);
        if (!ok) {
            // Silently continue or retry
        }
        
        // 3. Загрузка в GLES2 текстуру
        glBindTexture(GL_TEXTURE_2D, _texture);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, (GLsizei)_fbWidth, (GLsizei)_fbHeight, GL_RGBA, GL_UNSIGNED_BYTE, _avsFramebuffer);
        
        // 4. Отрисовка полноэкранного квада
        glBindFramebuffer(GL_FRAMEBUFFER, _defaultFramebuffer);
        glViewport(0, 0, _backingWidth, _backingHeight);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glUseProgram(_program);
        
        static const GLfloat quadVertices[] = {
            -1.0f, -1.0f, 0.0f, 1.0f,
             1.0f, -1.0f, 1.0f, 1.0f,
            -1.0f,  1.0f, 0.0f, 0.0f,
             1.0f,  1.0f, 1.0f, 0.0f,
        };
        
        glVertexAttribPointer(_posAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), &quadVertices[0]);
        glEnableVertexAttribArray(_posAttrib);
        
        glVertexAttribPointer(_texAttrib, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat), &quadVertices[2]);
        glEnableVertexAttribArray(_texAttrib);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _texture);
        glUniform1i(_samplerUniform, 0);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    @catch (NSException *ex) {
        NSLog(@"[VKAVSGLView] Exception in renderFrame: %@", ex);
    }
}

#pragma mark - Preset HUD Badge

- (void)setupBadge {
    self.badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.badgeLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.badgeLabel.textColor = [UIColor whiteColor];
    self.badgeLabel.font = [UIFont boldSystemFontOfSize:12];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.layer.cornerRadius = 14.0;
    self.badgeLabel.layer.masksToBounds = YES;
    self.badgeLabel.alpha = 0.0;
    [self addSubview:self.badgeLabel];
}

- (void)showPresetBadge {
    if (!self.badgeLabel) return;
    
    NSString *name = [self currentPresetName];
    self.badgeLabel.text = [NSString stringWithFormat:@"AVS: %@", name];
    
    [self.badgeFadeTimer invalidate];
    [UIView animateWithDuration:0.2 animations:^{
        self.badgeLabel.alpha = 1.0;
    }];
    
    self.badgeFadeTimer = [NSTimer scheduledTimerWithTimeInterval:2.5
                                                           target:self
                                                         selector:@selector(hidePresetBadge)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)hidePresetBadge {
    [UIView animateWithDuration:0.5 animations:^{
        self.badgeLabel.alpha = 0.0;
    }];
}

- (void)appDidEnterBackground {
    [self stopAnimation];
    if (_context && [EAGLContext currentContext] == _context) {
        glFinish();
    }
}

- (void)appWillEnterForeground {
    if (self.window && !self.hidden && self.isPlaying) {
        [self startAnimation];
    }
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!self.userInteractionEnabled) {
        return nil;
    }
    return [super hitTest:point withEvent:event];
}

@end