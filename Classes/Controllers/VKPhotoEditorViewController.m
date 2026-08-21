#import "VKPhotoEditorViewController.h"
#import "VKThemeManager.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>

// Модель одного штриха рисования (закрашка)
@interface VKDrawingStroke : NSObject
@property (nonatomic, strong) UIBezierPath *path;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CGFloat width;
@end

@implementation VKDrawingStroke
@end

// Холст для рисования кистью
@interface VKDrawingCanvasView : UIView
@property (nonatomic, strong) NSMutableArray<VKDrawingStroke *> *strokes;
@property (nonatomic, strong) UIColor *currentColor;
@property (nonatomic, assign) CGFloat currentWidth;
@property (nonatomic, strong) VKDrawingStroke *activeStroke;
@end

@implementation VKDrawingCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.strokes = [NSMutableArray array];
        self.currentColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.25 alpha:1.0];
        self.currentWidth = 6.0;
        self.userInteractionEnabled = YES;
        self.multipleTouchEnabled = NO;
    }
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self];
    
    self.activeStroke = [[VKDrawingStroke alloc] init];
    self.activeStroke.color = self.currentColor;
    self.activeStroke.width = self.currentWidth;
    self.activeStroke.path = [UIBezierPath bezierPath];
    self.activeStroke.path.lineWidth = self.currentWidth;
    self.activeStroke.path.lineCapStyle = kCGLineCapRound;
    self.activeStroke.path.lineJoinStyle = kCGLineJoinRound;
    [self.activeStroke.path moveToPoint:pt];
    
    [self.strokes addObject:self.activeStroke];
    [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.activeStroke) return;
    UITouch *touch = [touches anyObject];
    CGPoint pt = [touch locationInView:self];
    [self.activeStroke.path addLineToPoint:pt];
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.activeStroke = nil;
    [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.activeStroke = nil;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    for (VKDrawingStroke *stroke in self.strokes) {
        [stroke.color setStroke];
        [stroke.path stroke];
    }
}

- (void)undoLastStroke {
    if (self.strokes.count > 0) {
        [self.strokes removeLastObject];
        [self setNeedsDisplay];
    }
}

- (void)clearAllStrokes {
    [self.strokes removeAllObjects];
    [self setNeedsDisplay];
}

@end

// Режимы оригинальной панели VKPhotoEdit
typedef NS_ENUM(NSInteger, VKPhotoEditorMode) {
    VKPhotoEditorModeFilter,   // 🔲 Фильтры (photo_panel_mosaic)
    VKPhotoEditorModeDraw,     // 🖌 Кисть / Закрашка
    VKPhotoEditorModeCrop,     // ✂️ Кадрирование / Поворот (photo_panel_crop)
    VKPhotoEditorModeText,     // ✍️ Текст (photo_panel_text)
    VKPhotoEditorModeMagic     // ✨ Автоулучшение (photo_panel_magic)
};

@interface VKPhotoEditorViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIImage *originalImage;
@property (nonatomic, strong) UIImage *baseOrientedImage;
@property (nonatomic, strong) UIImage *filteredImage;
@property (nonatomic, assign) NSInteger currentFilterIndex;
@property (nonatomic, assign) BOOL isMagicEnhanced;

@property (nonatomic, strong) UIImageView *mainImageView;
@property (nonatomic, strong) VKDrawingCanvasView *drawingCanvas;
@property (nonatomic, strong) NSMutableArray<UILabel *> *textLabels;

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIView *filtersContainerView;
@property (nonatomic, strong) UIView *brushContainerView;
@property (nonatomic, strong) UIScrollView *filtersScrollView;
@property (nonatomic, strong) UIScrollView *brushColorsScrollView;

@property (nonatomic, assign) VKPhotoEditorMode currentMode;
@property (nonatomic, strong) NSArray *filterNames;
@property (nonatomic, strong) NSArray *brushColors;
@property (nonatomic, strong) NSMutableArray<UIButton *> *colorButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *brushSizeButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *modeButtons;

@end

@implementation VKPhotoEditorViewController

