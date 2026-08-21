#import "VKNewPostViewController.h"
#import "VKFeedService.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"
#import "VKThemeManager.h"
#import "VKPhotoEditorViewController.h"
#import "VKAPIClient.h"

// Модель прикрепленного объекта к записи
@interface VKAttachedItem : NSObject
@property (nonatomic, copy) NSString *type; // @"photo", @"video", @"doc", @"poll", @"copyright"
@property (nonatomic, copy) NSString *attachmentString; // e.g. "photo123_456"
@property (nonatomic, strong) UIImage *localImage;
@property (nonatomic, copy) NSString *title;
@end

@implementation VKAttachedItem
@end

@interface VKNewPostViewController () <UITextViewDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *placeholderLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;

@property (nonatomic, strong) UIScrollView *attachmentsTrayScrollView;
@property (nonatomic, strong) NSMutableArray<VKAttachedItem *> *attachedItems;
@property (nonatomic, copy) NSString *copyrightUrl;

@property (nonatomic, strong) UIView *toolbarView;
@property (nonatomic, strong) UIScrollView *toolbarScrollView;

// Опрос (данные при создании)
@property (nonatomic, copy) NSString *pendingPollQuestion;
@property (nonatomic, strong) NSMutableArray<NSString *> *pendingPollAnswers;
@property (nonatomic, assign) BOOL pendingPollIsAnonymous;

@end

@implementation VKNewPostViewController

