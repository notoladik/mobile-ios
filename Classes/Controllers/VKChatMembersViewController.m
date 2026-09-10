#import "VKChatMembersViewController.h"
#import "VKMessagesService.h"
#import "VKProfileViewController.h"
#import "VKAPIClient.h"
#import "VKImageLoader.h"
#import "VKThemeManager.h"
#import "VKAuthService.h"
#import "VKCrashLogger.h"

@interface VKChatMembersViewController () <UIAlertViewDelegate>
@property (nonatomic, strong) NSMutableArray<VKUser *> *members;
@property (nonatomic, assign) BOOL isLoading;
@end

@implementation VKChatMembersViewController

- (instancetype)initWithChatId:(NSInteger)chatId adminId:(NSInteger)adminId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _chatId = chatId;
        _adminId = adminId;
        _members = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Участники";
    self.view.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.backgroundColor = [[VKThemeManager sharedManager] backgroundColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    self.navigationItem.leftBarButtonItem = [[VKThemeManager sharedManager] barButtonItemWithTitle:@"Назад" target:self action:@selector(goBackAction) isBack:YES];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addMemberAction)];
    
    [self loadMembers];
}

- (void)goBackAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)loadMembers {
    if (self.isLoading) return;
    self.isLoading = YES;
    
    NSDictionary *params = @{
        @"chat_id": @(self.chatId),
        @"fields": @"photo_50,photo_100,photo_200,online,last_seen,sex,verified"
    };
    
    [[VKAPIClient sharedClient] callMethod:@"messages.getChat" parameters:params completionHandler:^(id response, NSError *error) {
        if (error) {
            self.isLoading = NO;
            [VKCrashLogger log:@"[VKChatMembersViewController] Error getChat: %@", error.localizedDescription];
            return;
        }
        
        NSDictionary *dict = [response isKindOfClass:[NSDictionary class]] ? (response[@"response"] ?: response) : nil;
        if (!dict) {
            self.isLoading = NO;
            return;
        }
        
        if ([dict[@"admin_id"] integerValue] > 0) {
            self.adminId = [dict[@"admin_id"] integerValue];
        }
        
        NSArray *users = dict[@"users"];
        if ([users isKindOfClass:[NSArray class]] && users.count > 0) {
            // Если users содержит словари объектов
            if ([users[0] isKindOfClass:[NSDictionary class]]) {
                [self.members removeAllObjects];
                for (NSDictionary *uDict in users) {
                    VKUser *u = [VKUser userFromDictionary:uDict];
                    if (u) [self.members addObject:u];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.isLoading = NO;
                    [self.tableView reloadData];
                });
                return;
            }
            
            // Если users содержит массив ID
            NSMutableArray *uids = [NSMutableArray array];
            for (id item in users) {
                [uids addObject:[item description]];
            }
            
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

- (void)addMemberAction {
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Добавить участника"
                                                 message:@"Введите ID или короткое имя пользователя:"
                                                delegate:self
                                       cancelButtonTitle:@"Отмена"
                                       otherButtonTitles:@"Добавить", nil];
    av.alertViewStyle = UIAlertViewStylePlainTextInput;
    av.tag = 6001;
    [av show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 6001 && buttonIndex == 1) {
        NSString *input = [alertView textFieldAtIndex:0].text;
        input = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length == 0) return;
        
        // Резолвим пользователя через users.get
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
                                [self loadMembers];
                            } else {
                                UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:addErr.localizedDescription ?: @"Не удалось добавить пользователя" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                [err show];
                            }
                        });
                    }];
                }
            }
        }];
    }
}

#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.members.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 56.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellId = @"VKChatMemberCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellId];
        cell.backgroundColor = [UIColor clearColor];
        
        UIImageView *avatar = [[UIImageView alloc] initWithFrame:CGRectMake(12, 8, 40, 40)];
        avatar.tag = 2001;
        avatar.layer.cornerRadius = [[VKThemeManager sharedManager] avatarCornerRadiusForSize:40.0];
        avatar.clipsToBounds = YES;
        avatar.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        [cell.contentView addSubview:avatar];
        
        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(62, 8, tableView.bounds.size.width - 74, 20)];
        nameLabel.tag = 2002;
        nameLabel.font = [UIFont boldSystemFontOfSize:15];
        nameLabel.textColor = [UIColor blackColor];
        nameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:nameLabel];
        
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(62, 30, tableView.bounds.size.width - 74, 16)];
        statusLabel.tag = 2003;
        statusLabel.font = [UIFont systemFontOfSize:12];
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
        statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:statusLabel];
    }
    
    if (indexPath.row >= (NSInteger)self.members.count) return cell;
    
    VKUser *user = self.members[indexPath.row];
    UIImageView *avatar = (UIImageView *)[cell.contentView viewWithTag:2001];
    UILabel *nameLabel = (UILabel *)[cell.contentView viewWithTag:2002];
    UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:2003];
    
    nameLabel.text = user.displayName ?: @"Пользователь";
    
    if (user.uid == self.adminId) {
        statusLabel.text = @"Создатель беседы";
        statusLabel.textColor = [[VKThemeManager sharedManager] accentColor];
    } else if (user.isOnline) {
        statusLabel.text = @"в сети";
        statusLabel.textColor = [UIColor colorWithRed:76.0/255.0 green:175.0/255.0 blue:80.0/255.0 alpha:1.0];
    } else {
        statusLabel.text = user.lastSeen ?: @"был(а) недавно";
        statusLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    }
    
    avatar.image = nil;
    if (user.avatarURL.length > 0) {
        [[VKImageLoader sharedLoader] loadImageWithURL:user.avatarURL completion:^(UIImage *img) {
            if (img) avatar.image = img;
        }];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= (NSInteger)self.members.count) return;
    
    VKUser *user = self.members[indexPath.row];
    VKProfileViewController *profVC = [[VKProfileViewController alloc] initWithUser:user];
    [self.navigationController pushViewController:profVC animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger myId = [[VKAuthService sharedService] currentUserId];
    if (indexPath.row >= (NSInteger)self.members.count) return NO;
    VKUser *user = self.members[indexPath.row];
    // Можно исключать если текущий пользователь админ и цель не админ
    return (myId == self.adminId && user.uid != self.adminId);
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Исключить";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        VKUser *user = self.members[indexPath.row];
        [[VKMessagesService sharedService] removeChatUserWithUserId:user.uid chatId:self.chatId completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [self.members removeObjectAtIndex:indexPath.row];
                    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
                } else {
                    UIAlertView *err = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:error.localizedDescription ?: @"Не удалось исключить пользователя" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [err show];
                }
            });
        }];
    }
}

@end
