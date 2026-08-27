#import <UIKit/UIKit.h>
#import "VKPost.h"

@interface VKFeedPostCell : UITableViewCell

@property (nonatomic, strong) UIView *cardBackgroundView;
@property (nonatomic, strong) UIView *avatarContainerView;
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UIImageView *wallOwnerAvatarImageView;
@property (nonatomic, strong) UILabel *authorNameLabel;
@property (nonatomic, strong) UILabel *verifiedBadgeLabel;
@property (nonatomic, strong) UIImageView *supporterBadgeImageView;
@property (nonatomic, strong) UILabel *wallOwnerNoteLabel;
@property (nonatomic, strong) UILabel *dateAndPlatformLabel;
@property (nonatomic, strong) UIButton *moreButton;

@property (nonatomic, strong) UIView *contentContainerView;
@property (nonatomic, strong) UILabel *postTextLabel;
@property (nonatomic, strong) UIButton *expandTextButton;

// Контейнер фотографий
@property (nonatomic, strong) UIView *photosContainerView;

// Вложения (Аудио, Видео, Опросы, Документы)
@property (nonatomic, strong) UIView *attachmentsContainerView;

// Спойлер (isExplicit)
@property (nonatomic, strong) UIView *spoilerOverlayView;
@property (nonatomic, strong) UIImageView *spoilerEyeImageView;
@property (nonatomic, strong) UILabel *spoilerTitleLabel;
@property (nonatomic, strong) UILabel *spoilerSubtitleLabel;

// Репост (repostHistory)
@property (nonatomic, strong) UIView *repostContainerView;
@property (nonatomic, strong) UIView *repostLeftBarView;
@property (nonatomic, strong) UIImageView *repostAvatarImageView;
@property (nonatomic, strong) UILabel *repostAuthorLabel;
@property (nonatomic, strong) UILabel *repostTextLabel;
@property (nonatomic, strong) UIButton *expandRepostTextButton;

// Кнопки действий
@property (nonatomic, strong) UIView *actionsContainerView;
@property (nonatomic, strong) UIButton *likeButton;
@property (nonatomic, strong) UIButton *commentsButton;
@property (nonatomic, strong) UIButton *repostButton;

@property (nonatomic, strong) VKPost *currentPost;
@property (nonatomic, assign) BOOL isExplicitRevealed;
@property (nonatomic, copy) void (^onLikeTapped)(VKPost *post);
@property (nonatomic, copy) void (^onCommentTapped)(VKPost *post);
@property (nonatomic, copy) void (^onRepostTapped)(VKPost *post);
@property (nonatomic, copy) void (^onAuthorTapped)(VKUser *user);
@property (nonatomic, copy) void (^onOptionsTapped)(VKPost *post);
@property (nonatomic, copy) void (^onRevealSpoilerTapped)(VKPost *post);
@property (nonatomic, copy) void (^onToggleTextExpanded)(VKPost *post);
@property (nonatomic, copy) void (^onToggleRepostTextExpanded)(VKPost *post);
@property (nonatomic, copy) void (^onPhotoTapped)(NSString *imageURL, UIImage *image);
@property (nonatomic, copy) void (^onPhotosGalleryTapped)(NSArray<NSString *> *photoURLs, NSInteger initialIndex);
@property (nonatomic, copy) void (^onVideoTapped)(VKAttachment *videoAttachment);
@property (nonatomic, copy) void (^onAudioTapped)(VKAttachment *audioAttachment);
@property (nonatomic, copy) void (^onPollVoted)(VKAttachment *pollAttachment, NSInteger optionId);
@property (nonatomic, copy) void (^onDocTapped)(VKAttachment *docAttachment);
@property (nonatomic, copy) void (^onGifTapped)(VKAttachment *gifAttachment);
@property (nonatomic, copy) void (^onLinkTapped)(NSString *url);
@property (nonatomic, copy) void (^onCopyrightTapped)(NSString *url);

+ (CGFloat)heightForPost:(VKPost *)post width:(CGFloat)width isRevealed:(BOOL)isRevealed;
- (void)configureWithPost:(VKPost *)post isRevealed:(BOOL)isRevealed;

@end
