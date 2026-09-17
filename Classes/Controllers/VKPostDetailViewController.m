#import "VKLikesListViewController.h"
#import "VKPostDetailViewController.h"
#import "VKCommentsService.h"
#import "VKFeedService.h"
#import "VKAuthService.h"
#import "VKFeedPostCell.h"
#import "VKProfileViewController.h"
#import "VKProfileService.h"
#import "VKPhotoViewerViewController.h"
#import "VKGifViewerViewController.h"
#import "VKVideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "VKAudioPlayer.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKCrashLogger.h"
#import "VKShareManager.h"

#pragma mark - VKCommentCell (Идентично скриншоту VK iOS с поддержкой вложений)

@interface VKCommentCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarImageView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *replyToLabel;
@property (nonatomic, strong) UILabel *dateLabel;
@property (nonatomic, strong) UILabel *commentTextLabel;
@property (nonatomic, strong) UIView *attachmentsContainerView;
@property (nonatomic, strong) UIButton *replyButton;
@property (nonatomic, strong) UIButton *moreButton;
@property (nonatomic, strong) UIButton *likeButton;

@property (nonatomic, strong) UIView *threadGuideLineView;
@property (nonatomic, strong) UIView *threadElbowLineView;

@property (nonatomic, copy) void (^onAvatarTapped)(void);
@property (nonatomic, copy) void (^onReplyAuthorTapped)(VKUser *user);
@property (nonatomic, copy) void (^onReplyTapped)(void);
@property (nonatomic, copy) void (^onMoreTapped)(void);
@property (nonatomic, copy) void (^onShowCommentLikesTapped)(VKComment *comment);
@property (nonatomic, copy) void (^onLikeTapped)(void);
@property (nonatomic, copy) void (^onPhotoTapped)(NSString *photoURL, UIImage *image);
@property (nonatomic, copy) void (^onPhotoWithFullURLTapped)(NSString *photoURL, NSString *fullPhotoURL, UIImage *image);
@property (nonatomic, copy) void (^onAudioTapped)(VKAttachment *audio);
@property (nonatomic, copy) void (^onVideoTapped)(VKAttachment *video);
@property (nonatomic, copy) void (^onDocTapped)(VKAttachment *doc);
@property (nonatomic, copy) void (^onLinkTapped)(NSString *url);

@property (nonatomic, strong) VKComment *currentComment;
@property (nonatomic, assign) NSUInteger configurationGeneration;
@end

@implementation VKCommentCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor whiteColor];
        
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 10, 36, 36)];
        _avatarImageView.layer.cornerRadius = 18.0;
        _avatarImageView.clipsToBounds = YES;
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        _avatarImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarClicked)];
        [_avatarImageView addGestureRecognizer:tap];
        [self.contentView addSubview:_avatarImageView];
        
        _threadGuideLineView = [[UIView alloc] initWithFrame:CGRectZero];
        _threadGuideLineView.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0];
        _threadGuideLineView.hidden = YES;
        [self.contentView addSubview:_threadGuideLineView];
        
        _threadElbowLineView = [[UIView alloc] initWithFrame:CGRectZero];
        _threadElbowLineView.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0];
        _threadElbowLineView.hidden = YES;
        [self.contentView addSubview:_threadElbowLineView];
        
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.font = [UIFont boldSystemFontOfSize:14];
        _nameLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        [self.contentView addSubview:_nameLabel];
        
        _replyToLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _replyToLabel.font = [UIFont systemFontOfSize:12];
        _replyToLabel.textColor = [UIColor colorWithRed:125.0/255.0 green:138.0/255.0 blue:155.0/255.0 alpha:1.0];
        _replyToLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *rTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(replyAuthorClicked)];
        [_replyToLabel addGestureRecognizer:rTap];
        _replyToLabel.hidden = YES;
        [self.contentView addSubview:_replyToLabel];
        
        UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(replyClicked)];
        swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
        [self.contentView addGestureRecognizer:swipeRight];
        
        _commentTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _commentTextLabel.font = [UIFont systemFontOfSize:14];
        _commentTextLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0];
        _commentTextLabel.numberOfLines = 0;
        [self.contentView addSubview:_commentTextLabel];
        
        _attachmentsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        _attachmentsContainerView.clipsToBounds = YES;
        [self.contentView addSubview:_attachmentsContainerView];
        
        _dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateLabel.font = [UIFont systemFontOfSize:11.5];
        _dateLabel.textColor = [UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0];
        [self.contentView addSubview:_dateLabel];
        
        _replyButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_replyButton setTitle:@"Ответить" forState:UIControlStateNormal];
        [_replyButton setTitleColor:[UIColor colorWithRed:125.0/255.0 green:135.0/255.0 blue:148.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _replyButton.titleLabel.font = [UIFont systemFontOfSize:11.5];
        _replyButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_replyButton addTarget:self action:@selector(replyClicked) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_replyButton];
        
        _moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButton setTitle:@"•••" forState:UIControlStateNormal];
        [_moreButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _moreButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [_moreButton addTarget:self action:@selector(moreClicked) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_moreButton];
        
        _likeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _likeButton.frame = CGRectMake(self.contentView.bounds.size.width - 50, 10, 44, 22);
        _likeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [_likeButton setTitle:@"♡" forState:UIControlStateNormal];
        [_likeButton setTitleColor:[UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _likeButton.titleLabel.font = [UIFont systemFontOfSize:12.5];
        _likeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_likeButton addTarget:self action:@selector(likeClicked) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *lpComm = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(commentLikeLongPressed:)];
        lpComm.minimumPressDuration = 0.45;
        [_likeButton addGestureRecognizer:lpComm];
        [self.contentView addSubview:_likeButton];
    }
    return self;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.configurationGeneration += 1;
    self.currentComment = nil;
    self.onAvatarTapped = nil;
    self.onReplyTapped = nil;
    self.onMoreTapped = nil;
    self.onLikeTapped = nil;
    self.onPhotoTapped = nil;
    self.onAudioTapped = nil;
    self.onVideoTapped = nil;
    self.onDocTapped = nil;
    self.onLinkTapped = nil;
    self.avatarImageView.image = nil;
    self.threadGuideLineView.hidden = YES;
    self.threadElbowLineView.hidden = YES;
    self.replyToLabel.hidden = YES;
    self.replyToLabel.text = nil;
    self.onReplyAuthorTapped = nil;
    [[self.attachmentsContainerView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.attachmentsContainerView.frame = CGRectZero;
}

- (void)avatarClicked {
    if (self.onAvatarTapped) self.onAvatarTapped();
}

- (void)replyAuthorClicked {
    if (self.onReplyAuthorTapped && self.currentComment.replyToAuthor) {
        self.onReplyAuthorTapped(self.currentComment.replyToAuthor);
    }
}

- (void)replyClicked {
    if (self.onReplyTapped) self.onReplyTapped();
}

- (void)moreClicked {
    if (self.onMoreTapped) self.onMoreTapped();
}

- (void)likeClicked {
    if (_likeButton) {
        [UIView animateWithDuration:0.1 animations:^{
            self.likeButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.12 animations:^{
                self.likeButton.transform = CGAffineTransformIdentity;
            }];
        }];
    }
    if (self.onLikeTapped) self.onLikeTapped();
}

- (void)commentLikeLongPressed:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (self.onShowCommentLikesTapped && self.currentComment) {
            self.onShowCommentLikesTapped(self.currentComment);
        }
    }
}

+ (NSAttributedString *)attributedTextForComment:(NSString *)rawText {
    if (!rawText || rawText.length == 0) return [[NSAttributedString alloc] initWithString:@""];
    
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc] initWithString:rawText attributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:24.0/255.0 alpha:1.0]
    }];
    
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(id|club)(\\d+)\\|([^\\]]+)\\]" options:0 error:&error];
    if (!error) {
        NSArray *matches = [regex matchesInString:attr.string options:0 range:NSMakeRange(0, attr.string.length)];
        for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
            NSRange fullRange = [match rangeAtIndex:0];
            NSRange nameRange = [match rangeAtIndex:3];
            NSString *name = [attr.string substringWithRange:nameRange];
            
            NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:name attributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:14],
                NSForegroundColorAttributeName: [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]
            }];
            [attr replaceCharactersInRange:fullRange withAttributedString:replacement];
        }
    }
    return attr;
}

