#import "VKPhotoViewerViewController.h"
#import "VKPhotoEditorViewController.h"
#import "VKImageLoader.h"
#import <QuartzCore/QuartzCore.h>

#import "VKAttachment.h"

@interface VKPhotoViewerViewController () <UIScrollViewDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) NSArray<NSString *> *photoURLs;
@property (nonatomic, strong) NSArray<NSString *> *fullPhotoURLs;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, strong) UIImage *initialSingleImage;

@property (nonatomic, strong) UIScrollView *pagingScrollView;
@property (nonatomic, strong) NSMutableArray<UIScrollView *> *zoomScrollViews;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *imageViews;

@property (nonatomic, strong) UIView *topBarView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *moreButton;

@property (nonatomic, strong) UIView *bottomBarView;
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UIButton *shareButton;
@property (nonatomic, strong) UIActivityIndicatorView *hqCenterSpinner;

@property (nonatomic, assign) BOOL isBarsHidden;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) BOOL isDraggingDown;
@end

@implementation VKPhotoViewerViewController

- (instancetype)initWithImageURL:(NSString *)imageURL initialImage:(UIImage *)initialImage {
    return [self initWithImageURL:imageURL fullImageURL:imageURL initialImage:initialImage];
}

- (instancetype)initWithImageURL:(NSString *)imageURL fullImageURL:(NSString *)fullImageURL initialImage:(UIImage *)initialImage {
    self = [super init];
    if (self) {
        _photoURLs = imageURL.length > 0 ? @[imageURL] : @[];
        _fullPhotoURLs = fullImageURL.length > 0 ? @[fullImageURL] : _photoURLs;
        _currentIndex = 0;
        _initialSingleImage = initialImage;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs initialIndex:(NSInteger)initialIndex {
    return [self initWithPhotoURLs:photoURLs fullPhotoURLs:photoURLs initialIndex:initialIndex];
}

- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs fullPhotoURLs:(NSArray<NSString *> *)fullPhotoURLs initialIndex:(NSInteger)initialIndex {
    self = [super init];
    if (self) {
        _photoURLs = (photoURLs.count > 0) ? [photoURLs copy] : @[];
        _fullPhotoURLs = (fullPhotoURLs.count > 0) ? [fullPhotoURLs copy] : _photoURLs;
        _currentIndex = (initialIndex >= 0 && initialIndex < (NSInteger)_photoURLs.count) ? initialIndex : 0;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

- (instancetype)initWithAttachments:(NSArray<VKAttachment *> *)attachments initialIndex:(NSInteger)initialIndex {
    NSMutableArray *urls = [NSMutableArray array];
    NSMutableArray *fulls = [NSMutableArray array];
    for (VKAttachment *att in attachments) {
        if (att.type == VKAttachmentTypePhoto) {
            NSString *low = att.photoURLLow ?: att.photoURL;
            NSString *full = att.photoURLFull ?: att.photoURL;
            if (low.length > 0) [urls addObject:low];
            if (full.length > 0) [fulls addObject:full];
        }
    }
    return [self initWithPhotoURLs:urls fullPhotoURLs:fulls initialIndex:initialIndex];
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
        zoomScroll.maximumZoomScale = 4.0;
        zoomScroll.showsHorizontalScrollIndicator = NO;
        zoomScroll.showsVerticalScrollIndicator = NO;
        zoomScroll.tag = 1000 + i;
        zoomScroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        UIImageView *imgView = [[UIImageView alloc] initWithFrame:zoomScroll.bounds];
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        imgView.clipsToBounds = YES;
        imgView.userInteractionEnabled = YES;
        imgView.tag = 2000 + i;
        imgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        // Двойной тап для быстрого зума
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [zoomScroll addGestureRecognizer:doubleTap];
        
        // Одиночный тап для скрытия/показа контролов
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleBarsAction)];
        singleTap.numberOfTapsRequired = 1;
        [singleTap requireGestureRecognizerToFail:doubleTap];
        [zoomScroll addGestureRecognizer:singleTap];
        
        // Свайп вниз для закрытия
        UIPanGestureRecognizer *panDismiss = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanDismiss:)];
        panDismiss.delegate = self;  // нужно для gestureRecognizerShouldBegin:
        [zoomScroll addGestureRecognizer:panDismiss];
        
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
                if (img) {
                    imgView.image = img;
                    [self centerImageInScrollView:zoomScroll];
                }
            }];
        }
    }
    
    // Прокручиваем к начальному индексу
    if (self.currentIndex > 0) {
        [self.pagingScrollView setContentOffset:CGPointMake(self.currentIndex * bounds.size.width, 0) animated:NO];
    }
    
    // Верхняя панель управления
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
    
    self.moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.moreButton.frame = CGRectMake(bounds.size.width - 54, 20, 44, 44);
    [self.moreButton setTitle:@"•••" forState:UIControlStateNormal];
    [self.moreButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.moreButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.moreButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.moreButton addTarget:self action:@selector(moreOptionsAction) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.moreButton];
    
    // Нижняя панель действий (Сохранить, Поделиться)
    self.bottomBarView = [[UIView alloc] initWithFrame:CGRectMake(0, bounds.size.height - 48, bounds.size.width, 48)];
    self.bottomBarView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.bottomBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBarView];
    
    self.saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.saveButton.frame = CGRectMake(16, 4, 120, 40);
    [self.saveButton setTitle:@"💾 Сохранить" forState:UIControlStateNormal];
    [self.saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.saveButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.saveButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.saveButton addTarget:self action:@selector(savePhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarView addSubview:self.saveButton];
    
    self.shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.shareButton.frame = CGRectMake(bounds.size.width - 136, 4, 120, 40);
    self.shareButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.shareButton setTitle:@"Поделиться ↗" forState:UIControlStateNormal];
    [self.shareButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.shareButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.shareButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [self.shareButton addTarget:self action:@selector(sharePhotoAction) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarView addSubview:self.shareButton];
    
    self.hqCenterSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.hqCenterSpinner.center = CGPointMake(bounds.size.width / 2.0, bounds.size.height / 2.0);
    self.hqCenterSpinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.hqCenterSpinner.hidesWhenStopped = YES;
    [self.view addSubview:self.hqCenterSpinner];
    
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
        self.bottomBarView.alpha = self.isBarsHidden ? 0.0 : 1.0;
    }];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    UIScrollView *zoomScroll = (UIScrollView *)gesture.view;
    if (zoomScroll.zoomScale > 1.0) {
        [zoomScroll setZoomScale:1.0 animated:YES];
    } else {
        CGPoint point = [gesture locationInView:zoomScroll];
        CGFloat newScale = 2.5;
        CGSize scrollSize = zoomScroll.bounds.size;
        CGFloat w = scrollSize.width / newScale;
        CGFloat h = scrollSize.height / newScale;
        CGRect zoomRect = CGRectMake(point.x - (w / 2.0), point.y - (h / 2.0), w, h);
        [zoomScroll zoomToRect:zoomRect animated:YES];
    }
}

