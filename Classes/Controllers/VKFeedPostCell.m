#import "VKFeedPostCell.h"
#import "VKImageLoader.h"
#import "VKSupportersService.h"
#import "VKThemeManager.h"
#import "VKAudioPlayer.h"
#import "VKAPIClient.h"
#import <QuartzCore/QuartzCore.h>

@interface VKFeedPostCell ()
@property (nonatomic, strong) NSMutableArray<UIImageView *> *photoImageViewsPool;
@property (nonatomic, strong) NSArray<VKAttachment *> *currentPhotos;
@end

@implementation VKFeedPostCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        
        _photoImageViewsPool = [NSMutableArray array];
        
        _cardBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        _cardBackgroundView.backgroundColor = [UIColor whiteColor];
        _cardBackgroundView.clipsToBounds = YES;
        [self.contentView addSubview:_cardBackgroundView];
        
        UIView *bottomSep = [[UIView alloc] initWithFrame:CGRectZero];
        bottomSep.tag = 999;
        [self.contentView addSubview:bottomSep];
        
        // Header
        _avatarContainerView = [[UIView alloc] initWithFrame:CGRectMake(12, 12, 42, 42)];
        _avatarContainerView.userInteractionEnabled = YES;
        UITapGestureRecognizer *avContTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(authorTapped)];
        [_avatarContainerView addGestureRecognizer:avContTap];
        [_cardBackgroundView addSubview:_avatarContainerView];
        
        _avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 42, 42)];
        _avatarImageView.clipsToBounds = YES;
        _avatarImageView.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
        _avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
        _avatarImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *avatarTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(authorTapped)];
        [_avatarImageView addGestureRecognizer:avatarTap];
        [_avatarContainerView addSubview:_avatarImageView];
        
        _wallOwnerAvatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(24, 24, 18, 18)];
        _wallOwnerAvatarImageView.layer.cornerRadius = 9.0;
        _wallOwnerAvatarImageView.layer.borderWidth = 1.5;
        _wallOwnerAvatarImageView.layer.borderColor = [[UIColor whiteColor] CGColor];
        _wallOwnerAvatarImageView.clipsToBounds = YES;
        _wallOwnerAvatarImageView.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
        _wallOwnerAvatarImageView.hidden = YES;
        [_avatarContainerView addSubview:_wallOwnerAvatarImageView];
        
        _authorNameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _authorNameLabel.font = [UIFont boldSystemFontOfSize:15];
        _authorNameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
        _authorNameLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *nameTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(authorTapped)];
        [_authorNameLabel addGestureRecognizer:nameTap];
        [_cardBackgroundView addSubview:_authorNameLabel];
        
        _verifiedBadgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _verifiedBadgeLabel.text = @"✓";
        _verifiedBadgeLabel.font = [UIFont boldSystemFontOfSize:10];
        _verifiedBadgeLabel.textColor = [UIColor whiteColor];
        _verifiedBadgeLabel.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        _verifiedBadgeLabel.textAlignment = NSTextAlignmentCenter;
        _verifiedBadgeLabel.layer.cornerRadius = 7.0;
        _verifiedBadgeLabel.clipsToBounds = YES;
        _verifiedBadgeLabel.hidden = YES;
        [_cardBackgroundView addSubview:_verifiedBadgeLabel];
        
        _supporterBadgeImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _supporterBadgeImageView.contentMode = UIViewContentModeScaleAspectFit;
        _supporterBadgeImageView.hidden = YES;
        [_cardBackgroundView addSubview:_supporterBadgeImageView];
        
        _wallOwnerNoteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _wallOwnerNoteLabel.font = [UIFont systemFontOfSize:12];
        _wallOwnerNoteLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        _wallOwnerNoteLabel.hidden = YES;
        [_cardBackgroundView addSubview:_wallOwnerNoteLabel];
        
        _dateAndPlatformLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _dateAndPlatformLabel.font = [UIFont systemFontOfSize:12];
        _dateAndPlatformLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
        [_cardBackgroundView addSubview:_dateAndPlatformLabel];
        
        _moreButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_moreButton setTitle:@"•••" forState:UIControlStateNormal];
        [_moreButton setTitleColor:[UIColor colorWithWhite:0.65 alpha:1.0] forState:UIControlStateNormal];
        _moreButton.titleLabel.font = [UIFont systemFontOfSize:13];
        [_moreButton addTarget:self action:@selector(optionsTapped) forControlEvents:UIControlEventTouchUpInside];
        [_cardBackgroundView addSubview:_moreButton];
        
        // Content container
        _contentContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        [_cardBackgroundView addSubview:_contentContainerView];
        
        _postTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _postTextLabel.font = [UIFont systemFontOfSize:15];
        _postTextLabel.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0];
        _postTextLabel.numberOfLines = 0;
        _postTextLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *textTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleTextExpandedAction)];
        [_postTextLabel addGestureRecognizer:textTap];
        [_contentContainerView addSubview:_postTextLabel];
        
        _expandTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _expandTextButton.titleLabel.font = [UIFont boldSystemFontOfSize:13.5];
        [_expandTextButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _expandTextButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_expandTextButton addTarget:self action:@selector(toggleTextExpandedAction) forControlEvents:UIControlEventTouchUpInside];
        _expandTextButton.hidden = YES;
        [_contentContainerView addSubview:_expandTextButton];
        
        // Фото контейнер
        _photosContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        _photosContainerView.clipsToBounds = YES;
        [_contentContainerView addSubview:_photosContainerView];
        
        // Вложения (Аудио, Видео, Опросы, Документы)
        _attachmentsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        [_contentContainerView addSubview:_attachmentsContainerView];
        
        // Spoiler Overlay
        _spoilerOverlayView = [[UIView alloc] initWithFrame:CGRectZero];
        _spoilerOverlayView.backgroundColor = [UIColor blackColor];
        _spoilerOverlayView.layer.cornerRadius = 8.0;
        _spoilerOverlayView.clipsToBounds = YES;
        _spoilerOverlayView.userInteractionEnabled = YES;
        _spoilerOverlayView.hidden = YES;
        UITapGestureRecognizer *spoilerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(revealSpoilerTapped)];
        [_spoilerOverlayView addGestureRecognizer:spoilerTap];
        [_contentContainerView addSubview:_spoilerOverlayView];
        
        _spoilerEyeImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
        _spoilerEyeImageView.layer.cornerRadius = 24.0;
        _spoilerEyeImageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        _spoilerEyeImageView.clipsToBounds = YES;
        [_spoilerOverlayView addSubview:_spoilerEyeImageView];
        
        _spoilerTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _spoilerTitleLabel.text = @"Содержимое поста скрыто под спойлером";
        _spoilerTitleLabel.font = [UIFont boldSystemFontOfSize:14];
        _spoilerTitleLabel.textColor = [UIColor whiteColor];
        _spoilerTitleLabel.textAlignment = NSTextAlignmentCenter;
        _spoilerTitleLabel.numberOfLines = 2;
        [_spoilerOverlayView addSubview:_spoilerTitleLabel];
        
        _spoilerSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _spoilerSubtitleLabel.text = @"Нажмите, чтобы просмотреть";
        _spoilerSubtitleLabel.font = [UIFont systemFontOfSize:12];
        _spoilerSubtitleLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
        _spoilerSubtitleLabel.textAlignment = NSTextAlignmentCenter;
        [_spoilerOverlayView addSubview:_spoilerSubtitleLabel];
        
        // Repost block
        _repostContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        _repostContainerView.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:245.0/255.0 blue:247.0/255.0 alpha:1.0];
        _repostContainerView.layer.cornerRadius = 6.0;
        _repostContainerView.clipsToBounds = YES;
        _repostContainerView.hidden = YES;
        [_contentContainerView addSubview:_repostContainerView];
        
        _repostLeftBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 3, 40)];
        _repostLeftBarView.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:0.7];
        [_repostContainerView addSubview:_repostLeftBarView];
        
        _repostAvatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 8, 28, 28)];
        _repostAvatarImageView.layer.cornerRadius = 14.0;
        _repostAvatarImageView.clipsToBounds = YES;
        _repostAvatarImageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        _repostAvatarImageView.userInteractionEnabled = YES;
        UITapGestureRecognizer *repAvTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(repostAuthorTapped)];
        [_repostAvatarImageView addGestureRecognizer:repAvTap];
        [_repostContainerView addSubview:_repostAvatarImageView];
        
        _repostAuthorLabel = [[UILabel alloc] initWithFrame:CGRectMake(46, 8, 200, 16)];
        _repostAuthorLabel.font = [UIFont boldSystemFontOfSize:13];
        _repostAuthorLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        _repostAuthorLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *repAuthTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(repostAuthorTapped)];
        [_repostAuthorLabel addGestureRecognizer:repAuthTap];
        [_repostContainerView addSubview:_repostAuthorLabel];
        
        _repostTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _repostTextLabel.font = [UIFont systemFontOfSize:13];
        _repostTextLabel.textColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        _repostTextLabel.numberOfLines = 0;
        _repostTextLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *repTextTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleRepostTextExpandedAction)];
        [_repostTextLabel addGestureRecognizer:repTextTap];
        [_repostContainerView addSubview:_repostTextLabel];
        
        _expandRepostTextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _expandRepostTextButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.5];
        [_expandRepostTextButton setTitleColor:[UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        _expandRepostTextButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [_expandRepostTextButton addTarget:self action:@selector(toggleRepostTextExpandedAction) forControlEvents:UIControlEventTouchUpInside];
        _expandRepostTextButton.hidden = YES;
        [_repostContainerView addSubview:_expandRepostTextButton];
        
        // Actions
        _actionsContainerView = [[UIView alloc] initWithFrame:CGRectZero];
        [_cardBackgroundView addSubview:_actionsContainerView];
        
        _likeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_likeButton addTarget:self action:@selector(likeTapped) forControlEvents:UIControlEventTouchUpInside];
        [_actionsContainerView addSubview:_likeButton];
        
        _commentsButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_commentsButton addTarget:self action:@selector(commentTapped) forControlEvents:UIControlEventTouchUpInside];
        [_actionsContainerView addSubview:_commentsButton];
        
        _repostButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_repostButton addTarget:self action:@selector(repostTapped) forControlEvents:UIControlEventTouchUpInside];
        [_actionsContainerView addSubview:_repostButton];
    }
    return self;
}