+ (CGFloat)heightForComment:(VKComment *)comment width:(CGFloat)width {
    if (!comment) return 44.0;
    CGFloat contentX = (comment.threadLevel > 0) ? 76.0 : 58.0;
    CGFloat textWidth = MAX(50.0, width - contentX - 10.0);
    
    CGFloat textH = 0;
    if (comment.text.length > 0) {
        NSAttributedString *attr = [self attributedTextForComment:comment.text];
        if ([attr respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
            CGRect rect = [attr boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
            textH = ceilf(rect.size.height);
        } else {
            CGSize sz = [comment.text sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(textWidth, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
            textH = ceilf(sz.height);
        }
    }
    
    CGFloat attsH = 0;
    for (VKAttachment *att in comment.attachments) {
        if (![att isKindOfClass:[VKAttachment class]]) continue;
        if (att.type == VKAttachmentTypePhoto || att.type == VKAttachmentTypeGif) {
            CGFloat maxW = MIN(220.0, textWidth);
            CGFloat h = 150.0;
            if (att.photoWidth > 0 && att.photoHeight > 0) {
                h = roundf(maxW * (att.photoHeight / att.photoWidth));
                h = MIN(180.0, MAX(70.0, h));
            }
            attsH += h + 6.0;
        } else if (att.type == VKAttachmentTypeSticker) {
            attsH += 128.0 + 6.0;
        } else if (att.type == VKAttachmentTypeAudio) {
            attsH += 44.0 + 6.0;
        } else if (att.type == VKAttachmentTypeVideo) {
            attsH += 130.0 + 6.0;
        } else if (att.type == VKAttachmentTypeDoc) {
            attsH += 38.0 + 6.0;
        } else if (att.type == VKAttachmentTypeLink) {
            attsH += 42.0 + 6.0;
        }
    }
    
    CGFloat contentH = (textH > 0 ? (textH + 4.0) : 0) + attsH;
    return MAX(62.0, 28.0 + contentH + 32.0);
}

- (void)configureWithComment:(VKComment *)comment width:(CGFloat)width {
    self.configurationGeneration += 1;
    NSUInteger generation = self.configurationGeneration;
    self.currentComment = comment;
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    
    BOOL isReply = (comment.threadLevel > 0);
    CGFloat leftIndent = isReply ? 28.0 : 0.0;
    CGFloat avatarX = 12.0 + leftIndent;
    CGFloat avatarSize = isReply ? 28.0 : 36.0;
    self.avatarImageView.frame = CGRectMake(avatarX, isReply ? 8 : 10, avatarSize, avatarSize);
    self.avatarImageView.layer.cornerRadius = isSkeuomorph ? 3.0 : (avatarSize / 2.0);
    self.avatarImageView.image = nil;
    
    if (isReply) {
        self.threadGuideLineView.hidden = NO;
        self.threadGuideLineView.frame = CGRectMake(20.0, 0, 1.5, 22.0);
        self.threadElbowLineView.hidden = NO;
        self.threadElbowLineView.frame = CGRectMake(20.0, 22.0, avatarX - 20.0, 1.5);
    } else {
        self.threadGuideLineView.hidden = YES;
        self.threadElbowLineView.hidden = YES;
    }
    
    if (comment.author.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:comment.author.avatarURL completion:^(UIImage *img) {
            if (img && self.configurationGeneration == generation && self.currentComment == comment) {
                self.avatarImageView.image = img;
            }
        }];
    }
    
    CGFloat contentX = avatarX + avatarSize + 8.0;
    CGFloat availableHeaderW = width - contentX - 64.0;
    
    self.nameLabel.text = comment.author.displayName ?: @"Пользователь";
    if (isSkeuomorph) {
        self.nameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
    } else {
        self.nameLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    }
    
    CGSize nameSize = [self.nameLabel.text sizeWithFont:[UIFont boldSystemFontOfSize:14]];
    CGFloat maxNameW = (comment.replyToAuthor || comment.replyToUser != 0) ? (availableHeaderW * 0.55) : availableHeaderW;
    CGFloat actualNameW = MIN(nameSize.width, maxNameW);
    self.nameLabel.frame = CGRectMake(contentX, 8, actualNameW, 18);
    
    if (comment.replyToAuthor || comment.replyToUser != 0) {
        NSString *rName = comment.replyToAuthor.displayName ?: (comment.replyToUser > 0 ? [NSString stringWithFormat:@"id%ld", (long)comment.replyToUser] : @"");
        if (rName.length > 0) {
            self.replyToLabel.hidden = NO;
            self.replyToLabel.text = [NSString stringWithFormat:@"↳ %@", rName];
            CGSize rSize = [self.replyToLabel.text sizeWithFont:[UIFont systemFontOfSize:12]];
            CGFloat rW = MIN(rSize.width, availableHeaderW - actualNameW - 4.0);
            self.replyToLabel.frame = CGRectMake(contentX + actualNameW + 4.0, 8, rW, 18);
        } else {
            self.replyToLabel.hidden = YES;
        }
    } else {
        self.replyToLabel.hidden = YES;
    }
    
    CGFloat textWidth = MAX(50.0, width - contentX - 10.0);
    CGFloat textH = 0;
    if (comment.text.length > 0) {
        NSAttributedString *attr = [VKCommentCell attributedTextForComment:comment.text];
        self.commentTextLabel.attributedText = attr;
        if ([attr respondsToSelector:@selector(boundingRectWithSize:options:context:)]) {
            CGRect rect = [attr boundingRectWithSize:CGSizeMake(textWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading context:nil];
            textH = ceilf(rect.size.height);
        } else {
            CGSize sz = [comment.text sizeWithFont:[UIFont systemFontOfSize:14] constrainedToSize:CGSizeMake(textWidth, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
            textH = ceilf(sz.height);
        }
        self.commentTextLabel.frame = CGRectMake(contentX, 28, textWidth, textH);
        self.commentTextLabel.hidden = NO;
    } else {
        self.commentTextLabel.text = nil;
        self.commentTextLabel.frame = CGRectZero;
        self.commentTextLabel.hidden = YES;
    }
    
    // Рендеринг вложений
    [[self.attachmentsContainerView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    CGFloat startAttY = (textH > 0) ? (28.0 + textH + 6.0) : 28.0;
    CGFloat currentY = 0;
    
    __weak typeof(self) weakSelf = self;
    
    for (VKAttachment *att in comment.attachments) {
        if (![att isKindOfClass:[VKAttachment class]]) continue;
        
        if (att.type == VKAttachmentTypePhoto || att.type == VKAttachmentTypeGif) {
            CGFloat maxW = MIN(220.0, textWidth);
            CGFloat h = 150.0;
            if (att.photoWidth > 0 && att.photoHeight > 0) {
                h = roundf(maxW * (att.photoHeight / att.photoWidth));
                h = MIN(180.0, MAX(70.0, h));
            }
            
            UIImageView *photoView = [[UIImageView alloc] initWithFrame:CGRectMake(0, currentY, maxW, h)];
            photoView.layer.cornerRadius = 6.0;
            photoView.clipsToBounds = YES;
            photoView.contentMode = UIViewContentModeScaleAspectFill;
            photoView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            photoView.userInteractionEnabled = YES;
            
            NSString *url = att.photoURL ?: att.gifPreviewURL;
            if (url) {
                [[VKImageLoader sharedLoader] loadImageWithURL:url completion:^(UIImage *img) {
                    if (img && weakSelf.configurationGeneration == generation) {
                        photoView.image = img;
                    }
                }];
            }
            
            UITapGestureRecognizer *pTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handlePhotoTap:)];
            photoView.tag = 1000 + (NSInteger)[comment.attachments indexOfObject:att];
            [photoView addGestureRecognizer:pTap];
            
            [self.attachmentsContainerView addSubview:photoView];
            currentY += h + 6.0;
            
        } else if (att.type == VKAttachmentTypeSticker) {
            UIImageView *stickView = [[UIImageView alloc] initWithFrame:CGRectMake(0, currentY, 128, 128)];
            stickView.contentMode = UIViewContentModeScaleAspectFit;
            stickView.backgroundColor = [UIColor clearColor];
            
            if (att.stickerURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.stickerURL completion:^(UIImage *img) {
                    if (img && weakSelf.configurationGeneration == generation) {
                        stickView.image = img;
                    }
                }];
            }
            [self.attachmentsContainerView addSubview:stickView];
            currentY += 128.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeAudio) {
            UIView *audioCard = [[UIView alloc] initWithFrame:CGRectMake(0, currentY, MIN(240.0, textWidth), 44)];
            audioCard.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:245.0/255.0 blue:248.0/255.0 alpha:1.0];
            audioCard.layer.cornerRadius = 6.0;
            audioCard.clipsToBounds = YES;
            audioCard.userInteractionEnabled = YES;
            
            UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            playBtn.frame = CGRectMake(6, 7, 30, 30);
            playBtn.layer.cornerRadius = 15.0;
            playBtn.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            [playBtn setTitle:@"▶" forState:UIControlStateNormal];
            playBtn.titleLabel.font = [UIFont systemFontOfSize:12];
            [playBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            playBtn.userInteractionEnabled = NO;
            [audioCard addSubview:playBtn];
            
            UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 4, audioCard.bounds.size.width - 48, 18)];
            titleLbl.font = [UIFont boldSystemFontOfSize:12.5];
            titleLbl.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0];
            titleLbl.text = att.audioTitle ?: @"Аудиозапись";
            [audioCard addSubview:titleLbl];
            
            UILabel *artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 22, audioCard.bounds.size.width - 48, 16)];
            artistLbl.font = [UIFont systemFontOfSize:11];
            artistLbl.textColor = [UIColor grayColor];
            artistLbl.text = att.audioArtist ?: @"Неизвестный исполнитель";
            [audioCard addSubview:artistLbl];
            
            UITapGestureRecognizer *aTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAudioTap:)];
            audioCard.tag = 1000 + (NSInteger)[comment.attachments indexOfObject:att];
            [audioCard addGestureRecognizer:aTap];
            
            [self.attachmentsContainerView addSubview:audioCard];
            currentY += 44.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeVideo) {
            CGFloat vW = MIN(220.0, textWidth);
            CGFloat vH = 130.0;
            UIView *vidCard = [[UIView alloc] initWithFrame:CGRectMake(0, currentY, vW, vH)];
            vidCard.layer.cornerRadius = 6.0;
            vidCard.clipsToBounds = YES;
            vidCard.backgroundColor = [UIColor blackColor];
            vidCard.userInteractionEnabled = YES;
            
            UIImageView *thumb = [[UIImageView alloc] initWithFrame:vidCard.bounds];
            thumb.contentMode = UIViewContentModeScaleAspectFill;
            thumb.clipsToBounds = YES;
            if (att.videoImageURL) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.videoImageURL completion:^(UIImage *img) {
                    if (img && weakSelf.configurationGeneration == generation) {
                        thumb.image = img;
                    }
                }];
            }
            [vidCard addSubview:thumb];
            
            UIView *overlay = [[UIView alloc] initWithFrame:vidCard.bounds];
            overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.25];
            [vidCard addSubview:overlay];
            
            UILabel *playIco = [[UILabel alloc] initWithFrame:CGRectMake((vW - 36)/2.0, (vH - 36)/2.0, 36, 36)];
            playIco.text = @"▶";
            playIco.textAlignment = NSTextAlignmentCenter;
            playIco.textColor = [UIColor whiteColor];
            playIco.font = [UIFont systemFontOfSize:20];
            playIco.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
            playIco.layer.cornerRadius = 18.0;
            playIco.clipsToBounds = YES;
            [vidCard addSubview:playIco];
            
            if (att.videoTitle) {
                UILabel *vTitle = [[UILabel alloc] initWithFrame:CGRectMake(6, vH - 22, vW - 12, 18)];
                vTitle.font = [UIFont boldSystemFontOfSize:11];
                vTitle.textColor = [UIColor whiteColor];
                vTitle.shadowColor = [UIColor blackColor];
                vTitle.shadowOffset = CGSizeMake(0, 1);
                vTitle.text = att.videoTitle;
                [vidCard addSubview:vTitle];
            }
            
            UITapGestureRecognizer *vTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleVideoTap:)];
            vidCard.tag = 1000 + (NSInteger)[comment.attachments indexOfObject:att];
            [vidCard addGestureRecognizer:vTap];
            
            [self.attachmentsContainerView addSubview:vidCard];
            currentY += vH + 6.0;
            
        } else if (att.type == VKAttachmentTypeDoc) {
            UIView *docCard = [[UIView alloc] initWithFrame:CGRectMake(0, currentY, MIN(240.0, textWidth), 38)];
            docCard.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
            docCard.layer.cornerRadius = 6.0;
            docCard.clipsToBounds = YES;
            docCard.userInteractionEnabled = YES;
            
            UILabel *docIco = [[UILabel alloc] initWithFrame:CGRectMake(8, 7, 24, 24)];
            docIco.text = @"📄";
            docIco.font = [UIFont systemFontOfSize:18];
            [docCard addSubview:docIco];
            
            UILabel *docTitle = [[UILabel alloc] initWithFrame:CGRectMake(36, 4, docCard.bounds.size.width - 42, 16)];
            docTitle.font = [UIFont boldSystemFontOfSize:12];
            docTitle.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            docTitle.text = att.docTitle ?: @"Документ";
            [docCard addSubview:docTitle];
            
            UILabel *docSub = [[UILabel alloc] initWithFrame:CGRectMake(36, 20, docCard.bounds.size.width - 42, 14)];
            docSub.font = [UIFont systemFontOfSize:10.5];
            docSub.textColor = [UIColor grayColor];
            docSub.text = att.docSize ?: (att.docExt ? [att.docExt uppercaseString] : @"Файл");
            [docCard addSubview:docSub];
            
            UITapGestureRecognizer *dTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDocTap:)];
            docCard.tag = 1000 + (NSInteger)[comment.attachments indexOfObject:att];
            [docCard addGestureRecognizer:dTap];
            
            [self.attachmentsContainerView addSubview:docCard];
            currentY += 38.0 + 6.0;
            
        } else if (att.type == VKAttachmentTypeLink) {
            UIView *linkCard = [[UIView alloc] initWithFrame:CGRectMake(0, currentY, MIN(240.0, textWidth), 42)];
            linkCard.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
            linkCard.layer.cornerRadius = 6.0;
            linkCard.clipsToBounds = YES;
            linkCard.userInteractionEnabled = YES;
            
            UILabel *linkIco = [[UILabel alloc] initWithFrame:CGRectMake(8, 9, 24, 24)];
            linkIco.text = @"🔗";
            linkIco.font = [UIFont systemFontOfSize:16];
            [linkCard addSubview:linkIco];
            
            UILabel *lTitle = [[UILabel alloc] initWithFrame:CGRectMake(36, 4, linkCard.bounds.size.width - 42, 16)];
            lTitle.font = [UIFont boldSystemFontOfSize:12];
            lTitle.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            lTitle.text = att.linkTitle ?: (att.linkURL ?: @"Ссылка");
            [linkCard addSubview:lTitle];
            
            UILabel *lSub = [[UILabel alloc] initWithFrame:CGRectMake(36, 22, linkCard.bounds.size.width - 42, 14)];
            lSub.font = [UIFont systemFontOfSize:10.5];
            lSub.textColor = [UIColor grayColor];
            lSub.text = att.linkURL ?: @"";
            [linkCard addSubview:lSub];
            
            UITapGestureRecognizer *lTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleLinkTap:)];
            linkCard.tag = 1000 + (NSInteger)[comment.attachments indexOfObject:att];
            [linkCard addGestureRecognizer:lTap];
            
            [self.attachmentsContainerView addSubview:linkCard];
            currentY += 42.0 + 6.0;
        }
    }
    
    self.attachmentsContainerView.frame = CGRectMake(contentX, startAttY, textWidth, currentY);
    
    CGFloat bottomY = startAttY + currentY + 4.0;
    NSString *dateStr = comment.timeAgo ?: @"сегодня";
    CGSize dateSize = [dateStr sizeWithFont:[UIFont systemFontOfSize:11.5]];
    self.dateLabel.text = dateStr;
    self.dateLabel.frame = CGRectMake(contentX, bottomY - 5.0, dateSize.width + 4, 26);
    self.replyButton.frame = CGRectMake(contentX + dateSize.width + 7.0, bottomY - 5.0, 64, 26);
    self.moreButton.frame = CGRectMake(contentX + dateSize.width + 76.0, bottomY - 5.0, 34, 26);
    self.replyButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.moreButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    
    // Кнопка Лайка
    self.likeButton.frame = CGRectMake(width - 68, bottomY - 5.0, 58, 26);
    self.likeButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    NSString *likeText = (comment.likesCount > 0) ? [NSString stringWithFormat:@"%ld", (long)comment.likesCount] : @"";
    [self.likeButton setTitle:likeText forState:UIControlStateNormal];
    UIColor *heartColor = comment.isLiked ? [UIColor colorWithRed:235.0/255.0 green:45.0/255.0 blue:70.0/255.0 alpha:1.0] : [UIColor colorWithRed:155.0/255.0 green:165.0/255.0 blue:175.0/255.0 alpha:1.0];
    [self.likeButton setImage:[[VKThemeManager sharedManager] reactionHeartIconWithColor:heartColor filled:comment.isLiked] forState:UIControlStateNormal];
    self.likeButton.imageEdgeInsets = (likeText.length > 0) ? UIEdgeInsetsMake(0, 0, 0, 4) : UIEdgeInsetsZero;
    self.likeButton.titleEdgeInsets = (likeText.length > 0) ? UIEdgeInsetsMake(0, 4, 0, 0) : UIEdgeInsetsZero;
    [self.likeButton setTitleColor:heartColor forState:UIControlStateNormal];
}

