#import "VKChatSettingsViewController.h"
#import "VKMessagesService.h"
#import "VKProfileViewController.h"
#import "VKAPIClient.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"

@interface VKChatSettingsViewController () <UIAlertViewDelegate>
@property (nonatomic, strong) NSMutableArray<VKUser *> *members;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) UIImageView *headerAvatarView;
@property (nonatomic, strong) UILabel *headerTitleLabel;
@property (nonatomic, strong) UILabel *headerMembersLabel;
@end

@implementation VKChatSettingsViewController

- (instancetype)initWithChatId:(NSInteger)chatId
                       adminId:(NSInteger)adminId
                         title:(NSString *)title
                      photoURL:(NSString *)photoURL
                  membersCount:(NSInteger)membersCount
                      isMember:(BOOL)isMember {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _chatId = chatId;
        _adminId = adminId;
        _chatTitle = title ?: @"Беседа";
        _chatPhotoURL = photoURL;
        _membersCount = membersCount;
        _isMember = isMember;
        _members = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Настройки беседы";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] isSkeuomorphic] ? [UIColor colorWithRed:235/255.0 green:238/255.0 blue:242/255.0 alpha:1.0] : [UIColor colorWithRed:239/255.0 green:239/255.0 blue:244/255.0 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    
    [self setupTableHeader];
    [self loadChatDetails];
}

- (void)goBackAction {
    if (self.onChatUpdated) {
        self.onChatUpdated(self.chatTitle, self.chatPhotoURL, self.isMember);
    }
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setupTableHeader {
    CGFloat width = self.view.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 140)];
    header.backgroundColor = [UIColor clearColor];
    
    // Аватарка беседы
    UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake((width - 64) / 2.0, 14, 64, 64)];
    avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:64.0];
    avatar.layer.borderWidth = [[VKThemeManager sharedManager] avatarBorderWidth];
    avatar.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.6].CGColor;
    avatar.clipsToBounds = YES;
    avatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    avatar.contentMode = UIViewContentModeScaleAspectFill;
    [header addSubview:avatar];
    self.headerAvatarView = avatar;
    
    if (self.chatPhotoURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:self.chatPhotoURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    // Название беседы
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 84, width - 32, 22)];
    titleLabel.text = self.chatTitle;
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textColor = [UIColor blackColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:titleLabel];
    self.headerTitleLabel = titleLabel;
    
    // Количество участников
    UILabel *membersLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 108, width - 32, 18)];
    membersLabel.text = [self membersCountString:self.membersCount];
    membersLabel.font = [UIFont systemFontOfSize:13];
    membersLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    membersLabel.textAlignment = NSTextAlignmentCenter;
    membersLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:membersLabel];
    self.headerMembersLabel = membersLabel;
    
    self.tableView.tableHeaderView = header;
}

- (NSString *)membersCountString:(NSInteger)count {
    if (count <= 0) return @"нет участников";
    NSInteger rem100 = count % 100;
    NSInteger rem10 = count % 10;
    if (rem100 >= 11 && rem100 <= 19) return [NSString stringWithFormat:@"%ld участников", (long)count];
    if (rem10 == 1) return [NSString stringWithFormat:@"%ld участник", (long)count];
    if (rem10 >= 2 && rem10 <= 4) return [NSString stringWithFormat:@"%ld участника", (long)count];
    return [NSString stringWithFormat:@"%ld участников", (long)count];
}