- (instancetype)initWithImage:(UIImage *)image {
    self = [super init];
    if (self) {
        _originalImage = image;
        _baseOrientedImage = [self fixOrientationOfImage:image];
        _filteredImage = _baseOrientedImage;
        _currentFilterIndex = 0;
        _isMagicEnhanced = NO;
        _textLabels = [NSMutableArray array];
        _currentMode = VKPhotoEditorModeFilter;
        _colorButtons = [NSMutableArray array];
        _brushSizeButtons = [NSMutableArray array];
        _modeButtons = [NSMutableArray array];
        
        _filterNames = @[
            @"Оригинал",
            @"Аврора",
            @"Латона",
            @"Веста",
            @"Нокс",
            @"Велес",
            @"Минерва",
            @"Луна",
            @"Терра",
            @"Гений"
        ];
        
        _brushColors = @[
            [UIColor colorWithRed:235.0/255.0 green:50.0/255.0 blue:50.0/255.0 alpha:1.0],   // Красный
            [UIColor colorWithRed:255.0/255.0 green:140.0/255.0 blue:0.0 alpha:1.0],        // Оранжевый
            [UIColor colorWithRed:255.0/255.0 green:215.0/255.0 blue:0.0 alpha:1.0],        // Жёлтый
            [UIColor colorWithRed:50.0/255.0 green:205.0/255.0 blue:50.0/255.0 alpha:1.0],  // Зелёный
            [UIColor colorWithRed:30.0/255.0 green:144.0/255.0 blue:255.0/255.0 alpha:1.0], // Голубой
            [UIColor colorWithRed:147.0/255.0 green:112.0/255.0 blue:219.0/255.0 alpha:1.0],// Фиолетовый
            [UIColor colorWithRed:255.0/255.0 green:105.0/255.0 blue:180.0/255.0 alpha:1.0],// Розовый
            [UIColor whiteColor],                                                           // Белый
            [UIColor blackColor]                                                            // Чёрный
        ];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    self.view.backgroundColor = [UIColor blackColor];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    // Верхняя панель (с аутентичными кнопками фото_панели ВК)
    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 54)];
    self.topBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.topBar];
    
    // Кнопка закрытия
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.frame = CGRectMake(10, 10, 44, 34);
    UIImage *closeImg = [UIImage imageNamed:@"photo_panel_close"];
    if (closeImg) {
        [cancelBtn setImage:closeImg forState:UIControlStateNormal];
    } else {
        [cancelBtn setTitle:@"✕" forState:UIControlStateNormal];
        [cancelBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        cancelBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    }
    [cancelBtn addTarget:self action:@selector(cancelAction) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:cancelBtn];
    
    UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(60, 10, width - 120, 34)];
    titleLbl.text = @"Редактор";
    titleLbl.textColor = [UIColor whiteColor];
    titleLbl.font = [UIFont boldSystemFontOfSize:16];
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:titleLbl];
    
    // Кнопка «Готово»
    UIButton *doneBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    doneBtn.frame = CGRectMake(width - 70, 10, 60, 34);
    doneBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    UIImage *okImg = [UIImage imageNamed:@"photo_panel_ok"];
    if (okImg) {
        [doneBtn setImage:okImg forState:UIControlStateNormal];
    } else {
        [doneBtn setTitle:@"Готово" forState:UIControlStateNormal];
        [doneBtn setTitleColor:[UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        doneBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    }
    [doneBtn addTarget:self action:@selector(doneAction) forControlEvents:UIControlEventTouchUpInside];
    [self.topBar addSubview:doneBtn];
    
    // Область просмотра и холст рисования
    CGFloat mainH = height - 54.0 - 134.0;
    UIView *imageContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 54, width, mainH)];
    imageContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageContainer.clipsToBounds = YES;
    [self.view addSubview:imageContainer];
    
    self.mainImageView = [[UIImageView alloc] initWithFrame:imageContainer.bounds];
    self.mainImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.mainImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mainImageView.image = self.filteredImage;
    [imageContainer addSubview:self.mainImageView];
    
    self.drawingCanvas = [[VKDrawingCanvasView alloc] initWithFrame:imageContainer.bounds];
    self.drawingCanvas.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.drawingCanvas.userInteractionEnabled = NO;
    [imageContainer addSubview:self.drawingCanvas];
    
    // Нижняя панель переключения режимов (оригинальный photo_panel)
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, height - 50, width, 50)];
    if (isSkeuomorph) {
        UIImage *panelBg = [UIImage imageNamed:@"photo_panel"];
        if (panelBg) {
            self.bottomBar.backgroundColor = [UIColor colorWithPatternImage:panelBg];
        } else {
            self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
        }
    } else {
        self.bottomBar.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    }
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBar];
    
    // 5 аутентичных режимов ВК
    NSArray *modes = @[
        @{@"tag": @(VKPhotoEditorModeFilter), @"skeuo": @"photo_panel_mosaic", @"flat": @"7_photo_panel_mosaic", @"title": @"Фильтры"},
        @{@"tag": @(VKPhotoEditorModeDraw),   @"skeuo": @"photo_panel_enhance", @"flat": @"7_photo_panel_enhance", @"title": @"Кисть"},
        @{@"tag": @(VKPhotoEditorModeCrop),   @"skeuo": @"photo_panel_crop",   @"flat": @"7_photo_panel_crop",   @"title": @"Поворот"},
        @{@"tag": @(VKPhotoEditorModeText),   @"skeuo": @"photo_panel_text",   @"flat": @"7_photo_panel_text",   @"title": @"Текст"},
        @{@"tag": @(VKPhotoEditorModeMagic),  @"skeuo": @"photo_panel_magic",  @"flat": @"7_photo_panel_magic",  @"title": @"Авто"}
    ];
    
    CGFloat itemW = width / modes.count;
    for (NSInteger i = 0; i < (NSInteger)modes.count; i++) {
        NSDictionary *m = modes[i];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(i * itemW, 0, itemW, 50);
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        btn.tag = [m[@"tag"] integerValue];
        
        NSString *imgName = isSkeuomorph ? m[@"skeuo"] : m[@"flat"];
        UIImage *icon = [UIImage imageNamed:imgName];
        if (icon) {
            [btn setImage:icon forState:UIControlStateNormal];
        } else {
            [btn setTitle:m[@"title"] forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        }
        
        if (i == 0) {
            btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        }
        
        [btn addTarget:self action:@selector(modeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomBar addSubview:btn];
        [self.modeButtons addObject:btn];
    }
    
    // Панель карусели фильтров (высота 84pt над нижней панелью)
    self.filtersContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 50 - 84, width, 84)];
    self.filtersContainerView.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.95];
    self.filtersContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.filtersContainerView];
    
    self.filtersScrollView = [[UIScrollView alloc] initWithFrame:self.filtersContainerView.bounds];
    self.filtersScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.filtersScrollView.showsHorizontalScrollIndicator = NO;
    [self.filtersContainerView addSubview:self.filtersScrollView];
    
    [self setupFiltersCarousel];
    
    // Панель кисти / закрашки (высота 84pt)
    self.brushContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 50 - 84, width, 84)];
    self.brushContainerView.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.95];
    self.brushContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.brushContainerView.hidden = YES;
    [self.view addSubview:self.brushContainerView];
    
    [self setupBrushToolbar];
}