- (void)handlePhotoTap:(UITapGestureRecognizer *)tap {
    NSInteger idx = tap.view.tag - 1000;
    if (idx >= 0 && idx < (NSInteger)self.currentComment.attachments.count) {
        VKAttachment *att = self.currentComment.attachments[idx];
        NSString *url = att.photoURL ?: att.gifPreviewURL;
        NSString *full = att.photoURLFull ?: url;
        UIImage *img = [(UIImageView *)tap.view image];
        if (self.onPhotoWithFullURLTapped) {
            self.onPhotoWithFullURLTapped(url, full, img);
        } else if (self.onPhotoTapped) {
            self.onPhotoTapped(url, img);
        }
    }
}

- (void)handleAudioTap:(UITapGestureRecognizer *)tap {
    NSInteger idx = tap.view.tag - 1000;
    if (idx >= 0 && idx < (NSInteger)self.currentComment.attachments.count) {
        VKAttachment *att = self.currentComment.attachments[idx];
        if (self.onAudioTapped) self.onAudioTapped(att);
    }
}

- (void)handleVideoTap:(UITapGestureRecognizer *)tap {
    NSInteger idx = tap.view.tag - 1000;
    if (idx >= 0 && idx < (NSInteger)self.currentComment.attachments.count) {
        VKAttachment *att = self.currentComment.attachments[idx];
        if (self.onVideoTapped) self.onVideoTapped(att);
    }
}