- (void)authorTapped {
    if (self.onAuthorTapped && self.currentPost.author) {
        self.onAuthorTapped(self.currentPost.author);
    }
}

- (void)optionsTapped {
    if (self.onOptionsTapped && self.currentPost) {
        self.onOptionsTapped(self.currentPost);
    }
}

- (void)revealSpoilerTapped {
    self.isExplicitRevealed = YES;
    if (self.onRevealSpoilerTapped && self.currentPost) {
        self.onRevealSpoilerTapped(self.currentPost);
    }
}

- (void)updateLikeButtonUI {
    if (!self.currentPost) return;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    UIColor *defIconColor = isSkeuomorph ? [UIColor colorWithRed:100.0/255.0 green:110.0/255.0 blue:125.0/255.0 alpha:1.0] : [UIColor colorWithRed:130.0/255.0 green:140.0/255.0 blue:155.0/255.0 alpha:1.0];
    UIColor *likeIconColor = self.currentPost.isLiked ? (isSkeuomorph ? [UIColor colorWithRed:215.0/255.0 green:35.0/255.0 blue:55.0/255.0 alpha:1.0] : [UIColor colorWithRed:235.0/255.0 green:45.0/255.0 blue:70.0/255.0 alpha:1.0]) : defIconColor;
    
    NSString *likeText = [NSString stringWithFormat:@"%ld", (long)self.currentPost.likesCount];
    [self.likeButton setImage:[[VKThemeManager sharedManager] reactionHeartIconWithColor:likeIconColor filled:self.currentPost.isLiked] forState:UIControlStateNormal];
    [self.likeButton setTitle:likeText forState:UIControlStateNormal];
    [self.likeButton setTitleColor:likeIconColor forState:UIControlStateNormal];
}

- (void)likeTapped {
    if (self.currentPost) {
        // Оптимистичное мгновенное переключение без перезагрузки всей таблицы
        self.currentPost.isLiked = !self.currentPost.isLiked;
        if (self.currentPost.isLiked) {
            self.currentPost.likesCount += 1;
        } else {
            self.currentPost.likesCount = MAX(0, self.currentPost.likesCount - 1);
        }
        [self updateLikeButtonUI];
    }
    
    if (self.likeButton) {
        [UIView animateWithDuration:0.1 animations:^{
            self.likeButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.12 animations:^{
                self.likeButton.transform = CGAffineTransformIdentity;
            }];
        }];
    }
    
    if (self.onLikeTapped && self.currentPost) {
        self.onLikeTapped(self.currentPost);
    }
}

- (void)commentTapped {
    if (self.onCommentTapped && self.currentPost) {
        self.onCommentTapped(self.currentPost);
    }
}

- (void)repostTapped {
    if (self.onRepostTapped && self.currentPost) {
        self.onRepostTapped(self.currentPost);
    }
}

- (void)photoCellTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag;
    if (self.onPhotosGalleryTapped && self.currentPhotos.count > 0) {
        NSMutableArray<NSString *> *urls = [NSMutableArray array];
        for (VKAttachment *att in self.currentPhotos) {
            if (att.photoURL.length > 0) [urls addObject:att.photoURL];
        }
        self.onPhotosGalleryTapped(urls, index);
    } else if (self.onPhotoTapped && index < (NSInteger)self.currentPhotos.count) {
        VKAttachment *att = self.currentPhotos[index];
        UIImageView *iv = (UIImageView *)gesture.view;
        self.onPhotoTapped(att.photoURL, iv.image);
    }
}

- (void)repostPhotoCellTapped:(UITapGestureRecognizer *)gesture {
    if (self.currentPost.repostHistory.count == 0) return;
    VKPost *rep = self.currentPost.repostHistory[0];
    NSMutableArray<NSString *> *urls = [NSMutableArray array];
    for (VKAttachment *att in rep.attachments) {
        if (att.type == VKAttachmentTypePhoto && att.photoURL.length > 0) [urls addObject:att.photoURL];
    }
    NSInteger index = gesture.view.tag;
    if (self.onPhotosGalleryTapped && urls.count > 0) {
        self.onPhotosGalleryTapped(urls, index);
    } else if (self.onPhotoTapped && index < (NSInteger)urls.count) {
        UIImageView *iv = (UIImageView *)gesture.view;
        self.onPhotoTapped(urls[index], iv.image);
    }
}

- (void)audioAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 6000;
    NSMutableArray *audios = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypeAudio) [audios addObject:att];
    }
    if (index >= 0 && index < (NSInteger)audios.count) {
        VKAttachment *att = audios[index];
        VKAudioTrack *t = [[VKAudioTrack alloc] init];
        t.trackId = att.audioId;
        t.ownerId = att.audioOwnerId;
        t.title = att.audioTitle ?: @"Аудиозапись";
        t.artist = att.audioArtist ?: @"Исполнитель";
        t.streamURL = att.audioURL;
        t.duration = att.audioDuration ?: @"3:00";
        
        if ([[VKAudioPlayer sharedPlayer] isPlaying] && [[[VKAudioPlayer sharedPlayer] currentTrack].title isEqualToString:t.title]) {
            [[VKAudioPlayer sharedPlayer] togglePlayPause];
        } else {
            [[VKAudioPlayer sharedPlayer] playTrack:t];
        }
        
        [self configureWithPost:self.currentPost isRevealed:self.isExplicitRevealed];
        
        if (self.onAudioTapped) {
            self.onAudioTapped(att);
        }
    }
}

- (void)pollOptionTapped:(UITapGestureRecognizer *)gesture {
    NSInteger rawTag = gesture.view.tag - 7000;
    NSInteger pollIdx = rawTag / 100;
    NSInteger optIdx = rawTag % 100;
    
    NSMutableArray *polls = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypePoll) [polls addObject:att];
    }
    if (pollIdx >= 0 && pollIdx < (NSInteger)polls.count) {
        VKAttachment *pollAtt = polls[pollIdx];
        if (optIdx >= 0 && optIdx < (NSInteger)pollAtt.pollOptions.count) {
            VKPollOption *opt = pollAtt.pollOptions[optIdx];
            
            // Оптимистичный отклик
            opt.votes += 1;
            pollAtt.pollTotalVotes += 1;
            [self configureWithPost:self.currentPost isRevealed:self.isExplicitRevealed];
            
            // Отправка голоса через API
            NSDictionary *params = @{
                @"poll_id": @(pollAtt.pollId),
                @"owner_id": @(pollAtt.pollOwnerId),
                @"answer_ids": [NSString stringWithFormat:@"%ld", (long)opt.optionId]
            };
            [[VKAPIClient sharedClient] callMethod:@"polls.addVote" parameters:params completionHandler:^(id response, NSError *error) {
                // Голос учтен на сервере OpenVK
            }];
            
            if (self.onPollVoted) {
                self.onPollVoted(pollAtt, opt.optionId);
            }
        }
    }
}

- (void)videoAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 5000;
    NSMutableArray *videos = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypeVideo) [videos addObject:att];
    }
    if (index >= 0 && index < (NSInteger)videos.count) {
        VKAttachment *videoAtt = videos[index];
        if (self.onVideoTapped) {
            self.onVideoTapped(videoAtt);
        }
    }
}

- (void)docAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 8000;
    NSMutableArray *docs = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypeDoc) [docs addObject:att];
    }
    if (index >= 0 && index < (NSInteger)docs.count) {
        VKAttachment *att = docs[index];
        if (self.onDocTapped) {
            self.onDocTapped(att);
        } else if (att.docURL.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:att.docURL]];
        }
    }
}

- (void)gifAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 8500;
    NSMutableArray *gifs = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypeGif) [gifs addObject:att];
    }
    if (index >= 0 && index < (NSInteger)gifs.count) {
        VKAttachment *att = gifs[index];
        if (self.onPhotoTapped) {
            self.onPhotoTapped(att.gifPreviewURL ?: att.docURL, nil);
        }
    }
}

- (void)linkAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger index = gesture.view.tag - 9000;
    NSMutableArray *links = [NSMutableArray array];
    for (VKAttachment *att in self.currentPost.attachments) {
        if (att.type == VKAttachmentTypeLink) [links addObject:att];
    }
    if (index >= 0 && index < (NSInteger)links.count) {
        VKAttachment *att = links[index];
        if (self.onLinkTapped) {
            self.onLinkTapped(att.linkURL);
        } else if (att.linkURL.length > 0) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:att.linkURL]];
        }
    }
}

- (void)copyrightTapped {
    if (self.currentPost.copyrightLink.length > 0) {
        if (self.onCopyrightTapped) {
            self.onCopyrightTapped(self.currentPost.copyrightLink);
        } else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.currentPost.copyrightLink]];
        }
    }
}

- (void)repostAuthorTapped {
    if (self.currentPost.repostHistory.count > 0) {
        VKPost *rep = self.currentPost.repostHistory[0];
        if (rep.author && self.onAuthorTapped) {
            self.onAuthorTapped(rep.author);
        }
    }
}

- (void)signerTapped {
    if (self.currentPost.signerUser && self.onAuthorTapped) {
        self.onAuthorTapped(self.currentPost.signerUser);
    }
}

#pragma mark - Height Calculation