#pragma mark - Filter Carousel with Authentic VK Borders

- (void)setupFiltersCarousel {
    for (UIView *v in self.filtersScrollView.subviews) [v removeFromSuperview];
    
    CGFloat thumbW = 56.0;
    CGFloat pad = 10.0;
    
    UIImage *thumbSrc = [self resizeImage:self.baseOrientedImage targetSize:CGSizeMake(80, 80)];
    
    for (NSInteger i = 0; i < (NSInteger)self.filterNames.count; i++) {
        CGFloat x = pad + i * (thumbW + pad);
        
        UIView *item = [[UIView alloc] initWithFrame:CGRectMake(x, 6, thumbW, 72)];
        
        UIImageView *thumbIV = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, thumbW, 48)];
        thumbIV.contentMode = UIViewContentModeScaleAspectFill;
        thumbIV.clipsToBounds = YES;
        thumbIV.layer.cornerRadius = 4.0;
        thumbIV.tag = 5000 + i;
        
        // Превью фильтра
        UIImage *thumbFiltered = [self applyFilterAtIndex:i toImage:thumbSrc];
        thumbIV.image = thumbFiltered ?: thumbSrc;
        [item addSubview:thumbIV];
        
        // Рамка активного фильтра из оригинального клиента VK
        UIImageView *borderIV = [[UIImageView alloc] initWithFrame:thumbIV.bounds];
        borderIV.contentMode = UIViewContentModeScaleToFill;
        borderIV.tag = 7000 + i;
        UIImage *borderImg = [UIImage imageNamed:@"filter_photo_active_border"] ?: [UIImage imageNamed:@"7_filter_photo_active_border"];
        if (borderImg) {
            borderIV.image = borderImg;
        } else {
            borderIV.layer.borderWidth = 2.5;
            borderIV.layer.borderColor = [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0].CGColor;
            borderIV.layer.cornerRadius = 4.0;
        }
        borderIV.hidden = (i != self.currentFilterIndex);
        [item addSubview:borderIV];
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, thumbW, 18)];
        lbl.text = self.filterNames[i];
        lbl.font = [UIFont systemFontOfSize:10.5];
        lbl.textColor = (i == self.currentFilterIndex) ? [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.75 alpha:1.0];
        lbl.textAlignment = NSTextAlignmentCenter;
        lbl.tag = 6000 + i;
        [item addSubview:lbl];
        
        UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        tapBtn.frame = item.bounds;
        tapBtn.tag = i;
        [tapBtn addTarget:self action:@selector(filterSelected:) forControlEvents:UIControlEventTouchUpInside];
        [item addSubview:tapBtn];
        
        [self.filtersScrollView addSubview:item];
    }
    
    self.filtersScrollView.contentSize = CGSizeMake(pad + self.filterNames.count * (thumbW + pad), 84);
}

