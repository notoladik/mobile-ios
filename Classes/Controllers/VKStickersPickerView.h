#import <UIKit/UIKit.h>

@class VKStickerPack;

@interface VKStickersPickerView : UIView

@property (nonatomic, copy) void (^onStickerSelected)(NSInteger stickerId);
@property (nonatomic, copy) void (^onOpenStore)(void);

- (void)reloadPacks;

@end