+ (CGFloat)heightForPost:(VKPost *)post width:(CGFloat)width isRevealed:(BOOL)isRevealed {
    if (!post) return 0;
    
    CGFloat margin = [[VKThemeManager sharedManager] cardHorizontalMargin];
    CGFloat cardWidth = (margin > 0) ? (width - margin * 2.0) : width;
    CGFloat contentWidth = cardWidth - 24.0;
    
    CGFloat h = 60.0; // Header (Avatar 40pt at y=10 + bottom margin 10pt)
    
    if (post.isExplicit && !isRevealed) {
        return h + 180.0 + 34.0 + 8.0;
    }
    
    // Текст
    if (post.text.length > 0) {
        CGSize textSize = [post.text sizeWithFont:[UIFont systemFontOfSize:15]
                               constrainedToSize:CGSizeMake(contentWidth, CGFLOAT_MAX)
                                   lineBreakMode:NSLineBreakByWordWrapping];
        CGFloat fullH = ceilf(textSize.height);
        BOOL isLongText = post.text.length > 250 || [post.text componentsSeparatedByString:@"\n"].count > 5;
        if (isLongText) {
            CGFloat collapsedH = MIN(fullH, [UIFont systemFontOfSize:15].lineHeight * 6.0);
            CGFloat textH = post.isTextExpanded ? fullH : collapsedH;
            h += textH + 24.0 + 10.0;
        } else {
            h += fullH + 10.0;
        }
    }
    
    // Фотографии (сетка)
    NSMutableArray *photos = [NSMutableArray array];
    for (VKAttachment *att in post.attachments) {
        if (att.type == VKAttachmentTypePhoto && att.photoURL.length > 0) [photos addObject:att];
    }
    if (photos.count == 1) {
        VKAttachment *a = photos[0];
        CGFloat photoH = 240.0;
        if (a.photoWidth > 0 && a.photoHeight > 0) {
            photoH = MAX(160.0, MIN(320.0, floorf(contentWidth * (a.photoHeight / a.photoWidth))));
        }
        h += photoH + 10.0;
    } else if (photos.count == 2) {
        h += 170.0 + 10.0;
    } else if (photos.count == 3) {
        h += 180.0 + 10.0;
    } else if (photos.count == 4) {
        h += 256.0 + 10.0;
    } else if (photos.count >= 5) {
        h += 230.0 + 10.0;
    }
    
    // Прочие вложения (Аудио, Видео, Опросы, Документы, GIF, Ссылки)
    for (VKAttachment *att in post.attachments) {
        if (att.type == VKAttachmentTypeAudio) {
            h += 44.0;
        } else if (att.type == VKAttachmentTypeVideo) {
            h += 166.0;
        } else if (att.type == VKAttachmentTypePoll) {
            h += 30.0 + (att.pollOptions.count * 30.0) + 24.0;
        } else if (att.type == VKAttachmentTypeDoc) {
            h += 44.0;
        } else if (att.type == VKAttachmentTypeGif) {
            h += 188.0;
        } else if (att.type == VKAttachmentTypeLink) {
            h += (att.linkImageURL.length > 0) ? 188.0 : 62.0;
        }
    }
    
    // Репост
    if (post.repostHistory.count > 0) {
        VKPost *rep = post.repostHistory[0];
        CGFloat repContentW = contentWidth - 16.0;
        CGFloat repH = 38.0;
        if (rep.text.length > 0) {
            CGSize repTextSize = [rep.text sizeWithFont:[UIFont systemFontOfSize:13]
                                      constrainedToSize:CGSizeMake(repContentW, CGFLOAT_MAX)
                                          lineBreakMode:NSLineBreakByWordWrapping];
            CGFloat fullRepH = ceilf(repTextSize.height);
            BOOL isLongRep = rep.text.length > 250 || [rep.text componentsSeparatedByString:@"\n"].count > 5;
            if (isLongRep) {
                CGFloat collapsedRepH = MIN(fullRepH, [UIFont systemFontOfSize:13].lineHeight * 6.0);
                CGFloat repTextH = rep.isRepostTextExpanded ? fullRepH : collapsedRepH;
                repH += repTextH + 22.0 + 8.0;
            } else {
                repH += fullRepH + 8.0;
            }
        }
        
        // Фотографии репоста
        NSMutableArray *repPhotos = [NSMutableArray array];
        for (VKAttachment *att in rep.attachments) {
            if (att.type == VKAttachmentTypePhoto && att.photoURL.length > 0) [repPhotos addObject:att];
        }
        if (repPhotos.count == 1) {
            VKAttachment *a = repPhotos[0];
            CGFloat photoH = 220.0;
            if (a.photoWidth > 0 && a.photoHeight > 0) {
                photoH = MAX(140.0, MIN(280.0, floorf(repContentW * (a.photoHeight / a.photoWidth))));
            }
            repH += photoH + 8.0;
        } else if (repPhotos.count == 2) {
            repH += 150.0 + 8.0;
        } else if (repPhotos.count == 3) {
            repH += 160.0 + 8.0;
        } else if (repPhotos.count >= 4) {
            repH += 220.0 + 8.0;
        }
        
        // Прочие вложения репоста
        for (VKAttachment *att in rep.attachments) {
            if (att.type == VKAttachmentTypeAudio) {
                repH += 38.0;
            } else if (att.type == VKAttachmentTypeVideo) {
                repH += 140.0;
            } else if (att.type == VKAttachmentTypePoll) {
                repH += 30.0 + (att.pollOptions.count * 30.0) + 20.0;
            } else if (att.type == VKAttachmentTypeDoc) {
                repH += 38.0;
            } else if (att.type == VKAttachmentTypeGif) {
                repH += 160.0;
            } else if (att.type == VKAttachmentTypeLink) {
                repH += (att.linkImageURL.length > 0) ? 180.0 : 54.0;
            }
        }
        h += repH + 10.0;
    }
    
    // Источник и подпись
    if (post.copyrightName.length > 0) {
        h += 22.0;
    }
    if (post.signerUser != nil) {
        h += 22.0;
    }
    
    h += 38.0; // Кнопки действий (лайк, комменты, репост)
    h += 8.0;  // Нижний отступ разделителя
    return h;
}

#pragma mark - Configure

