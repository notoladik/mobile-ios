#import <UIKit/UIKit.h>

@class VKAttachment;

@interface VKPhotoViewerViewController : UIViewController

// Инициализация одиночным фото
- (instancetype)initWithImageURL:(NSString *)imageURL initialImage:(UIImage *)initialImage;
- (instancetype)initWithImageURL:(NSString *)imageURL fullImageURL:(NSString *)fullImageURL initialImage:(UIImage *)initialImage;

// Инициализация массивом ссылок на фото с начальным индексом
- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs initialIndex:(NSInteger)initialIndex;
- (instancetype)initWithPhotoURLs:(NSArray<NSString *> *)photoURLs fullPhotoURLs:(NSArray<NSString *> *)fullPhotoURLs initialIndex:(NSInteger)initialIndex;

// Инициализация массивом вложений
- (instancetype)initWithAttachments:(NSArray<VKAttachment *> *)attachments initialIndex:(NSInteger)initialIndex;

@end
