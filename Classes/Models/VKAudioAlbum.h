#import <Foundation/Foundation.h>

@interface VKAudioAlbum : NSObject

@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *thumbURL;
@property (nonatomic, assign) NSInteger trackCount;

+ (instancetype)albumFromDictionary:(NSDictionary *)dict;

@end
