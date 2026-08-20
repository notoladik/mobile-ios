#import "VKPhotoViewerViewController.h"
#import "VKImageLoader.h"

@interface VKPhotoViewerViewController () <UIScrollViewDelegate>
@property (nonatomic, strong) NSArray<NSString *> *photoURLs;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) UIImage *initialSingleImage;

@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) NSMutableArray<UIScrollView *> *zoomScrollViews;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *imageViews;

@property (nonatomic, strong) UIView *topBarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, assign) BOOL isBarsHidden;
@end

@implementation VKPhotoViewerViewController

- (instancetype)initWithImageURL:(NSString *)imageURL initialImage:(UIImage *)initialImage {
    self = [super init];
    if (self) {
        _photoURLs = imageURL.length > 0 ? @[imageURL] : @[];
        _currentIndex = 0;
        _initialSingleImage = initialImage;
    }
    return self;
}

- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs initialIndex:(NSInteger)initialIndex {
    self = [super init];
    if (self) {
        _photoURLs = (photoURLs.count > 0) ? [photoURLs copy] : @[];
        _currentIndex = (initialIndex >= 0 && initialIndex < (NSInteger)_photoURLs.count) ? initialIndex : 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    self.zoomScrollViews = [NSMutableArray array];
    self.imageViews = [NSMutableArray array];
    
    CGRect bounds = self.view.bounds;
    
    // Пейджинг скролл
    self.pagingScrollView = [[UIScrollView alloc] initWithFrame:bounds];
    self.pagingScrollView.pagingEnabled = YES;
    self.pagingScrollView.delegate = self;
    self.pagingScrollView.showsHorizontalScrollIndicator = NO;
    self.pagingScrollView.showsVerticalScrollIndicator = NO;
    self.pagingScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.pagingScrollView];
    
    NSInteger count = MAX(1, self.photoURLs.count);
    self.pagingScrollView.contentSize = CGSizeMake(bounds.size.width * count, bounds.size.height);
    
    for (NSInteger i = 0; i < count; i++) {
        CGRect pageFrame = CGRectMake(i * bounds.size.width, 0, bounds.size.width, bounds.size.height);
        
        UIScrollView *zoomScroll = [[UIScrollView alloc] initWithFrame:pageFrame];
        zoomScroll.delegate = self;
        zoomScroll.minimumZoomScale = 1.0;
        zoomScroll.maximumZoomScale = 3.5;
        zoomScroll.showsHorizontalScrollIndicator = NO;
        zoomScroll.showsVerticalScrollIndicator = NO;
        zoomScroll.tag = 1000 + i;
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:zoomScroll.bounds];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        imgView.clipsToBounds = YES;
        imgView.userInteractionEnabled = YES;
        imgView.tag = 2000 + i;
        
        // Двойной тап для зума
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [zoomScroll addGestureRecognizer:doubleTap];
        
        // Одиночный тап для скрытия/показа панелей
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleBarsAction)];
        singleTap.numberOfTapsRequired = 1;
        [singleTap requireGestureRecognizerToFail:doubleTap];
        [zoomScroll addGestureRecognizer:singleTap];
        
        [zoomScroll addSubview:imgView];
        [self.pagingScrollView addSubview:zoomScroll];
        
        [self.zoomScrollViews addObject:zoomScroll];
        [self.imageViews addObject:imgView];
        
        if (i < (NSInteger)self.photoURLs.count) {
            NSString *url = self.photoURLs[i];
            if (i == 0 && self.initialSingleImage) {
                imgView.image = self.initialSingleImage;
            }
            [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                if (img) imgView.image = img;
            }];
        }
    }
    
    // Прокручиваем к текущему индексу
    if (self.currentIndex > 0) {
        [self.pagingScrollView setContentOffset:CGPointMake(self.currentIndex * bounds.size.width, 0) animated:NO];
    }
    
    // Верхняя панель
    self.topBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 64)];
    self.topBarView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.topBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.topBarView];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.closeButton.frame = CGRectMake(10, 20, 44, 44);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [self.closeButton addTarget:self action:@selector(closeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.closeButton];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 26, bounds.size.width - 120, 30)];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBarView addSubview:self.titleLabel];
    
    self.saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.saveButton.frame = CGRectMake(bounds.size.width - 54, 20, 44, 44);
    [self.saveButton setTitle:@"💾" forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont systemFontOfSize:20];
    self.saveButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.saveButton addTarget:self action:@selector(savePhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.saveButton];
    
    [self updateTitleForIndex:self.currentIndex];
}

- (void)updateTitleForIndex:(NSInteger)index {
    if (self.photoURLs.count > 1) {
        self.titleLabel.text = [NSString stringWithFormat:@"%ld из %lu", (long)(index + 1), (unsigned long)self.photoURLs.count];
    } else {
        self.titleLabel.text = @"Фотография";
    }
}

- (void)toggleBarsAction {
    self.isBarsHidden = !self.isBarsHidden;
    [UIView animateWithDuration:0.25 animations:^{
        self.topBarView.alpha = self.isBarsHidden ? 0.0 : 1.0;
    }];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    UIScrollView *zoomScroll = (UIScrollView *)gesture.view;
    if (zoomScroll.zoomScale > 1.0) {
        [zoomScroll setZoomScale:1.0 animated:YES];
    } else {
        CGPoint point = [gesture locationInView:zoomScroll];
        CGRect zoomRect = CGRectMake(point.x - 40, point.y - 40, 80, 80);
        [zoomScroll zoomToRect:zoomRect animated:YES];
    }
}

- (void)savePhotoAction {
    if (self.currentIndex < (NSInteger)self.imageViews.count) {
        UIImage *img = self.imageViews[self.currentIndex].image;
        if (img) {
            UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        }
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:(error ? @"Ошибка" : @"Успешно")
                                                    message:(error ? @"Не удалось сохранить фото" : @"Фотография сохранена в Фотопленку")
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)closeAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    if (scrollView == self.pagingScrollView) return nil;
    NSInteger index = scrollView.tag - 1000;
    if (index >= 0 && index < (NSInteger)self.imageViews.count) {
        return self.imageViews[index];
    }
    return nil;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.pagingScrollView) {
        CGFloat pageWidth = scrollView.frame.size.width;
        NSInteger page = floor((scrollView.contentOffset.x - pageWidth / 2.0) / pageWidth) + 1;
        if (page >= 0 && page < (NSInteger)self.photoURLs.count) {
            self.currentIndex = page;
            [self updateTitleForIndex:page];
            
            // Сбрасываем зум на соседних страницах
            for (NSInteger i = 0; i < (NSInteger)self.zoomScrollViews.count; i++) {
                if (i != page) {
                    [self.zoomScrollViews[i] setZoomScale:1.0 animated:NO];
                }
            }
        }
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

@end