- (void)handleDocTap:(UITapGestureRecognizer *)tap {
    NSInteger idx = tap.view.tag - 1000;
    if (idx >= 0 && idx < (NSInteger)self.currentComment.attachments.count) {
        VKAttachment *att = self.currentComment.attachments[idx];
        if (self.onDocTapped) self.onDocTapped(att);
    }
}

- (void)handleLinkTap:(UITapGestureRecognizer *)tap {
    NSInteger idx = tap.view.tag - 1000;
    if (idx >= 0 && idx < (NSInteger)self.currentComment.attachments.count) {
        VKAttachment *att = self.currentComment.attachments[idx];
        if (self.onLinkTapped) self.onLinkTapped(att.linkURL);
    }
}

@end

#pragma mark - VKPostDetailViewController

@interface VKPostDetailViewController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray *comments;
@property (nonatomic, strong) UIView *inputContainerView;
@property (nonatomic, strong) UIButton *attachButton;
@property (nonatomic, strong) UITextField *commentTextField;
@property (nonatomic, strong) UIButton *smileyButton;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) VKComment *selectedCommentForAction;
@property (nonatomic, assign) NSInteger replyingToCommentId;
@property (nonatomic, strong) VKComment *replyingToComment;
@property (nonatomic, strong) UIView *replyBarView;
@property (nonatomic, strong) UILabel *replyBarTitleLabel;
@property (nonatomic, strong) UILabel *replyBarSnippetLabel;
@property (nonatomic, strong) UIButton *cancelReplyButton;

@property (nonatomic, strong) UIImage *attachedImage;
@property (nonatomic, strong) UIView *attachmentPreviewBar;
@property (nonatomic, strong) UIImageView *attachmentPreviewImageView;
@property (nonatomic, strong) UIButton *removeAttachmentButton;
@property (nonatomic, assign) CGFloat lastKeyboardHeight;
@end

@implementation VKPostDetailViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.tableView reloadData];
}

- (instancetype)initWithPost:(VKPost *)post {
    self = [super init];
    if (self) {
        _post = post;
        _comments = [NSMutableArray array];
        self.hidesBottomBarWhenPushed = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Запись";
    
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    if ([self respondsToSelector:@selector(setExtendedLayoutIncludesOpaqueBars:)]) {
        self.extendedLayoutIncludesOpaqueBars = NO;
    }
    
    [self applyThemeStyle];
    [self setupTableView];
    [self setupInputBar];
    [self setupNavigationItems];
    [self loadComments];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyThemeStyle) name:VKThemeDidChangeNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.focusCommentInputOnAppear) {
        self.focusCommentInputOnAppear = NO;
        [self.commentTextField becomeFirstResponder];
    }
}

- (void)setupNavigationItems {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"•••" style:UIBarButtonItemStylePlain target:self action:@selector(postOptionsAction)];
}

- (void)applyThemeStyle {
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    [self.tableView reloadData];
}

- (void)setupTableView {
    CGFloat inputH = 46.0;
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - inputH) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 8.0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 8.0, 0);
    
    if (NSClassFromString(@"UIRefreshControl")) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        [self.refreshControl addTarget:self action:@selector(loadComments) forControlEvents:UIControlEventValueChanged];
        [self.tableView addSubview:self.refreshControl];
    }
    
    [self.view addSubview:self.tableView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tap];
}