- (void)filterSelected:(UIButton *)btn {
    self.currentFilterIndex = btn.tag;
    
    for (NSInteger i = 0; i < (NSInteger)self.filterNames.count; i++) {
        UIView *borderIV = [self.filtersScrollView viewWithTag:7000 + i];
        UILabel *lbl = (UILabel *)[self.filtersScrollView viewWithTag:6000 + i];
        if (borderIV) borderIV.hidden = (i != self.currentFilterIndex);
        if (lbl) {
            lbl.textColor = (i == self.currentFilterIndex) ? [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.75 alpha:1.0];
        }
    }
    
    self.filteredImage = [self applyFilterAtIndex:self.currentFilterIndex toImage:self.baseOrientedImage];
    if (self.isMagicEnhanced) {
        self.filteredImage = [self applyMagicEnhanceToImage:self.filteredImage];
    }
    self.mainImageView.image = self.filteredImage;
}

#pragma mark - Brush Toolbar (Закрашка / Кисть)

- (void)setupBrushToolbar {
    CGFloat width = self.view.bounds.size.width;
    
    // Верхний ряд: палитра цветов
    self.brushColorsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(10, 6, width - 110, 36)];
    self.brushColorsScrollView.showsHorizontalScrollIndicator = NO;
    [self.brushContainerView addSubview:self.brushColorsScrollView];
    
    CGFloat colorSize = 28.0;
    CGFloat pad = 8.0;
    for (NSInteger i = 0; i < (NSInteger)self.brushColors.count; i++) {
        UIColor *col = self.brushColors[i];
        UIButton *cBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        cBtn.frame = CGRectMake(i * (colorSize + pad), 4, colorSize, colorSize);
        cBtn.backgroundColor = col;
        cBtn.layer.cornerRadius = colorSize / 2.0;
        cBtn.layer.borderWidth = (i == 0) ? 2.5 : 1.0;
        cBtn.layer.borderColor = (i == 0) ? [UIColor whiteColor].CGColor : [UIColor colorWithWhite:0.4 alpha:0.8].CGColor;
        cBtn.tag = i;
        [cBtn addTarget:self action:@selector(brushColorSelected:) forControlEvents:UIControlEventTouchUpInside];
        [self.brushColorsScrollView addSubview:cBtn];
        [self.colorButtons addObject:cBtn];
    }
    self.brushColorsScrollView.contentSize = CGSizeMake(self.brushColors.count * (colorSize + pad), 36);
    
    // Кнопка отмены последнего штриха (Undo ↶)
    UIButton *undoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    undoBtn.frame = CGRectMake(width - 92, 4, 38, 36);
    [undoBtn setTitle:@"↶" forState:UIControlStateNormal];
    [undoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    undoBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [undoBtn addTarget:self action:@selector(undoBrushAction) forControlEvents:UIControlEventTouchUpInside];
    [self.brushContainerView addSubview:undoBtn];
    
    // Кнопка очистки (🗑)
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    clearBtn.frame = CGRectMake(width - 48, 4, 38, 36);
    [clearBtn setTitle:@"🗑" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:18];
    [clearBtn addTarget:self action:@selector(clearBrushAction) forControlEvents:UIControlEventTouchUpInside];
    [self.brushContainerView addSubview:clearBtn];
    
    // Нижний ряд: выбор толщины кисти (3pt, 8pt, 16pt, 28pt)
    NSArray *sizes = @[@"Тонкая", @"Средняя", @"Толстая", @"Маркер"];
    NSArray *widths = @[@(3.0), @(8.0), @(16.0), @(28.0)];
    CGFloat sizeBtnW = (width - 20) / sizes.count;
    
    for (NSInteger i = 0; i < (NSInteger)sizes.count; i++) {
        UIButton *sBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        sBtn.frame = CGRectMake(10 + i * sizeBtnW, 46, sizeBtnW, 30);
        [sBtn setTitle:sizes[i] forState:UIControlStateNormal];
        [sBtn setTitleColor:(i == 1 ? [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.6 alpha:1.0]) forState:UIControlStateNormal];
        sBtn.titleLabel.font = [UIFont systemFontOfSize:12];
        sBtn.tag = [widths[i] integerValue];
        [sBtn addTarget:self action:@selector(brushSizeSelected:) forControlEvents:UIControlEventTouchUpInside];
        [self.brushContainerView addSubview:sBtn];
        [self.brushSizeButtons addObject:sBtn];
    }
}

