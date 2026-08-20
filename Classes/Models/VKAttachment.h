#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, VKAttachmentType) {
    VKAttachmentTypePhoto = 0,
    VKAttachmentTypeVideo,
    VKAttachmentTypeAudio,
    VKAttachmentTypeDoc,
    VKAttachmentTypePoll,
    VKAttachmentTypeGif,
    VKAttachmentTypeLink,
    VKAttachmentTypeNote
};

@interface VKPollOption : NSObject
@property (nonatomic, assign) NSInteger optionId;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) NSInteger votes;
@end

@interface VKAttachment : NSObject

@property (nonatomic, assign) VKAttachmentType type;

// Photo
@property (nonatomic, assign) NSInteger photoId;
@property (nonatomic, assign) NSInteger ownerId;
@property (nonatomic, copy) NSString *photoURL;
@property (nonatomic, assign) CGFloat photoWidth;
@property (nonatomic, assign) CGFloat photoHeight;
@property (nonatomic, assign) NSInteger photoLikes;
@property (nonatomic, assign) BOOL photoIsLiked;

// Video
@property (nonatomic, assign) NSInteger videoId;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSString *videoDuration;
@property (nonatomic, copy) NSString *videoImageURL;
@property (nonatomic, copy) NSString *videoURL;

// Audio
@property (nonatomic, assign) NSInteger audioId;
@property (nonatomic, assign) NSInteger audioOwnerId;
@property (nonatomic, copy) NSString *audioArtist;
@property (nonatomic, copy) NSString *audioTitle;
@property (nonatomic, copy) NSString *audioDuration;
@property (nonatomic, copy) NSString *audioURL;

// Document / GIF
@property (nonatomic, copy) NSString *docTitle;
@property (nonatomic, copy) NSString *docExt;
@property (nonatomic, copy) NSString *docSize;
@property (nonatomic, copy) NSString *docURL;
@property (nonatomic, copy) NSString *gifPreviewURL;
@property (nonatomic, assign) CGFloat gifWidth;
@property (nonatomic, assign) CGFloat gifHeight;

// Link (Snippet)
@property (nonatomic, copy) NSString *linkURL;
@property (nonatomic, copy) NSString *linkTitle;
@property (nonatomic, copy) NSString *linkDescription;
@property (nonatomic, copy) NSString *linkImageURL;

// Poll
@property (nonatomic, assign) NSInteger pollId;
@property (nonatomic, assign) NSInteger pollOwnerId;
@property (nonatomic, copy) NSString *pollQuestion;
@property (nonatomic, strong) NSArray *pollOptions;
@property (nonatomic, assign) NSInteger pollTotalVotes;

+ (instancetype)attachmentFromDictionary:(NSDictionary *)dict;

@end
