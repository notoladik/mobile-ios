#import "VKStickersPickerView.h"
#import "VKStickersService.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"

@interface VKStickersPickerView ()

@property (nonatomic, strong) NSArray<VKStickerPack *> *packs;
@property (nonatomic, assign) NSInteger selectedPackIndex;

@property (nonatomic, strong) UIScrollView *stickersScrollView;
@property (nonatomic, strong) UIScrollView *packsScrollView;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UIButton *storeButton;

@end

@implementation VKStickersPickerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (frame.size.height < 216.0) {
        frame.size.height = 216.0;
    }
    self = [super initWithFrame:frame];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self setupUI];
        [self reloadPacks];
    }
    return self;
}

- (void)setupUI {
    CGFloat width = self.bounds.size.width;
    CGFloat height = self.bounds.size.height;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    if (isSkeuomorph) {
        self.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
    } else {
        self.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
    }
    
    // 1. Верхний разделитель
    UIView *topSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    topSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topSep.backgroundColor = [UIColor colorWithRed:185.0/255.0 green:190.0/255.0 blue:198.0/255.0 alpha:1.0];
    [self addSubview:topSep];
    
    // 2. Скролл со стикерами
    self.stickersScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0.5, width, height - 42.5)];
    self.stickersScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.stickersScrollView.showsVerticalScrollIndicator = YES;
    self.stickersScrollView.alwaysBounceVertical = YES;
    [self addSubview:self.stickersScrollView];
    
    // 3. Нижняя панель вкладок с паками
    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, height - 42.0, width, 42.0)];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    if (isSkeuomorph) {
        self.bottomBar.backgroundColor = [UIColor colorWithRed:195.0/255.0 green:200.0/255.0 blue:208.0/255.0 alpha:1.0];
    } else {
        self.bottomBar.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:248.0/255.0 blue:250.0/255.0 alpha:1.0];
    }
    
    UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 0.5)];
    bottomSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    bottomSep.backgroundColor = [UIColor colorWithRed:185.0/255.0 green:190.0/255.0 blue:198.0/255.0 alpha:1.0];
    [self.bottomBar addSubview:bottomSep];
    
    // Скролл для иконок паков
    self.packsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0.5, width - 44.0, 41.5)];
    self.packsScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.packsScrollView.showsHorizontalScrollIndicator = NO;
    [self.bottomBar addSubview:self.packsScrollView];
    
    // Кнопка магазина «+»
    self.storeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.storeButton.frame = CGRectMake(width - 44.0, 0.5, 44.0, 41.5);
    self.storeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
    [self.storeButton setTitle:@"+" forState:UIControlStateNormal];
    [self.storeButton setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
    self.storeButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [self.storeButton addTarget:self action:@selector(storeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBar addSubview:self.storeButton];
    
    UIView *storeSep = [[UIView alloc] initWithFrame:CGRectMake(width - 44.5, 0, 0.5, 42.0)];
    storeSep.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
    storeSep.backgroundColor = [UIColor colorWithRed:200.0/255.0 green:204.0/255.0 blue:210.0/255.0 alpha:1.0];
    [self.bottomBar addSubview:storeSep];
    
    [self addSubview:self.bottomBar];
}

- (void)reloadPacks {
    self.packs = [[VKStickersService sharedService] activeStickerPacks];
    if (self.selectedPackIndex >= (NSInteger)self.packs.count) {
        self.selectedPackIndex = 0;
    }
    [self renderPacksBar];
    [self renderStickersGrid];
}

- (void)renderPacksBar {
    for (UIView *v in self.packsScrollView.subviews) {
        [v removeFromSuperview];
    }
    
    CGFloat x = 6.0;
    for (NSInteger i = 0; i < (NSInteger)self.packs.count; i++) {
        VKStickerPack *pack = self.packs[i];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(x, 4.0, 34.0, 34.0);
        btn.layer.cornerRadius = 6.0;
        btn.clipsToBounds = YES;
        btn.tag = 2000 + i;
        
        if (i == self.selectedPackIndex) {
            btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
            btn.layer.borderWidth = 1.5;
            btn.layer.borderColor = [[VKThemeManager sharedManager] accentColor].CGColor;
        } else {
            btn.backgroundColor = [UIColor clearColor];
            btn.layer.borderWidth = 0.0;
        }
        
        [btn addTarget:self action:@selector(packButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(2, 2, 30, 30)];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.clipsToBounds = YES;
        iv.userInteractionEnabled = NO;
        if (pack.previewURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:pack.previewURL completion:^(UIImage *img) {
                if (img) iv.image = img;
            }];
        }
        [btn addSubview:iv];
        
        [self.packsScrollView addSubview:btn];
        x += 40.0;
    }
    
    self.packsScrollView.contentSize = CGSizeMake(x + 10.0, 41.5);
}

- (void)packButtonTapped:(UIButton *)sender {
    NSInteger idx = sender.tag - 2000;
    if (idx >= 0 && idx < (NSInteger)self.packs.count) {
        self.selectedPackIndex = idx;
        [self renderPacksBar];
        [self renderStickersGrid];
    }
}

- (void)storeButtonTapped {
    if (self.onOpenStore) {
        self.onOpenStore();
    }
}

- (void)renderStickersGrid {
    for (UIView *v in self.stickersScrollView.subviews) {
        [v removeFromSuperview];
    }
    
    if (self.selectedPackIndex >= (NSInteger)self.packs.count) return;
    VKStickerPack *pack = self.packs[self.selectedPackIndex];
    
    CGFloat totalWidth = self.stickersScrollView.bounds.size.width;
    if (totalWidth <= 0) totalWidth = [UIScreen mainScreen].bounds.size.width;
    
    NSInteger cols = 4;
    CGFloat padding = 8.0;
    CGFloat itemSize = floor((totalWidth - (padding * (cols + 1))) / cols);
    if (itemSize < 50.0) itemSize = 50.0;
    
    CGFloat curX = padding;
    CGFloat curY = padding;
    
    for (NSInteger i = 0; i < (NSInteger)pack.stickers.count; i++) {
        VKSticker *st = pack.stickers[i];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.frame = CGRectMake(curX, curY, itemSize, itemSize);
        btn.tag = 3000 + i;
        btn.adjustsImageWhenHighlighted = YES;
        [btn addTarget:self action:@selector(stickerButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(4, 4, itemSize - 8, itemSize - 8)];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.clipsToBounds = YES;
        iv.userInteractionEnabled = NO;
        if (st.imageURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:st.imageURL completion:^(UIImage *img) {
                if (img) iv.image = img;
            }];
        }
        [btn addSubview:iv];
        [self.stickersScrollView addSubview:btn];
        
        if ((i + 1) % cols == 0) {
            curX = padding;
            curY += itemSize + padding;
        } else {
            curX += itemSize + padding;
        }
    }
    
    if (pack.stickers.count % cols != 0) {
        curY += itemSize + padding;
    }
    
    self.stickersScrollView.contentSize = CGSizeMake(totalWidth, curY + 10.0);
}

- (void)stickerButtonTapped:(UIButton *)sender {
    if (self.selectedPackIndex >= (NSInteger)self.packs.count) return;
    VKStickerPack *pack = self.packs[self.selectedPackIndex];
    NSInteger idx = sender.tag - 3000;
    if (idx >= 0 && idx < (NSInteger)pack.stickers.count) {
        VKSticker *st = pack.stickers[idx];
        if (self.onStickerSelected) {
            self.onStickerSelected(st.stickerId);
        }
    }
}

@end
