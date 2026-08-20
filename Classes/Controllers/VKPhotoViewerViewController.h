#import <UIKit/UIKit.h>

@interface VKPhotoViewerViewController : UIViewController

// Инициализация одиночным фото
- (instancetype)initWithImageURL:(NSString *)imageURL initialImage:(UIImage *)initialImage;

// Инициализация массивом ссылок на фото с начальным индексом
- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs initialIndex:(NSInteger)initialIndex;

@end