- (instancetype)initWithOwnerId:(NSInteger)ownerId {
    self = [super init];
    if (self) {
        _ownerId = ownerId;
        _attachedItems = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Новая запись";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Отмена" style:UIBarButtonItemStylePlain target:self action:@selector(cancelAction)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Опубликовать" style:UIBarButtonItemStyleDone target:self action:@selector(publishAction)];
    
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(16, 12, width - 32, 140)];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.textView.font = [UIFont systemFontOfSize:16];
    self.textView.delegate = self;
    self.textView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.textView];
    
    self.placeholderLabel = [[UILabel alloc] initWithFrame:CGRectMake(22, 20, width - 44, 22)];
    self.placeholderLabel.text = @"Что у вас нового?";
    self.placeholderLabel.font = [UIFont systemFontOfSize:16];
    self.placeholderLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    [self.view addSubview:self.placeholderLabel];
    
    // Трей вложений (горизонтальный скролл)
    self.attachmentsTrayScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(16, 160, width - 32, 86)];
    self.attachmentsTrayScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.attachmentsTrayScrollView.showsHorizontalScrollIndicator = NO;
    self.attachmentsTrayScrollView.hidden = YES;
    [self.view addSubview:self.attachmentsTrayScrollView];
    
    // Нижняя панель действий со всеми типами вложений
    self.toolbarView = [[UIView alloc] initWithFrame:CGRectMake(0, height - 48, width, 48)];
    self.toolbarView.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
    self.toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.toolbarView];
    
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 1)];
    sep.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    sep.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.toolbarView addSubview:sep];
    
    self.toolbarScrollView = [[UIScrollView alloc] initWithFrame:self.toolbarView.bounds];
    self.toolbarScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.toolbarScrollView.showsHorizontalScrollIndicator = NO;
    [self.toolbarView addSubview:self.toolbarScrollView];
    
    [self setupToolbarButtons];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.activityIndicator.center = CGPointMake(width / 2.0, 100);
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    // Клавиатурные события
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    [self.textView becomeFirstResponder];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGRect kbFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    CGFloat viewH = self.view.bounds.size.height;
    CGFloat kbH = kbFrame.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        self.toolbarView.frame = CGRectMake(0, viewH - kbH - 48, self.view.bounds.size.width, 48);
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    NSTimeInterval duration = [[info objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGFloat viewH = self.view.bounds.size.height;
    
    [UIView animateWithDuration:duration animations:^{
        self.toolbarView.frame = CGRectMake(0, viewH - 48, self.view.bounds.size.width, 48);
    }];
}

- (void)setupToolbarButtons {
    NSArray *buttons = @[
        @{@"title": @"📷 Фото", @"tag": @(101)},
        @{@"title": @"🎬 Видео", @"tag": @(102)},
        @{@"title": @"📄 Документ", @"tag": @(103)},
        @{@"title": @"📊 Опрос", @"tag": @(104)},
        @{@"title": @"🔗 Источник", @"tag": @(105)}
    ];
    
    CGFloat curX = 10.0;
    for (NSDictionary *b in buttons) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = [b[@"tag"] integerValue];
        [btn setTitle:b[@"title"] forState:UIControlStateNormal];
        [btn setTitleColor:[[VKThemeManager sharedManager] accentColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        
        CGSize s = [b[@"title"] sizeWithFont:btn.titleLabel.font];
        btn.frame = CGRectMake(curX, 6, s.width + 16.0, 36);
        btn.layer.cornerRadius = 6.0;
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1.0].CGColor;
        [btn addTarget:self action:@selector(toolbarButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.toolbarScrollView addSubview:btn];
        
        curX += s.width + 24.0;
    }
    self.toolbarScrollView.contentSize = CGSizeMake(curX + 10.0, 48);
}

#pragma mark - Attachments UI Refresh

- (void)reloadAttachmentsTray {
    for (UIView *v in self.attachmentsTrayScrollView.subviews) [v removeFromSuperview];
    
    if (self.attachedItems.count == 0 && self.copyrightUrl.length == 0) {
        self.attachmentsTrayScrollView.hidden = YES;
        return;
    }
    
    self.attachmentsTrayScrollView.hidden = NO;
    CGFloat curX = 0;
    
    // Отрисовка прикрепленных карточек
    for (NSInteger i = 0; i < (NSInteger)self.attachedItems.count; i++) {
        VKAttachedItem *item = self.attachedItems[i];
        
        if ([item.type isEqualToString:@"photo"] && item.localImage) {
            UIView *box = [[UIView alloc] initWithFrame:CGRectMake(curX, 0, 80, 80)];
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 74, 74)];
            iv.contentMode = UIViewContentModeScaleAspectFill;
            iv.clipsToBounds = YES;
            iv.layer.cornerRadius = 6.0;
            iv.image = item.localImage;
            iv.userInteractionEnabled = YES;
            iv.tag = i;
            
            UITapGestureRecognizer *tapEdit = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(editPhotoAttachmentTapped:)];
            [iv addGestureRecognizer:tapEdit];
            [box addSubview:iv];
            
            // Иконка карандаша в левом нижнем углу миниатюры
            UILabel *pencilBadge = [[UILabel alloc] initWithFrame:CGRectMake(4, 52, 20, 18)];
            pencilBadge.text = @"✏️";
            pencilBadge.font = [UIFont systemFontOfSize:11];
            pencilBadge.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.6];
            pencilBadge.layer.cornerRadius = 4.0;
            pencilBadge.clipsToBounds = YES;
            pencilBadge.textAlignment = NSTextAlignmentCenter;
            [iv addSubview:pencilBadge];
            
            UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            delBtn.frame = CGRectMake(60, 0, 20, 20);
            delBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75];
            delBtn.layer.cornerRadius = 10.0;
            [delBtn setTitle:@"✕" forState:UIControlStateNormal];
            [delBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            delBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
            delBtn.tag = i;
            [delBtn addTarget:self action:@selector(removeAttachmentAtIndex:) forControlEvents:UIControlEventTouchUpInside];
            [box addSubview:delBtn];
            
            [self.attachmentsTrayScrollView addSubview:box];
            curX += 86.0;
        } else {
            // Плашка для видео, документов, опросов
            NSString *icon = [item.type isEqualToString:@"video"] ? @"🎬" : ([item.type isEqualToString:@"doc"] ? @"📄" : @"📊");
            NSString *dispTitle = [NSString stringWithFormat:@"%@ %@", icon, item.title ?: item.type];
            CGSize s = [dispTitle sizeWithFont:[UIFont systemFontOfSize:13]];
            CGFloat chipW = s.width + 44.0;
            
            UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(curX, 20, chipW, 40)];
            chip.backgroundColor = [UIColor colorWithWhite:0.92 alpha:1.0];
            chip.layer.cornerRadius = 6.0;
            
            UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 10, s.width + 10.0, 20)];
            lbl.font = [UIFont systemFontOfSize:13];
            lbl.textColor = [UIColor colorWithRed:30.0/255.0 green:30.0/255.0 blue:35.0/255.0 alpha:1.0];
            lbl.text = dispTitle;
            [chip addSubview:lbl];
            
            UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            delBtn.frame = CGRectMake(chipW - 24, 10, 20, 20);
            delBtn.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1.0];
            delBtn.layer.cornerRadius = 10.0;
            [delBtn setTitle:@"✕" forState:UIControlStateNormal];
            [delBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            delBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
            delBtn.tag = i;
            [delBtn addTarget:self action:@selector(removeAttachmentAtIndex:) forControlEvents:UIControlEventTouchUpInside];
            [chip addSubview:delBtn];
            
            [self.attachmentsTrayScrollView addSubview:chip];
            curX += chipW + 10.0;
        }
    }
    
    // Плашка источника (copyright)
    if (self.copyrightUrl.length > 0) {
        NSString *cText = [NSString stringWithFormat:@"🔗 Источник: %@", self.copyrightUrl];
        CGSize s = [cText sizeWithFont:[UIFont systemFontOfSize:13]];
        CGFloat chipW = s.width + 44.0;
        
        UIView *chip = [[UIView alloc] initWithFrame:CGRectMake(curX, 20, chipW, 40)];
        chip.backgroundColor = [UIColor colorWithRed:235.0/255.0 green:243.0/255.0 blue:255.0/255.0 alpha:1.0];
        chip.layer.cornerRadius = 6.0;
        
        UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(8, 10, s.width + 10.0, 20)];
        lbl.font = [UIFont systemFontOfSize:13];
        lbl.textColor = [[VKThemeManager sharedManager] accentColor];
        lbl.text = cText;
        [chip addSubview:lbl];
        
        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        delBtn.frame = CGRectMake(chipW - 24, 10, 20, 20);
        delBtn.backgroundColor = [UIColor colorWithWhite:0.7 alpha:1.0];
        delBtn.layer.cornerRadius = 10.0;
        [delBtn setTitle:@"✕" forState:UIControlStateNormal];
        [delBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        delBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        [delBtn addTarget:self action:@selector(removeCopyright) forControlEvents:UIControlEventTouchUpInside];
        [chip addSubview:delBtn];
        
        [self.attachmentsTrayScrollView addSubview:chip];
        curX += chipW + 10.0;
    }
    
    self.attachmentsTrayScrollView.contentSize = CGSizeMake(curX + 10.0, 86);
}