- (void)handlePanDismiss:(UIPanGestureRecognizer *)gesture {
    UIScrollView *zoomScroll = (UIScrollView *)gesture.view;
    if (zoomScroll.zoomScale > 1.0) return; // Не смахивать при зуме
    
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isDraggingDown = (translation.y > 0);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        if (translation.y > 0) {
            CGFloat progress = translation.y / self.view.bounds.size.height;
            self.pagingScrollView.transform = CGAffineTransformMakeTranslation(0, translation.y);
            CGFloat scale = MAX(0.8, 1.0 - (progress * 0.3));
            self.pagingScrollView.transform = CGAffineTransformScale(self.pagingScrollView.transform, scale, scale);
            self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:MAX(0.2, 1.0 - progress * 1.5)];
            self.topBarView.alpha = MAX(0.0, 1.0 - progress * 3.0);
            self.bottomBarView.alpha = MAX(0.0, 1.0 - progress * 3.0);
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        if (translation.y > 100 || velocity.y > 600) {
            [UIView animateWithDuration:0.25 animations:^{
                self.pagingScrollView.transform = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height);
                self.view.backgroundColor = [UIColor clearColor];
                self.topBarView.alpha = 0.0;
                self.bottomBarView.alpha = 0.0;
            } completion:^(BOOL finished) {
                [self dismissViewControllerAnimated:NO completion:nil];
            }];
        } else {
            [UIView animateWithDuration:0.25 animations:^{
                self.pagingScrollView.transform = CGAffineTransformIdentity;
                self.view.backgroundColor = [UIColor blackColor];
                self.topBarView.alpha = self.isBarsHidden ? 0.0 : 1.0;
                self.bottomBarView.alpha = self.isBarsHidden ? 0.0 : 1.0;
            }];
        }
    }
}