- (void)setupInputBar {
    CGFloat inputH = 46.0;
    CGFloat y = self.view.bounds.size.height - inputH;
    
    self.inputContainerView = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.bounds.size.width, inputH)];
    self.inputContainerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.inputContainerView.backgroundColor = [UIColor colorWithRed:246.0/255.0 green:247.0/255.0 blue:249.0/255.0 alpha:1.0];
    
    // Панель ответа на комментарий
    self.replyBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 38.0)];
    self.replyBarView.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:243.0/255.0 blue:247.0/255.0 alpha:1.0];
    self.replyBarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.replyBarView.hidden = YES;
    
    UIView *rTopLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 0.5)];
    rTopLine.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
    rTopLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.replyBarView addSubview:rTopLine];
    
    UIView *blueStripe = [[UIView alloc] initWithFrame:CGRectMake(10, 6, 3, 26)];
    blueStripe.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    blueStripe.layer.cornerRadius = 1.5;
    [self.replyBarView addSubview:blueStripe];
    
    UILabel *arrowIco = [[UILabel alloc] initWithFrame:CGRectMake(18, 6, 14, 14)];
    arrowIco.text = @"↩";
    arrowIco.font = [UIFont systemFontOfSize:11];
    arrowIco.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    [self.replyBarView addSubview:arrowIco];
    
    self.replyBarTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 4, self.view.bounds.size.width - 76, 15)];
    self.replyBarTitleLabel.font = [UIFont boldSystemFontOfSize:11.5];
    self.replyBarTitleLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
    self.replyBarTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.replyBarView addSubview:self.replyBarTitleLabel];
    
    self.replyBarSnippetLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 19, self.view.bounds.size.width - 76, 14)];
    self.replyBarSnippetLabel.font = [UIFont systemFontOfSize:11];
    self.replyBarSnippetLabel.textColor = [UIColor colorWithRed:120.0/255.0 green:125.0/255.0 blue:135.0/255.0 alpha:1.0];
    self.replyBarSnippetLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.replyBarView addSubview:self.replyBarSnippetLabel];
    
    self.cancelReplyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cancelReplyButton.frame = CGRectMake(self.view.bounds.size.width - 38, 4, 30, 30);
    self.cancelReplyButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.cancelReplyButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.cancelReplyButton setTitleColor:[UIColor colorWithRed:140.0/255.0 green:150.0/255.0 blue:160.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.cancelReplyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.cancelReplyButton addTarget:self action:@selector(cancelReplyAction) forControlEvents:UIControlEventTouchUpInside];
    [self.replyBarView addSubview:self.cancelReplyButton];
    
    [self.inputContainerView addSubview:self.replyBarView];
    
    // Панель предпросмотра прикрепленного фото
    self.attachmentPreviewBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 54)];
    self.attachmentPreviewBar.backgroundColor = [UIColor colorWithRed:238.0/255.0 green:240.0/255.0 blue:244.0/255.0 alpha:1.0];
    self.attachmentPreviewBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.attachmentPreviewBar.hidden = YES;
    
    UIView *pTopLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 0.5)];
    pTopLine.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
    pTopLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.attachmentPreviewBar addSubview:pTopLine];
    
    self.attachmentPreviewImageView = [[UIImageView alloc] initWithFrame:CGRectMake(12, 6, 42, 42)];
    self.attachmentPreviewImageView.layer.cornerRadius = 4.0;
    self.attachmentPreviewImageView.clipsToBounds = YES;
    self.attachmentPreviewImageView.contentMode = UIViewContentModeScaleAspectFill;
    [self.attachmentPreviewBar addSubview:self.attachmentPreviewImageView];
    
    UILabel *pLabel = [[UILabel alloc] initWithFrame:CGRectMake(62, 16, self.view.bounds.size.width - 110, 20)];
    pLabel.text = @"Прикреплена фотография";
    pLabel.font = [UIFont systemFontOfSize:13];
    pLabel.textColor = [UIColor colorWithRed:60.0/255.0 green:65.0/255.0 blue:75.0/255.0 alpha:1.0];
    pLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.attachmentPreviewBar addSubview:pLabel];
    
    self.removeAttachmentButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.removeAttachmentButton.frame = CGRectMake(self.view.bounds.size.width - 40, 11, 32, 32);
    self.removeAttachmentButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.removeAttachmentButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.removeAttachmentButton setTitleColor:[UIColor colorWithRed:140.0/255.0 green:150.0/255.0 blue:160.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.removeAttachmentButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.removeAttachmentButton addTarget:self action:@selector(removeAttachmentAction) forControlEvents:UIControlEventTouchUpInside];
    [self.attachmentPreviewBar addSubview:self.removeAttachmentButton];
    
    [self.inputContainerView addSubview:self.attachmentPreviewBar];
    
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 0.5)];
    topLine.tag = 888;
    topLine.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
    topLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:topLine];
    
    // Кнопка + (Вложения)
    self.attachButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.attachButton.frame = CGRectMake(6, 6, 34, 34);
    [self.attachButton setTitle:@"+" forState:UIControlStateNormal];
    [self.attachButton setTitleColor:[UIColor colorWithRed:145.0/255.0 green:155.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.attachButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [self.attachButton addTarget:self action:@selector(attachAction) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.attachButton];
    
    // Капсула поля ввода
    CGFloat tfX = 46.0;
    CGFloat tfW = self.view.bounds.size.width - tfX - 58.0;
    UIView *fieldBg = [[UIView alloc] initWithFrame:CGRectMake(tfX, 7, tfW, 32)];
    fieldBg.tag = 777;
    fieldBg.backgroundColor = [UIColor whiteColor];
    fieldBg.layer.cornerRadius = 16.0;
    fieldBg.layer.borderWidth = 0.5;
    fieldBg.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0].CGColor;
    fieldBg.clipsToBounds = YES;
    fieldBg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputContainerView addSubview:fieldBg];
    
    self.commentTextField = [[UITextField alloc] initWithFrame:CGRectMake(12, 4, tfW - 40, 24)];
    self.commentTextField.placeholder = @"Ваш комментарий...";
    self.commentTextField.font = [UIFont systemFontOfSize:13.5];
    self.commentTextField.returnKeyType = UIReturnKeySend;
    self.commentTextField.delegate = (id<UITextFieldDelegate>)self;
    self.commentTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.commentTextField addTarget:self action:@selector(textFieldChanged) forControlEvents:UIControlEventEditingChanged];
    [fieldBg addSubview:self.commentTextField];
    
    self.smileyButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.smileyButton.frame = CGRectMake(tfW - 28, 4, 24, 24);
    [self.smileyButton setTitle:@"☺" forState:UIControlStateNormal];
    [self.smileyButton setTitleColor:[UIColor colorWithRed:150.0/255.0 green:160.0/255.0 blue:170.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.smileyButton.titleLabel.font = [UIFont systemFontOfSize:16];
    self.smileyButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [fieldBg addSubview:self.smileyButton];
    
    // Кнопка "Отпр."
    self.sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.sendButton.frame = CGRectMake(self.view.bounds.size.width - 54, 7, 48, 32);
    self.sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
    [self.sendButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    self.sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.sendButton addTarget:self action:@selector(sendComment) forControlEvents:UIControlEventTouchUpInside];
    [self.inputContainerView addSubview:self.sendButton];
    
    [self.view addSubview:self.inputContainerView];
}

- (void)showAttachmentPreviewWithImage:(UIImage *)image {
    self.attachedImage = image;
    self.attachmentPreviewImageView.image = image;
    self.attachmentPreviewBar.hidden = NO;
    [self.sendButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    [self relayoutInputBarAnimated:YES];
}

- (void)removeAttachmentAction {
    self.attachedImage = nil;
    self.attachmentPreviewBar.hidden = YES;
    [self textFieldChanged];
    [self relayoutInputBarAnimated:YES];
}

- (CGFloat)currentInputBarHeight {
    CGFloat h = 46.0;
    if (self.replyingToComment != nil) h += 38.0;
    if (self.attachedImage != nil) h += 54.0;
    return h;
}

- (void)relayoutInputBarAnimated:(BOOL)animated {
    CGFloat h = [self currentInputBarHeight];
    CGFloat y = self.view.bounds.size.height - h - self.lastKeyboardHeight;
    
    void (^layoutBlock)(void) = ^{
        self.inputContainerView.frame = CGRectMake(0, y, self.view.bounds.size.width, h);
        
        CGFloat curY = 0.0;
        if (self.replyingToComment != nil) {
            self.replyBarView.frame = CGRectMake(0, curY, self.view.bounds.size.width, 38.0);
            curY += 38.0;
        }
        if (self.attachedImage != nil) {
            self.attachmentPreviewBar.frame = CGRectMake(0, curY, self.view.bounds.size.width, 54.0);
            curY += 54.0;
        }
        
        UIView *topLine = [self.inputContainerView viewWithTag:888];
        topLine.frame = CGRectMake(0, curY, self.view.bounds.size.width, 0.5);
        
        self.attachButton.frame = CGRectMake(6, curY + 6, 34, 34);
        
        UIView *fieldBg = [self.inputContainerView viewWithTag:777];
        CGFloat tfX = 46.0;
        CGFloat tfW = self.view.bounds.size.width - tfX - 58.0;
        fieldBg.frame = CGRectMake(tfX, curY + 7, tfW, 32);
        
        self.sendButton.frame = CGRectMake(self.view.bounds.size.width - 54, curY + 7, 48, 32);
        
        self.tableView.frame = CGRectMake(0, 0, self.view.bounds.size.width, y);
    };
    
    if (animated) {
        [UIView animateWithDuration:0.25 animations:layoutBlock];
    } else {
        layoutBlock();
    }
}

- (void)startReplyingToComment:(VKComment *)comment {
    if (!comment) return;
    self.replyingToComment = comment;
    self.replyingToCommentId = comment.commentId;
    self.replyBarTitleLabel.text = [NSString stringWithFormat:@"В ответ %@", comment.author.displayName ?: @"пользователю"];
    NSString *snip = comment.text ?: @"";
    if (snip.length == 0 && comment.attachments.count > 0) snip = @"[Вложение]";
    self.replyBarSnippetLabel.text = snip;
    self.replyBarView.hidden = NO;
    [self.sendButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    [self relayoutInputBarAnimated:YES];
    [self.commentTextField becomeFirstResponder];
}

- (void)cancelReplyAction {
    self.replyingToComment = nil;
    self.replyingToCommentId = 0;
    self.replyBarView.hidden = YES;
    [self textFieldChanged];
    [self relayoutInputBarAnimated:YES];
}

- (void)textFieldChanged {
    NSString *trimmed = [self.commentTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length > 0 || self.attachedImage != nil || self.replyingToComment != nil) {
        [self.sendButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.sendButton setTitleColor:[UIColor colorWithRed:160.0/255.0 green:170.0/255.0 blue:180.0/255.0 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)dismissKeyboard {
    [self.commentTextField resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notif {
    NSDictionary *info = [notif userInfo];
    CGRect kbFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.lastKeyboardHeight = kbFrame.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        [self relayoutInputBarAnimated:NO];
    }];
}

- (void)keyboardWillHide:(NSNotification *)notif {
    NSTimeInterval duration = [notif.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    self.lastKeyboardHeight = 0;
    
    [UIView animateWithDuration:duration animations:^{
        [self relayoutInputBarAnimated:NO];
    }];
}

- (void)postOptionsAction {
    NSInteger currentUserId = [[VKAuthService sharedService] currentUserModel].uid;
    BOOL isMyPost = (self.post.ownerID == currentUserId || self.post.author.uid == currentUserId);
    
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    sheet.tag = isMyPost ? 1003 : 1001;
    
    if (isMyPost) {
        sheet.destructiveButtonIndex = [sheet addButtonWithTitle:@"Удалить запись"];
        NSString *archiveTitle = self.post.isArchived ? @"Восстановить на стену" : @"Архивировать запись";
        [sheet addButtonWithTitle:archiveTitle];
    }
    
    [sheet addButtonWithTitle:@"Поделиться"];
    [sheet addButtonWithTitle:@"Скопировать ссылку"];
    if (self.post.likesCount > 0) {
        [sheet addButtonWithTitle:@"Кто оценил"];
    }
    if (self.post.repostsCount > 0) {
        [sheet addButtonWithTitle:@"Кто поделился"];
    }
    
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}

- (void)attachAction {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Прикрепить фотографию"
                                                       delegate:self
                                              cancelButtonTitle:@"Отмена"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [sheet addButtonWithTitle:@"Сделать снимок"];
    }
    [sheet addButtonWithTitle:@"Выбрать из медиатеки"];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    sheet.tag = 1002;
    [sheet showInView:self.view];
}

- (void)openImagePickerWithSourceType:(UIImagePickerControllerSourceType)type {
    if (![UIImagePickerController isSourceTypeAvailable:type]) return;
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
    picker.sourceType = type;
    picker.allowsEditing = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (img) {
            [self showAttachmentPreviewWithImage:img];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSArray *)organizeCommentsIntoThreads:(NSArray *)flatComments {
    if (flatComments.count == 0) return @[];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (VKComment *c in flatComments) {
        if (c.commentId > 0) {
            dict[@(c.commentId)] = c;
        }
    }
    
    NSMutableDictionary *repliesMap = [NSMutableDictionary dictionary];
    NSMutableArray *rootComments = [NSMutableArray array];
    
    for (VKComment *c in flatComments) {
        if (c.replyToComment > 0 && dict[@(c.replyToComment)] != nil) {
            VKComment *parent = dict[@(c.replyToComment)];
            c.parentComment = parent;
            if (!c.replyToAuthor && parent.author) {
                c.replyToAuthor = parent.author;
            }
            c.threadLevel = 1;
            NSMutableArray *replies = repliesMap[@(c.replyToComment)];
            if (!replies) {
                replies = [NSMutableArray array];
                repliesMap[@(c.replyToComment)] = replies;
            }
            [replies addObject:c];
        } else {
            c.threadLevel = (c.replyToComment > 0 || c.replyToUser > 0) ? 1 : 0;
            [rootComments addObject:c];
        }
    }
    
    NSMutableArray *ordered = [NSMutableArray array];
    for (VKComment *root in rootComments) {
        [ordered addObject:root];
        NSArray *replies = repliesMap[@(root.commentId)];
        if (replies.count > 0) {
            [ordered addObjectsFromArray:replies];
        }
    }
    return ordered;
}

- (void)loadComments {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    [[VKCommentsService sharedService] fetchCommentsForOwnerId:self.post.ownerID postId:self.post.vkID offset:0 count:50 completion:^(NSArray *comments, NSInteger totalCount, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.refreshControl endRefreshing];
            self.isLoading = NO;
            if (!error && comments) {
                NSArray *threaded = [self organizeCommentsIntoThreads:comments];
                [self.comments removeAllObjects];
                [self.comments addObjectsFromArray:threaded];
                [self.tableView reloadData];
            }
        });
    }];
}

- (void)sendComment {
    NSString *text = [self.commentTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0 && !self.attachedImage) return;
    
    self.sendButton.userInteractionEnabled = NO;
    NSInteger replyId = self.replyingToCommentId;
    
    if (self.attachedImage) {
        [self.sendButton setTitle:@"..." forState:UIControlStateNormal];
        UIImage *uploadImg = self.attachedImage;
        [[VKFeedService sharedService] uploadWallPhoto:uploadImg ownerId:self.post.ownerID completion:^(NSString *attachmentString, NSError *uploadError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (uploadError || !attachmentString) {
                    self.sendButton.userInteractionEnabled = YES;
                    [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
                    NSString *errMsg = uploadError.localizedDescription ?: @"Не удалось загрузить фото";
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка загрузки"
                                                                    message:errMsg
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alert show];
                    return;
                }
                
                [[VKCommentsService sharedService] addCommentForOwnerId:self.post.ownerID
                                                                 postId:self.post.vkID
                                                                message:text
                                                             replyToCid:replyId
                                                            attachments:attachmentString
                                                             completion:^(BOOL success, NSInteger commentId, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.sendButton.userInteractionEnabled = YES;
                        [self.sendButton setTitle:@"Отпр." forState:UIControlStateNormal];
                        if (success) {
                            [self removeAttachmentAction];
                            self.commentTextField.text = @"";
                            [self cancelReplyAction];
                            [self.commentTextField resignFirstResponder];
                            [self loadComments];
                        } else {
                            NSString *errMsg = error.localizedDescription ?: @"Не удалось отправить комментарий.";
                            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                                            message:errMsg
                                                                           delegate:nil
                                                                  cancelButtonTitle:@"OK"
                                                                  otherButtonTitles:nil];
                            [alert show];
                        }
                    });
                }];
            });
        }];
    } else {
        [[VKCommentsService sharedService] addCommentForOwnerId:self.post.ownerID
                                                         postId:self.post.vkID
                                                        message:text
                                                     replyToCid:replyId
                                                    attachments:nil
                                                     completion:^(BOOL success, NSInteger commentId, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.sendButton.userInteractionEnabled = YES;
                if (success) {
                    self.commentTextField.text = @"";
                    [self cancelReplyAction];
                    [self.commentTextField resignFirstResponder];
                    [self loadComments];
                } else {
                    NSString *errMsg = error.localizedDescription ?: @"Не удалось отправить комментарий.";
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка"
                                                                    message:errMsg
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alert show];
                }
            });
        }];
    }
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2; // 0: Пост, 1: Комментарии
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return MAX(1, self.comments.count);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return 32.0;
    }
    return 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        UIView *hView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 32.0)];
        BOOL isSkeuo = [[VKThemeManager sharedManager] isSkeuomorphic];
        hView.backgroundColor = isSkeuo ? [UIColor colorWithRed:236.0/255.0 green:239.0/255.0 blue:243.0/255.0 alpha:0.98] : [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:0.98];
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 7, tableView.bounds.size.width - 24, 18)];
        lbl.font = [UIFont boldSystemFontOfSize:12.5];
        lbl.textColor = [UIColor colorWithRed:120.0/255.0 green:130.0/255.0 blue:145.0/255.0 alpha:1.0];
        lbl.text = self.comments.count > 0 ? [NSString stringWithFormat:@"Комментарии (%ld)", (long)self.comments.count] : @"Комментарии";
        [hView addSubview:lbl];
        
        UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectMake(0, 31.5, tableView.bounds.size.width, 0.5)];
        bottomSep.backgroundColor = [UIColor colorWithRed:215.0/255.0 green:218.0/255.0 blue:224.0/255.0 alpha:1.0];
        bottomSep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [hView addSubview:bottomSep];
        
        return hView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = tableView.bounds.size.width;
    if (width <= 0) width = [[UIScreen mainScreen] bounds].size.width;
    if (indexPath.section == 0) {
        return [VKFeedPostCell heightForPost:self.post width:width isRevealed:YES];
    } else {
        if (self.comments.count == 0) return 70.0;
        VKComment *c = self.comments[indexPath.row];
        return [VKCommentCell heightForComment:c width:width];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = tableView.bounds.size.width;
    if (width <= 0) width = [[UIScreen mainScreen] bounds].size.width;
    
    if (indexPath.section == 0) {
        static NSString *PostCellId = @"VKPostDetailPostCell";
        VKFeedPostCell *cell = [tableView dequeueReusableCellWithIdentifier:PostCellId];
        if (!cell) {
            cell = [[VKFeedPostCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:PostCellId];
        }
        [cell configureWithPost:self.post isRevealed:YES width:tableView.bounds.size.width];
        __weak typeof(self) weakSelf = self;
        cell.onOptionsTapped = ^(VKPost *p) {
            [weakSelf postOptionsAction];
        };
        cell.onLikeTapped = ^(VKPost *p) {
            [[VKFeedService sharedService] likePost:p completion:nil];
        };
        
        cell.onShowLikesTapped = ^(VKPost *p, NSInteger filter) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post"
                                                                                         ownerId:p.ownerID
                                                                                          itemId:p.vkID
                                                                                   initialFilter:filter];
            [weakSelf.navigationController pushViewController:likesVC animated:YES];
        };
        
        cell.onRepostTapped = ^(VKPost *p) {
            [[VKShareManager sharedManager] presentShareSheetForPost:p fromViewController:weakSelf completion:^{
                [weakSelf.tableView reloadData];
            }];
        };
        cell.onPhotosGalleryWithFullURLsTapped = ^(NSArray<NSString *> *photoURLs, NSArray<NSString *> *fullPhotoURLs, NSInteger initialIndex) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs fullPhotoURLs:fullPhotoURLs initialIndex:initialIndex];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onPhotosGalleryTapped = ^(NSArray<NSString *> *photoURLs, NSInteger initialIndex) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithPhotoURLs:photoURLs initialIndex:initialIndex];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onPhotoWithFullURLTapped = ^(NSString *photoURL, NSString *fullPhotoURL, UIImage *image) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL fullImageURL:fullPhotoURL initialImage:image];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onPhotoTapped = ^(NSString *photoURL, UIImage *image) {
            VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL initialImage:image];
            [weakSelf presentViewController:viewer animated:YES completion:nil];
        };
        
        cell.onVideoTapped = ^(VKAttachment *videoAttachment) {
            VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:videoAttachment];
            [weakSelf presentMoviePlayerViewControllerAnimated:player];
        };
        
        cell.onAudioTapped = ^(VKAttachment *audioAttachment) {
            [weakSelf.tableView reloadData];
        };
        
        cell.onPollVoted = ^(VKAttachment *pollAttachment, NSInteger optionId) {
            [weakSelf.tableView reloadData];
        };
        
        cell.onDocTapped = ^(VKAttachment *docAttachment) {
            if (docAttachment.docURL.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:docAttachment.docURL]];
            }
        };
        
        cell.onGifTapped = ^(VKAttachment *gifAttachment) {
            VKGifViewerViewController *gifVC = [[VKGifViewerViewController alloc] initWithAttachment:gifAttachment];
            [weakSelf presentViewController:gifVC animated:YES completion:nil];
        };
        
        cell.onLinkTapped = ^(NSString *url) {
            if (url.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
        };
        
        cell.onAuthorTapped = ^(VKUser *author) {
            if (author) {
                VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:author];
                [weakSelf.navigationController pushViewController:profVC animated:YES];
            }
        };
        
        cell.onToggleTextExpanded = ^(VKPost *p) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView beginUpdates];
                [weakSelf.tableView endUpdates];
            });
        };
        
        cell.onToggleRepostTextExpanded = ^(VKPost *p) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView beginUpdates];
                [weakSelf.tableView endUpdates];
            });
        };
        
        cell.onCopyrightTapped = ^(NSString *url) {
            if (url.length > 0) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
        };
        
        return cell;
    } else {
        if (self.comments.count == 0) {
            static NSString *EmptyCellId = @"VKCommentEmptyCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:EmptyCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:EmptyCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor clearColor];
                cell.textLabel.font = [UIFont systemFontOfSize:13.5];
                cell.textLabel.textColor = [UIColor colorWithRed:150.0/255.0 green:160.0/255.0 blue:170.0/255.0 alpha:1.0];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.textLabel.numberOfLines = 2;
            }
            cell.textLabel.text = self.isLoading ? @"Загрузка комментариев..." : @"Комментариев пока нет.\nОставьте первый комментарий!";
            return cell;
        }
        
        static NSString *CommentCellId = @"VKCommentCell";
        VKCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:CommentCellId];
        if (!cell) {
            cell = [[VKCommentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CommentCellId];
        }
        if (indexPath.row < (NSInteger)self.comments.count) {
            VKComment *comment = self.comments[indexPath.row];
            [cell configureWithComment:comment width:width];
            
            __weak typeof(self) weakSelf = self;
            
            cell.onAvatarTapped = ^{
                if (comment.author) {
                    VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:comment.author];
                    [weakSelf.navigationController pushViewController:profVC animated:YES];
                }
            };
            
            cell.onReplyTapped = ^{
                [weakSelf startReplyingToComment:comment];
            };
            
            cell.onReplyAuthorTapped = ^(VKUser *authorUser) {
                if (authorUser) {
                    VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:authorUser];
                    [weakSelf.navigationController pushViewController:profVC animated:YES];
                }
            };
            
            cell.onLikeTapped = ^{
                BOOL newLiked = !comment.isLiked;
                comment.isLiked = newLiked;
                comment.likesCount += newLiked ? 1 : -1;
                if (comment.likesCount < 0) comment.likesCount = 0;
                [weakSelf.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                
                [[VKCommentsService sharedService] likeCommentId:comment.commentId ownerId:weakSelf.post.ownerID isLike:newLiked completion:^(BOOL success) {
                    // Лайк обновлен
                }];
            };
            
            cell.onMoreTapped = ^{
                [weakSelf showCommentActionSheetForComment:comment];
            };
            
            cell.onShowCommentLikesTapped = ^(VKComment *comm) {
                VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"comment"
                                                                                             ownerId:comm.ownerId ?: weakSelf.post.ownerID
                                                                                              itemId:comm.commentId
                                                                                       initialFilter:0];
                [weakSelf.navigationController pushViewController:likesVC animated:YES];
            };
            
            cell.onPhotoWithFullURLTapped = ^(NSString *photoURL, NSString *fullPhotoURL, UIImage *image) {
                if (photoURL.length > 0) {
                    VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL fullImageURL:fullPhotoURL initialImage:image];
                    [weakSelf presentViewController:viewer animated:YES completion:nil];
                }
            };
            
            cell.onPhotoTapped = ^(NSString *photoURL, UIImage *image) {
                if (photoURL.length > 0) {
                    VKPhotoViewerViewController *viewer = [[VKPhotoViewerViewController alloc] initWithImageURL:photoURL initialImage:image];
                    [weakSelf presentViewController:viewer animated:YES completion:nil];
                }
            };
            
            cell.onAudioTapped = ^(VKAttachment *audio) {
                if (audio.audioURL.length > 0) {
                    VKAudioTrack *track = [[VKAudioTrack alloc] init];
                    track.title = audio.audioTitle ?: @"Аудиозапись";
                    track.artist = audio.audioArtist ?: @"";
                    track.url = audio.audioURL;
                    [[VKAudioPlayer sharedPlayer] playTrack:track];
                }
            };
            
            cell.onVideoTapped = ^(VKAttachment *video) {
                VKVideoPlayerViewController *player = [[VKVideoPlayerViewController alloc] initWithAttachment:video];
                [weakSelf presentViewController:player animated:YES completion:nil];
            };
            
            cell.onDocTapped = ^(VKAttachment *doc) {
                if (doc.docURL.length > 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:doc.docURL]];
                }
            };
            
            cell.onLinkTapped = ^(NSString *linkUrl) {
                if (linkUrl.length > 0) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkUrl]];
                }
            };
        }
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1 && indexPath.row < (NSInteger)self.comments.count) {
        VKComment *c = self.comments[indexPath.row];
        [self showCommentActionSheetForComment:c];
    }
}