- (void)editPhotoAttachmentTapped:(UITapGestureRecognizer *)gesture {
    NSInteger idx = gesture.view.tag;
    if (idx >= 0 && idx < (NSInteger)self.attachedItems.count) {
        VKAttachedItem *item = self.attachedItems[idx];
        if (item.localImage) {
            VKPhotoEditorViewController *editor = [[VKPhotoEditorViewController alloc] initWithImage:item.localImage];
            __weak typeof(self) weakSelf = self;
            editor.onImageEdited = ^(UIImage *edited) {
                if (edited) {
                    item.localImage = edited;
                    [weakSelf reloadAttachmentsTray];
                }
            };
            [self presentViewController:editor animated:YES completion:nil];
        }
    }
}

- (void)removeAttachmentAtIndex:(UIButton *)btn {
    NSInteger idx = btn.tag;
    if (idx >= 0 && idx < (NSInteger)self.attachedItems.count) {
        [self.attachedItems removeObjectAtIndex:idx];
        [self reloadAttachmentsTray];
    }
}

- (void)removeCopyright {
    self.copyrightUrl = nil;
    [self reloadAttachmentsTray];
}

#pragma mark - Toolbar Actions

- (void)toolbarButtonTapped:(UIButton *)btn {
    [self.view endEditing:YES];
    
    if (btn.tag == 101) {
        // Фото
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Прикрепить фото"
                                                           delegate:self
                                                  cancelButtonTitle:@"Отмена"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"Сделать снимок", @"Выбрать из галереи", @"Мои фотографии ВК", nil];
        sheet.tag = 8001;
        [sheet showInView:self.view];
    } else if (btn.tag == 102) {
        // Видео
        [self pickUserVideos];
    } else if (btn.tag == 103) {
        // Документ
        [self pickUserDocuments];
    } else if (btn.tag == 104) {
        // Опрос
        [self showCreatePollDialog];
    } else if (btn.tag == 105) {
        // Источник (Copyright)
        [self showCopyrightDialog];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet.tag == 8001) {
        if (buttonIndex == 0) {
            // Камера
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                UIImagePickerController *p = [[UIImagePickerController alloc] init];
                p.sourceType = UIImagePickerControllerSourceTypeCamera;
                p.delegate = self;
                [self presentViewController:p animated:YES completion:nil];
            }
        } else if (buttonIndex == 1) {
            // Галерея устройства
            UIImagePickerController *p = [[UIImagePickerController alloc] init];
            p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            p.delegate = self;
            [self presentViewController:p animated:YES completion:nil];
        } else if (buttonIndex == 2) {
            // Мои фотографии ВК
            [self pickUserPhotosFromVK];
        }
    }
}