- (void)centerImageInScrollView:(UIScrollView *)scrollView {
    NSInteger index = scrollView.tag - 1000;
    if (index >= 0 && index < (NSInteger)self.imageViews.count) {
        UIImageView *iv = self.imageViews[index];
        CGFloat offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
        CGFloat offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
        iv.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX, scrollView.contentSize.height * 0.5 + offsetY);
    }
}

- (void)savePhotoAction {
    UIImage *img = nil;
    if (self.currentIndex < (NSInteger)self.imageViews.count) {
        img = self.imageViews[self.currentIndex].image;
    }
    
    if (img) {
        // Нормализуем в стандартный RGB bitmap для гарантированного сохранения на всех версиях iOS
        UIGraphicsBeginImageContextWithOptions(img.size, NO, img.scale);
        [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
        UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        UIImageWriteToSavedPhotosAlbum(normalizedImage ?: img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    } else if (self.currentIndex < (NSInteger)self.photoURLs.count) {
        NSString *urlStr = self.photoURLs[self.currentIndex];
        [[VKImageLoader sharedLoader] loadImageWithURL:urlStr completion:^(UIImage *loadedImg) {
            if (loadedImg) {
                UIGraphicsBeginImageContextWithOptions(loadedImg.size, NO, loadedImg.scale);
                [loadedImg drawInRect:CGRectMake(0, 0, loadedImg.size.width, loadedImg.size.height)];
                UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                UIImageWriteToSavedPhotosAlbum(normalizedImage ?: loadedImg, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
            }
        }];
    }
}

- (void)sharePhotoAction {
    if (self.currentIndex < (NSInteger)self.imageViews.count) {
        UIImage *img = self.imageViews[self.currentIndex].image;
        NSString *urlStr = (self.currentIndex < (NSInteger)self.photoURLs.count) ? self.photoURLs[self.currentIndex] : nil;
        
        NSMutableArray *items = [NSMutableArray array];
        if (img) [items addObject:img];
        if (urlStr) [items addObject:[NSURL URLWithString:urlStr]];
        
        if (NSClassFromString(@"UIActivityViewController") && items.count > 0) {
            UIActivityViewController *act = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
            [self presentViewController:act animated:YES completion:nil];
        } else {
            [self moreOptionsAction];
        }
    }
}

- (void)moreOptionsAction {
    NSString *currentURL = (self.currentIndex < (NSInteger)self.photoURLs.count) ? self.photoURLs[self.currentIndex] : nil;
    NSString *fullURL = (self.currentIndex < (NSInteger)self.fullPhotoURLs.count) ? self.fullPhotoURLs[self.currentIndex] : nil;
    
    BOOL isAlreadyFull = (fullURL.length == 0) || [fullURL isEqualToString:currentURL];
    BOOL isFullOnDisk = fullURL ? [[VKImageLoader sharedLoader] isImageCachedOnDiskForURL:fullURL] : NO;
    BOOL canLoadHQ = !isAlreadyFull && !isFullOnDisk;
    
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    sheet.tag = 1000;
    
    if (canLoadHQ) {
        [sheet addButtonWithTitle:@"Загрузить в высоком качестве (HQ)"];
    } else {
        [sheet addButtonWithTitle:@"Качество: Оригинал (HQ) ✓"];
    }
    [sheet addButtonWithTitle:@"Сохранить в фотопленку"];
    [sheet addButtonWithTitle:@"Редактировать"];
    [sheet addButtonWithTitle:@"Скопировать ссылку"];
    
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
    if ([title isEqualToString:@"Загрузить в высоком качестве (HQ)"]) {
        [self loadHQPhotoAction];
    } else if ([title isEqualToString:@"Качество: Оригинал (HQ) ✓"]) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Качество"
                                                    message:@"Фотография уже загружена в оригинальном высоком качестве."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
        [a show];
    } else if ([title isEqualToString:@"Сохранить в фотопленку"]) {
        [self savePhotoAction];
    } else if ([title isEqualToString:@"Редактировать"]) {
        if (self.currentIndex < (NSInteger)self.imageViews.count) {
            UIImage *img = self.imageViews[self.currentIndex].image;
            if (img) {
                VKPhotoEditorViewController *editor = [[VKPhotoEditorViewController alloc] initWithImage:img];
                __weak typeof(self) weakSelf = self;
                editor.onImageEdited = ^(UIImage *edited) {
                    if (edited && weakSelf.currentIndex < (NSInteger)weakSelf.imageViews.count) {
                        weakSelf.imageViews[weakSelf.currentIndex].image = edited;
                    }
                };
                [self presentViewController:editor animated:YES completion:nil];
            }
        }
    } else if ([title isEqualToString:@"Скопировать ссылку"]) {
        if (self.currentIndex < (NSInteger)self.photoURLs.count) {
            NSString *urlStr = self.photoURLs[self.currentIndex];
            [UIPasteboard generalPasteboard].string = urlStr;
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Скопировано"
                                                        message:@"Ссылка на фотографию скопирована в буфер обмена"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
            [a show];
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

#pragma mark - UIGestureRecognizerDelegate

// Не запускать pan-dismiss когда scrollView уже зумнут — тогда работает нативный pan UIScrollView
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) return YES;
    // Ищем в каком zoomScroll живёт этот recognizer
    for (UIScrollView *zs in self.zoomScrollViews) {
        if ([zs.gestureRecognizers containsObject:gestureRecognizer]) {
            // Если зумнуто — не перехватываем, пусть UIScrollView панирует
            if (zs.zoomScale > 1.01) return NO;
            // Если горизонтальный свайп — не мешаем горизонтальному пейджингу
            UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
            CGPoint vel = [pan velocityInView:zs];
            if (ABS(vel.x) > ABS(vel.y) * 1.5) return NO;
            break;
        }
    }
    return YES;
}

// Разрешаем double-tap и pan работать одновременно со scroll
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b {
    return NO; // scroll views сами разбираются; одновременность только через scroll delegate
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

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self centerImageInScrollView:scrollView];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if (scrollView == self.pagingScrollView) {
        CGFloat pageWidth = scrollView.frame.size.width;
        NSInteger page = floor((scrollView.contentOffset.x - pageWidth / 2.0) / pageWidth) + 1;
        if (page >= 0 && page < (NSInteger)self.photoURLs.count) {
            self.currentIndex = page;
            [self updateTitleForIndex:page];
            
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

- (void)loadHQPhotoAction {
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)self.fullPhotoURLs.count) return;
    NSString *fullURL = self.fullPhotoURLs[self.currentIndex];
    if (!fullURL || fullURL.length == 0) return;
    
    [self.hqCenterSpinner startAnimating];
    
    NSInteger pageIndex = self.currentIndex;
    [[VKImageLoader sharedLoader] loadImageWithURL:fullURL completion:^(UIImage *fullImg) {
        [self.hqCenterSpinner stopAnimating];
        if (fullImg) {
            if (pageIndex < (NSInteger)self.imageViews.count) {
                UIImageView *iv = self.imageViews[pageIndex];
                [UIView transitionWithView:iv
                                  duration:0.35
                                   options:UIViewAnimationOptionTransitionCrossDissolve
                                animations:^{
                                    iv.image = fullImg;
                                } completion:nil];
                if (pageIndex < (NSInteger)self.zoomScrollViews.count) {
                    [self centerImageInScrollView:self.zoomScrollViews[pageIndex]];
                }
            }
            NSMutableArray *mutURLs = [self.photoURLs mutableCopy];
            if (pageIndex < (NSInteger)mutURLs.count) {
                mutURLs[pageIndex] = fullURL;
                self.photoURLs = [mutURLs copy];
            }
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                            message:@"Не удалось загрузить фото в высоком качестве. Проверьте соединение с интернетом."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
    }];
}

@end