#pragma mark - Comment Actions & Management

- (void)showCommentActionSheetForComment:(VKComment *)comment {
    self.selectedCommentForAction = comment;
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    BOOL isMyComment = (comment.fromId == myId || (comment.author && comment.author.uid == myId));
    
    UIActionSheet *sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    sheet.tag = isMyComment ? 2001 : 2002;
    
    if (isMyComment) {
        sheet.destructiveButtonIndex = [sheet addButtonWithTitle:@"Удалить"];
        [sheet addButtonWithTitle:@"Ответить"];
        [sheet addButtonWithTitle:@"Редактировать"];
        [sheet addButtonWithTitle:@"Скопировать"];
    } else {
        [sheet addButtonWithTitle:@"Ответить"];
        [sheet addButtonWithTitle:@"Скопировать"];
        [sheet addButtonWithTitle:@"Пожаловаться"];
    }
    if (comment.likesCount > 0) {
        [sheet addButtonWithTitle:@"Кто оценил"];
    }
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Отмена"];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 2001) {
        // Меню своего комментария: 0: Удалить, 1: Ответить, 2: Редактировать, 3: Скопировать
        NSString *btnTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([btnTitle isEqualToString:@"Кто оценил"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"comment"
                                                                                         ownerId:self.selectedCommentForAction.ownerId ?: self.post.ownerID
                                                                                          itemId:self.selectedCommentForAction.commentId
                                                                                   initialFilter:0];
            [self.navigationController pushViewController:likesVC animated:YES];
            return;
        }
        if (buttonIndex == 0) {
            [self deleteSelectedComment];
        } else if (buttonIndex == 1) {
            [self replyToSelectedComment];
        } else if (buttonIndex == 2) {
            [self editSelectedComment];
        } else if (buttonIndex == 3) {
            [self copySelectedComment];
        }
    } else if (actionSheet.tag == 2002) {
        // Меню чужого комментария: 0: Ответить, 1: Скопировать, 2: Пожаловаться
        NSString *btnTitle = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([btnTitle isEqualToString:@"Кто оценил"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"comment"
                                                                                         ownerId:self.selectedCommentForAction.ownerId ?: self.post.ownerID
                                                                                          itemId:self.selectedCommentForAction.commentId
                                                                                   initialFilter:0];
            [self.navigationController pushViewController:likesVC animated:YES];
            return;
        }
        if (buttonIndex == 0) {
            [self replyToSelectedComment];
        } else if (buttonIndex == 1) {
            [self copySelectedComment];
        }
    } else if (actionSheet.tag == 1001 || actionSheet.tag == 1003) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        
        if ([title isEqualToString:@"Удалить запись"]) {
            [[VKProfileService sharedService] deletePost:self.post.vkID ownerId:self.post.ownerID completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        [self.navigationController popViewControllerAnimated:YES];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Архивировать запись"]) {
            [[VKProfileService sharedService] archivePost:self.post.vkID ownerId:self.post.ownerID completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        self.post.isArchived = YES;
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"В архиве" message:@"Запись сохранена в архив." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Восстановить на стену"]) {
            [[VKProfileService sharedService] restorePost:self.post.vkID ownerId:self.post.ownerID completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        self.post.isArchived = NO;
                        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Восстановлено" message:@"Запись восстановлена на стену." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                        [alert show];
                    }
                });
            }];
        } else if ([title isEqualToString:@"Поделиться"]) {
            [[VKShareManager sharedManager] presentShareSheetForPost:self.post fromViewController:self completion:nil];
        } else if ([title isEqualToString:@"Скопировать ссылку"]) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"https://openvk.su/wall%ld_%ld", (long)self.post.ownerID, (long)self.post.vkID];
        } else if ([title isEqualToString:@"Кто оценил"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post"
                                                                                         ownerId:self.post.ownerID
                                                                                          itemId:self.post.vkID
                                                                                   initialFilter:0];
            [self.navigationController pushViewController:likesVC animated:YES];
        } else if ([title isEqualToString:@"Кто поделился"]) {
            VKLikesListViewController *likesVC = [[VKLikesListViewController alloc] initWithType:@"post"
                                                                                         ownerId:self.post.ownerID
                                                                                          itemId:self.post.vkID
                                                                                   initialFilter:1];
            [self.navigationController pushViewController:likesVC animated:YES];
        }
    } else if (actionSheet.tag == 1002) {
        if (buttonIndex == actionSheet.cancelButtonIndex) return;
        NSString *title = [actionSheet buttonTitleAtIndex:buttonIndex];
        if ([title isEqualToString:@"Сделать снимок"]) {
            [self openImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
        } else if ([title isEqualToString:@"Выбрать из медиатеки"]) {
            [self openImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        }
    }
}

- (void)replyToSelectedComment {
    if (!self.selectedCommentForAction) return;
    [self startReplyingToComment:self.selectedCommentForAction];
}

- (void)copySelectedComment {
    if (!self.selectedCommentForAction) return;
    [UIPasteboard generalPasteboard].string = self.selectedCommentForAction.text ?: @"";
}

- (void)editSelectedComment {
    if (!self.selectedCommentForAction) return;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Редактирование"
                                                    message:nil
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сохранить", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.text = self.selectedCommentForAction.text ?: @"";
    alert.tag = 3001;
    [alert show];
}

- (void)deleteSelectedComment {
    if (!self.selectedCommentForAction) return;
    VKComment *c = self.selectedCommentForAction;
    NSInteger idx = [self.comments indexOfObject:c];
    
    [[VKCommentsService sharedService] deleteCommentForOwnerId:self.post.ownerID commentId:c.commentId completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                if (idx != NSNotFound && idx < (NSInteger)self.comments.count) {
                    [self.comments removeObjectAtIndex:idx];
                    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:idx inSection:1]] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        });
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 3001 && buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *newText = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newText.length == 0 || !self.selectedCommentForAction) return;
        
        VKComment *c = self.selectedCommentForAction;
        [[VKCommentsService sharedService] editCommentForOwnerId:self.post.ownerID commentId:c.commentId message:newText completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    c.text = newText;
                    [self.tableView reloadData];
                }
            });
        }];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendComment];
    return YES;
}

@end