- (void)brushColorSelected:(UIButton *)btn {
    UIColor *col = self.brushColors[btn.tag];
    self.drawingCanvas.currentColor = col;
    
    for (NSInteger i = 0; i < (NSInteger)self.colorButtons.count; i++) {
        UIButton *b = self.colorButtons[i];
        b.layer.borderWidth = (i == btn.tag) ? 2.5 : 1.0;
        b.layer.borderColor = (i == btn.tag) ? [UIColor whiteColor].CGColor : [UIColor colorWithWhite:0.4 alpha:0.8].CGColor;
    }
}

- (void)brushSizeSelected:(UIButton *)btn {
    self.drawingCanvas.currentWidth = (CGFloat)btn.tag;
    for (UIButton *b in self.brushSizeButtons) {
        BOOL isSel = (b == btn);
        [b setTitleColor:(isSel ? [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.6 alpha:1.0]) forState:UIControlStateNormal];
    }
}

- (void)undoBrushAction {
    [self.drawingCanvas undoLastStroke];
}

- (void)clearBrushAction {
    [self.drawingCanvas clearAllStrokes];
}

#pragma mark - Modes Switching

- (void)modeButtonTapped:(UIButton *)btn {
    VKPhotoEditorMode mode = (VKPhotoEditorMode)btn.tag;
    
    if (mode == VKPhotoEditorModeCrop) {
        [self rotateImage90Degrees];
        return;
    }
    
    if (mode == VKPhotoEditorModeText) {
        [self showAddTextDialog];
        return;
    }
    
    if (mode == VKPhotoEditorModeMagic) {
        self.isMagicEnhanced = !self.isMagicEnhanced;
        btn.backgroundColor = self.isMagicEnhanced ? [UIColor colorWithRed:74.0/255.0 green:160.0/255.0 blue:245.0/255.0 alpha:0.35] : [UIColor clearColor];
        
        self.filteredImage = [self applyFilterAtIndex:self.currentFilterIndex toImage:self.baseOrientedImage];
        if (self.isMagicEnhanced) {
            self.filteredImage = [self applyMagicEnhanceToImage:self.filteredImage];
        }
        self.mainImageView.image = self.filteredImage;
        return;
    }
    
    self.currentMode = mode;
    
    for (UIButton *b in self.modeButtons) {
        BOOL isSel = (b.tag == (NSInteger)mode);
        b.backgroundColor = isSel ? [UIColor colorWithWhite:1.0 alpha:0.15] : [UIColor clearColor];
    }
    
    if (mode == VKPhotoEditorModeFilter) {
        self.filtersContainerView.hidden = NO;
        self.brushContainerView.hidden = YES;
        self.drawingCanvas.userInteractionEnabled = NO;
    } else if (mode == VKPhotoEditorModeDraw) {
        self.filtersContainerView.hidden = YES;
        self.brushContainerView.hidden = NO;
        self.drawingCanvas.userInteractionEnabled = YES;
    }
}

