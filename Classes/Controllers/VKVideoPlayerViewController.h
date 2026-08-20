#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import "VKAttachment.h"

@interface VKVideoPlayerViewController : MPMoviePlayerViewController

- (instancetype)initWithVideoURL:(NSURL *)videoURL;
- (instancetype)initWithAttachment:(VKAttachment *)attachment;

@end