- (void)loadChatDetails {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    NSDictionary *params = @{
        @"chat_id": @(self.chatId),
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getChat" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            self.isLoading = NO;
            return;
        }
        
        NSDictionary *dict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (!dict) {
            self.isLoading = NO;
            return;
        }
        
        NSString *title = dict[@"title"];
        NSString *photo = dict[@"photo_100"] ?: dict[@"photo_50"] ?: dict[@"photo_200"];
        NSInteger adminId = [dict[@"admin_id"] integerValue];
        NSArray *users = dict[@"users"];
        
        NSInteger myId = [[VKAuthService sharedService] currentUserId];
        BOOL isMember = NO;
        if ([users isKindOfClass:[NSArray class]]) {
            for (id u in users) {
                NSInteger uid = [u isKindOfClass:[NSDictionary class]] ? ([u[@"id"] integerValue] ?: [u[@"uid"] integerValue]) : [u integerValue];
                if (uid == myId) {
                    isMember = YES;
                    break;
                }
            }
        }
        if ([dict[@"left"] integerValue] == 1 || [dict[@"kicked"] integerValue] == 1) {
            isMember = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.adminId = adminId;
            self.isMember = isMember;
            if (title.length > 0) {
                self.chatTitle = title;
                self.headerTitleLabel.text = title;
            }
            if (photo.length > 0) {
                self.chatPhotoURL = photo;
                [[VKImageLoader sharedLoader] loadImageWithURL:photo completion:^(UIImage *img) {
                    if (img) self.headerAvatarView.image = img;
                }];
            }
        });
        
        // Загружаем профили участников
        if ([users isKindOfClass:[NSArray class]] && users.count > 0) {
            if ([users[0] isKindOfClass:[NSDictionary class]]) {
                [self.members removeAllObjects];
                for (NSDictionary *uDict in users) {
                    VKUser *u = [VKUser userFromDictionary:uDict];
                    if (u) [self.members addObject:u];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isLoading = NO;
                    self.membersCount = self.members.count;
                    self.headerMembersLabel.text = [self membersCountString:self.membersCount];
                    [self.tableView reloadData];
                });
                return;
            }
            
            NSMutableArray *uids = [NSMutableArray array];
            for (id item in users) [uids addObject:[item description]];
            
            NSDictionary *userParams = @{
                @"user_ids": [uids componentsJoinedByString:@","],
                @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
            };
            
            [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:userParams completionHandler:^(id uResponse, NSError *uError) {
                self.isLoading = NO;
                if (!uError && [uResponse isKindOfClass:[NSDictionary class]]) {
                    NSArray *items = uResponse[@"response"] ?: uResponse;
                    if ([items isKindOfClass:[NSArray class]]) {
                        [self.members removeAllObjects];
                        for (NSDictionary *uDict in items) {
                            VKUser *u = [VKUser userFromDictionary:uDict];
                            if (u) [self.members addObject:u];
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.membersCount = self.members.count;
                            self.headerMembersLabel.text = [self membersCountString:self.membersCount];
                            [self.tableView reloadData];
                        });
                    }
                }
            }];
        } else {
            self.isLoading = NO;
        }
    }];
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        // Уведомления и Вложения
        return 2;
    } else if (section == 1) {
        // Участники: кнопка «Добавить участника» + сами участники
        return (self.isMember ? 1 : 0) + self.members.count;
    } else if (section == 2) {
        // Действия: Покинуть/Вернуться + Очистить историю
        return 2;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return @"УЧАСТНИКИ";
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && (self.isMember ? indexPath.row > 0 : YES)) {
        return 50.0;
    }
    return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // 1. Секция уведомлений и вложений
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            static NSString *MuteCellId = @"VKChatMuteCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MuteCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MuteCellId];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectZero];
                sw.on = YES;
                cell.accessoryView = sw;
            }
            cell.textLabel.text = @"Уведомления";
            cell.textLabel.textColor = [UIColor blackColor];
            cell.imageView.image = [UIImage imageNamed:@"chat_mute"];
            return cell;
        } else {
            static NSString *MediaCellId = @"VKChatMediaCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MediaCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MediaCellId];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
            cell.textLabel.text = @"Вложения";
            cell.textLabel.textColor = [UIColor blackColor];
            cell.imageView.image = [UIImage imageNamed:@"chat_shared_media"];
            return cell;
        }
    }
    
    // 2. Секция участников
    if (indexPath.section == 1) {
        // Кнопка «Добавить участника»
        if (self.isMember && indexPath.row == 0) {
            static NSString *AddMemberCellId = @"VKChatAddMemberCell";
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:AddMemberCellId];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:AddMemberCellId];
            }
            cell.textLabel.text = @"Добавить участника";
            cell.textLabel.textColor = [[VKThemeManager sharedManager] accentColor];
            cell.imageView.image = nil;
            return cell;
        }
        
        // Строка участника
        NSInteger memberIndex = self.isMember ? (indexPath.row - 1) : indexPath.row;
        static NSString *UserCellId = @"VKChatUserCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:UserCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:UserCellId];
            
            UIImageView *av = [[UIImageView alloc] initWithFrame:CGRectMake(12, 7, 36, 36)];
            av.tag = 3001;
            av.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:36.0];
            av.clipsToBounds = YES;
            av.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
            [cell.contentView addSubview:av];
            
            UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(58, 7, tableView.bounds.size.width - 96, 18)];
            name.tag = 3002;
            name.font = [UIFont boldSystemFontOfSize:14.5];
            name.textColor = [UIColor blackColor];
            name.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:name];
            
            UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(58, 26, tableView.bounds.size.width - 96, 16)];
            status.tag = 3003;
            status.font = [UIFont systemFontOfSize:11.5];
            status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            [cell.contentView addSubview:status];
            
            UIImageView *badge = [[UIImageView alloc] initWithFrame:CGRectMake(tableView.bounds.size.width - 34, 15, 20, 20)];
            badge.tag = 3004;
            badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
            badge.contentMode = UIViewContentModeScaleAspectFit;
            [cell.contentView addSubview:badge];
        }
        
        if (memberIndex >= (NSInteger)self.members.count) return cell;
        VKUser *user = self.members[memberIndex];
        
        UIImageView *av = (UIImageView *)[cell.contentView viewWithTag:3001];
        UILabel *name = (UILabel *)[cell.contentView viewWithTag:3002];
        UILabel *status = (UILabel *)[cell.contentView viewWithTag:3003];
        UIImageView *badge = (UIImageView *)[cell.contentView viewWithTag:3004];
        
        name.text = user.displayName ?: @"Пользователь";
        
        if (user.uid == self.adminId) {
            status.text = @"Создатель беседы";
            status.textColor = [[VKThemeManager sharedManager] accentColor];
            badge.image = [UIImage imageNamed:@"chat_creator_badge"];
            badge.hidden = NO;
        } else {
            badge.hidden = YES;
            if (user.isOnline) {
                status.text = @"в сети";
                status.textColor = [UIColor colorWithRed:76.0/255.0 green:175.0/255.0 blue:80.0/255.0 alpha:1.0];
            } else {
                status.text = user.lastSeen ?: @"был(а) недавно";
                status.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
            }
        }
        
        av.image = nil;
        if (user.avatarURL.length > 0) {
            [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
                if (img) av.image = img;
            }];
        }
        return cell;
    }
    
    // 3. Секция действий
    if (indexPath.section == 2) {
        static NSString *ActionCellId = @"VKChatActionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ActionCellId];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ActionCellId];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
        }
        if (indexPath.row == 0) {
            if (self.isMember) {
                cell.textLabel.text = @"Покинуть беседу";
                cell.textLabel.textColor = [UIColor colorWithRed:235.0/255.0 green:60.0/255.0 blue:60.0/255.0 alpha:1.0];
            } else {
                cell.textLabel.text = @"Вернуться в беседу";
                cell.textLabel.textColor = [[VKThemeManager sharedManager] accentColor];
            }
            cell.imageView.image = nil;
        } else {
            cell.textLabel.text = @"Очистить историю";
            cell.textLabel.textColor = [UIColor colorWithRed:235.0/255.0 green:60.0/255.0 blue:60.0/255.0 alpha:1.0];
            cell.imageView.image = nil;
        }
        return cell;
    }
    
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Секция участников
    if (indexPath.section == 1) {
        if (self.isMember && indexPath.row == 0) {
            // Добавить участника
            UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Добавить участника"
                                                         message:@"Введите ID или короткое имя пользователя:"
                                                        delegate:self
                                               cancelButtonTitle:@"Отмена"
                                               otherButtonTitles:@"Добавить", nil];
            av.alertViewStyle = UIAlertViewStylePlainTextInput;
            av.tag = 8001;
            [av show];
            return;
        }
        
        NSInteger memberIndex = self.isMember ? (indexPath.row - 1) : indexPath.row;
        if (memberIndex < (NSInteger)self.members.count) {
            VKUser *user = self.members[memberIndex];
            VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:user];
            [self.navigationController pushViewController:profVC animated:YES];
        }
        return;
    }
    
    // Секция действий
    if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            if (self.isMember) {
                UIAlertView *confirm = [[UIAlertView alloc] initWithTitle:@"Покинуть беседу?"
                                                                  message:@"Покинув беседу, Вы не будете получать новых сообщений от участников. Вы сможете вернуться при наличии свободных мест."
                                                                 delegate:self
                                                        cancelButtonTitle:@"Отмена"
                                                        otherButtonTitles:@"Покинуть", nil];
                confirm.tag = 8002;
                [confirm show];
            } else {
                // Вернуться в беседу
                [[VKMessagesService sharedService] returnToChatWithChatId:self.chatId completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            self.isMember = YES;
                            [self loadChatDetails];
                        } else {
                            UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось вернуться в беседу" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                            [err show];
                        }
                    });
                }];
            }
        } else if (indexPath.row == 1) {
            UIAlertView *clearAlert = [[UIAlertView alloc] initWithTitle:@"Очистить историю?"
                                                                 message:@"Вы действительно хотите удалить все сообщения из этой беседы?"
                                                                delegate:self
                                                       cancelButtonTitle:@"Отмена"
                                                       otherButtonTitles:@"Очистить", nil];
            clearAlert.tag = 8003;
            [clearAlert show];
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 8001 && buttonIndex == 1) {
        // Добавление участника
        NSString *input = [alertView textFieldAtIndex:0].text;
        input = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) return;
        
        [[VKAPIClient sharedClient] callMethod:@"users.get" parameters:@{@"user_ids": input} completionHandler:^(id response, NSError *error) {
            if (error || ![response isKindOfClass:[NSDictionary class]]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Пользователь не найден" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                });
                return;
            }
            NSArray *items = response[@"response"] ?: response;
            if ([items isKindOfClass:[NSArray class]] && items.count > 0) {
                NSInteger targetUid = [items[0][@"id"] integerValue] ?: [items[0][@"uid"] integerValue];
                if (targetUid > 0) {
                    [[VKMessagesService sharedService] addChatUserWithUserId:targetUid chatId:self.chatId completion:^(BOOL success, NSError *addErr) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (success) {
                                [self loadChatDetails];
                            } else {
                                UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:addErr.localizedDescription ?: @"Не удалось добавить пользователя" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                [err show];
                            }
                        });
                    }];
                }
            }
        }];
    } else if (alertView.tag == 8002 && buttonIndex == 1) {
        // Покинуть беседу
        [[VKMessagesService sharedService] leaveChatWithChatId:self.chatId completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    self.isMember = NO;
                    [self loadChatDetails];
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось покинуть беседу" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        NSInteger myId = [[VKAuthService sharedService] currentUserId];
        NSInteger memberIndex = self.isMember ? (indexPath.row - 1) : indexPath.row;
        if (self.isMember && indexPath.row == 0) return NO;
        if (memberIndex >= (NSInteger)self.members.count) return NO;
        VKUser *user = self.members[memberIndex];
        return (myId == self.adminId && user.uid != self.adminId);
    }
    return NO;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Исключить";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == 1) {
        NSInteger memberIndex = self.isMember ? (indexPath.row - 1) : indexPath.row;
        if (memberIndex >= (NSInteger)self.members.count) return;
        VKUser *user = self.members[memberIndex];
        
        [[VKMessagesService sharedService] removeChatUserWithUserId:user.uid chatId:self.chatId completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.members removeObjectAtIndex:memberIndex];
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                    self.membersCount = self.members.count;
                    self.headerMembersLabel.text = [self membersCountString:self.membersCount];
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось исключить пользователя" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
    }
}

@end
