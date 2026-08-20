#import <Foundation/Foundation.h>

@interface VKAudioTrack : NSObject

@property (nonatomic, assign) NSInteger trackId;
@property (nonatomic, assign) NSInteger audioId;
@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *duration;
@property (nonatomic, assign) NSInteger durationSeconds;
@property (nonatomic, copy) NSString *streamURL;
@property (nonatomic, copy) NSString *coverURL;

+ (instancetype)trackFromDictionary:(NSDictionary *)dict;

@end