- (void)rotateImage90Degrees {
    self.baseOrientedImage = [self rotateImage:self.baseOrientedImage byDegrees:90.0];
    self.filteredImage = [self applyFilterAtIndex:self.currentFilterIndex toImage:self.baseOrientedImage];
    if (self.isMagicEnhanced) {
        self.filteredImage = [self applyMagicEnhanceToImage:self.filteredImage];
    }
    self.mainImageView.image = self.filteredImage;
    [self setupFiltersCarousel];
}

#pragma mark - Fonts & Text Overlay

- (UIFont *)fontForIndex:(NSInteger)idx size:(CGFloat)size {
    switch (idx % 8) {
        case 0: return [UIFont fontWithName:@"Impact" size:size] ?: [UIFont boldSystemFontOfSize:size];
        case 1: return [UIFont fontWithName:@"Lobster" size:size] ?: [UIFont italicSystemFontOfSize:size];
        case 2: return [UIFont fontWithName:@"Pacifico-Regular" size:size] ?: [UIFont fontWithName:@"Pacifico" size:size] ?: [UIFont italicSystemFontOfSize:size];
        case 3: return [UIFont fontWithName:@"AmaticSC-Bold" size:size] ?: [UIFont fontWithName:@"Amatic SC" size:size] ?: [UIFont boldSystemFontOfSize:size];
        case 4: return [UIFont fontWithName:@"RodchenkoCondensedBold" size:size] ?: [UIFont fontWithName:@"Rodchenko_Condensed_Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
        case 5: return [UIFont fontWithName:@"MarkerFelt-Wide" size:size] ?: [UIFont fontWithName:@"Marker Felt" size:size] ?: [UIFont boldSystemFontOfSize:size];
        case 6: return [UIFont fontWithName:@"Courier-Bold" size:size] ?: [UIFont boldSystemFontOfSize:size];
        default: return [UIFont boldSystemFontOfSize:size];
    }
}

- (void)showAddTextDialog {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Текст на фото" message:@"Введите текст надписи:" delegate:self cancelButtonTitle:@"Отмена" otherButtonTitles:@"Добавить", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 3001;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 3001 && buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *text = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (text.length > 0) {
            [self addTextLabelWithText:text];
        }
    }
}

- (void)addTextLabelWithText:(NSString *)text {
    UIFont *font = [self fontForIndex:0 size:22.0];
    CGSize size = [text sizeWithFont:font];
    CGFloat w = MAX(60.0, ceilf(size.width) + 20.0);
    CGFloat h = ceilf(size.height) + 12.0;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - w) / 2.0, 100, w, h)];
    lbl.text = text;
    lbl.font = font;
    lbl.textColor = [UIColor whiteColor];
    lbl.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    lbl.textAlignment = NSTextAlignmentCenter;
    lbl.layer.cornerRadius = 6.0;
    lbl.clipsToBounds = YES;
    lbl.userInteractionEnabled = YES;
    lbl.tag = 0;
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTextPan:)];
    [lbl addGestureRecognizer:pan];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTextTap:)];
    [lbl addGestureRecognizer:tap];
    
    [self.mainImageView.superview addSubview:lbl];
    [self.textLabels addObject:lbl];
}