#pragma mark - Image Picker & Photo Editor

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (img) {
            VKPhotoEditorViewController *editor = [[VKPhotoEditorViewController alloc] initWithImage:img];
            __weak typeof(self) weakSelf = self;
            editor.onImageEdited = ^(UIImage *edited) {
                if (edited) {
                    VKAttachedItem *item = [[VKAttachedItem alloc] init];
                    item.type = @"photo";
                    item.localImage = edited;
                    [weakSelf.attachedItems addObject:item];
                    [weakSelf reloadAttachmentsTray];
                }
            };
            [weakSelf presentViewController:editor animated:YES completion:nil];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Picking from VK Servers (Photos, Videos, Docs)

- (void)pickUserPhotosFromVK {
    [[VKAPIClient sharedClient] callMethod:@"photos.getAll" parameters:@{@"count": @(20), @"extended": @"1"} completionHandler:^(id response, NSError *error) {
        if (error || ![response isKindOfClass:[NSDictionary class]]) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Фотографии" message:@"Не удалось загрузить ваши фотографии" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        NSDictionary *resp = response[@"response"] ?: response;
        NSArray *items = resp[@"items"] ?: @[];
        if (items.count == 0) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Фотографии" message:@"У вас пока нет загруженных фотографий" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        // Добавляем первое доступное фото как образец
        NSDictionary *p = items[0];
        NSInteger pid = [p[@"id"] integerValue] ?: [p[@"pid"] integerValue];
        NSInteger pOwner = [p[@"owner_id"] integerValue];
        
        VKAttachedItem *item = [[VKAttachedItem alloc] init];
        item.type = @"photo";
        item.attachmentString = [NSString stringWithFormat:@"photo%ld_%ld", (long)pOwner, (long)pid];
        item.title = [NSString stringWithFormat:@"Фотография #%ld", (long)pid];
        [self.attachedItems addObject:item];
        [self reloadAttachmentsTray];
    }];
}

- (void)pickUserVideos {
    [[VKAPIClient sharedClient] callMethod:@"video.get" parameters:@{@"count": @(20)} completionHandler:^(id response, NSError *error) {
        if (error || ![response isKindOfClass:[NSDictionary class]]) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Видеозаписи" message:@"Не удалось загрузить видеозаписи" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        NSDictionary *resp = response[@"response"] ?: response;
        NSArray *items = resp[@"items"] ?: @[];
        if (items.count == 0) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Видеозаписи" message:@"У вас пока нет видеозаписей" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        NSDictionary *v = items[0];
        NSInteger vid = [v[@"id"] integerValue] ?: [v[@"vid"] integerValue];
        NSInteger vOwner = [v[@"owner_id"] integerValue];
        NSString *vTitle = v[@"title"] ?: @"Видеозапись";
        
        VKAttachedItem *item = [[VKAttachedItem alloc] init];
        item.type = @"video";
        item.attachmentString = [NSString stringWithFormat:@"video%ld_%ld", (long)vOwner, (long)vid];
        item.title = vTitle;
        [self.attachedItems addObject:item];
        [self reloadAttachmentsTray];
    }];
}

- (void)pickUserDocuments {
    [[VKAPIClient sharedClient] callMethod:@"docs.get" parameters:@{@"count": @(20)} completionHandler:^(id response, NSError *error) {
        if (error || ![response isKindOfClass:[NSDictionary class]]) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Документы" message:@"Не удалось загрузить документы" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        NSDictionary *resp = response[@"response"] ?: response;
        NSArray *items = resp[@"items"] ?: @[];
        if (items.count == 0) {
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Документы" message:@"У вас пока нет документов" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
            return;
        }
        
        NSDictionary *d = items[0];
        NSInteger did = [d[@"id"] integerValue] ?: [d[@"did"] integerValue];
        NSInteger dOwner = [d[@"owner_id"] integerValue];
        NSString *dTitle = d[@"title"] ?: @"Документ";
        
        VKAttachedItem *item = [[VKAttachedItem alloc] init];
        item.type = @"doc";
        item.attachmentString = [NSString stringWithFormat:@"doc%ld_%ld", (long)dOwner, (long)did];
        item.title = dTitle;
        [self.attachedItems addObject:item];
        [self reloadAttachmentsTray];
    }];
}

#pragma mark - Poll Dialog

- (void)showCreatePollDialog {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Создать опрос"
                                                    message:@"Введите вопрос опроса:"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Далее", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 9001;
    [alert show];
}

- (void)showPollOptionsDialogWithQuestion:(NSString *)question {
    self.pendingPollQuestion = question;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Варианты ответа"
                                                    message:@"Введите варианты через запятую (например: Да, Нет):"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Создать", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 9002;
    [alert show];
}

#pragma mark - Copyright Dialog

- (void)showCopyrightDialog {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Источник"
                                                    message:@"Укажите ссылку на источник материала (https://...):"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сохранить", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    alert.tag = 9003;
    UITextField *tf = [alert textFieldAtIndex:0];
    tf.text = self.copyrightUrl ?: @"";
    tf.placeholder = @"https://...";
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        UITextField *tf = [alertView textFieldAtIndex:0];
        NSString *text = [tf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (alertView.tag == 9001 && text.length > 0) {
            [self showPollOptionsDialogWithQuestion:text];
        } else if (alertView.tag == 9002 && text.length > 0) {
            NSArray *parts = [text componentsSeparatedByString:@","];
            NSMutableArray *opts = [NSMutableArray array];
            for (NSString *p in parts) {
                NSString *cl = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (cl.length > 0) [opts addObject:cl];
            }
            if (opts.count < 2) {
                [opts addObject:@"Да"];
                [opts addObject:@"Нет"];
            }
            self.pendingPollAnswers = opts;
            
            VKAttachedItem *item = [[VKAttachedItem alloc] init];
            item.type = @"poll";
            item.title = self.pendingPollQuestion;
            [self.attachedItems addObject:item];
            [self reloadAttachmentsTray];
        } else if (alertView.tag == 9003 && text.length > 0) {
            self.copyrightUrl = text;
            [self reloadAttachmentsTray];
        }
    }
}

#pragma mark - Publishing Post with All Attachments

- (void)textViewDidChange:(UITextView *)textView {
    self.placeholderLabel.hidden = (textView.text.length > 0);
}

- (void)cancelAction {
    [self.textView resignFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)publishAction {
    NSString *text = [self.textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0 && self.attachedItems.count == 0) return;
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [self.activityIndicator startAnimating];
    
    NSInteger targetOwner = self.ownerId;
    if (targetOwner == 0) {
        targetOwner = [[VKAuthService sharedService] currentUserModel].uid;
    }
    
    [VKCrashLogger log:@"[VKNewPostViewController] Starting post publication (owner=%ld)...", (long)targetOwner];
    
    // Загрузка локальных фото и опросов перед отправкой записи
    [self uploadPendingAttachmentsAndPublishWithText:text ownerId:targetOwner];
}

- (void)uploadPendingAttachmentsAndPublishWithText:(NSString *)text ownerId:(NSInteger)targetOwner {
    NSMutableArray *finalAttachments = [NSMutableArray array];
    
    // Собираем уже готовые вложения
    for (VKAttachedItem *item in self.attachedItems) {
        if (item.attachmentString.length > 0) {
            [finalAttachments addObject:item.attachmentString];
        }
    }
    
    // Проверяем локальные фото для загрузки
    NSMutableArray<VKAttachedItem *> *photosToUpload = [NSMutableArray array];
    VKAttachedItem *pollToCreate = nil;
    
    for (VKAttachedItem *item in self.attachedItems) {
        if ([item.type isEqualToString:@"photo"] && item.localImage && item.attachmentString.length == 0) {
            [photosToUpload addObject:item];
        } else if ([item.type isEqualToString:@"poll"] && item.attachmentString.length == 0) {
            pollToCreate = item;
        }
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    // 1. Загрузка фото
    for (VKAttachedItem *pItem in photosToUpload) {
        dispatch_group_enter(group);
        [[VKFeedService sharedService] uploadWallPhoto:pItem.localImage ownerId:targetOwner completion:^(NSString *attStr, NSError *error) {
            if (attStr) {
                [finalAttachments addObject:attStr];
            }
            dispatch_group_leave(group);
        }];
    }
    
    // 2. Создание опроса
    if (pollToCreate && self.pendingPollQuestion && self.pendingPollAnswers.count >= 2) {
        dispatch_group_enter(group);
        [[VKFeedService sharedService] createPollWithQuestion:self.pendingPollQuestion answers:self.pendingPollAnswers isAnonymous:NO ownerId:targetOwner completion:^(NSString *attStr, NSError *error) {
            if (attStr) {
                [finalAttachments addObject:attStr];
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSString *attCombined = (finalAttachments.count > 0) ? [finalAttachments componentsJoinedByString:@","] : nil;
        
        [[VKFeedService sharedService] createPostWithText:text
                                                  ownerId:targetOwner
                                              attachments:attCombined
                                                copyright:self.copyrightUrl
                                                 explicit:NO
                                                fromGroup:NO
                                               completion:^(BOOL success, NSError *error) {
            [self.activityIndicator stopAnimating];
            self.navigationItem.rightBarButtonItem.enabled = YES;
            
            if (success) {
                [VKCrashLogger log:@"[VKNewPostViewController] Post with attachments published successfully!"];
                if (self.onPostCreated) self.onPostCreated();
                [self.textView resignFirstResponder];
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Не удалось опубликовать запись" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alert show];
            }
        }];
    });
}

@end