- (void)configureWithPost:(VKPost *)post isRevealed:(BOOL)isRevealed {
    if (!post) return;
    self.currentPost = post;
    self.isExplicitRevealed = isRevealed;
    
    CGFloat width = [[UIScreen mainScreen] bounds].size.width;
    if (width <= 0) width = 320.0;
    
    BOOL isSkeuomorph = [[VKThemeManager sharedManager] isSkeuomorphic];
    BOOL isFlat = [[VKThemeManager sharedManager] isClassicFlat];
    
    self.avatarImageView.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:40.0];
    self.avatarImageView.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    self.avatarImageView.layer.borderColor = [[VKThemeManager sharedManager] avatarBorderColor].CGColor;
    
    self.authorNameLabel.text = post.author.displayName ?: @"Пользователь";
    self.authorNameLabel.font = [[VKThemeManager sharedManager] titleFontOfSize:15];
    
    if (isSkeuomorph) {
        self.authorNameLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0]; // #2B587A
    } else if (isFlat) {
        self.authorNameLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0]; // #4A76A8
    } else {
        self.authorNameLabel.textColor = [UIColor colorWithRed:20.0/255.0 green:20.0/255.0 blue:20.0/255.0 alpha:1.0];
    }
    
    self.avatarImageView.image = nil;
    if (post.author.avatarURL) {
        [[VKImageLoader sharedLoader] loadImageWithURL:post.author.avatarURL completion:^(UIImage *img) {
            if (img) self.avatarImageView.image = img;
        }];
    }
    
    // Владелец стены
    if (post.wallOwner && post.wallOwner.uid != post.author.uid) {
        self.wallOwnerAvatarImageView.hidden = NO;
        self.wallOwnerAvatarImageView.image = nil;
        if (post.wallOwner.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:post.wallOwner.avatarURL completion:^(UIImage *img) {
                if (img) self.wallOwnerAvatarImageView.image = img;
            }];
        }
        self.wallOwnerNoteLabel.hidden = NO;
        self.wallOwnerNoteLabel.text = [NSString stringWithFormat:@"на стене %@", post.wallOwner.displayName ?: @""];
    } else {
        self.wallOwnerAvatarImageView.hidden = YES;
        self.wallOwnerNoteLabel.hidden = YES;
    }
    
    // Дата и платформа
    NSString *platformName = @"";
    if (post.platform.length > 0) {
        if ([post.platform isEqualToString:@"iphone"] || [post.platform isEqualToString:@"ipad"]) platformName = @"";
        else if ([post.platform isEqualToString:@"android"]) platformName = @"Android";
        else if ([post.platform isEqualToString:@"wphone"]) platformName = @"WP";
    }
    self.dateAndPlatformLabel.text = platformName.length > 0 ? [NSString stringWithFormat:@"%@ • %@", post.timeAgo, platformName] : post.timeAgo;
    
    // Позиционирование карточки
    CGFloat margin = [[VKThemeManager sharedManager] cardHorizontalMargin];
    CGFloat cornerRadius = [[VKThemeManager sharedManager] cardCornerRadius];
    CGFloat cardWidth = (margin > 0) ? (width - margin * 2.0) : width;
    
    self.cardBackgroundView.layer.cornerRadius = cornerRadius;
    self.cardBackgroundView.backgroundColor = [[VKThemeManager sharedManager] cardBackgroundColor];
    
    if (isSkeuomorph || isFlat) {
        self.cardBackgroundView.layer.borderWidth = 0.5;
        self.cardBackgroundView.layer.borderColor = [[VKThemeManager sharedManager] cardBorderColor].CGColor;
    } else {
        self.cardBackgroundView.layer.borderWidth = 0.0;
    }
    
    CGFloat totalHeight = [VKFeedPostCell heightForPost:post width:width isRevealed:isRevealed];
    CGFloat bottomSpacing = 8.0;
    self.cardBackgroundView.frame = CGRectMake(margin, (margin > 0 ? 4.0 : 0.0), cardWidth, totalHeight - bottomSpacing);
    
    UIView *bottomSep = [self.contentView viewWithTag:999];
    if (isSkeuomorph || isFlat) {
        bottomSep.hidden = NO;
        bottomSep.frame = CGRectMake(0, totalHeight - bottomSpacing, width, bottomSpacing);
        bottomSep.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:226.0/255.0 green:229.0/255.0 blue:235.0/255.0 alpha:1.0] : [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
    } else {
        bottomSep.hidden = YES;
    }
    
    CGFloat headerLeft = 60.0;
    CGFloat headerRight = cardWidth - 36.0;
    self.avatarContainerView.frame = CGRectMake(12.0, 10.0, 40.0, 40.0);
    self.avatarImageView.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    self.wallOwnerAvatarImageView.frame = CGRectMake(24.0, 24.0, 18.0, 18.0);
    
    self.authorNameLabel.frame = CGRectMake(headerLeft, 10.0, headerRight - headerLeft, 19.0);
    self.dateAndPlatformLabel.frame = CGRectMake(headerLeft, 31.0, headerRight - headerLeft, 15.0);
    self.moreButton.frame = CGRectMake(cardWidth - 36.0, 8.0, 28.0, 28.0);
    
    // Контент
    CGFloat contentX = 12.0;
    CGFloat contentW = cardWidth - 24.0;
    CGFloat currentY = 60.0;
    self.contentContainerView.frame = CGRectMake(contentX, 0, contentW, totalHeight);
    
    // Текст поста
    if (post.text.length > 0) {
        self.postTextLabel.hidden = NO;
        self.postTextLabel.text = post.text;
        CGSize textSize = [post.text sizeWithFont:[UIFont systemFontOfSize:15]
                               constrainedToSize:CGSizeMake(contentW, CGFLOAT_MAX)
                                   lineBreakMode:NSLineBreakByWordWrapping];
        CGFloat fullH = ceilf(textSize.height);
        BOOL isLongText = post.text.length > 250 || [post.text componentsSeparatedByString:@"\n"].count > 5;
        
        if (isLongText) {
            self.expandTextButton.hidden = NO;
            [self.expandTextButton setTitle:(post.isTextExpanded ? @"Свернуть" : @"Показать полностью...") forState:UIControlStateNormal];
            
            CGFloat collapsedH = MIN(fullH, [UIFont systemFontOfSize:15].lineHeight * 6.0);
            CGFloat textH = post.isTextExpanded ? fullH : collapsedH;
            self.postTextLabel.numberOfLines = post.isTextExpanded ? 0 : 6;
            self.postTextLabel.frame = CGRectMake(0, currentY, contentW, textH);
            currentY += textH;
            
            self.expandTextButton.frame = CGRectMake(0, currentY, 200, 24);
            currentY += 24.0 + 10.0;
        } else {
            self.expandTextButton.hidden = YES;
            self.postTextLabel.numberOfLines = 0;
            self.postTextLabel.frame = CGRectMake(0, currentY, contentW, fullH);
            currentY += fullH + 10.0;
        }
    } else {
        self.postTextLabel.hidden = YES;
        self.expandTextButton.hidden = YES;
    }
    
    // Сетка фотографий (до 10 фото!)
    NSMutableArray *photos = [NSMutableArray array];
    for (VKAttachment *att in post.attachments) {
        if (att.type == VKAttachmentTypePhoto && att.photoURL.length > 0) {
            [photos addObject:att];
        }
    }
    self.currentPhotos = [photos copy];
    
    for (UIView *v in self.photosContainerView.subviews) [v removeFromSuperview];
    
    if (photos.count > 0) {
        self.photosContainerView.hidden = NO;
        CGFloat photoCorner = isSkeuomorph ? 3.0 : (isFlat ? 2.0 : 6.0);
        
        if (photos.count == 1) {
            VKAttachment *a = photos[0];
            CGFloat photoH = 240.0;
            if (a.photoWidth > 0 && a.photoHeight > 0) {
                photoH = MAX(160.0, MIN(320.0, floorf(contentW * (a.photoHeight / a.photoWidth))));
            }
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentW, photoH)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
            iv.layer.cornerRadius = photoCorner;
            iv.tag = 0;
            iv.userInteractionEnabled = YES;
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)];
            [iv addGestureRecognizer:tap];
            
            [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) {
                if (img) iv.image = img;
            }];
            [self.photosContainerView addSubview:iv];
            self.photosContainerView.frame = CGRectMake(0, currentY, contentW, photoH);
            currentY += photoH + 10.0;
        } else if (photos.count == 2) {
            CGFloat halfW = (contentW - 4.0) / 2.0;
            CGFloat rowH = 170.0;
            for (NSInteger i = 0; i < 2; i++) {
                UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(i * (halfW + 4.0), 0, halfW, rowH)];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
                iv.layer.cornerRadius = photoCorner;
                iv.tag = i;
                iv.userInteractionEnabled = YES;
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)];
                [iv addGestureRecognizer:tap];
                
                VKAttachment *a = photos[i];
                [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
                [self.photosContainerView addSubview:iv];
            }
            self.photosContainerView.frame = CGRectMake(0, currentY, contentW, rowH);
            currentY += rowH + 10.0;
        } else if (photos.count == 3) {
            CGFloat leftW = floorf(contentW * 0.64);
            CGFloat rightW = contentW - leftW - 4.0;
            CGFloat totalH = 180.0;
            CGFloat rightH = (totalH - 4.0) / 2.0;
            
            UIImageView *iv1 = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, leftW, totalH)];
            iv1.contentMode = UIViewContentModeScaleAspectFill;
            iv1.clipsToBounds = YES;
            iv1.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
            iv1.layer.cornerRadius = photoCorner;
            iv1.tag = 0;
            iv1.userInteractionEnabled = YES;
            [iv1 addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)]];
            [[VKImageLoader sharedLoader] loadImageWithURL:((VKAttachment *)photos[0]).photoURL completion:^(UIImage *img) { if (img) iv1.image = img; }];
            [self.photosContainerView addSubview:iv1];
            
            for (NSInteger i = 1; i <= 2; i++) {
                UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(leftW + 4.0, (i - 1) * (rightH + 4.0), rightW, rightH)];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
                iv.layer.cornerRadius = photoCorner;
                iv.tag = i;
                iv.userInteractionEnabled = YES;
                [iv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)]];
                [[VKImageLoader sharedLoader] loadImageWithURL:((VKAttachment *)photos[i]).photoURL completion:^(UIImage *img) { if (img) iv.image = img; }];
                [self.photosContainerView addSubview:iv];
            }
            self.photosContainerView.frame = CGRectMake(0, currentY, contentW, totalH);
            currentY += totalH + 10.0;
        } else if (photos.count == 4) {
            CGFloat halfW = (contentW - 4.0) / 2.0;
            CGFloat rowH = 126.0;
            CGFloat totalH = rowH * 2.0 + 4.0;
            for (NSInteger i = 0; i < 4; i++) {
                CGFloat x = (i % 2) * (halfW + 4.0);
                CGFloat y = (i / 2) * (rowH + 4.0);
                UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, halfW, rowH)];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
                iv.layer.cornerRadius = photoCorner;
                iv.tag = i;
                iv.userInteractionEnabled = YES;
                [iv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)]];
                
                VKAttachment *a = photos[i];
                [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
                [self.photosContainerView addSubview:iv];
            }
            self.photosContainerView.frame = CGRectMake(0, currentY, contentW, totalH);
            currentY += totalH + 10.0;
        } else {
            // 5+ фото: 2 сверху, 3 снизу
            CGFloat row1W = (contentW - 4.0) / 2.0;
            CGFloat row1H = 130.0;
            CGFloat row2W = (contentW - 8.0) / 3.0;
            CGFloat row2H = 96.0;
            CGFloat totalH = row1H + 4.0 + row2H;
            
            for (NSInteger i = 0; i < MIN(5, (NSInteger)photos.count); i++) {
                CGRect photoFrame;
                if (i < 2) {
                    photoFrame = CGRectMake(i * (row1W + 4.0), 0, row1W, row1H);
                } else {
                    photoFrame = CGRectMake((i - 2) * (row2W + 4.0), row1H + 4.0, row2W, row2H);
                }
                
                UIImageView *iv = [[UIImageView alloc] initWithFrame:photoFrame];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
                iv.layer.cornerRadius = photoCorner;
                iv.tag = i;
                iv.userInteractionEnabled = YES;
                [iv addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(photoCellTapped:)]];
                
                VKAttachment *a = photos[i];
                [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) {
                    if (img) iv.image = img;
                }];
                [self.photosContainerView addSubview:iv];
                
                // Бейдж "+N", если фото больше 5
                if (i == 4 && photos.count > 5) {
                    UIView *overlay = [[UIView alloc] initWithFrame:iv.bounds];
                    overlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
                    UILabel *moreLbl = [[UILabel alloc] initWithFrame:overlay.bounds];
                    moreLbl.text = [NSString stringWithFormat:@"+%lu", (unsigned long)(photos.count - 4)];
                    moreLbl.textColor = [UIColor whiteColor];
                    moreLbl.font = [UIFont boldSystemFontOfSize:18];
                    moreLbl.textAlignment = NSTextAlignmentCenter;
                    [overlay addSubview:moreLbl];
                    [iv addSubview:overlay];
                }
            }
            self.photosContainerView.frame = CGRectMake(0, currentY, contentW, totalH);
            currentY += totalH + 10.0;
        }
    } else {
        self.photosContainerView.hidden = YES;
    }
    
    // Вложения (Аудио, Видео, Опросы, Документы)
    for (UIView *v in self.attachmentsContainerView.subviews) [v removeFromSuperview];
    CGFloat attY = 0;
    NSInteger videoIndex = 0;
    NSInteger audioIndex = 0;
    NSInteger pollIndex = 0;
    NSInteger docIndex = 0;
    NSInteger gifIndex = 0;
    NSInteger linkIndex = 0;
    for (VKAttachment *att in post.attachments) {
        if (att.type == VKAttachmentTypeAudio) {
            UIView *audioView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, 38)];
            audioView.backgroundColor = [UIColor clearColor];
            audioView.tag = 6000 + audioIndex;
            audioView.userInteractionEnabled = YES;
            UITapGestureRecognizer *aTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(audioAttachmentTapped:)];
            [audioView addGestureRecognizer:aTap];
            
            BOOL isPlayingThis = [[VKAudioPlayer sharedPlayer] isPlaying] && [[[VKAudioPlayer sharedPlayer] currentTrack].title isEqualToString:att.audioTitle];
            
            // Кнопка play / pause
            UILabel *playIcon = [[UILabel alloc] initWithFrame:CGRectMake(2, 6, 24, 24)];
            playIcon.text = isPlayingThis ? @"⏸" : @"▶";
            playIcon.font = [UIFont boldSystemFontOfSize:11];
            playIcon.textAlignment = NSTextAlignmentCenter;
            
            if (isSkeuomorph) {
                playIcon.backgroundColor = isPlayingThis ? [UIColor colorWithRed:45.0/255.0 green:140.0/255.0 blue:240.0/255.0 alpha:1.0] : [UIColor colorWithRed:74.0/255.0 green:109.0/255.0 blue:148.0/255.0 alpha:1.0];
                playIcon.textColor = [UIColor whiteColor];
                playIcon.layer.cornerRadius = 3.5;
                playIcon.layer.borderWidth = 0.5;
                playIcon.layer.borderColor = [UIColor colorWithRed:55.0/255.0 green:85.0/255.0 blue:120.0/255.0 alpha:1.0].CGColor;
            } else if (isFlat) {
                playIcon.backgroundColor = isPlayingThis ? [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] : [UIColor clearColor];
                playIcon.textColor = isPlayingThis ? [UIColor whiteColor] : [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
                playIcon.layer.cornerRadius = 12.0;
                playIcon.layer.borderWidth = 1.2;
                playIcon.layer.borderColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0].CGColor;
            } else {
                playIcon.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
                playIcon.textColor = [UIColor whiteColor];
                playIcon.layer.cornerRadius = 12.0;
            }
            playIcon.clipsToBounds = YES;
            [audioView addSubview:playIcon];
            
            // Название трека
            UILabel *trackLbl = [[UILabel alloc] initWithFrame:CGRectMake(34, 2, contentW - 86, 17)];
            trackLbl.text = att.audioTitle ?: @"Аудиозапись";
            trackLbl.font = [UIFont boldSystemFontOfSize:13];
            trackLbl.textColor = isPlayingThis ? [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0] : (isSkeuomorph ? [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0] : (isFlat ? [UIColor colorWithRed:44.0/255.0 green:62.0/255.0 blue:80.0/255.0 alpha:1.0] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0]));
            [audioView addSubview:trackLbl];
            
            // Исполнитель
            UILabel *artistLbl = [[UILabel alloc] initWithFrame:CGRectMake(34, 19, contentW - 86, 15)];
            artistLbl.text = att.audioArtist ?: @"Исполнитель";
            artistLbl.font = [UIFont systemFontOfSize:11.5];
            artistLbl.textColor = [UIColor colorWithWhite:0.45 alpha:1.0];
            [audioView addSubview:artistLbl];
            
            // Длительность
            UILabel *durLbl = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 48, 10, 48, 16)];
            durLbl.text = att.audioDuration ?: @"3:00";
            durLbl.font = [UIFont systemFontOfSize:11.5];
            durLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
            durLbl.textAlignment = NSTextAlignmentRight;
            [audioView addSubview:durLbl];
            
            // Разделитель снизу
            UIView *line = [[UIView alloc] initWithFrame:CGRectMake(34, 37.5, contentW - 34, 0.5)];
            line.backgroundColor = [UIColor colorWithRed:228.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
            [audioView addSubview:line];
            
            [self.attachmentsContainerView addSubview:audioView];
            attY += 40.0;
            audioIndex++;
        } else if (att.type == VKAttachmentTypeVideo) {
            UIView *vidView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, 158)];
            vidView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
            vidView.layer.cornerRadius = 6.0;
            vidView.clipsToBounds = YES;
            vidView.tag = 5000 + videoIndex;
            vidView.userInteractionEnabled = YES;
            UITapGestureRecognizer *vTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(videoAttachmentTapped:)];
            [vidView addGestureRecognizer:vTap];
            
            UIImageView *vidImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentW, 158)];
            vidImg.contentMode = UIViewContentModeScaleAspectFill;
            vidImg.clipsToBounds = YES;
            if (att.videoImageURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:att.videoImageURL completion:^(UIImage *img) {
                    if (img) vidImg.image = img;
                }];
            }
            [vidView addSubview:vidImg];
            
            UILabel *playBadge = [[UILabel alloc] initWithFrame:CGRectMake((contentW - 48)/2.0, 55, 48, 48)];
            playBadge.text = @"▶";
            playBadge.textColor = [UIColor whiteColor];
            playBadge.font = [UIFont boldSystemFontOfSize:22];
            playBadge.textAlignment = NSTextAlignmentCenter;
            playBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
            playBadge.layer.cornerRadius = 24.0;
            playBadge.clipsToBounds = YES;
            [vidView addSubview:playBadge];
            
            UIView *titleGrad = [[UIView alloc] initWithFrame:CGRectMake(0, 126, contentW, 32)];
            titleGrad.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            [vidView addSubview:titleGrad];
            
            UILabel *titleBadge = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, contentW - 16, 20)];
            titleBadge.text = att.videoTitle ?: @"Видеозапись";
            titleBadge.textColor = [UIColor whiteColor];
            titleBadge.font = [UIFont boldSystemFontOfSize:13];
            [titleGrad addSubview:titleBadge];
            
            [self.attachmentsContainerView addSubview:vidView];
            attY += 166.0;
            videoIndex++;
        } else if (att.type == VKAttachmentTypeDoc) {
            UIView *docView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, 36)];
            docView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0] : [UIColor colorWithRed:245.0/255.0 green:246.0/255.0 blue:248.0/255.0 alpha:1.0];
            docView.layer.cornerRadius = isSkeuomorph ? 3.5 : 4.0;
            if (isSkeuomorph) {
                docView.layer.borderWidth = 0.5;
                docView.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0].CGColor;
            }
            docView.tag = 8000 + docIndex;
            docView.userInteractionEnabled = YES;
            UITapGestureRecognizer *dTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(docAttachmentTapped:)];
            [docView addGestureRecognizer:dTap];
            
            NSString *ext = att.docExt ?: @"DOC";
            UIColor *badgeColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            if ([ext isEqualToString:@"PDF"]) {
                badgeColor = [UIColor colorWithRed:217.0/255.0 green:83.0/255.0 blue:79.0/255.0 alpha:1.0];
            } else if ([ext isEqualToString:@"ZIP"] || [ext isEqualToString:@"RAR"] || [ext isEqualToString:@"7Z"]) {
                badgeColor = [UIColor colorWithRed:240.0/255.0 green:173.0/255.0 blue:78.0/255.0 alpha:1.0];
            } else if ([ext isEqualToString:@"MP3"] || [ext isEqualToString:@"WAV"] || [ext isEqualToString:@"FLAC"]) {
                badgeColor = [UIColor colorWithRed:92.0/255.0 green:184.0/255.0 blue:92.0/255.0 alpha:1.0];
            }
            
            UILabel *docIcon = [[UILabel alloc] initWithFrame:CGRectMake(8, 6, 34, 24)];
            docIcon.text = (ext.length > 4) ? [ext substringToIndex:4] : ext;
            docIcon.font = [UIFont boldSystemFontOfSize:10.5];
            docIcon.textColor = badgeColor;
            docIcon.textAlignment = NSTextAlignmentCenter;
            docIcon.layer.borderWidth = 1.0;
            docIcon.layer.borderColor = badgeColor.CGColor;
            docIcon.layer.cornerRadius = 3.0;
            [docView addSubview:docIcon];
            
            UILabel *nameLbl = [[UILabel alloc] initWithFrame:CGRectMake(48, 8, contentW - 120, 20)];
            nameLbl.text = att.docTitle ?: @"Документ";
            nameLbl.font = [UIFont boldSystemFontOfSize:13];
            nameLbl.textColor = [UIColor colorWithRed:44.0/255.0 green:80.0/255.0 blue:120.0/255.0 alpha:1.0];
            [docView addSubview:nameLbl];
            
            UILabel *sizeLbl = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 68, 8, 60, 20)];
            sizeLbl.text = att.docSize ?: @"";
            sizeLbl.font = [UIFont systemFontOfSize:11];
            sizeLbl.textColor = [UIColor grayColor];
            sizeLbl.textAlignment = NSTextAlignmentRight;
            [docView addSubview:sizeLbl];
            
            [self.attachmentsContainerView addSubview:docView];
            attY += 44.0;
            docIndex++;
        } else if (att.type == VKAttachmentTypeGif) {
            CGFloat gifH = 180.0;
            UIView *gifView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, gifH)];
            gifView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
            gifView.layer.cornerRadius = 6.0;
            gifView.clipsToBounds = YES;
            gifView.tag = 8500 + gifIndex;
            gifView.userInteractionEnabled = YES;
            UITapGestureRecognizer *gTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(gifAttachmentTapped:)];
            [gifView addGestureRecognizer:gTap];
            
            UIImageView *gifImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentW, gifH)];
            gifImg.contentMode = UIViewContentModeScaleAspectFit;
            gifImg.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
            gifImg.clipsToBounds = YES;
            NSString *imgURL = att.gifPreviewURL.length > 0 ? att.gifPreviewURL : att.docURL;
            if (imgURL.length > 0) {
                [[VKImageLoader sharedLoader] loadImageWithURL:imgURL completion:^(UIImage *img) {
                    if (img) gifImg.image = img;
                }];
            }
            [gifView addSubview:gifImg];
            
            UILabel *gifBadge = [[UILabel alloc] initWithFrame:CGRectMake(8, gifH - 28, 36, 20)];
            gifBadge.text = @"GIF";
            gifBadge.textColor = [UIColor whiteColor];
            gifBadge.font = [UIFont boldSystemFontOfSize:11];
            gifBadge.textAlignment = NSTextAlignmentCenter;
            gifBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
            gifBadge.layer.cornerRadius = 3.0;
            gifBadge.clipsToBounds = YES;
            [gifView addSubview:gifBadge];
            
            [self.attachmentsContainerView addSubview:gifView];
            attY += gifH + 8.0;
            gifIndex++;
        } else if (att.type == VKAttachmentTypeLink) {
            BOOL hasImage = (att.linkImageURL.length > 0);
            CGFloat linkH = hasImage ? 180.0 : 54.0;
            UIView *linkView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, linkH)];
            linkView.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0] : [UIColor colorWithRed:247.0/255.0 green:248.0/255.0 blue:250.0/255.0 alpha:1.0];
            linkView.layer.cornerRadius = 5.0;
            linkView.layer.borderWidth = 0.5;
            linkView.layer.borderColor = [UIColor colorWithRed:215.0/255.0 green:220.0/255.0 blue:228.0/255.0 alpha:1.0].CGColor;
            linkView.clipsToBounds = YES;
            linkView.tag = 9000 + linkIndex;
            linkView.userInteractionEnabled = YES;
            UITapGestureRecognizer *lTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(linkAttachmentTapped:)];
            [linkView addGestureRecognizer:lTap];
            
            CGFloat textY = 6.0;
            if (hasImage) {
                UIImageView *lImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, contentW, 126)];
                lImg.contentMode = UIViewContentModeScaleAspectFill;
                lImg.clipsToBounds = YES;
                [[VKImageLoader sharedLoader] loadImageWithURL:att.linkImageURL completion:^(UIImage *img) {
                    if (img) lImg.image = img;
                }];
                [linkView addSubview:lImg];
                textY = 132.0;
            }
            
            UILabel *lTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, textY, contentW - 20, 20)];
            lTitle.text = att.linkTitle ?: @"Ссылка";
            lTitle.font = [UIFont boldSystemFontOfSize:13];
            lTitle.textColor = [UIColor colorWithRed:44.0/255.0 green:80.0/255.0 blue:120.0/255.0 alpha:1.0];
            [linkView addSubview:lTitle];
            
            UILabel *lDesc = [[UILabel alloc] initWithFrame:CGRectMake(10, textY + 20, contentW - 20, 16)];
            lDesc.text = att.linkDescription.length > 0 ? att.linkDescription : att.linkURL;
            lDesc.font = [UIFont systemFontOfSize:11.5];
            lDesc.textColor = [UIColor grayColor];
            [linkView addSubview:lDesc];
            
            [self.attachmentsContainerView addSubview:linkView];
            attY += linkH + 8.0;
            linkIndex++;
        } else if (att.type == VKAttachmentTypePoll) {
            CGFloat pollH = 34.0 + (att.pollOptions.count * 34.0) + 24.0;
            UIView *pollView = [[UIView alloc] initWithFrame:CGRectMake(0, attY, contentW, pollH)];
            
            if (isSkeuomorph) {
                pollView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0];
                pollView.layer.cornerRadius = 4.0;
                pollView.layer.borderWidth = 0.5;
                pollView.layer.borderColor = [UIColor colorWithRed:205.0/255.0 green:210.0/255.0 blue:220.0/255.0 alpha:1.0].CGColor;
            } else if (isFlat) {
                pollView.backgroundColor = [UIColor colorWithRed:244.0/255.0 green:246.0/255.0 blue:249.0/255.0 alpha:1.0];
                pollView.layer.cornerRadius = 3.0;
                pollView.layer.borderWidth = 0.0;
            } else {
                pollView.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:247.0/255.0 alpha:1.0];
                pollView.layer.cornerRadius = 10.0;
                pollView.layer.borderWidth = 0.0;
            }
            pollView.clipsToBounds = YES;
            
            // Вопрос опроса
            UILabel *qLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, contentW - 20, 20)];
            qLbl.text = [NSString stringWithFormat:@"📊  %@", att.pollQuestion ?: @"Опрос"];
            qLbl.font = [UIFont boldSystemFontOfSize:13.5];
            qLbl.textColor = isSkeuomorph ? [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0] : [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
            [pollView addSubview:qLbl];
            
            CGFloat optY = 34.0;
            NSInteger optIndex = 0;
            for (VKPollOption *opt in att.pollOptions) {
                UIView *barBg = [[UIView alloc] initWithFrame:CGRectMake(10, optY, contentW - 20, 26)];
                barBg.backgroundColor = isSkeuomorph ? [UIColor colorWithRed:232.0/255.0 green:235.0/255.0 blue:240.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.92 alpha:1.0];
                barBg.layer.cornerRadius = isSkeuomorph ? 3.5 : 4.0;
                if (isSkeuomorph) {
                    barBg.layer.borderWidth = 0.5;
                    barBg.layer.borderColor = [UIColor colorWithRed:210.0/255.0 green:214.0/255.0 blue:222.0/255.0 alpha:1.0].CGColor;
                }
                barBg.clipsToBounds = YES;
                barBg.tag = 7000 + (pollIndex * 100) + optIndex;
                barBg.userInteractionEnabled = YES;
                UITapGestureRecognizer *optTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pollOptionTapped:)];
                [barBg addGestureRecognizer:optTap];
                
                CGFloat percent = (att.pollTotalVotes > 0) ? ((CGFloat)opt.votes / (CGFloat)att.pollTotalVotes) : 0.0;
                UIView *barFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, (contentW - 20) * percent, 26)];
                
                if (isSkeuomorph) {
                    barFill.backgroundColor = [UIColor colorWithRed:83.0/255.0 green:124.0/255.0 blue:164.0/255.0 alpha:0.55];
                } else if (isFlat) {
                    barFill.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:0.35];
                } else {
                    barFill.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:0.35];
                }
                [barBg addSubview:barFill];
                
                UILabel *tLbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 3, contentW - 75, 20)];
                tLbl.text = opt.text;
                tLbl.font = [UIFont systemFontOfSize:12.5];
                tLbl.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1.0];
                [barBg addSubview:tLbl];
                
                UILabel *pLbl = [[UILabel alloc] initWithFrame:CGRectMake(contentW - 70, 3, 44, 20)];
                pLbl.text = [NSString stringWithFormat:@"%d%%", (int)(percent * 100)];
                pLbl.font = [UIFont boldSystemFontOfSize:12];
                pLbl.textColor = isSkeuomorph ? [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0] : [UIColor colorWithWhite:0.4 alpha:1.0];
                pLbl.textAlignment = NSTextAlignmentRight;
                [barBg addSubview:pLbl];
                
                [pollView addSubview:barBg];
                optY += 30.0;
                optIndex++;
            }
            
            // Количество голосов внизу опроса
            UILabel *voteCountLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, optY + 2, contentW - 20, 16)];
            voteCountLbl.text = [NSString stringWithFormat:@"Проголосовало %ld чел.", (long)att.pollTotalVotes];
            voteCountLbl.font = [UIFont systemFontOfSize:11];
            voteCountLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
            [pollView addSubview:voteCountLbl];
            
            [self.attachmentsContainerView addSubview:pollView];
            attY += pollH + 8.0;
            pollIndex++;
        }
    }
    self.attachmentsContainerView.frame = CGRectMake(0, currentY, contentW, attY);
    currentY += attY;
    
    // Репост
    if (post.repostHistory.count > 0) {
        VKPost *rep = post.repostHistory[0];
        self.repostContainerView.hidden = NO;
        
        self.repostAuthorLabel.text = rep.author.displayName ?: @"Пользователь";
        self.repostAvatarImageView.image = nil;
        if (rep.author.avatarURL) {
            [[VKImageLoader sharedLoader] loadImageWithURL:rep.author.avatarURL completion:^(UIImage *img) {
                if (img) self.repostAvatarImageView.image = img;
            }];
        }
        
        // Стилизация репоста по темам
        if (isSkeuomorph) {
            // iOS 6: рельефная рамка, скругление 3.5, квадратный аватар, темно-синий заголовок #2B587A
            self.repostContainerView.backgroundColor = [UIColor colorWithRed:245.0/255.0 green:247.0/255.0 blue:250.0/255.0 alpha:1.0];
            self.repostContainerView.layer.cornerRadius = 3.5;
            self.repostContainerView.layer.borderWidth = 0.5;
            self.repostContainerView.layer.borderColor = [UIColor colorWithRed:205.0/255.0 green:210.0/255.0 blue:220.0/255.0 alpha:1.0].CGColor;
            
            self.repostLeftBarView.backgroundColor = [UIColor colorWithRed:69.0/255.0 green:104.0/255.0 blue:142.0/255.0 alpha:1.0];
            self.repostLeftBarView.layer.cornerRadius = 0.0;
            
            self.repostAvatarImageView.layer.cornerRadius = 3.0;
            self.repostAvatarImageView.layer.borderWidth = 0.5;
            self.repostAvatarImageView.layer.borderColor = [UIColor colorWithWhite:0.8 alpha:1.0].CGColor;
            
            self.repostAuthorLabel.textColor = [UIColor colorWithRed:43.0/255.0 green:88.0/255.0 blue:122.0/255.0 alpha:1.0];
            self.repostAuthorLabel.font = [UIFont boldSystemFontOfSize:13];
            self.repostTextLabel.textColor = [UIColor colorWithRed:40.0/255.0 green:40.0/255.0 blue:40.0/255.0 alpha:1.0];
        } else if (isFlat) {
            // UIKit Classic Flat (iOS 7-10): сплошной серый фон, скругление 0, круглая аватарка, синий #4A76A8
            self.repostContainerView.backgroundColor = [UIColor colorWithRed:240.0/255.0 green:242.0/255.0 blue:245.0/255.0 alpha:1.0];
            self.repostContainerView.layer.cornerRadius = 0.0;
            self.repostContainerView.layer.borderWidth = 0.0;
            
            self.repostLeftBarView.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            self.repostLeftBarView.layer.cornerRadius = 0.0;
            
            self.repostAvatarImageView.layer.cornerRadius = 14.0;
            self.repostAvatarImageView.layer.borderWidth = 0.0;
            
            self.repostAuthorLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
            self.repostAuthorLabel.font = [UIFont boldSystemFontOfSize:13];
            self.repostTextLabel.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:30.0/255.0 alpha:1.0];
        } else {
            // Modern Swift (iOS 16-18): скругленная карточка 10pt, акцентный синий #2D81E0 с закруглением, SF Pro
            self.repostContainerView.backgroundColor = [UIColor colorWithRed:242.0/255.0 green:243.0/255.0 blue:247.0/255.0 alpha:1.0];
            self.repostContainerView.layer.cornerRadius = 10.0;
            self.repostContainerView.layer.borderWidth = 0.0;
            
            self.repostLeftBarView.backgroundColor = [UIColor colorWithRed:45.0/255.0 green:129.0/255.0 blue:224.0/255.0 alpha:1.0];
            self.repostLeftBarView.layer.cornerRadius = 1.5;
            
            self.repostAvatarImageView.layer.cornerRadius = 14.0;
            self.repostAvatarImageView.layer.borderWidth = 0.0;
            
            self.repostAuthorLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
            self.repostAuthorLabel.font = [UIFont boldSystemFontOfSize:13.5];
            self.repostTextLabel.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:26.0/255.0 alpha:1.0];
        }
        
        // Удаляем динамические вложения репоста
        for (UIView *sub in self.repostContainerView.subviews) {
            if (sub != self.repostLeftBarView && sub != self.repostAvatarImageView && sub != self.repostAuthorLabel && sub != self.repostTextLabel && sub != self.expandRepostTextButton) {
                [sub removeFromSuperview];
            }
        }
        
        CGFloat repInnerW = contentW - 16.0;
        CGFloat repCurY = 42.0;
        
        self.repostAvatarImageView.frame = CGRectMake(8, 8, 28, 28);
        self.repostAuthorLabel.frame = CGRectMake(42, 14, repInnerW - 36, 16);
        
        if (rep.text.length > 0) {
            self.repostTextLabel.hidden = NO;
            self.repostTextLabel.text = rep.text;
            CGSize repTextSize = [rep.text sizeWithFont:[UIFont systemFontOfSize:13]
                                      constrainedToSize:CGSizeMake(repInnerW, CGFLOAT_MAX)
                                          lineBreakMode:NSLineBreakByWordWrapping];
            CGFloat fullRepH = ceilf(repTextSize.height);
            BOOL isLongRep = rep.text.length > 250 || [rep.text componentsSeparatedByString:@"\n"].count > 5;
            
            if (isLongRep) {
                self.expandRepostTextButton.hidden = NO;
                [self.expandRepostTextButton setTitle:(rep.isRepostTextExpanded ? @"Свернуть" : @"Показать полностью...") forState:UIControlStateNormal];
                
                CGFloat collapsedRepH = MIN(fullRepH, [UIFont systemFontOfSize:13].lineHeight * 6.0);
                CGFloat repTextH = rep.isRepostTextExpanded ? fullRepH : collapsedRepH;
                self.repostTextLabel.numberOfLines = rep.isRepostTextExpanded ? 0 : 6;
                self.repostTextLabel.frame = CGRectMake(8, repCurY, repInnerW, repTextH);
                repCurY += repTextH;
                
                self.expandRepostTextButton.frame = CGRectMake(8, repCurY, 180, 22);
                repCurY += 22.0 + 8.0;
            } else {
                self.expandRepostTextButton.hidden = YES;
                self.repostTextLabel.numberOfLines = 0;
                self.repostTextLabel.frame = CGRectMake(8, repCurY, repInnerW, fullRepH);
                repCurY += fullRepH + 8.0;
            }
        } else {
            self.repostTextLabel.hidden = YES;
            self.expandRepostTextButton.hidden = YES;
        }
        
        // Вложения репоста (Фотографии)
        NSMutableArray *repPhotos = [NSMutableArray array];
        for (VKAttachment *att in rep.attachments) {
            if (att.type == VKAttachmentTypePhoto && att.photoURL.length > 0) [repPhotos addObject:att];
        }
        
        if (repPhotos.count == 1) {
            VKAttachment *a = repPhotos[0];
            CGFloat photoH = 220.0;
            if (a.photoWidth > 0 && a.photoHeight > 0) {
                photoH = MAX(140.0, MIN(280.0, floorf(repInnerW * (a.photoHeight / a.photoWidth))));
            }
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, photoH)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
            iv.layer.cornerRadius = 4.0;
            iv.tag = 0;
            iv.userInteractionEnabled = YES;
            UITapGestureRecognizer *repTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(repostPhotoCellTapped:)];
            [iv addGestureRecognizer:repTap];
            
            [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) { if (img) iv.image = img; }];
            [self.repostContainerView addSubview:iv];
            repCurY += photoH + 8.0;
        } else if (repPhotos.count > 1) {
            CGFloat halfW = (repInnerW - 4.0) / 2.0;
            CGFloat rowH = 120.0;
            for (NSInteger i = 0; i < MIN(4, (NSInteger)repPhotos.count); i++) {
                CGFloat x = 8.0 + (i % 2) * (halfW + 4.0);
                CGFloat y = repCurY + (i / 2) * (rowH + 4.0);
                UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, halfW, rowH)];
                iv.contentMode = UIViewContentModeScaleAspectFill;
                iv.clipsToBounds = YES;
                iv.layer.cornerRadius = 4.0;
                iv.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:237.0/255.0 blue:240.0/255.0 alpha:1.0];
                iv.tag = i;
                iv.userInteractionEnabled = YES;
                UITapGestureRecognizer *repTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(repostPhotoCellTapped:)];
                [iv addGestureRecognizer:repTap];
                
                VKAttachment *a = repPhotos[i];
                [[VKImageLoader sharedLoader] loadImageWithURL:a.photoURL completion:^(UIImage *img) { if (img) iv.image = img; }];
                [self.repostContainerView addSubview:iv];
            }
            NSInteger rows = ceilf(MIN(4, repPhotos.count) / 2.0);
            repCurY += rows * (rowH + 4.0) + 4.0;
        }
        
        // Прочие вложения репоста (Аудио, Видео, Опросы)
        for (VKAttachment *att in rep.attachments) {
            if (att.type == VKAttachmentTypeAudio) {
                UIView *aView = [[UIView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, 36)];
                UILabel *playI = [[UILabel alloc] initWithFrame:CGRectMake(0, 6, 24, 24)];
                playI.text = @"▶";
                playI.font = [UIFont boldSystemFontOfSize:11];
                playI.textAlignment = NSTextAlignmentCenter;
                playI.backgroundColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
                playI.textColor = [UIColor whiteColor];
                playI.layer.cornerRadius = 12.0;
                playI.clipsToBounds = YES;
                [aView addSubview:playI];
                
                UILabel *aLbl = [[UILabel alloc] initWithFrame:CGRectMake(32, 8, repInnerW - 40, 20)];
                aLbl.font = [UIFont boldSystemFontOfSize:13];
                aLbl.textColor = [UIColor colorWithRed:35.0/255.0 green:35.0/255.0 blue:40.0/255.0 alpha:1.0];
                aLbl.text = [NSString stringWithFormat:@"%@ — %@", att.audioArtist ?: @"", att.audioTitle ?: @"Аудио"];
                [aView addSubview:aLbl];
                
                [self.repostContainerView addSubview:aView];
                repCurY += 40.0;
            } else if (att.type == VKAttachmentTypeVideo) {
                UIView *vView = [[UIView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, 140)];
                vView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
                vView.layer.cornerRadius = 4.0;
                vView.clipsToBounds = YES;
                
                UIImageView *vImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, repInnerW, 140)];
                vImg.contentMode = UIViewContentModeScaleAspectFill;
                vImg.clipsToBounds = YES;
                if (att.videoImageURL.length > 0) {
                    [[VKImageLoader sharedLoader] loadImageWithURL:att.videoImageURL completion:^(UIImage *img) { if (img) vImg.image = img; }];
                }
                [vView addSubview:vImg];
                
                UILabel *pBadge = [[UILabel alloc] initWithFrame:CGRectMake((repInnerW - 40)/2.0, 50, 40, 40)];
                pBadge.text = @"▶";
                pBadge.textColor = [UIColor whiteColor];
                pBadge.font = [UIFont boldSystemFontOfSize:18];
                pBadge.textAlignment = NSTextAlignmentCenter;
                pBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
                pBadge.layer.cornerRadius = 20.0;
                pBadge.clipsToBounds = YES;
                [vView addSubview:pBadge];
                
                [self.repostContainerView addSubview:vView];
                repCurY += 148.0;
            } else if (att.type == VKAttachmentTypeDoc) {
                UIView *dView = [[UIView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, 34)];
                dView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
                dView.layer.cornerRadius = 3.0;
                
                UILabel *dIcon = [[UILabel alloc] initWithFrame:CGRectMake(4, 5, 32, 24)];
                dIcon.text = att.docExt ?: @"DOC";
                dIcon.font = [UIFont boldSystemFontOfSize:10];
                dIcon.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
                dIcon.textAlignment = NSTextAlignmentCenter;
                dIcon.layer.borderWidth = 1.0;
                dIcon.layer.borderColor = dIcon.textColor.CGColor;
                dIcon.layer.cornerRadius = 3.0;
                [dView addSubview:dIcon];
                
                UILabel *dLbl = [[UILabel alloc] initWithFrame:CGRectMake(42, 7, repInnerW - 48, 20)];
                dLbl.text = att.docTitle ?: @"Документ";
                dLbl.font = [UIFont boldSystemFontOfSize:12.5];
                dLbl.textColor = [UIColor colorWithRed:44.0/255.0 green:80.0/255.0 blue:120.0/255.0 alpha:1.0];
                [dView addSubview:dLbl];
                
                [self.repostContainerView addSubview:dView];
                repCurY += 42.0;
            } else if (att.type == VKAttachmentTypeGif) {
                UIImageView *gImg = [[UIImageView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, 140)];
                gImg.contentMode = UIViewContentModeScaleAspectFill;
                gImg.clipsToBounds = YES;
                gImg.layer.cornerRadius = 4.0;
                if (att.gifPreviewURL.length > 0) {
                    [[VKImageLoader sharedLoader] loadImageWithURL:att.gifPreviewURL completion:^(UIImage *img) { if (img) gImg.image = img; }];
                }
                [self.repostContainerView addSubview:gImg];
                repCurY += 148.0;
            } else if (att.type == VKAttachmentTypeLink) {
                UIView *lView = [[UIView alloc] initWithFrame:CGRectMake(8, repCurY, repInnerW, 46)];
                lView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
                lView.layer.cornerRadius = 4.0;
                
                UILabel *lTitle = [[UILabel alloc] initWithFrame:CGRectMake(8, 4, repInnerW - 16, 18)];
                lTitle.text = att.linkTitle ?: @"Ссылка";
                lTitle.font = [UIFont boldSystemFontOfSize:12.5];
                lTitle.textColor = [UIColor colorWithRed:44.0/255.0 green:80.0/255.0 blue:120.0/255.0 alpha:1.0];
                [lView addSubview:lTitle];
                
                UILabel *lDesc = [[UILabel alloc] initWithFrame:CGRectMake(8, 22, repInnerW - 16, 16)];
                lDesc.text = att.linkURL;
                lDesc.font = [UIFont systemFontOfSize:11];
                lDesc.textColor = [UIColor grayColor];
                [lView addSubview:lDesc];
                
                [self.repostContainerView addSubview:lView];
                repCurY += 54.0;
            }
        }
        
        CGFloat finalRepH = MAX(44.0, repCurY + 6.0);
        self.repostContainerView.frame = CGRectMake(0, currentY, contentW, finalRepH);
        self.repostLeftBarView.frame = CGRectMake(0, 0, (isFlat ? 2.5 : 3.0), finalRepH);
        currentY += finalRepH + 10.0;
    } else {
        self.repostContainerView.hidden = YES;
    }
    
    // Удаляем старые лейблы источника и автора
    [[self.contentContainerView viewWithTag:9901] removeFromSuperview];
    [[self.contentContainerView viewWithTag:9902] removeFromSuperview];
    
    // Источник (Copyright)
    if (post.copyrightName.length > 0) {
        UILabel *cLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, currentY, contentW, 18)];
        cLabel.tag = 9901;
        cLabel.text = [NSString stringWithFormat:@"🔗 Источник: %@", post.copyrightName];
        cLabel.font = [UIFont systemFontOfSize:12];
        cLabel.textColor = [UIColor colorWithRed:74.0/255.0 green:118.0/255.0 blue:168.0/255.0 alpha:1.0];
        cLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *cTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyrightTapped)];
        [cLabel addGestureRecognizer:cTap];
        [self.contentContainerView addSubview:cLabel];
        currentY += 22.0;
    }
    
    // Автор подписи (Signer)
    if (post.signerUser != nil) {
        UILabel *sLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, currentY, contentW, 18)];
        sLabel.tag = 9902;
        sLabel.text = [NSString stringWithFormat:@"✍️ Автор: %@", post.signerUser.displayName ?: @""];
        sLabel.font = [UIFont systemFontOfSize:12];
        sLabel.textColor = [UIColor colorWithRed:85.0/255.0 green:100.0/255.0 blue:120.0/255.0 alpha:1.0];
        sLabel.userInteractionEnabled = YES;
        UITapGestureRecognizer *sTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(signerTapped)];
        [sLabel addGestureRecognizer:sTap];
        [self.contentContainerView addSubview:sLabel];
        currentY += 22.0;
    }
    
    // Кнопки лайк / комменты / репост
    self.actionsContainerView.frame = CGRectMake(12.0, currentY + 4.0, contentW, 30.0);
    
    UIColor *defIconColor = isSkeuomorph ? [UIColor colorWithRed:100.0/255.0 green:110.0/255.0 blue:125.0/255.0 alpha:1.0] : [UIColor colorWithRed:130.0/255.0 green:140.0/255.0 blue:155.0/255.0 alpha:1.0];
    UIColor *likeIconColor = post.isLiked ? (isSkeuomorph ? [UIColor colorWithRed:215.0/255.0 green:35.0/255.0 blue:55.0/255.0 alpha:1.0] : [UIColor colorWithRed:235.0/255.0 green:45.0/255.0 blue:70.0/255.0 alpha:1.0]) : defIconColor;
    
    CGFloat btnH = 28.0;
    
    // 1. Комментарии (СЛЕВА)
    NSString *commText = [NSString stringWithFormat:@"%ld", (long)post.commentsCount];
    [self.commentsButton setImage:[[VKThemeManager sharedManager] reactionCommentIconWithColor:defIconColor] forState:UIControlStateNormal];
    [self.commentsButton setTitle:commText forState:UIControlStateNormal];
    self.commentsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.commentsButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 5);
    self.commentsButton.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 0);
    CGSize commTextSize = [commText sizeWithFont:[UIFont systemFontOfSize:13]];
    CGFloat commWidth = MAX(44.0, ceilf(commTextSize.width) + 24.0);
    self.commentsButton.frame = CGRectMake(0, 0, commWidth, btnH);
    
    // 2. Репост (СЛЕВА, РЯДОМ С КОММЕНТАРИЯМИ)
    NSString *repText = (post.repostsCount > 0) ? [NSString stringWithFormat:@"%ld", (long)post.repostsCount] : @"";
    [self.repostButton setImage:[[VKThemeManager sharedManager] reactionMegaphoneIconWithColor:defIconColor] forState:UIControlStateNormal];
    [self.repostButton setTitle:repText forState:UIControlStateNormal];
    self.repostButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.repostButton.imageEdgeInsets = (repText.length > 0) ? UIEdgeInsetsMake(0, 0, 0, 5) : UIEdgeInsetsZero;
    self.repostButton.titleEdgeInsets = (repText.length > 0) ? UIEdgeInsetsMake(0, 5, 0, 0) : UIEdgeInsetsZero;
    CGSize repTextSize = [repText sizeWithFont:[UIFont systemFontOfSize:13]];
    CGFloat repWidth = (repText.length > 0) ? MAX(44.0, ceilf(repTextSize.width) + 24.0) : 32.0;
    self.repostButton.frame = CGRectMake(commWidth + 18.0, 0, repWidth, btnH);
    
    // 3. Лайк (СПРАВА)
    NSString *likeText = [NSString stringWithFormat:@"%ld", (long)post.likesCount];
    [self.likeButton setImage:[[VKThemeManager sharedManager] reactionHeartIconWithColor:likeIconColor filled:post.isLiked] forState:UIControlStateNormal];
    [self.likeButton setTitle:likeText forState:UIControlStateNormal];
    self.likeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    self.likeButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 5);
    self.likeButton.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, 0);
    CGSize likeTextSize = [likeText sizeWithFont:[UIFont systemFontOfSize:13]];
    CGFloat likeWidth = MAX(44.0, ceilf(likeTextSize.width) + 24.0);
    self.likeButton.frame = CGRectMake(contentW - likeWidth, 0, likeWidth, btnH);
    
    if (isSkeuomorph) {
        // 1. iOS 6: Прямоугольные кнопки со скруглением 3.5pt, рельефным градиентом и рамкой!
        CGFloat sBtnH = 28.0;
        CGFloat sCommW = MAX(56.0, ceilf(commTextSize.width) + 34.0);
        CGFloat sRepW = (repText.length > 0) ? MAX(46.0, ceilf(repTextSize.width) + 30.0) : 38.0;
        CGFloat sLikeW = MAX(54.0, ceilf(likeTextSize.width) + 32.0);
        
        self.commentsButton.frame = CGRectMake(0, 0, sCommW, sBtnH);
        self.commentsButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.repostButton.frame = CGRectMake(sCommW + 6.0, 0, sRepW, sBtnH);
        self.repostButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        self.likeButton.frame = CGRectMake(contentW - sLikeW, 0, sLikeW, sBtnH);
        self.likeButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        
        UIImage *commBtnNorm = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sCommW height:sBtnH highlighted:NO];
        UIImage *commBtnPress = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sCommW height:sBtnH highlighted:YES];
        UIImage *repBtnNorm = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sRepW height:sBtnH highlighted:NO];
        UIImage *repBtnPress = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sRepW height:sBtnH highlighted:YES];
        UIImage *likeBtnNorm = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sLikeW height:sBtnH highlighted:NO];
        UIImage *likeBtnPress = [[VKThemeManager sharedManager] skeuomorphicButtonImageWithWidth:sLikeW height:sBtnH highlighted:YES];
        
        self.commentsButton.layer.cornerRadius = 3.5;
        self.commentsButton.clipsToBounds = YES;
        [self.commentsButton setBackgroundImage:commBtnNorm forState:UIControlStateNormal];
        [self.commentsButton setBackgroundImage:commBtnPress forState:UIControlStateHighlighted];
        self.commentsButton.backgroundColor = [UIColor clearColor];
        self.commentsButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.commentsButton.titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        self.commentsButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
        [self.commentsButton setTitleColor:[UIColor colorWithRed:75.0/255.0 green:80.0/255.0 blue:90.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        
        self.repostButton.layer.cornerRadius = 3.5;
        self.repostButton.clipsToBounds = YES;
        [self.repostButton setBackgroundImage:repBtnNorm forState:UIControlStateNormal];
        [self.repostButton setBackgroundImage:repBtnPress forState:UIControlStateHighlighted];
        self.repostButton.backgroundColor = [UIColor clearColor];
        self.repostButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.repostButton.titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        self.repostButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
        [self.repostButton setTitleColor:[UIColor colorWithRed:75.0/255.0 green:80.0/255.0 blue:90.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        
        self.likeButton.layer.cornerRadius = 3.5;
        self.likeButton.clipsToBounds = YES;
        [self.likeButton setBackgroundImage:likeBtnNorm forState:UIControlStateNormal];
        [self.likeButton setBackgroundImage:likeBtnPress forState:UIControlStateHighlighted];
        self.likeButton.backgroundColor = [UIColor clearColor];
        self.likeButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.likeButton.titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        self.likeButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
        [self.likeButton setTitleColor:likeIconColor forState:UIControlStateNormal];
        
    } else {
        // 2. UIKit Classic Flat & Modern Swift: чистые плоские кнопки без рамок и без капсул
        self.commentsButton.layer.cornerRadius = 0.0;
        self.commentsButton.clipsToBounds = NO;
        self.commentsButton.backgroundColor = [UIColor clearColor];
        [self.commentsButton setBackgroundImage:nil forState:UIControlStateNormal];
        [self.commentsButton setBackgroundImage:nil forState:UIControlStateHighlighted];
        self.commentsButton.titleLabel.shadowColor = nil;
        self.commentsButton.titleLabel.font = [UIFont systemFontOfSize:13.5];
        [self.commentsButton setTitleColor:[UIColor colorWithRed:130.0/255.0 green:140.0/255.0 blue:155.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        
        self.repostButton.layer.cornerRadius = 0.0;
        self.repostButton.clipsToBounds = NO;
        self.repostButton.backgroundColor = [UIColor clearColor];
        [self.repostButton setBackgroundImage:nil forState:UIControlStateNormal];
        [self.repostButton setBackgroundImage:nil forState:UIControlStateHighlighted];
        self.repostButton.titleLabel.shadowColor = nil;
        self.repostButton.titleLabel.font = [UIFont systemFontOfSize:13.5];
        [self.repostButton setTitleColor:[UIColor colorWithRed:130.0/255.0 green:140.0/255.0 blue:155.0/255.0 alpha:1.0] forState:UIControlStateNormal];
        
        self.likeButton.layer.cornerRadius = 0.0;
        self.likeButton.clipsToBounds = NO;
        self.likeButton.backgroundColor = [UIColor clearColor];
        [self.likeButton setBackgroundImage:nil forState:UIControlStateNormal];
        [self.likeButton setBackgroundImage:nil forState:UIControlStateHighlighted];
        self.likeButton.titleLabel.shadowColor = nil;
        self.likeButton.titleLabel.font = [UIFont systemFontOfSize:13.5];
        [self.likeButton setTitleColor:likeIconColor forState:UIControlStateNormal];
    }
}

- (void)toggleTextExpandedAction {
    if (!self.currentPost) return;
    BOOL isLongText = self.currentPost.text.length > 250 || [self.currentPost.text componentsSeparatedByString:@"\n"].count > 5;
    if (!isLongText) return;
    
    self.currentPost.isTextExpanded = !self.currentPost.isTextExpanded;
    if (self.onToggleTextExpanded) {
        self.onToggleTextExpanded(self.currentPost);
    }
}

- (void)toggleRepostTextExpandedAction {
    if (!self.currentPost || self.currentPost.repostHistory.count == 0) return;
    VKPost *rep = self.currentPost.repostHistory[0];
    BOOL isLongRep = rep.text.length > 250 || [rep.text componentsSeparatedByString:@"\n"].count > 5;
    if (!isLongRep) return;
    
    rep.isRepostTextExpanded = !rep.isRepostTextExpanded;
    if (self.onToggleRepostTextExpanded) {
        self.onToggleRepostTextExpanded(self.currentPost);
    }
}

@end