- (void)handleTextTap:(UITapGestureRecognizer *)gesture {
    UILabel *lbl = (UILabel *)gesture.view;
    lbl.tag = (lbl.tag + 1) % 8;
    lbl.font = [self fontForIndex:lbl.tag size:22.0];
    CGSize size = [lbl.text sizeWithFont:lbl.font];
    CGFloat w = MAX(60.0, ceilf(size.width) + 20.0);
    CGFloat h = ceilf(size.height) + 12.0;
    lbl.bounds = CGRectMake(0, 0, w, h);
}

- (void)handleTextPan:(UIPanGestureRecognizer *)gesture {
    UIView *v = gesture.view;
    CGPoint translation = [gesture translationInView:v.superview];
    v.center = CGPointMake(v.center.x + translation.x, v.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:v.superview];
}

#pragma mark - Filter & Magic Processing

- (UIImage *)applyFilterAtIndex:(NSInteger)index toImage:(UIImage *)image {
    if (!image) return nil;
    if (index == 0) return image;
    
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) return image;
    
    CIFilter *filter = nil;
    
    switch (index) {
        case 1: filter = [CIFilter filterWithName:@"CIPhotoEffectInstant"]; break;
        case 2: filter = [CIFilter filterWithName:@"CIPhotoEffectProcess"]; break;
        case 3: filter = [CIFilter filterWithName:@"CIPhotoEffectChrome"]; break;
        case 4: filter = [CIFilter filterWithName:@"CIPhotoEffectNoir"]; break;
        case 5:
            filter = [CIFilter filterWithName:@"CISepiaTone"];
            [filter setValue:@(0.85) forKey:kCIInputIntensityKey];
            break;
        case 6: filter = [CIFilter filterWithName:@"CIPhotoEffectFade"]; break;
        case 7: filter = [CIFilter filterWithName:@"CIPhotoEffectMono"]; break;
        case 8: filter = [CIFilter filterWithName:@"CIPhotoEffectTonal"]; break;
        case 9:
            filter = [CIFilter filterWithName:@"CIColorControls"];
            [filter setValue:@(1.3) forKey:kCIInputSaturationKey];
            [filter setValue:@(1.2) forKey:kCIInputContrastKey];
            break;
        default: return image;
    }
    
    if (!filter) return image;
    [filter setValue:ciImage forKey:kCIInputImageKey];
    CIImage *output = [filter outputImage];
    if (!output) return image;
    
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cgImg = [ctx createCGImage:output fromRect:[output extent]];
    if (!cgImg) return image;
    
    UIImage *res = [UIImage imageWithCGImage:cgImg scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImg);
    return res ?: image;
}

- (UIImage *)applyMagicEnhanceToImage:(UIImage *)image {
    if (!image) return nil;
    CIImage *ciImage = [[CIImage alloc] initWithImage:image];
    if (!ciImage) return image;
    
    CIFilter *filter = [CIFilter filterWithName:@"CIColorControls"];
    [filter setValue:ciImage forKey:kCIInputImageKey];
    [filter setValue:@(1.15) forKey:kCIInputBrightnessKey];
    [filter setValue:@(1.2) forKey:kCIInputContrastKey];
    [filter setValue:@(1.25) forKey:kCIInputSaturationKey];
    
    CIImage *output = [filter outputImage];
    if (!output) return image;
    
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cgImg = [ctx createCGImage:output fromRect:[output extent]];
    if (!cgImg) return image;
    
    UIImage *res = [UIImage imageWithCGImage:cgImg scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImg);
    return res ?: image;
}

#pragma mark - Image Helpers & Export

- (UIImage *)fixOrientationOfImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) return image;
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage ?: image;
}

- (UIImage *)rotateImage:(UIImage *)image byDegrees:(CGFloat)degrees {
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180.0);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, image.scale);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(bitmap, rotatedSize.width / 2.0, rotatedSize.height / 2.0);
    CGContextRotateCTM(bitmap, degrees * M_PI / 180.0);
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-image.size.width / 2.0, -image.size.height / 2.0, image.size.width, image.size.height), [image CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage ?: image;
}

- (UIImage *)resizeImage:(UIImage *)image targetSize:(CGSize)targetSize {
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *res = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return res;
}

#pragma mark - Export Flattened Final Image

- (UIImage *)generateFinalImage {
    UIImage *base = self.filteredImage ?: self.baseOrientedImage;
    if (!base) return nil;
    
    CGSize baseSize = base.size;
    UIGraphicsBeginImageContextWithOptions(baseSize, YES, 1.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // 1. Отрисовка базового изображения
    [base drawInRect:CGRectMake(0, 0, baseSize.width, baseSize.height)];
    
    CGRect ivBounds = self.mainImageView.bounds;
    if (ivBounds.size.width > 0 && ivBounds.size.height > 0) {
        CGFloat scaleW = ivBounds.size.width / baseSize.width;
        CGFloat scaleH = ivBounds.size.height / baseSize.height;
        CGFloat fitScale = MIN(scaleW, scaleH);
        
        CGFloat displayedW = baseSize.width * fitScale;
        CGFloat displayedH = baseSize.height * fitScale;
        CGFloat originX = (ivBounds.size.width - displayedW) / 2.0;
        CGFloat originY = (ivBounds.size.height - displayedH) / 2.0;
        
        // 2. Отрисовка кисти / закрашки
        if (self.drawingCanvas.strokes.count > 0) {
            CGContextSaveGState(ctx);
            CGContextScaleCTM(ctx, baseSize.width / displayedW, baseSize.height / displayedH);
            CGContextTranslateCTM(ctx, -originX, -originY);
            
            for (VKDrawingStroke *stroke in self.drawingCanvas.strokes) {
                [stroke.color setStroke];
                stroke.path.lineWidth = stroke.width * (displayedW / baseSize.width);
                [stroke.path stroke];
            }
            CGContextRestoreGState(ctx);
        }
        
        // 3. Отрисовка текстовых подписей
        for (UILabel *lbl in self.textLabels) {
            CGPoint labelPos = [lbl convertPoint:CGPointZero toView:self.mainImageView];
            CGFloat targetX = (labelPos.x - originX) * (baseSize.width / displayedW);
            CGFloat targetY = (labelPos.y - originY) * (baseSize.height / displayedH);
            CGFloat targetW = lbl.bounds.size.width * (baseSize.width / displayedW);
            CGFloat targetH = lbl.bounds.size.height * (baseSize.height / displayedH);
            
            CGRect drawRect = CGRectMake(targetX, targetY, targetW, targetH);
            
            [[UIColor colorWithWhite:0.0 alpha:0.55] setFill];
            UIBezierPath *bgPath = [UIBezierPath bezierPathWithRoundedRect:drawRect cornerRadius:6.0 * (baseSize.width / displayedW)];
            [bgPath fill];
            
            UIFont *font = [self fontForIndex:lbl.tag size:22.0 * (baseSize.width / displayedW)];
            CGSize tSize = [lbl.text sizeWithFont:font];
            CGRect textDrawRect = CGRectMake(drawRect.origin.x + (drawRect.size.width - tSize.width) / 2.0,
                                             drawRect.origin.y + (drawRect.size.height - tSize.height) / 2.0,
                                             tSize.width, tSize.height);
            [[UIColor whiteColor] setFill];
            [lbl.text drawInRect:textDrawRect withFont:font lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
        }
    }
    
    UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return finalImage ?: base;
}

- (void)cancelAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)doneAction {
    UIImage *result = [self generateFinalImage];
    if (self.onImageEdited) {
        self.onImageEdited(result);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
